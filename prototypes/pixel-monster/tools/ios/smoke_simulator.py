#!/usr/bin/env python3
"""Run a bounded, non-destructive iOS simulator smoke test for a built app."""
from __future__ import annotations

import argparse
import json
import plistlib
import re
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Dict, Optional, Sequence, Tuple

BOOT_TIMEOUT_SECONDS = 120.0
LIVE_WAIT_SECONDS = 5.0
LOG_ERROR_RE = re.compile(
    r"SCRIPT ERROR|Parse Error|failed to load (?:script|resource)|"
    r"error loading resource|resource load error|(?:fatal|uncaught) error|"
    r"(?:crash|crashed|SIGABRT|SIGSEGV|EXC_CRASH|EXC_BAD_ACCESS)", re.IGNORECASE)

class SmokeError(RuntimeError):
    """A smoke-test precondition or runtime check failed."""

def run_command(args: Sequence[str], timeout: float) -> Any:
    try:
        return subprocess.run(list(args), stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                              text=True, check=False, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise SmokeError("command failed: %s (%s)" % (" ".join(args), exc)) from exc


def _run(args: Sequence[str], label: str, timeout: float) -> Any:
    result = run_command(args, timeout)
    if result.returncode:
        detail = (result.stderr or result.stdout or "").strip()
        raise SmokeError("%s failed (%d): %s" % (label, result.returncode, detail[:2000]))
    return result
def _best_effort(args: Sequence[str]) -> None:
    try:
        run_command(args, 15.0)
    except SmokeError:
        pass
def _read_build_inputs(build_dir: Path) -> Tuple[str, str, Path]:
    info_path = build_dir / "build-info.txt"
    if not info_path.is_file():
        raise SmokeError("missing %s" % info_path)
    values: Dict[str, str] = {}
    for line in info_path.read_text(encoding="utf-8").splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip()
    missing = [key for key in ("simulator_udid", "bundle_identifier", "app") if not values.get(key)]
    if missing:
        raise SmokeError("build-info.txt missing: %s" % ", ".join(missing))

    app = Path(values["app"]).expanduser()
    if not app.is_absolute(): app = build_dir / app
    app = app.resolve()
    if not app.is_dir() or app.suffix != ".app":
        raise SmokeError("built app is not an existing .app: %s" % app)
    plist_path = app / "Info.plist"
    try:
        with plist_path.open("rb") as plist_file: bundle = plistlib.load(plist_file).get("CFBundleIdentifier")
    except (OSError, plistlib.InvalidFileException, ValueError, AttributeError) as exc:
        raise SmokeError("cannot read %s: %s" % (plist_path, exc)) from exc
    if bundle != values["bundle_identifier"]:
        raise SmokeError("Info.plist bundle identifier does not match build-info.txt")
    return values["simulator_udid"], values["bundle_identifier"], app
def _device_state(udid: str) -> str:
    result = _run(["xcrun", "simctl", "list", "devices", "available", "--json"], "simulator listing", 30.0)
    try:
        devices = json.loads(result.stdout).get("devices", {})
    except (AttributeError, TypeError, ValueError) as exc:
        raise SmokeError("simulator listing was not valid JSON") from exc
    for device_group in devices.values():
        for device in device_group if isinstance(device_group, list) else []:
            if device.get("udid") == udid:
                if device.get("isAvailable") is False: raise SmokeError("simulator is unavailable: %s" % udid)
                return str(device.get("state", ""))
    raise SmokeError("simulator UDID not found in available devices: %s" % udid)
def _app_pid(udid: str, bundle: str) -> int:
    result = _run(["xcrun", "simctl", "spawn", udid, "launchctl", "list"], "launchctl list", 20.0)
    service = re.compile(r"(?:UIKitApplication:)?" + re.escape(bundle) + r"(?:\[[^\]]+\])*")
    found = False
    for line in result.stdout.splitlines():
        fields = line.split()
        if len(fields) < 3 or not service.fullmatch(fields[-1]):
            continue
        found = True
        try:
            pid = int(fields[0])
        except ValueError:
            continue
        if pid > 0: return pid
    if found:
        raise SmokeError("app service exists but has no live pid: %s" % bundle)
    raise SmokeError("launchctl has no exact app service: %s" % bundle)
def _check_logs(paths: Sequence[Path]) -> None:
    for path in paths:
        if not path.is_file():
            raise SmokeError("simulator did not create captured log: %s" % path)
        text = path.read_text(encoding="utf-8", errors="replace")
        match = LOG_ERROR_RE.search(text)
        if match:
            raise SmokeError("runtime error in %s: %s" % (path.name, match.group(0)))
def smoke(build_dir: Path) -> int:
    udid, bundle, app = _read_build_inputs(build_dir)
    logs = (build_dir / "logs").resolve()
    logs.mkdir(parents=True, exist_ok=True)
    stdout_log = logs / "app-stdout.log"
    stderr_log = logs / "app-stderr.log"
    screenshot = logs / "simulator.png"
    stdout_log.write_text("", encoding="utf-8")
    stderr_log.write_text("", encoding="utf-8")
    if screenshot.exists(): screenshot.unlink()
    booted_by_helper = False
    try:
        if _device_state(udid) != "Booted":
            _run(["xcrun", "simctl", "boot", udid], "simulator boot", 30.0)
            booted_by_helper = True
        _run(["xcrun", "simctl", "bootstatus", udid, "-b"], "simulator bootstatus", BOOT_TIMEOUT_SECONDS)
        _run(["xcrun", "simctl", "install", udid, str(app)], "app install", 60.0)
        _run(["xcrun", "simctl", "launch", "--terminate-running-process",
              "--stdout=%s" % stdout_log, "--stderr=%s" % stderr_log, udid, bundle],
             "app launch", 60.0)
        time.sleep(LIVE_WAIT_SECONDS)
        pid = _app_pid(udid, bundle)
        _check_logs((stdout_log, stderr_log))
        _run(["xcrun", "simctl", "io", udid, "screenshot", str(screenshot)],
             "simulator screenshot", 30.0)
        if not screenshot.is_file() or screenshot.stat().st_size == 0:
            raise SmokeError("simulator screenshot was not captured")
        print("simulator smoke PASS: %s (pid %d)" % (bundle, pid))
        return 0
    finally:
        _best_effort(["xcrun", "simctl", "terminate", udid, bundle])
        if booted_by_helper:
            _best_effort(["xcrun", "simctl", "shutdown", udid])
def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build-dir", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        return smoke(args.build_dir.resolve())
    except SmokeError as exc:
        print("smoke_simulator: %s" % exc, file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
