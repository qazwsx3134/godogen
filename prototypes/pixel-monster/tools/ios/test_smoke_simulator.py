#!/usr/bin/env python3
"""Check native smoke failure detection without starting CoreSimulator."""
from __future__ import annotations

import importlib.util
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest import mock

spec = importlib.util.spec_from_file_location("native_smoke", Path(__file__).with_name("smoke_simulator.py"))
assert spec and spec.loader
smoke = importlib.util.module_from_spec(spec)
spec.loader.exec_module(smoke)


class NativeSmokeTests(unittest.TestCase):
    def test_running_uikit_service_is_recognized(self):
        result = SimpleNamespace(stdout="6257\t0\tUIKitApplication:org.godogen.pixelmonster.ci[uuid][rb-legacy]\n")
        with mock.patch.object(smoke, "_run", return_value=result):
            self.assertEqual(smoke._app_pid("simulator", "org.godogen.pixelmonster.ci"), 6257)

    def test_stopped_service_and_another_bundle_cannot_pass(self):
        for output in (
            "-\t1\tUIKitApplication:org.godogen.pixelmonster.ci[uuid]\n",
            "123\t0\tUIKitApplication:org.godogen.pixelmonster.ci.other[uuid]\n",
        ):
            with self.subTest(output=output), \
                 mock.patch.object(smoke, "_run", return_value=SimpleNamespace(stdout=output)), \
                 self.assertRaises(smoke.SmokeError):
                smoke._app_pid("simulator", "org.godogen.pixelmonster.ci")

    def test_resource_failure_is_fatal_even_with_live_process(self):
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / "stderr.log"
            log.write_text('ERROR: Failed to load script "res://ui/main.gd"\n')
            with self.assertRaises(smoke.SmokeError):
                smoke._check_logs([log])


if __name__ == "__main__":
    unittest.main()
