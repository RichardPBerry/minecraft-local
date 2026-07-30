import os
import subprocess
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import app.app as app_module

app = app_module.app


class FlaskAppTests(unittest.TestCase):
    def setUp(self):
        # Prevent availability checks from failing in test environments by
        # stubbing out the docker availability check.
        self.ensure_patcher = patch("app.app.docker_wrapper.ensure_docker_available")
        self.mock_ensure = self.ensure_patcher.start()
        self.addCleanup(self.ensure_patcher.stop)

        self.client = app.test_client()

    @patch("app.app.subprocess.run")
    def test_api_servers_lists_servers(self, mock_run):
        mock_run.return_value = subprocess.CompletedProcess(
            args=[],
            returncode=0,
            stdout="NAME STATUS\nserver Up",
            stderr="",
        )

        response = self.client.get("/api/servers")

        self.assertEqual(response.status_code, 200)
        data = response.get_json()
        self.assertEqual(data[0]["id"], "001-survival-vanilla")
        self.assertEqual(data[0]["status"], "running")

    @patch("app.app.subprocess.run")
    def test_start_server_returns_success(self, mock_run):
        mock_run.return_value = subprocess.CompletedProcess(
            args=[],
            returncode=0,
            stdout="Started",
            stderr="",
        )

        response = self.client.post("/api/start/001-survival-vanilla")

        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.get_json()["success"])

    @patch("app.app.subprocess.run")
    def test_stop_server_uses_compose_service_name(self, mock_run):
        mock_run.side_effect = [
            subprocess.CompletedProcess(args=[], returncode=0, stdout="", stderr=""),
            subprocess.CompletedProcess(args=[], returncode=0, stdout="NAME STATUS\nserver Up", stderr=""),
        ]

        response = self.client.post("/api/stop/001-survival-vanilla")

        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.get_json()["success"])
        stop_command = mock_run.call_args_list[0].args[0]
        self.assertIn("survival-server-001", stop_command)

    @patch("app.app.app.run")
    def test_main_uses_safe_runtime_defaults(self, mock_run):
        with patch.dict(os.environ, {"FLASK_HOST": "0.0.0.0", "FLASK_PORT": "7000"}, clear=False):
            app_module.main()

        mock_run.assert_called_once_with(host="0.0.0.0", port=7000, debug=False, use_reloader=False)


if __name__ == "__main__":
    unittest.main()
