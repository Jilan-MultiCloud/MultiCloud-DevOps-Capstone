"""Expose real endpoint health and latency for all three clouds to Prometheus."""
import json
import os
import time
from prometheus_client import Gauge, start_http_server
from prometheus_client.parser import text_string_to_metric_families
from app import router

HEALTH = Gauge("capstone_cloud_healthy", "Successful application health check", ["cloud"])
LATENCY = Gauge("capstone_probe_duration_seconds", "Health check duration", ["cloud"])
BACKUP = Gauge("capstone_backup_last_success_timestamp_seconds", "Last verified backup")
BACKUP_ENABLED = Gauge("capstone_backup_monitoring_enabled", "Backup freshness monitoring configured")
SPEND = Gauge("capstone_monthly_cost", "Manually supplied billing amount in declared currency", ["cloud", "currency"])
BUDGET = Gauge("capstone_monthly_budget", "Monthly cost threshold in declared currency", ["cloud", "currency"])
BILLING = Gauge("capstone_billing_data_timestamp_seconds", "Timestamp of supplied billing data")
METRICS_UP = Gauge("capstone_metrics_available", "Runtime metrics endpoint available", ["cloud"])
MEMORY = Gauge("capstone_process_memory_bytes", "Resident memory of sampled process", ["cloud"])
LIMIT = Gauge("capstone_process_memory_limit_bytes", "Configured process memory budget", ["cloud"])
CPU = Gauge("capstone_process_cpu_seconds", "Cumulative CPU of sampled process; replicas may differ", ["cloud"])


def collect_once():
    for cloud in router.CLOUDS:
        started = time.monotonic()
        HEALTH.labels(cloud).set(int(router.check_cloud(cloud)["healthy"]))
        LATENCY.labels(cloud).set(time.monotonic() - started)
        METRICS_UP.labels(cloud).set(0)
        for gauge in (MEMORY, LIMIT, CPU):
            try:
                gauge.remove(cloud)
            except KeyError:
                pass
        try:
            response = router.request_cloud(cloud, "/metrics")
            response.raise_for_status()
            samples = {sample.name: sample.value
                       for family in text_string_to_metric_families(response.text)
                       for sample in family.samples}
            if "process_cpu_seconds_total" not in samples:
                raise ValueError("No process metrics")
            for name, gauge in (("process_resident_memory_bytes", MEMORY),
                                ("process_memory_limit_bytes", LIMIT),
                                ("process_cpu_seconds_total", CPU)):
                if name in samples:
                    gauge.labels(cloud).set(samples[name])
            METRICS_UP.labels(cloud).set(1)
        except (router.requests.RequestException, RuntimeError, ValueError, router.BotoCoreError):
            pass
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
            currency = values.get("currency", billing.get("currency", ""))
            SPEND.labels(cloud, currency).set(values["actual"])
            BUDGET.labels(cloud, currency).set(values["budget"])
        BILLING.set(float(billing["timestamp"]))
    except (OSError, ValueError, KeyError, TypeError):
        pass


if __name__ == "__main__":
    start_http_server(9108)
    while True:
        collect_once()
        time.sleep(max(5, int(os.environ.get("PROBE_INTERVAL", "30"))))
