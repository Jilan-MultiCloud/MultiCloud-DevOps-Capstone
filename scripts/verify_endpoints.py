"""Record current application health without changing cloud resources."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
from app import router


def collect():
    report = {"checked_at": datetime.now(timezone.utc).isoformat(), "clouds": {}}
    for cloud in router.CLOUDS:
        result = router.check_cloud(cloud)
        result.pop("detail", None)
        try:
            metrics = router.request_cloud(cloud, "/metrics")
            result["metrics_available"] = metrics.status_code == 200 and "process_cpu_seconds_total" in metrics.text
        except (router.requests.RequestException, RuntimeError, router.BotoCoreError):
            result["metrics_available"] = False
        report["clouds"][cloud] = result
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    report = collect()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))
    raise SystemExit(0 if all(item["healthy"] for item in report["clouds"].values()) else 1)
