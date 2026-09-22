#!/usr/bin/env python3
"""Build the Pixel Monster iOS export without putting Apple identity in git.

The checked-in export preset deliberately has empty Team ID and bundle identifier
fields.  Godot requires both fields even for an Xcode project export, so this tool
copies the project to a temporary directory and injects real caller-provided values
there.  The source tree is never rewritten.

Commands:
  preflight  Validate local/CI tools and required inputs.
  export     Export the Godot project to a direct Xcode project and packed resource file.
  build      Export and build an unsigned simulator app or signed device archive.

All subprocesses are argv-based (never shell=True).  Secret material is written only
to temporary files and is removed in finally blocks.  The module intentionally keeps
the command runner replaceable so test_ios_pipeline.py can exercise the contract
without invoking Godot, Xcode, a simulator, or Apple's services.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from types import SimpleNamespace
from typing import Any, Iterable, Mapping, Sequence


PROJECT_DIR = Path(__file__).resolve().parents[2]
PRESET_PATH = PROJECT_DIR / "export_presets.cfg"
EXPECTED_GODOT_VERSION = "4.7.stable.official.5b4e0cb0f"
DEFAULT_GODOT_BIN = "/Applications/Godot.app/Contents/MacOS/Godot"
DEFAULT_XCODE_VERSION = "26.6"
DEFAULT_SIMULATOR_NAME = "iPhone 17 Pro"
DEFAULT_SIMULATOR_RUNTIME = "com.apple.CoreSimulator.SimRuntime.iOS-26-5"
DEFAULT_OUTPUT_DIR = PROJECT_DIR / "build" / "ios"
SIMULATOR_PLACEHOLDER_TEAM_ID = "0000000000"
SIMULATOR_PLACEHOLDER_BUNDLE_ID = "org.godogen.pixelmonster.ci"

_TEAM_ID_RE = re.compile(r"^[A-Za-z0-9]{10}$")
_BUNDLE_ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9.-]*\.[A-Za-z0-9][A-Za-z0-9.-]*$")
_APPLE_BUILD_VERSION_RE = re.compile(r"^[1-9][0-9]{0,3}(?:\.[0-9]{1,2}){0,2}$")


class PipelineError(RuntimeError):
    """A user-actionable export/preflight error."""


def _result(stdout: str = "", stderr: str = "", returncode: int = 0) -> Any:
    return SimpleNamespace(stdout=stdout, stderr=stderr, returncode=returncode)


def run_command(
    args: Sequence[str],
    *,
    cwd: Path | None = None,
    env: Mapping[str, str] | None = None,
    capture: bool = False,
) -> Any:
    """The single subprocess seam; tests replace this function with a fake."""

    return subprocess.run(
        [str(value) for value in args],
        cwd=str(cwd) if cwd else None,
        env=dict(env) if env else None,
        text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture else None,
        check=False,
    )


def _command_text(args: Sequence[str]) -> str:
    return " ".join(str(value) for value in args)


def invoke(
    args: Sequence[str],
    *,
    label: str,
    cwd: Path | None = None,
    env: Mapping[str, str] | None = None,
    capture: bool = False,
    log_path: Path | None = None,
    dry_run: bool = False,
) -> Any:
    """Run an argv command and keep diagnostics free of environment secrets."""

    if dry_run:
        print(f"[dry-run] {label}: {_command_text(args)}")
        return _result()

    result = run_command(args, cwd=cwd, env=env, capture=capture or log_path is not None)
    if log_path is not None:
        log_path.parent.mkdir(parents=True, exist_ok=True)
        output = (result.stdout or "")
        if result.stdout and result.stderr:
            output += "\n"
        output += result.stderr or ""
        log_path.write_text(output, encoding="utf-8")
    if result.returncode != 0:
        detail = (result.stderr or result.stdout or "").strip()
        if len(detail) > 4000:
            detail = detail[-4000:]
        suffix = f"\n{detail}" if detail else ""
        raise PipelineError(f"{label} failed with exit {result.returncode}.{suffix}")
    return result


def _env(name: str) -> str:
    return os.environ.get(name, "").strip()


def _identity(mode: str, simulator_only: bool = False) -> tuple[str, str]:
    if simulator_only:
        if mode != "unsigned":
            raise PipelineError("simulator-only placeholders are forbidden for release builds")
        return SIMULATOR_PLACEHOLDER_TEAM_ID, SIMULATOR_PLACEHOLDER_BUNDLE_ID
    return _env("IOS_TEAM_ID"), _env("IOS_BUNDLE_IDENTIFIER")


def _simulator_template_override(mode: str, simulator_only: bool) -> Path | None:
    """Return the matching-source template only for unsigned simulator exports.

    The signed device path intentionally leaves Godot's official release
    template selection untouched.  Preflight reports an explicitly supplied
    override on any other path as invalid; rendering itself therefore cannot
    accidentally put a simulator archive into a device export.
    """

    configured = _env("IOS_SIMULATOR_TEMPLATE")
    if not configured or mode != "unsigned" or not simulator_only:
        return None
    path = Path(configured)
    if not path.is_absolute():
        raise PipelineError("IOS_SIMULATOR_TEMPLATE must be an absolute path")
    if path.suffix.lower() != ".zip":
        raise PipelineError("IOS_SIMULATOR_TEMPLATE must point to a .zip template")
    if not path.is_file():
        raise PipelineError(f"IOS_SIMULATOR_TEMPLATE does not exist: {path}")
    return path


def godot_bin() -> str:
    configured = _env("GODOT_BIN")
    if configured:
        return configured
    if Path(DEFAULT_GODOT_BIN).is_file():
        return DEFAULT_GODOT_BIN
    return shutil.which("godot") or shutil.which("godot4") or DEFAULT_GODOT_BIN


def xcode_version() -> str:
    return _env("IOS_XCODE_VERSION") or DEFAULT_XCODE_VERSION


def output_dir(value: str | None = None) -> Path:
    return Path(value or _env("IOS_OUTPUT_DIR") or DEFAULT_OUTPUT_DIR).expanduser().resolve()


def required_inputs(mode: str, upload: bool = False, simulator_only: bool = False) -> list[str]:
    # Godot 4.7's iOS exporter requires Team ID and Bundle Identifier even when
    # export_project_only=true and the subsequent Xcode build disables signing.
    names: list[str] = []
    if not simulator_only:
        names.extend(["IOS_TEAM_ID", "IOS_BUNDLE_IDENTIFIER"])
    if mode == "release":
        names.extend(
            [
                "IOS_CERTIFICATE_P12_BASE64",
                "IOS_CERTIFICATE_PASSWORD",
                "IOS_PROVISIONING_PROFILE_BASE64",
                "IOS_CODE_SIGN_IDENTITY",
            ]
        )
    if upload:
        names.extend(["ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_PRIVATE_KEY_P8"])
    return names


def _build_number(mode: str) -> str:
    explicit = _env("IOS_BUILD_NUMBER")
    if explicit:
        value = explicit
    elif _env("GITHUB_RUN_NUMBER"):
        try:
            run_number = int(_env("GITHUB_RUN_NUMBER"))
            attempt = int(_env("GITHUB_RUN_ATTEMPT") or "1")
        except ValueError as error:
            raise PipelineError(f"GitHub run number/attempt must be integers: {error}")
        if run_number < 1 or attempt < 1 or attempt > 99:
            raise PipelineError("GitHub run number must be positive and run attempt must be 1..99")
        # Apple accepts at most four digits in the first CFBundleVersion
        # component and two digits in each following component. Encode the
        # run number and attempt bijectively into that shape.
        serial = (run_number - 1) * 99 + (attempt - 1)
        major = serial // 10000 + 1
        if major > 9999:
            raise PipelineError("GitHub run number is too large for an Apple CFBundleVersion")
        minor = (serial // 100) % 100
        patch = serial % 100
        value = f"{major}.{minor}.{patch}"
    elif mode == "release":
        raise PipelineError("IOS_BUILD_NUMBER is required for a local release outside GitHub Actions")
    else:
        # Local simulator builds are not uploaded. Keep the fallback within
        # Apple's CFBundleVersion grammar; local release builds must provide an
        # explicit value because they may be uploaded.
        value = "1.0.0"
    if not _APPLE_BUILD_VERSION_RE.fullmatch(value):
        raise PipelineError(
            "IOS_BUILD_NUMBER must be an Apple build version: 1-4 digits followed by "
            "up to two dot-separated components of 1-2 digits"
        )
    return value


def _marketing_version() -> str:
    value = _env("IOS_MARKETING_VERSION") or "0.1.0"
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", value):
        raise PipelineError("IOS_MARKETING_VERSION must use semantic numeric form major.minor.patch")
    return value


def validate_inputs(
    mode: str,
    upload: bool = False,
    simulator_only: bool = False,
) -> tuple[list[str], list[str]]:
    missing = [name for name in required_inputs(mode, upload, simulator_only) if not _env(name)]
    invalid: list[str] = []
    team_id, bundle_id = _identity(mode, simulator_only)
    if mode == "release" and (
        _env("IOS_TEAM_ID") == SIMULATOR_PLACEHOLDER_TEAM_ID
        or _env("IOS_BUNDLE_IDENTIFIER") == SIMULATOR_PLACEHOLDER_BUNDLE_ID
    ):
        invalid.append("release identity (simulator-only placeholder is forbidden)")
    if team_id and not _TEAM_ID_RE.fullmatch(team_id):
        invalid.append("IOS_TEAM_ID (expected the 10-character Apple Team ID)")
    if bundle_id and not _BUNDLE_ID_RE.fullmatch(bundle_id):
        invalid.append("IOS_BUNDLE_IDENTIFIER (expected a unique reverse-DNS identifier)")
    if mode == "release":
        identity = _env("IOS_CODE_SIGN_IDENTITY")
        if identity and "\n" in identity:
            invalid.append("IOS_CODE_SIGN_IDENTITY (must be one line)")
    simulator_template = _env("IOS_SIMULATOR_TEMPLATE")
    if simulator_template and not (mode == "unsigned" and simulator_only):
        invalid.append(
            "IOS_SIMULATOR_TEMPLATE (only allowed for unsigned --simulator-only; "
            "signed release uses the official device template)"
        )
    elif simulator_template:
        try:
            _simulator_template_override(mode, simulator_only)
        except PipelineError as error:
            invalid.append(str(error))
    try:
        _marketing_version()
        _build_number(mode)
    except (PipelineError, ValueError) as error:
        invalid.append(str(error))
    return missing, invalid


def _preset_option(text: str, key: str, value: str | int | bool) -> str:
    if isinstance(value, bool):
        encoded = "true" if value else "false"
    elif isinstance(value, int):
        encoded = str(value)
    else:
        encoded = json.dumps(value, ensure_ascii=False)
    line = f"{key}={encoded}"
    pattern = re.compile(rf"(?m)^{re.escape(key)}=.*$")
    if pattern.search(text):
        return pattern.sub(line, text, count=1)
    marker = "[preset.0.options]"
    if marker not in text:
        raise PipelineError(f"export preset is missing {marker}")
    return text.replace(marker, f"{marker}\n{line}", 1)


def rendered_preset(source: Path, *, mode: str, simulator_only: bool = False) -> str:
    text = source.read_text(encoding="utf-8")
    team_id, bundle_id = _identity(mode, simulator_only)
    text = _preset_option(text, "application/app_store_team_id", team_id)
    text = _preset_option(text, "application/bundle_identifier", bundle_id)
    text = _preset_option(text, "application/short_version", _marketing_version())
    text = _preset_option(text, "application/version", _build_number(mode))
    template = _simulator_template_override(mode, simulator_only)
    if template is not None:
        text = _preset_option(text, "custom_template/release", str(template))
    if mode == "release":
        text = _preset_option(
            text,
            "application/code_sign_identity_release",
            _env("IOS_CODE_SIGN_IDENTITY"),
        )
        profile_name = _env("IOS_PROVISIONING_PROFILE_NAME")
        if profile_name:
            text = _preset_option(
                text,
                "application/provisioning_profile_specifier_release",
                profile_name,
            )
    return text


def copy_project_for_export(mode: str, simulator_only: bool = False) -> Path:
    runner_temp = _env("RUNNER_TEMP") or None
    temp_root = Path(tempfile.mkdtemp(prefix="pixel-monster-ios-", dir=runner_temp))
    destination = temp_root / "project"

    def ignore(path: str, names: list[str]) -> set[str]:
        ignored = {".godot", "build", "evidence", ".git", "__pycache__"}
        if Path(path).resolve() == (PROJECT_DIR / "tools" / "ios").resolve():
            ignored.update({".pytest_cache"})
        return {name for name in names if name in ignored}

    shutil.copytree(PROJECT_DIR, destination, ignore=ignore)
    (destination / "export_presets.cfg").write_text(
        rendered_preset(PRESET_PATH, mode=mode, simulator_only=simulator_only), encoding="utf-8"
    )
    return destination


def _temporary_project_cleanup(project: Path) -> None:
    # copy_project_for_export uses a temp directory one level above project.
    shutil.rmtree(project.parent, ignore_errors=True)


def _template_root() -> Path:
    configured = _env("GODOT_TEMPLATE_ROOT")
    if configured:
        return Path(configured).expanduser()
    return Path.home() / "Library" / "Application Support" / "Godot" / "export_templates" / "4.7.stable"


def preflight(
    mode: str,
    *,
    upload: bool = False,
    simulator_only: bool = False,
    dry_run: bool = False,
) -> None:
    missing, invalid = validate_inputs(mode, upload, simulator_only)
    print(
        f"iOS preflight: mode={mode}, upload={'yes' if upload else 'no'}, "
        f"simulator_only={'yes' if simulator_only else 'no'}"
    )
    print(f"Godot pin: {EXPECTED_GODOT_VERSION}")
    print(f"Xcode pin: {xcode_version()}")
    print("deployment target: iOS 16.0; device family: iPhone")
    print("source preset identity: empty; CI/local values are injected into a temporary copy")
    print(f"marketing version/build number: {_env('IOS_MARKETING_VERSION') or '0.1.0'}/{_env('IOS_BUILD_NUMBER') or 'derived'}")
    if simulator_only:
        print(
            "simulator-only identity placeholders: "
            f"{SIMULATOR_PLACEHOLDER_TEAM_ID} / {SIMULATOR_PLACEHOLDER_BUNDLE_ID} "
            "(syntax only; never accepted by release)"
        )
    if _env("IOS_SIMULATOR_TEMPLATE") and mode == "unsigned" and simulator_only:
        print(f"matching-source simulator template: {_env('IOS_SIMULATOR_TEMPLATE')}")
    if missing:
        print("missing inputs: " + ", ".join(missing))
    if invalid:
        print("invalid inputs: " + ", ".join(invalid))
    if dry_run:
        print("dry-run: no tool, signing, simulator, or network command executed")
        return
    if missing or invalid:
        raise PipelineError(
            "required iOS identity inputs are not configured; see the missing/invalid list above"
        )
    if not PROJECT_DIR.joinpath("project.godot").is_file():
        raise PipelineError(f"missing Godot project: {PROJECT_DIR / 'project.godot'}")
    if not PRESET_PATH.is_file():
        raise PipelineError(f"missing iOS export preset: {PRESET_PATH}")
    if not Path(godot_bin()).is_file():
        raise PipelineError(f"Godot executable not found: {godot_bin()}")

    version = invoke([godot_bin(), "--version"], label="Godot version", capture=True)
    actual = (version.stdout or "").strip().splitlines()[0] if version.stdout else ""
    if actual != EXPECTED_GODOT_VERSION:
        raise PipelineError(f"Godot version mismatch: expected {EXPECTED_GODOT_VERSION}, got {actual!r}")

    selected = invoke(["xcode-select", "-p"], label="xcode-select", capture=True)
    selected_path = (selected.stdout or "").strip()
    if not selected_path.endswith("/Contents/Developer"):
        raise PipelineError(f"xcode-select is not pointing at an Xcode developer directory: {selected_path!r}")
    xcode = invoke(["xcodebuild", "-version"], label="Xcode version", capture=True)
    first_line = (xcode.stdout or "").splitlines()[0] if xcode.stdout else ""
    if first_line != f"Xcode {xcode_version()}":
        raise PipelineError(f"Xcode version mismatch: expected {xcode_version()}, got {first_line!r}")
    if not (_template_root() / "ios.zip").is_file():
        raise PipelineError(f"Godot 4.7 iOS export template missing: {_template_root() / 'ios.zip'}")

    preset = PRESET_PATH.read_text(encoding="utf-8")
    if re.search(r'(?m)^application/app_store_team_id="[^"].*"$', preset):
        raise PipelineError("export_presets.cfg must not contain a committed Apple Team ID")
    if re.search(r'(?m)^application/bundle_identifier="[^"].*"$', preset):
        raise PipelineError("export_presets.cfg must not contain a committed bundle identifier")
    if "application/min_ios_version=\"16.0\"" not in preset:
        raise PipelineError("iOS preset must keep application/min_ios_version=\"16.0\"")
    if "application/targeted_device_family=0" not in preset:
        raise PipelineError("iOS preset must target iPhone (application/targeted_device_family=0)")
    project_settings = PROJECT_DIR.joinpath("project.godot").read_text(encoding="utf-8")
    if "textures/vram_compression/import_etc2_astc=true" not in project_settings:
        raise PipelineError(
            "project.godot must enable textures/vram_compression/import_etc2_astc=true "
            "for Apple embedded export configuration"
        )

    if mode == "release":
        sdk = invoke(
            ["xcrun", "--sdk", "iphoneos", "--show-sdk-version"],
            label="iPhoneOS SDK version",
            capture=True,
        )
        sdk_version = (sdk.stdout or "").strip()
        try:
            sdk_major = int(sdk_version.split(".", 1)[0])
        except (ValueError, IndexError):
            raise PipelineError(f"could not parse iPhoneOS SDK version: {sdk_version!r}")
        if sdk_major < 26:
            raise PipelineError(
                f"release upload requires iOS 26 SDK after 2026-04-28; selected SDK is {sdk_version}"
            )


def _export_command(mode: str, project: Path, destination: Path) -> list[str]:
    # Both signed release and unsigned simulator smoke compile the Release
    # Godot template. Xcode then selects device or simulator SDK as needed.
    flag = "--export-release" if mode in {"release", "unsigned"} else "--export-debug"
    return [godot_bin(), "--headless", "--path", str(project), flag, "iOS", str(destination)]


def export_project(
    mode: str,
    destination: Path,
    *,
    simulator_only: bool = False,
    dry_run: bool = False,
) -> Path:
    if not dry_run:
        destination.mkdir(parents=True, exist_ok=True)
    temp_project = (
        copy_project_for_export(mode, simulator_only)
        if not dry_run
        else PROJECT_DIR / ".ci-temporary-project"
    )
    # With application/export_project_only=true Godot writes the Xcode project
    # directly and does not create the requested .zip. Keep that output in an
    # isolated subdirectory so the caller can package only the built app.
    xcode_output = destination / "xcode" / "PocketDiary.xcodeproj"
    if not dry_run:
        xcode_output.parent.mkdir(parents=True, exist_ok=True)
    try:
        command_env = os.environ.copy()
        profile_uuid = _env("IOS_PROVISIONING_PROFILE_UUID")
        if profile_uuid:
            command_env["GODOT_IOS_PROVISIONING_PROFILE_UUID_RELEASE"] = profile_uuid
        invoke(
            _export_command(mode, temp_project, xcode_output),
            label=f"Godot {mode} iOS export",
            env=command_env,
            log_path=destination / "logs" / "godot-export.log",
            dry_run=dry_run,
        )
        if dry_run:
            return xcode_output
        if not xcode_output.is_dir():
            raise PipelineError(f"Godot export completed without Xcode project: {xcode_output}")
        return xcode_output
    finally:
        if not dry_run:
            _temporary_project_cleanup(temp_project)


def _scheme_for_project(project: Path, *, dry_run: bool = False) -> str:
    result = invoke(
        ["xcodebuild", "-project", str(project), "-list", "-json"],
        label="Xcode scheme discovery",
        capture=True,
        dry_run=dry_run,
    )
    if dry_run:
        return project.stem
    try:
        payload = json.loads(result.stdout or "{}")
        schemes = payload.get("project", {}).get("schemes", [])
        if schemes:
            return str(schemes[0])
    except json.JSONDecodeError:
        pass
    return project.stem


def _simulator_device_type(name: str) -> str:
    configured = _env("SIMULATOR_DEVICE_TYPE")
    if configured:
        return configured
    known = {
        "iPhone 12": "com.apple.CoreSimulator.SimDeviceType.iPhone-12",
        "iPhone 17 Pro": "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro",
    }
    if name in known:
        return known[name]
    slug = re.sub(r"[^A-Za-z0-9]+", "-", name).strip("-")
    return f"com.apple.CoreSimulator.SimDeviceType.{slug}"


def ensure_simulator(name: str, *, dry_run: bool = False) -> str:
    configured_udid = _env("SIMULATOR_UDID")
    if configured_udid:
        return configured_udid
    runtime = _env("SIMULATOR_RUNTIME") or DEFAULT_SIMULATOR_RUNTIME
    list_result = invoke(
        ["xcrun", "simctl", "list", "devices", "available", "-j"],
        label="available iOS simulators",
        capture=True,
        dry_run=dry_run,
    )
    if dry_run:
        print(f"[dry-run] simulator target: {name} ({runtime})")
        return "SIMULATOR-UDID"
    try:
        payload = json.loads(list_result.stdout or "{}")
    except json.JSONDecodeError as error:
        raise PipelineError(f"simctl returned invalid JSON: {error}")
    create_name = f"Pixel Monster {name}"
    for runtime_id, devices in payload.get("devices", {}).items():
        if runtime_id != runtime:
            continue
        for device in devices:
            if device.get("name") in {name, create_name} and device.get("isAvailable", True):
                return str(device["udid"])
    created = invoke(
        ["xcrun", "simctl", "create", create_name, _simulator_device_type(name), runtime],
        label=f"create simulator {name}",
        capture=True,
    )
    udid = (created.stdout or "").strip()
    if not udid:
        raise PipelineError(
            f"simulator {name} ({runtime}) is not installed and simctl could not create it; "
            "install the matching runtime/device type or set SIMULATOR_UDID"
        )
    # Xcode can compile for a shutdown simulator. The smoke test owns booting
    # and shutting down its device, including the first-run data migration.
    return udid


def build_unsigned(
    destination: Path,
    *,
    simulator: str | None,
    simulator_only: bool = False,
    dry_run: bool = False,
) -> Path:
    xcode_project = export_project(
        "unsigned",
        destination,
        simulator_only=simulator_only,
        dry_run=dry_run,
    )
    scheme = _scheme_for_project(xcode_project, dry_run=dry_run)
    simulator_name = simulator or _env("SIMULATOR_NAME") or DEFAULT_SIMULATOR_NAME
    simulator_udid = ensure_simulator(simulator_name, dry_run=dry_run)
    derived_data = destination / "DerivedData" / simulator_name.replace(" ", "-")
    command = [
        "xcodebuild",
        "-project",
        str(xcode_project),
        "-scheme",
        scheme,
        "-configuration",
        "Release",
        "-sdk",
        "iphonesimulator",
        "-destination",
        f"id={simulator_udid}",
        "-derivedDataPath",
        str(derived_data),
        "CODE_SIGNING_ALLOWED=NO",
        "CODE_SIGNING_REQUIRED=NO",
        "build",
    ]
    invoke(
        command,
        label=f"unsigned simulator build ({simulator_name})",
        log_path=destination / "logs" / "xcodebuild.log",
        dry_run=dry_run,
    )
    if dry_run:
        return xcode_project

    products_dir = derived_data / "Build" / "Products" / "Release-iphonesimulator"
    apps = _find_simulator_apps(products_dir)
    if not apps:
        raise PipelineError(f"Xcode produced no Release-iphonesimulator .app in {products_dir}")
    app = apps[0]
    simulator_archive = destination / "simulator-app.zip"
    invoke(
        [
            "ditto",
            "-c",
            "-k",
            "--sequesterRsrc",
            "--keepParent",
            str(app),
            str(simulator_archive),
        ],
        label="package unsigned simulator app",
    )
    if not simulator_archive.is_file():
        raise PipelineError(f"ditto completed without simulator app archive: {simulator_archive}")
    build_team_id, build_bundle_id = _identity("unsigned", simulator_only)
    build_info = destination / "build-info.txt"
    build_info.write_text(
        "\n".join(
            [
                "Pixel Monster iOS unsigned simulator build",
                "mode=unsigned",
                "configuration=Release",
                f"simulator={simulator_name}",
                f"simulator_udid={simulator_udid}",
                f"godot={EXPECTED_GODOT_VERSION}",
                f"xcode={xcode_version()}",
                f"bundle_identifier={build_bundle_id}",
                f"team_id={build_team_id}",
                f"marketing_version={_marketing_version()}",
                f"build_number={_build_number('unsigned')}",
                f"app={app}",
                f"archive={simulator_archive}",
            ]
        )
        + "\n",
        encoding="utf-8",
    )
    return xcode_project


def _find_simulator_apps(products_dir: Path) -> list[Path]:
    return sorted(path for path in products_dir.glob("*.app") if path.is_dir())


def _decode_secret(name: str, destination: Path) -> Path:
    value = _env(name)
    if not value:
        raise PipelineError(f"missing {name}")
    try:
        decoded = base64.b64decode(value, validate=True)
    except ValueError as error:
        raise PipelineError(f"{name} is not valid base64: {error}")
    destination.write_bytes(decoded)
    destination.chmod(0o600)
    return destination


def _profile_metadata(profile: Path) -> dict[str, str]:
    result = run_command(["security", "cms", "-D", "-i", str(profile)], capture=True)
    if result.returncode != 0:
        raise PipelineError("could not decode the provisioning profile")
    try:
        data = plistlib.loads((result.stdout or "").encode("utf-8"))
    except (plistlib.InvalidFileException, UnicodeEncodeError) as error:
        raise PipelineError(f"could not parse the provisioning profile: {error}")
    name = str(data.get("Name", "")).strip()
    uuid = str(data.get("UUID", "")).strip()
    if not name or not uuid:
        raise PipelineError("provisioning profile did not contain Name and UUID")
    return {"name": name, "uuid": uuid}


class TemporaryProvisioningProfile:
    """Install one profile for Xcode and restore/remove exactly that file."""

    def __init__(self, profile: Path, uuid: str) -> None:
        self.profile = profile
        self.uuid = uuid
        self.directory = Path.home() / "Library" / "MobileDevice" / "Provisioning Profiles"
        self.target = self.directory / f"{uuid}.mobileprovision"
        self.previous: bytes | None = None
        self.previous_mode: int | None = None
        self.installed = False

    def __enter__(self) -> "TemporaryProvisioningProfile":
        try:
            if self.target.exists():
                self.previous = self.target.read_bytes()
                self.previous_mode = self.target.stat().st_mode & 0o777
            self.directory.mkdir(parents=True, exist_ok=True)
            shutil.copy2(self.profile, self.target)
            self.target.chmod(0o600)
            self.installed = True
            return self
        except Exception:
            self._restore()
            raise

    def _restore(self) -> None:
        if not self.installed and self.previous is None and not self.target.exists():
            return
        if self.previous is None:
            self.target.unlink(missing_ok=True)
            return
        self.target.write_bytes(self.previous)
        self.target.chmod(self.previous_mode or 0o600)

    def __exit__(self, *_: object) -> None:
        self._restore()
        self.installed = False


class TemporaryKeychain:
    """Import a signing certificate and always delete the temporary keychain."""

    def __init__(self, certificate: Path) -> None:
        self.certificate = certificate
        self.path = Path(tempfile.mkdtemp(prefix="pixel-monster-keychain-")) / "signing.keychain-db"
        self.password = base64.urlsafe_b64encode(os.urandom(24)).decode("ascii")
        self.created = False
        self.original_search_list: list[str] = []
        self.search_list_changed = False

    def _capture_search_list(self) -> list[str]:
        result = run_command(["security", "list-keychains", "-d", "user"], capture=True)
        if result.returncode != 0:
            raise PipelineError("could not read the user's keychain search list")
        return re.findall(r'"([^"]+)"', result.stdout or "")

    def _restore_search_list(self) -> None:
        if not self.search_list_changed:
            return
        if self.original_search_list:
            run_command(
                ["security", "list-keychains", "-d", "user", "-s", *self.original_search_list],
                capture=True,
            )
        else:
            run_command(["security", "list-keychains", "-d", "user", "-s"], capture=True)
        self.search_list_changed = False

    def _cleanup(self) -> None:
        # Restore the caller's search list before deleting the keychain.  Cleanup
        # is best-effort so a failed import cannot mask the original error.
        try:
            self._restore_search_list()
        except Exception:
            print("warning: temporary keychain search-list restore failed", file=sys.stderr)
        if self.created:
            cleanup = run_command(["security", "delete-keychain", str(self.path)], capture=True)
            if cleanup.returncode != 0:
                print("warning: temporary signing keychain cleanup failed", file=sys.stderr)
            self.created = False
        shutil.rmtree(self.path.parent, ignore_errors=True)

    def __enter__(self) -> "TemporaryKeychain":
        try:
            # Capture the caller's list inside the same guard as every later
            # operation.  The constructor has already allocated a temp
            # directory, so even a security-tool failure here must remove it.
            self.original_search_list = self._capture_search_list()
            invoke(
                ["security", "create-keychain", "-p", self.password, str(self.path)],
                label="create temporary signing keychain",
            )
            self.created = True
            invoke(
                ["security", "set-keychain-settings", "-lut", "21600", str(self.path)],
                label="configure temporary signing keychain",
            )
            invoke(
                ["security", "unlock-keychain", "-p", self.password, str(self.path)],
                label="unlock temporary signing keychain",
            )
            self.search_list_changed = True
            invoke(
                [
                    "security",
                    "list-keychains",
                    "-d",
                    "user",
                    "-s",
                    str(self.path),
                    *self.original_search_list,
                ],
                label="add temporary signing keychain to search list",
            )
            invoke(
                [
                    "security",
                    "import",
                    str(self.certificate),
                    "-k",
                    str(self.path),
                    "-P",
                    _env("IOS_CERTIFICATE_PASSWORD"),
                    "-T",
                    "/usr/bin/codesign",
                    "-T",
                    "/usr/bin/security",
                ],
                label="import signing certificate",
            )
            invoke(
                [
                    "security",
                    "set-key-partition-list",
                    "-S",
                    "apple-tool:,apple:,codesign:",
                    "-s",
                    "-k",
                    self.password,
                    str(self.path),
                ],
                label="authorize codesign keychain access",
            )
            return self
        except Exception:
            self._cleanup()
            raise

    def __exit__(self, *_: object) -> None:
        self._cleanup()


def _write_export_options(path: Path, profile_name: str) -> None:
    options = {
        "method": "app-store",
        "signingStyle": "manual",
        "teamID": _env("IOS_TEAM_ID"),
        "provisioningProfiles": {_env("IOS_BUNDLE_IDENTIFIER"): profile_name},
        "signingCertificate": _env("IOS_CODE_SIGN_IDENTITY"),
        "uploadSymbols": True,
    }
    path.write_bytes(plistlib.dumps(options, sort_keys=True))


def _asc_upload(ipa: Path, *, dry_run: bool = False) -> None:
    key_id = _env("ASC_KEY_ID")
    issuer_id = _env("ASC_ISSUER_ID")
    key_contents = _env("ASC_PRIVATE_KEY_P8")
    if not key_id or not issuer_id or not key_contents:
        raise PipelineError("ASC_KEY_ID, ASC_ISSUER_ID, and ASC_PRIVATE_KEY_P8 are required for upload")
    if dry_run:
        print("[dry-run] ASC upload: xcrun altool --upload-app (private key content is not displayed)")
        return
    private_keys_dir = Path(tempfile.mkdtemp(prefix="pixel-monster-asc-keys-"))
    key_path = private_keys_dir / f"AuthKey_{key_id}.p8"
    try:
        # Start cleanup before writing/chmodding the key: filesystem failures
        # must not leave the temporary API key directory behind.
        key_path.write_text(key_contents, encoding="utf-8")
        key_path.chmod(0o600)
        env = os.environ.copy()
        # Xcode 26's current altool man page explicitly supports this variable;
        # never redirect HOME, which could affect unrelated runner state.
        env["API_PRIVATE_KEYS_DIR"] = str(private_keys_dir)
        invoke(
            [
                "xcrun",
                "altool",
                "--upload-app",
                "--file",
                str(ipa),
                "--platform",
                "ios",
                "--api-key",
                key_id,
                "--api-issuer",
                issuer_id,
            ],
            label="upload signed IPA to App Store Connect/TestFlight",
            env=env,
        )
    finally:
        key_path.unlink(missing_ok=True)
        shutil.rmtree(private_keys_dir, ignore_errors=True)


def build_release(destination: Path, *, upload: bool, dry_run: bool = False) -> Path:
    if dry_run:
        xcode_project = export_project("release", destination, dry_run=True)
        scheme = _scheme_for_project(xcode_project, dry_run=True)
        archive = destination / "PocketDiary.xcarchive"
        print(
            "[dry-run] signed archive: xcodebuild archive "
            f"-project {xcode_project} -scheme {scheme} -sdk iphoneos"
        )
        print(f"[dry-run] export IPA: xcodebuild -exportArchive -archivePath {archive}")
        if upload:
            _asc_upload(destination / "PocketDiary.ipa", dry_run=True)
        return destination / "PocketDiary.ipa"

    temp_root = Path(tempfile.mkdtemp(prefix="pixel-monster-release-"))
    old_profile_name = os.environ.get("IOS_PROVISIONING_PROFILE_NAME")
    old_profile_uuid = os.environ.get("IOS_PROVISIONING_PROFILE_UUID")
    try:
        # The try/finally starts before any decoded secret or profile metadata is
        # created, so every failure path removes the release temp directory.
        certificate = _decode_secret("IOS_CERTIFICATE_P12_BASE64", temp_root / "signing.p12")
        profile = _decode_secret("IOS_PROVISIONING_PROFILE_BASE64", temp_root / "profile.mobileprovision")
        metadata = _profile_metadata(profile)
        profile_name = _env("IOS_PROVISIONING_PROFILE_NAME") or metadata["name"]
        os.environ["IOS_PROVISIONING_PROFILE_NAME"] = profile_name
        os.environ["IOS_PROVISIONING_PROFILE_UUID"] = metadata["uuid"]
        with TemporaryProvisioningProfile(profile, metadata["uuid"]):
            with TemporaryKeychain(certificate) as keychain:
                xcode_project = export_project("release", destination)
                scheme = _scheme_for_project(xcode_project)
                archive = destination / "PocketDiary.xcarchive"
                archive_command = [
                    "xcodebuild",
                    "-project",
                    str(xcode_project),
                    "-scheme",
                    scheme,
                    "-configuration",
                    "Release",
                    "-sdk",
                    "iphoneos",
                    "-archivePath",
                    str(archive),
                    "CODE_SIGN_STYLE=Manual",
                    f"DEVELOPMENT_TEAM={_env('IOS_TEAM_ID')}",
                    f"CODE_SIGN_IDENTITY={_env('IOS_CODE_SIGN_IDENTITY')}",
                    f"PROVISIONING_PROFILE_SPECIFIER={profile_name}",
                    f"PROVISIONING_PROFILE={metadata['uuid']}",
                    f"OTHER_CODE_SIGN_FLAGS=--keychain {keychain.path}",
                    "archive",
                ]
                invoke(archive_command, label="signed device archive")
                options = destination / "export-options.plist"
                _write_export_options(options, profile_name)
                export_dir = destination / "ipa"
                invoke(
                    [
                        "xcodebuild",
                        "-exportArchive",
                        "-archivePath",
                        str(archive),
                        "-exportOptionsPlist",
                        str(options),
                        "-exportPath",
                        str(export_dir),
                    ],
                    label="export signed IPA",
                )
                ipas = sorted(export_dir.glob("*.ipa"))
                if not ipas:
                    raise PipelineError(f"Xcode export produced no IPA in {export_dir}")
                ipa = destination / ipas[0].name
                shutil.copy2(ipas[0], ipa)
            if upload:
                _asc_upload(ipa)
            return ipa
    finally:
        if old_profile_name is None:
            os.environ.pop("IOS_PROVISIONING_PROFILE_NAME", None)
        else:
            os.environ["IOS_PROVISIONING_PROFILE_NAME"] = old_profile_name
        if old_profile_uuid is None:
            os.environ.pop("IOS_PROVISIONING_PROFILE_UUID", None)
        else:
            os.environ["IOS_PROVISIONING_PROFILE_UUID"] = old_profile_uuid
        shutil.rmtree(temp_root, ignore_errors=True)


def dry_run_plan(
    mode: str,
    *,
    upload: bool,
    simulator: str | None,
    simulator_only: bool,
) -> None:
    print("Pixel Monster iOS pipeline dry-run")
    print(
        f"mode={mode}; simulator={simulator or _env('SIMULATOR_NAME') or DEFAULT_SIMULATOR_NAME}; "
        f"upload={upload}; simulator_only={simulator_only}"
    )
    preflight(mode, upload=upload, simulator_only=simulator_only, dry_run=True)
    if mode == "unsigned":
        build_unsigned(
            output_dir(),
            simulator=simulator,
            simulator_only=simulator_only,
            dry_run=True,
        )
    else:
        build_release(output_dir(), upload=upload, dry_run=True)


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["preflight", "export", "build"])
    parser.add_argument("--mode", choices=["unsigned", "release"], default="unsigned")
    parser.add_argument("--upload", action="store_true", help="upload release IPA to TestFlight via altool")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument(
        "--simulator-only",
        action="store_true",
        help="unsigned-only syntax placeholders; forbidden for release and upload",
    )
    parser.add_argument("--simulator", help="simulator name, e.g. 'iPhone 17 Pro' or 'iPhone 12'")
    parser.add_argument("--output-dir")
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    try:
        if args.command == "preflight":
            preflight(
                args.mode,
                upload=args.upload,
                simulator_only=args.simulator_only,
                dry_run=args.dry_run,
            )
            return 0
        if args.dry_run:
            dry_run_plan(
                args.mode,
                upload=args.upload,
                simulator=args.simulator,
                simulator_only=args.simulator_only,
            )
            return 0
        preflight(args.mode, upload=args.upload, simulator_only=args.simulator_only)
        destination = output_dir(args.output_dir)
        if args.command == "export":
            project = export_project(
                args.mode,
                destination,
                simulator_only=args.simulator_only,
            )
            print(f"Xcode project: {project}")
            return 0
        if args.mode == "unsigned":
            project = build_unsigned(
                destination,
                simulator=args.simulator,
                simulator_only=args.simulator_only,
            )
            print(f"unsigned simulator build source: {project}")
        else:
            ipa = build_release(destination, upload=args.upload)
            print(f"signed IPA: {ipa}")
        return 0
    except PipelineError as error:
        print(f"iOS pipeline error: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
