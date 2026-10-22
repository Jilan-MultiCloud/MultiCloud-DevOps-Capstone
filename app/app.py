
import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse

CLOUD_NAME = os.getenv("CLOUD_NAME", "local")
PORT = int(os.getenv("PORT", "8080"))


class AppHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        # Ignore query parameters when matching the URL path.
        path = urlparse(self.path).path

        if path == "/health":
            status = 200
            response = {"status": "healthy", "cloud": CLOUD_NAME}
        elif path == "/":
            status = 200
            response = {
                "project": "Multi-Cloud Deployment and Management with Terraform",
                "cloud": CLOUD_NAME,
                "status": "running",
            }
        else:
            status = 404
            response = {"error": "not found"}

        body = json.dumps(response).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        print(f"{self.address_string()} - {format % args}")


if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", PORT), AppHandler)
    print(f"Starting app for {CLOUD_NAME} on port {PORT}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping application.")
    finally:
        server.server_close()
