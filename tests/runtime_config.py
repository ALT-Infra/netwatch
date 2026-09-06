"""Run inside the matching Frigate image to use its real parser and config writer."""

import os
import tempfile
import unittest
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from unittest.mock import patch

from frigate.config import FrigateConfig
from frigate.util.builtin import clean_camera_user_pass
from frigate.util.netwatch_config import commit_config, redact_config
from ruamel.yaml import YAML


class ConfigTransactions(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.path = Path(self.folder.name) / "config.yml"
        self.path.write_text("mqtt:\n  enabled: false\ncameras: {}\n")
        self.path.chmod(0o600)

    def test_invalid_real_config_preserves_original_bytes(self):
        before = self.path.read_bytes()
        with self.assertRaises(Exception):
            commit_config(
                self.path,
                FrigateConfig.parse_yaml,
                updates={
                    "mqtt.port": "not-a-port",
                    "cameras.broken.ffmpeg.inputs": [
                        {"path": "rtsp://a:b@host/x", "roles": ["invalid"]}
                    ],
                },
            )
        self.assertEqual(before, self.path.read_bytes())
        self.assertEqual(list(self.path.parent.glob(".netwatch-config-*")), [])

    def test_failed_replace_preserves_original(self):
        before = self.path.read_bytes()
        with patch("frigate.util.netwatch_config.os.replace", side_effect=OSError("full")):
            with self.assertRaises(OSError):
                commit_config(
                    self.path,
                    FrigateConfig.parse_yaml,
                    updates={"detect.enabled": False},
                )
        self.assertEqual(before, self.path.read_bytes())

    def test_concurrent_updates_are_not_lost(self):
        def write(index):
            commit_config(
                self.path,
                YAML().load,
                updates={f"env_vars.FRIGATE_TEST_{index}": str(index)},
            )

        with ThreadPoolExecutor(max_workers=4) as pool:
            list(pool.map(write, range(12)))
        data = YAML().load(self.path.read_text())
        self.assertEqual(len(data["env_vars"]), 12)
        self.assertEqual(os.stat(self.path).st_mode & 0o777, 0o600)

    def test_camera_removal_prunes_private_sources_but_keeps_shared(self):
        self.path.write_text("""mqtt:
  enabled: false
cameras:
  first:
    live:
      streams: {Private: first_private, Shared: shared}
  second:
    live:
      streams: {Shared: shared}
go2rtc:
  streams:
    first_private: rtsp://private:secret@host/private
    shared: rtsp://shared:secret@host/shared
    independent: rtsp://operator:secret@host/independent
""")
        commit_config(self.path, YAML().load, updates={"cameras.first": None})
        data = YAML().load(self.path.read_text())
        self.assertEqual(set(data["go2rtc"]["streams"]), {"shared", "independent"})
        self.assertNotIn("private:secret", self.path.read_text())

    def test_last_camera_removal_passes_real_parser(self):
        self.path.write_text(
            "mqtt: {enabled: false}\n"
            "cameras: {first: {live: {streams: {Main: first}}}}\n"
            "go2rtc: {streams: {first: 'rtsp://secret@host/live'}}\n"
        )
        result = commit_config(self.path, FrigateConfig.parse_yaml, updates={"cameras.first": None})
        self.assertEqual(result.cameras, {})
        self.assertEqual(YAML().load(self.path.read_text())["cameras"], {})
        self.assertNotIn("secret", self.path.read_text())

    def test_public_config_omits_nested_secrets(self):
        public = redact_config(
            {
                "cameras": {"first": {"onvif": {"host": "camera", "password": "private"}}},
                "colormap": {0: [255, 0, 0]},
                "environment_vars": {"FRIGATE_SECRET": "private"},
                "env_vars": {"FRIGATE_SECRET": "private"},
                "go2rtc": {"rtsp": {"password": "private"}},
            }
        )
        self.assertNotIn("private", str(public))
        self.assertEqual(public["colormap"][0], [255, 0, 0])
        self.assertEqual(public["cameras"]["first"]["onvif"]["host"], "camera")

    def test_scrubs_query_tokens_and_url_passwords(self):
        value = clean_camera_user_pass("rtsp://alice:private@host/live?token=opaque&channel=1")
        self.assertNotIn("private", value)
        self.assertNotIn("opaque", value)
        self.assertIn("channel=1", value)


if __name__ == "__main__":
    unittest.main()
