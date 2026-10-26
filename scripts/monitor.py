"""Expose real endpoint health and latency for all three clouds to Prometheus."""
import json
import os
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from prometheus_client import Gauge, start_http_server
from app import router

HEALTH = Gauge("capstone_cloud_healthy", "Successful application health check", ["cloud"])
LATENCY = Gauge("capstone_probe_duration_seconds", "Health check duration", ["cloud"])
BACKUP = Gauge("capstone_backup_last_success_timestamp_seconds", "Last verified backup")
BACKUP_ENABLED = Gauge("capstone_backup_monitoring_enabled", "Backup freshness monitoring configured")
SPEND = Gauge("capstone_monthly_cost", "Manually supplied billing amount in declared currency", ["cloud", "currency"])
BUDGET = Gauge("capstone_monthly_budget", "Monthly cost threshold in declared currency", ["cloud", "currency"])
BILLING = Gauge("capstone_billing_data_timestamp_seconds", "Timestamp of supplied billing data")


def collect_once():
    for cloud in router.CLOUDS:
        started = time.monotonic()
        HEALTH.labels(cloud).set(int(router.check_cloud(cloud)["healthy"]))
        LATENCY.labels(cloud).set(time.monotonic() - started)
    backup_path = os.environ.get("BACKUP_SUCCESS_FILE")
    BACKUP_ENABLED.set(bool(backup_path))
    BACKUP.set(0)
    if backup_path:
        try:
            with open(backup_path, encoding="utf-8") as stream:
                BACKUP.set(float(json.load(stream)["timestamp"]))
        except (OSError, ValueError, KeyError):
            pass  # Missing/invalid evidence must trigger the stale-backup rule.
    SPEND.clear()
    BUDGET.clear()
    BILLING.set(0)
    try:
        with open(os.environ.get("BILLING_FILE", "/data/billing.json"), encoding="utf-8") as stream:
            billing = json.load(stream)
        for cloud, values in billing["clouds"].items():
            SPEND.labels(cloud, billing["currency"]).set(values["actual"])
            BUDGET.labels(cloud, billing["currency"]).set(values["budget"])
        BILLING.set(float(billing["timestamp"]))
    except (OSError, ValueError, KeyError, TypeError):
        pass


if __name__ == "__main__":
    start_http_server(9108)
    while True:
        collect_once()
        time.sleep(max(5, int(os.environ.get("PROBE_INTERVAL", "30"))))
