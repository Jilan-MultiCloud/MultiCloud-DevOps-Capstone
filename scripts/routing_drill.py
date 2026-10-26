"""Exercise local failover against real cloud backends without stopping them."""
import argparse
from datetime import datetime, timezone
from http.server import ThreadingHTTPServer
import json
import os
from pathlib import Path
import threading
import requests
from app import router


def drill():
    previous = os.environ.get("ENABLE_SIMULATION")
    os.environ["ENABLE_SIMULATION"] = "true"
    router._simulated_down.clear()
    server = ThreadingHTTPServer(("127.0.0.1", 0), router.RouterHandler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    base = f"http://127.0.0.1:{server.server_port}"
    results = {"checked_at": datetime.now(timezone.utc).isoformat(),
               "scope": "local router; live cloud backends; simulated backend exclusions",
               "outages": []}
    try:
        response = requests.get(base + "/status", timeout=60)
        response.raise_for_status()
        results["baseline"] = response.json()
        if not all(item["healthy"] for item in results["baseline"]["clouds"].values()):
            raise RuntimeError("All three backends must be healthy before the drill")
        for cloud in router.CLOUDS:
            requests.get(base + f"/simulate/{cloud}/down", timeout=5).raise_for_status()
            response = requests.get(base + "/", timeout=60)
            response.raise_for_status()
            selected = response.headers["X-Selected-Cloud"]
            if selected == cloud:
                raise AssertionError("Traffic selected the excluded backend")
            results["outages"].append({"excluded": cloud, "selected": selected,
                                      "status": response.status_code})
            requests.get(base + f"/simulate/{cloud}/up", timeout=5).raise_for_status()
        response = requests.get(base + "/status", timeout=60)
        response.raise_for_status()
        results["recovery"] = response.json()
        if not all(item["healthy"] for item in results["recovery"]["clouds"].values()):
            raise AssertionError("Not all backends recovered")
        return results
    finally:
        router._simulated_down.clear()
        server.shutdown()
        server.server_close()
        thread.join()
        if previous is None:
            os.environ.pop("ENABLE_SIMULATION", None)
        else:
            os.environ["ENABLE_SIMULATION"] = previous


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    result = drill()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps(result, indent=2))
