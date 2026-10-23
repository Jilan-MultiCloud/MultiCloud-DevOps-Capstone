
import json
import os
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit

import boto3
import requests
from requests_aws4auth import AWS4Auth


PORT = int(os.getenv("PORT", "8090"))
AWS_REGION = os.getenv("AWS_REGION", "ap-south-1")
AWS_FUNCTION_URL = os.getenv(
    "AWS_FUNCTION_URL",
    "https://hr5wkrgtaoxun4fbodccb6a7zu0bqjya"
    ".lambda-url.ap-south-1.on.aws/",
).rstrip("/")
GCP_SERVICE_URL = os.getenv(
    "GCP_SERVICE_URL",
    "https://multicloud-capstone-kmacr5flaa-el.a.run.app",
).rstrip("/")
HTTP_TIMEOUT = float(os.getenv("HTTP_TIMEOUT", "4"))

CLOUDS = ("aws", "gcp")
_counter_lock = threading.Lock()
_state_lock = threading.Lock()
_next_cloud = 0

# Local test controls: simulate an outage without touching real cloud services.
_simulated_down = set()

session = boto3.Session(region_name=AWS_REGION)


def aws_auth():
    credentials = session.get_credentials()
    if credentials is None:
        raise RuntimeError(
            "AWS credentials not found. Check your AWS CLI authentication."
        )

    frozen = credentials.get_frozen_credentials()
    return AWS4Auth(
        frozen.access_key,
        frozen.secret_key,
        AWS_REGION,
        "lambda",
        session_token=frozen.token,
    )


def cloud_url(cloud, path):
    base = AWS_FUNCTION_URL if cloud == "aws" else GCP_SERVICE_URL
    return f"{base}{path}"


def is_simulated_down(cloud):
    with _state_lock:
        return cloud in _simulated_down


def set_simulated_down(cloud, down):
    with _state_lock:
        if down:
            _simulated_down.add(cloud)
        else:
            _simulated_down.discard(cloud)


def request_cloud(cloud, path):
    if is_simulated_down(cloud):
        raise requests.ConnectionError(
            f"{cloud} is marked unavailable by the local test simulator"
        )

    auth = aws_auth() if cloud == "aws" else None
    return requests.get(
        cloud_url(cloud, path),
        auth=auth,
        timeout=HTTP_TIMEOUT,
        allow_redirects=False,
    )


def check_cloud(cloud):
    if is_simulated_down(cloud):
        return {"healthy": False, "reason": "simulated_outage"}

    try:
        response = request_cloud(cloud, "/health")

        if response.status_code != 200:
            return {
                "healthy": False,
                "status_code": response.status_code,
            }

        payload = response.json()

        return {
            "healthy": payload.get("status") == "healthy",
            "status_code": response.status_code,
            "response": payload,
        }

    except requests.RequestException as exc:
        # Show safe diagnostic details, not request headers or credentials.
        print(f"Health check failed for {cloud}: {exc}")
        return {
            "healthy": False,
            "error": type(exc).__name__,
            "detail": str(exc),
        }

    except (ValueError, RuntimeError) as exc:
        print(f"Health check failed for {cloud}: {type(exc).__name__}")
        return {
            "healthy": False,
            "error": type(exc).__name__,
        }

def healthy_clouds():
    return [cloud for cloud in CLOUDS if check_cloud(cloud)["healthy"]]


def choose_starting_cloud(healthy):
    global _next_cloud

    with _counter_lock:
        start = _next_cloud
        _next_cloud = (_next_cloud + 1) % len(CLOUDS)

    order = [
        CLOUDS[(start + offset) % len(CLOUDS)]
        for offset in range(len(CLOUDS))
    ]
    return [cloud for cloud in order if cloud in healthy]


class RouterHandler(BaseHTTPRequestHandler):
    def send_json(self, status_code, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        path = urlsplit(self.path).path

        # Only allow simulation controls when explicitly enabled.
        # The server also binds to loopback by default.
        if path.startswith("/simulate/"):
            if os.getenv("ENABLE_SIMULATION", "true").lower() != "true":
                self.send_json(403, {"error": "Simulation is disabled"})
                return

            parts = path.strip("/").split("/")
            if (
                len(parts) != 3
                or parts[0] != "simulate"
                or parts[1] not in CLOUDS
                or parts[2] not in ("down", "up")
            ):
                self.send_json(
                    400,
                    {"error": "Use /simulate/aws/down, /simulate/aws/up, "
                              "/simulate/gcp/down, or /simulate/gcp/up"},
                )
                return

            cloud = parts[1]
            down = parts[2] == "down"
            set_simulated_down(cloud, down)
            self.send_json(
                200,
                {
                    "cloud": cloud,
                    "simulated_down": down,
                    "message": "Local simulation updated; real cloud unchanged",
                },
            )
            return

        if path == "/health":
            self.send_json(200, {"status": "healthy", "service": "router"})
            return

        if path == "/status":
            status = {cloud: check_cloud(cloud) for cloud in CLOUDS}
            available = any(item["healthy"] for item in status.values())
            self.send_json(
                200 if available else 503,
                {
                    "router": "healthy" if available else "degraded",
                    "clouds": status,
                },
            )
            return

        healthy = healthy_clouds()
        if not healthy:
            self.send_json(
                503,
                {"error": "No healthy cloud endpoints available"},
            )
            return

        last_error = None
        for cloud in choose_starting_cloud(healthy):
            try:
                response = request_cloud(cloud, self.path)
                if response.status_code >= 500:
                    last_error = f"{cloud} returned HTTP {response.status_code}"
                    continue

                body = response.content
                self.send_response(response.status_code)
                self.send_header(
                    "Content-Type",
                    response.headers.get("Content-Type", "application/json"),
                )
                self.send_header("Content-Length", str(len(body)))
                self.send_header("X-Selected-Cloud", cloud)
                self.end_headers()
                self.wfile.write(body)
                print(f"{self.path} -> {cloud} HTTP {response.status_code}")
                return
            except (requests.RequestException, RuntimeError) as exc:
                last_error = f"{cloud} request failed: {type(exc).__name__}"

        self.send_json(
            502,
            {
                "error": "All candidate cloud requests failed",
                "detail": last_error,
            },
        )

    def log_message(self, format_string, *args):
        print(f"{self.address_string()} - {format_string % args}")


if __name__ == "__main__":
    server = ThreadingHTTPServer(("127.0.0.1", PORT), RouterHandler)
    print(f"Router listening at http://127.0.0.1:{PORT}")
    print("Local simulation endpoints enabled.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping router.")
    finally:
        server.server_close()
