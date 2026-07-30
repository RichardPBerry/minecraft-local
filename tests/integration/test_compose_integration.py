import os
import tempfile
from pathlib import Path

import unittest

import app.app as app_module


class ComposeIntegrationTests(unittest.TestCase):
    def test_compose_service_parsing_and_resolution(self):
        tmpdir = tempfile.TemporaryDirectory()
        try:
            compose_path = Path(tmpdir.name) / "compose.yaml"
            compose_content = """
services:
  my-service:
    image: alpine:3.16
  other-service:
    image: busybox
"""
            compose_path.write_text(compose_content, encoding="utf-8")

            server = {
                "id": "int-test",
                "compose_project": str(compose_path),
                "service_name": "my-service",
            }

            services = app_module.get_compose_service_names(compose_path)
            self.assertIn("my-service", services)
            self.assertIn("other-service", services)

            resolved = app_module.resolve_service_name(server)
            self.assertEqual(resolved, "my-service")
        finally:
            tmpdir.cleanup()
