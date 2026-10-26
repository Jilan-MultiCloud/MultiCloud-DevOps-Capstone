import json
import os
import threading
import unittest
from http.server import ThreadingHTTPServer
from unittest.mock import patch
import requests
from app.app import AppHandler
from app.lambda_function import lambda_handler
from app import router


class HttpTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), AppHandler)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.url = f"http://127.0.0.1:{cls.server.server_port}"

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join()

    def test_container_routes(self):
        for path, status in [("/", 200), ("/health?probe=1", 200), ("/missing", 404)]:
            self.assertEqual(requests.get(self.url + path, timeout=3).status_code, status)

    def test_lambda_routes(self):
        for path, expected in [("/", 200), ("/health", 200), ("/missing", 404)]:
            result = lambda_handler({"requestContext": {"http": {"path": path}}}, None)
            self.assertEqual(result["statusCode"], expected)
            self.assertIsInstance(json.loads(result["body"]), dict)


class RouterTests(unittest.TestCase):
    def setUp(self):
        router._simulated_down.clear()
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), router.RouterHandler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.url = f"http://127.0.0.1:{self.server.server_port}"

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()
        router._simulated_down.clear()

    def response(self, code=200):
        result = requests.Response()
        result.status_code = code
        result._content = b'{"status":"healthy"}'
        return result

    def test_azure_is_a_candidate_and_simulation_is_disabled_by_default(self):
        with patch.dict(os.environ, {"ENABLE_SIMULATION": "false"}):
            self.assertEqual(requests.get(self.url + "/simulate/aws/down", timeout=3).status_code, 403)
        with patch.object(router, "healthy_clouds", return_value=["azure"]), patch.object(
                router, "request_cloud", return_value=self.response()):
            response = requests.get(self.url + "/", timeout=3)
            self.assertEqual(response.headers["X-Selected-Cloud"], "azure")

    def test_real_backend_failure_retries_and_preserves_query(self):
        with patch.object(router, "healthy_clouds", return_value=["aws", "azure"]), patch.object(
                router, "choose_starting_cloud", return_value=["aws", "azure"]), patch.object(
                router, "request_cloud", side_effect=[requests.ConnectionError(), self.response()]) as fetch:
            response = requests.get(self.url + "/?key=value", timeout=3)
            self.assertEqual(response.headers["X-Selected-Cloud"], "azure")
            self.assertEqual(fetch.call_args.args, ("azure", "/?key=value"))

    def test_total_outage_and_recovery(self):
        with patch.object(router, "request_cloud", return_value=self.response()):
            for cloud in router.CLOUDS:
                router.set_simulated_down(cloud, True)
            self.assertEqual(requests.get(self.url, timeout=3).status_code, 503)
            router.set_simulated_down("gcp", False)
            response = requests.get(self.url, timeout=3)
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.headers["X-Selected-Cloud"], "gcp")

    def test_invalid_health_payload_is_unhealthy(self):
        response = self.response()
        response._content = b"not-json"
        with patch.object(router, "request_cloud", return_value=response):
            self.assertFalse(router.check_cloud("gcp")["healthy"])


if __name__ == "__main__":
    unittest.main()
