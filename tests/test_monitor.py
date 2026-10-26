import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import requests
from scripts import monitor


class MonitorTests(unittest.TestCase):
    def test_metrics_and_missing_evidence_are_not_reported_as_success(self):
        response = requests.Response()
        response.status_code = 200
        response._content = (b"process_cpu_seconds_total 3\n"
                             b"process_resident_memory_bytes 100\n"
                             b"process_memory_limit_bytes 200\n")
        with tempfile.TemporaryDirectory() as directory:
            env = {"BILLING_FILE": directory + "/missing.json",
                   "BACKUP_SUCCESS_FILE": directory + "/missing-backup.json"}
            with patch.dict("os.environ", env), patch.object(monitor.router, "check_cloud",
                    return_value={"healthy": True}), patch.object(monitor.router, "request_cloud",
                    return_value=response):
                monitor.collect_once()
                self.assertEqual(monitor.METRICS_UP.labels("azure")._value.get(), 1)
                self.assertEqual(monitor.MEMORY.labels("azure")._value.get(), 100)
                self.assertEqual(monitor.BILLING._value.get(), 0)
                self.assertEqual(monitor.BACKUP._value.get(), 0)

    def test_per_cloud_currencies_and_missing_metrics(self):
        with tempfile.TemporaryDirectory() as directory:
            billing = Path(directory) / "billing.json"
            billing.write_text(json.dumps({"timestamp": 123, "clouds": {
                "aws": {"actual": 1, "budget": 5, "currency": "USD"},
                "azure": {"actual": 10, "budget": 50, "currency": "INR"}}}))
            with patch.dict("os.environ", {"BILLING_FILE": str(billing)}), patch.object(
                    monitor.router, "check_cloud", return_value={"healthy": False}), patch.object(
                    monitor.router, "request_cloud", side_effect=requests.ConnectionError):
                monitor.collect_once()
                self.assertEqual(monitor.METRICS_UP.labels("aws")._value.get(), 0)
                self.assertEqual(monitor.SPEND.labels("azure", "INR")._value.get(), 10)
