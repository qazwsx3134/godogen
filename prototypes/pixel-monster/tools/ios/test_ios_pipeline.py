#!/usr/bin/env python3
"""Offline contract tests for the iOS pipeline.

These tests deliberately replace the subprocess seam.  They validate command
shape, identity injection, and secret handling without invoking Godot, Xcode,
CoreSimulator, a keychain, or App Store Connect.
"""

from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import os
import shutil
import tempfile
from pathlib import Path
from types import SimpleNamespace
from unittest import mock


SCRIPT = Path(__file__).with_name("build_ios.py")
SPEC = importlib.util.spec_from_file_location("pixel_monster_ios_pipeline", SCRIPT)
assert SPEC and SPEC.loader
pipeline = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(pipeline)


def test_preset_injection_does_not_mutate_source() -> None:
    source = pipeline.PRESET_PATH.read_text(encoding="utf-8")
    old_team = os.environ.get("IOS_TEAM_ID")
    old_bundle = os.environ.get("IOS_BUNDLE_IDENTIFIER")
    try:
        os.environ["IOS_TEAM_ID"] = "ABCDE12345"
        os.environ["IOS_BUNDLE_IDENTIFIER"] = "com.review.pixelmonster"
        rendered = pipeline.rendered_preset(pipeline.PRESET_PATH, mode="unsigned")
    finally:
        if old_team is None:
            os.environ.pop("IOS_TEAM_ID", None)
        else:
            os.environ["IOS_TEAM_ID"] = old_team
        if old_bundle is None:
            os.environ.pop("IOS_BUNDLE_IDENTIFIER", None)
        else:
            os.environ["IOS_BUNDLE_IDENTIFIER"] = old_bundle
    assert 'application/app_store_team_id="ABCDE12345"' in rendered
    assert 'application/bundle_identifier="com.review.pixelmonster"' in rendered
    assert pipeline.PRESET_PATH.read_text(encoding="utf-8") == source


def test_preflight_mock_subprocess_contract() -> None:
    old = {name: os.environ.get(name) for name in ("IOS_TEAM_ID", "IOS_BUNDLE_IDENTIFIER", "GODOT_BIN", "GODOT_TEMPLATE_ROOT")}
    calls: list[list[str]] = []
    try:
        os.environ["IOS_TEAM_ID"] = "ABCDE12345"
        os.environ["IOS_BUNDLE_IDENTIFIER"] = "com.review.pixelmonster"
        os.environ["GODOT_BIN"] = "/Applications/Godot.app/Contents/MacOS/Godot"
        with tempfile.TemporaryDirectory() as temp:
            template_root = Path(temp)
            (template_root / "ios.zip").write_bytes(b"mock-template")
            os.environ["GODOT_TEMPLATE_ROOT"] = str(template_root)

            def fake_run(args, *, cwd=None, env=None, capture=False):
                command = [str(value) for value in args]
                calls.append(command)
                if command[0].endswith("/Godot"):
                    return SimpleNamespace(stdout=pipeline.EXPECTED_GODOT_VERSION + "\n", stderr="", returncode=0)
                if command[:2] == ["xcode-select", "-p"]:
                    return SimpleNamespace(stdout="/Applications/Xcode_26.6.app/Contents/Developer\n", stderr="", returncode=0)
                if command[:2] == ["xcodebuild", "-version"]:
                    return SimpleNamespace(stdout="Xcode 26.6\nBuild version 17F113\n", stderr="", returncode=0)
                return SimpleNamespace(stdout="", stderr="", returncode=0)

            original = pipeline.run_command
            pipeline.run_command = fake_run
            pipeline.preflight("unsigned")
            pipeline.run_command = original
    finally:
        for name, value in old.items():
            if value is None:
                os.environ.pop(name, None)
            else:
                os.environ[name] = value
    assert any(command[:2] == ["xcode-select", "-p"] for command in calls)
    assert any(command[:2] == ["xcodebuild", "-version"] for command in calls)
    assert all("--editorimport" not in command for command in calls)


def test_dry_run_never_prints_secret() -> None:
    old_values = {
        "IOS_TEAM_ID": os.environ.get("IOS_TEAM_ID"),
        "IOS_BUNDLE_IDENTIFIER": os.environ.get("IOS_BUNDLE_IDENTIFIER"),
        "ASC_KEY_ID": os.environ.get("ASC_KEY_ID"),
        "ASC_ISSUER_ID": os.environ.get("ASC_ISSUER_ID"),
        "ASC_PRIVATE_KEY_P8": os.environ.get("ASC_PRIVATE_KEY_P8"),
    }
    secret = "-----BEGIN PRIVATE KEY-----\nnever-print-me\n-----END PRIVATE KEY-----"
    try:
        os.environ["IOS_TEAM_ID"] = "ABCDE12345"
        os.environ["IOS_BUNDLE_IDENTIFIER"] = "com.review.pixelmonster"
        os.environ["ASC_KEY_ID"] = "KEY1234567"
        os.environ["ASC_ISSUER_ID"] = "issuer-for-contract-test"
        os.environ["ASC_PRIVATE_KEY_P8"] = secret
        stream = io.StringIO()
        with contextlib.redirect_stdout(stream):
            pipeline.dry_run_plan(
                "release",
                upload=True,
                simulator=None,
                simulator_only=False,
            )
        output = stream.getvalue()
    finally:
        for name, value in old_values.items():
            if value is None:
                os.environ.pop(name, None)
            else:
                os.environ[name] = value
    assert secret not in output
    assert "--editorimport" not in output
    assert "private key content is not displayed" in output


def test_command_contract_for_unsigned_build() -> None:
    # Keep this assertion close to the actual command builder so a future change
    # cannot accidentally turn PR builds into signed/device builds.
    destination = Path("/tmp/pixel-monster-contract-build")
    old_values = {
        "IOS_TEAM_ID": os.environ.get("IOS_TEAM_ID"),
        "IOS_BUNDLE_IDENTIFIER": os.environ.get("IOS_BUNDLE_IDENTIFIER"),
    }
    try:
        os.environ["IOS_TEAM_ID"] = "ABCDE12345"
        os.environ["IOS_BUNDLE_IDENTIFIER"] = "com.review.pixelmonster"
        commands: list[list[str]] = []

        def fake_invoke(args, **kwargs):
            command = [str(value) for value in args]
            commands.append(command)
            if command and command[0] == "ditto":
                Path(command[-1]).write_bytes(b"mock-app-zip")
            return SimpleNamespace(stdout="", stderr="", returncode=0)

        original_invoke = pipeline.invoke
        original_export = pipeline.export_project
        original_scheme = pipeline._scheme_for_project
        original_simulator = pipeline.ensure_simulator
        original_apps = pipeline._find_simulator_apps
        pipeline.invoke = fake_invoke
        pipeline.export_project = (
            lambda mode, destination, simulator_only=False, dry_run=False:
            destination / "xcode" / "PocketDiary.xcodeproj"
        )
        pipeline._scheme_for_project = lambda project, dry_run=False: "PocketDiary"
        pipeline.ensure_simulator = lambda name, dry_run=False: "SIMULATOR-UDID"
        pipeline._find_simulator_apps = lambda products_dir: [products_dir / "PocketDiary.app"]
        destination.mkdir(parents=True, exist_ok=True)
        pipeline.build_unsigned(destination, simulator="iPhone 17 Pro", dry_run=False)
        pipeline.invoke = original_invoke
        pipeline.export_project = original_export
        pipeline._scheme_for_project = original_scheme
        pipeline.ensure_simulator = original_simulator
        pipeline._find_simulator_apps = original_apps
    finally:
        for name, value in old_values.items():
            if value is None:
                os.environ.pop(name, None)
            else:
                os.environ[name] = value
    xcode_command = next(command for command in commands if command and command[0] == "xcodebuild")
    assert "iphonesimulator" in xcode_command
    assert "Release" in xcode_command
    assert "CODE_SIGNING_ALLOWED=NO" in xcode_command
    assert "CODE_SIGNING_REQUIRED=NO" in xcode_command
    assert "archive" not in xcode_command
    ditto_command = next(command for command in commands if command and command[0] == "ditto")
    assert "--keepParent" in ditto_command
    assert ditto_command[-1].endswith("simulator-app.zip")
    build_info = (destination / "build-info.txt").read_text(encoding="utf-8")
    assert "bundle_identifier=com.review.pixelmonster" in build_info
    assert "team_id=ABCDE12345" in build_info


def test_export_project_consumes_direct_godot_xcode_output() -> None:
    old_copy = pipeline.copy_project_for_export
    old_invoke = pipeline.invoke
    try:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source_project = root / "source" / "project"
            source_project.mkdir(parents=True)
            (source_project / "project.godot").write_text("[application]\n", encoding="utf-8")
            destination = root / "output"

            pipeline.copy_project_for_export = lambda mode, simulator_only=False: source_project

            def fake_invoke(args, **kwargs):
                output = Path(str(args[-1]))
                output.mkdir(parents=True)
                (output.parent / "PocketDiary.pck").write_bytes(b"packed")
                return SimpleNamespace(stdout="", stderr="", returncode=0)

            pipeline.invoke = fake_invoke
            project = pipeline.export_project(
                "unsigned",
                destination,
                simulator_only=True,
                dry_run=False,
            )
            assert project == destination / "xcode" / "PocketDiary.xcodeproj"
            assert project.is_dir()
            assert (destination / "xcode" / "PocketDiary.pck").is_file()
    finally:
        pipeline.copy_project_for_export = old_copy
        pipeline.invoke = old_invoke


def test_matching_source_template_is_unsigned_simulator_only() -> None:
    old_template = os.environ.get("IOS_SIMULATOR_TEMPLATE")
    old_build_number = os.environ.get("IOS_BUILD_NUMBER")
    try:
        with tempfile.TemporaryDirectory() as temp:
            template = Path(temp) / "ios-arm64.zip"
            template.write_bytes(b"matching-source-template")
            os.environ["IOS_SIMULATOR_TEMPLATE"] = str(template)
            os.environ["IOS_BUILD_NUMBER"] = "1.0.1"

            rendered = pipeline.rendered_preset(
                pipeline.PRESET_PATH,
                mode="unsigned",
                simulator_only=True,
            )
            assert f'custom_template/release="{template}"' in rendered

            release_rendered = pipeline.rendered_preset(
                pipeline.PRESET_PATH,
                mode="release",
                simulator_only=False,
            )
            assert 'custom_template/release=""' in release_rendered
            assert str(template) not in release_rendered

            _, release_invalid = pipeline.validate_inputs("release")
            assert any("IOS_SIMULATOR_TEMPLATE" in item for item in release_invalid)
    finally:
        if old_template is None:
            os.environ.pop("IOS_SIMULATOR_TEMPLATE", None)
        else:
            os.environ["IOS_SIMULATOR_TEMPLATE"] = old_template
        if old_build_number is None:
            os.environ.pop("IOS_BUILD_NUMBER", None)
        else:
            os.environ["IOS_BUILD_NUMBER"] = old_build_number


def test_matching_source_template_requires_absolute_existing_zip() -> None:
    old_template = os.environ.get("IOS_SIMULATOR_TEMPLATE")
    try:
        os.environ["IOS_SIMULATOR_TEMPLATE"] = "relative/ios.zip"
        try:
            pipeline.rendered_preset(
                pipeline.PRESET_PATH,
                mode="unsigned",
                simulator_only=True,
            )
        except pipeline.PipelineError as error:
            assert "absolute path" in str(error)
        else:
            raise AssertionError("relative simulator template path was accepted")
    finally:
        if old_template is None:
            os.environ.pop("IOS_SIMULATOR_TEMPLATE", None)
        else:
            os.environ["IOS_SIMULATOR_TEMPLATE"] = old_template


def test_build_number_uses_apple_shape_and_run_attempt() -> None:
    old_values = {
        "IOS_BUILD_NUMBER": os.environ.get("IOS_BUILD_NUMBER"),
        "GITHUB_RUN_NUMBER": os.environ.get("GITHUB_RUN_NUMBER"),
        "GITHUB_RUN_ATTEMPT": os.environ.get("GITHUB_RUN_ATTEMPT"),
    }
    try:
        os.environ.pop("IOS_BUILD_NUMBER", None)
        os.environ["GITHUB_RUN_NUMBER"] = "12345"
        os.environ["GITHUB_RUN_ATTEMPT"] = "2"
        first = pipeline._build_number("release")
        os.environ["GITHUB_RUN_ATTEMPT"] = "3"
        second = pipeline._build_number("release")
        assert first != second
        assert pipeline._APPLE_BUILD_VERSION_RE.fullmatch(first)
        assert pipeline._APPLE_BUILD_VERSION_RE.fullmatch(second)
        os.environ["IOS_BUILD_NUMBER"] = "1790044800"
        try:
            pipeline._build_number("release")
        except pipeline.PipelineError:
            pass
        else:
            raise AssertionError("timestamp build number was accepted")
    finally:
        for name, value in old_values.items():
            if value is None:
                os.environ.pop(name, None)
            else:
                os.environ[name] = value


def test_simulator_only_placeholders_never_enter_release() -> None:
    old_values = {
        "IOS_TEAM_ID": os.environ.get("IOS_TEAM_ID"),
        "IOS_BUNDLE_IDENTIFIER": os.environ.get("IOS_BUNDLE_IDENTIFIER"),
    }
    try:
        os.environ.pop("IOS_TEAM_ID", None)
        os.environ.pop("IOS_BUNDLE_IDENTIFIER", None)
        missing, invalid = pipeline.validate_inputs("unsigned", simulator_only=True)
        assert missing == []
        assert invalid == []
        rendered = pipeline.rendered_preset(
            pipeline.PRESET_PATH,
            mode="unsigned",
            simulator_only=True,
        )
        assert 'application/app_store_team_id="0000000000"' in rendered
        assert 'application/bundle_identifier="org.godogen.pixelmonster.ci"' in rendered
        os.environ["IOS_TEAM_ID"] = "0000000000"
        os.environ["IOS_BUNDLE_IDENTIFIER"] = "org.godogen.pixelmonster.ci"
        _, release_invalid = pipeline.validate_inputs("release")
        assert any("placeholder" in item for item in release_invalid)
    finally:
        for name, value in old_values.items():
            if value is None:
                os.environ.pop(name, None)
            else:
                os.environ[name] = value


def test_provisioning_profile_restores_same_uuid() -> None:
    with tempfile.TemporaryDirectory() as temp:
        root = Path(temp)
        profile = root / "incoming.mobileprovision"
        profile.write_bytes(b"new-profile")
        directory = root / "Library" / "MobileDevice" / "Provisioning Profiles"
        target = directory / "UUID-1.mobileprovision"
        directory.mkdir(parents=True)
        target.write_bytes(b"old-profile")
        target.chmod(0o640)
        holder = pipeline.TemporaryProvisioningProfile(profile, "UUID-1")
        holder.directory = directory
        holder.target = target
        with holder:
            assert target.read_bytes() == b"new-profile"
        assert target.read_bytes() == b"old-profile"
        assert target.stat().st_mode & 0o777 == 0o640


def test_keychain_failure_restores_search_list_and_deletes_keychain() -> None:
    calls: list[tuple[str, list[str]]] = []
    old_run = pipeline.run_command
    old_invoke = pipeline.invoke

    def fake_run(args, *, cwd=None, env=None, capture=False):
        command = [str(value) for value in args]
        calls.append(("run", command))
        if command[:4] == ["security", "list-keychains", "-d", "user"] and "-s" not in command:
            return SimpleNamespace(stdout='    "/old/login.keychain-db"\n', stderr="", returncode=0)
        return SimpleNamespace(stdout="", stderr="", returncode=0)

    def fake_invoke(args, *, label, cwd=None, env=None, capture=False, dry_run=False):
        calls.append((label, [str(value) for value in args]))
        if label == "authorize codesign keychain access":
            raise pipeline.PipelineError("mock partition failure")
        return SimpleNamespace(stdout="", stderr="", returncode=0)

    try:
        pipeline.run_command = fake_run
        pipeline.invoke = fake_invoke
        with tempfile.TemporaryDirectory() as temp:
            certificate = Path(temp) / "signing.p12"
            certificate.write_bytes(b"certificate")
            keychain = pipeline.TemporaryKeychain(certificate)
            try:
                keychain.__enter__()
            except pipeline.PipelineError:
                pass
            else:
                raise AssertionError("mock keychain failure did not raise")
            labels = [name for name, _ in calls]
            assert "authorize codesign keychain access" in labels
            assert any(
                name == "run"
                and command[:5] == ["security", "list-keychains", "-d", "user", "-s"]
                and "/old/login.keychain-db" in command
                for name, command in calls
            )
            assert any(name == "run" and command[:2] == ["security", "delete-keychain"] for name, command in calls)
            assert not keychain.path.parent.exists()
    finally:
        pipeline.run_command = old_run
        pipeline.invoke = old_invoke


def test_keychain_search_list_failure_does_not_mutate() -> None:
    calls: list[list[str]] = []
    old_run = pipeline.run_command
    old_invoke = pipeline.invoke

    def fake_run(args, *, cwd=None, env=None, capture=False):
        command = [str(value) for value in args]
        calls.append(command)
        if command[:4] == ["security", "list-keychains", "-d", "user"]:
            return SimpleNamespace(stdout="", stderr="security unavailable", returncode=1)
        return SimpleNamespace(stdout="", stderr="", returncode=0)

    def fail_invoke(*args, **kwargs):
        raise AssertionError("keychain mutation happened before search-list read succeeded")

    try:
        pipeline.run_command = fake_run
        pipeline.invoke = fail_invoke
        with tempfile.TemporaryDirectory() as temp:
            certificate = Path(temp) / "signing.p12"
            certificate.write_bytes(b"certificate")
            keychain = pipeline.TemporaryKeychain(certificate)
            try:
                keychain.__enter__()
            except pipeline.PipelineError:
                pass
            else:
                raise AssertionError("search-list failure did not raise")
            assert calls == [["security", "list-keychains", "-d", "user"]]
            assert not keychain.path.parent.exists()
    finally:
        pipeline.run_command = old_run
        pipeline.invoke = old_invoke


def test_altool_uses_api_private_keys_dir_without_home_override() -> None:
    old_values = {
        "ASC_KEY_ID": os.environ.get("ASC_KEY_ID"),
        "ASC_ISSUER_ID": os.environ.get("ASC_ISSUER_ID"),
        "ASC_PRIVATE_KEY_P8": os.environ.get("ASC_PRIVATE_KEY_P8"),
    }
    old_invoke = pipeline.invoke
    observed: dict[str, object] = {}
    try:
        os.environ["ASC_KEY_ID"] = "KEY1234567"
        os.environ["ASC_ISSUER_ID"] = "issuer-for-contract-test"
        os.environ["ASC_PRIVATE_KEY_P8"] = "PRIVATE-KEY-CONTENT"

        def fake_invoke(args, *, label, cwd=None, env=None, capture=False, dry_run=False):
            observed["args"] = [str(value) for value in args]
            observed["env"] = dict(env or {})
            return SimpleNamespace(stdout="", stderr="", returncode=0)

        pipeline.invoke = fake_invoke
        with tempfile.TemporaryDirectory() as temp:
            ipa = Path(temp) / "build.ipa"
            ipa.write_bytes(b"mock-ipa")
            pipeline._asc_upload(ipa)
        command = observed["args"]
        env = observed["env"]
        assert "--platform" in command and "ios" in command
        assert "--api-key" in command and "--api-issuer" in command
        assert "API_PRIVATE_KEYS_DIR" in env
        assert env["HOME"] == os.environ.get("HOME")
        assert not Path(str(env["API_PRIVATE_KEYS_DIR"])).exists()
    finally:
        pipeline.invoke = old_invoke
        for name, value in old_values.items():
            if value is None:
                os.environ.pop(name, None)
            else:
                os.environ[name] = value


def test_altool_write_failure_cleans_private_key_directory() -> None:
    old_values = {
        "ASC_KEY_ID": os.environ.get("ASC_KEY_ID"),
        "ASC_ISSUER_ID": os.environ.get("ASC_ISSUER_ID"),
        "ASC_PRIVATE_KEY_P8": os.environ.get("ASC_PRIVATE_KEY_P8"),
    }
    old_write_text = pipeline.Path.write_text
    root = Path(tempfile.mkdtemp(prefix="pixel-monster-asc-test-"))
    old_mkdtemp = pipeline.tempfile.mkdtemp
    try:
        os.environ["ASC_KEY_ID"] = "KEY1234567"
        os.environ["ASC_ISSUER_ID"] = "issuer-for-contract-test"
        os.environ["ASC_PRIVATE_KEY_P8"] = "PRIVATE-KEY-CONTENT"

        def fail_key_write(path, data, *args, **kwargs):
            if path.name.startswith("AuthKey_"):
                raise OSError("mock p8 write failure")
            return old_write_text(path, data, *args, **kwargs)

        pipeline.Path.write_text = fail_key_write
        pipeline.tempfile.mkdtemp = lambda prefix="": str(root)
        try:
            pipeline._asc_upload(Path("/tmp/mock.ipa"))
        except OSError:
            pass
        else:
            raise AssertionError("mock p8 write failure did not raise")
        assert not root.exists()
    finally:
        pipeline.tempfile.mkdtemp = old_mkdtemp
        pipeline.Path.write_text = old_write_text
        shutil.rmtree(root, ignore_errors=True)
        for name, value in old_values.items():
            if value is None:
                os.environ.pop(name, None)
            else:
                os.environ[name] = value


def test_release_decode_failure_removes_temp_root() -> None:
    old_values = {
        "IOS_CERTIFICATE_P12_BASE64": os.environ.get("IOS_CERTIFICATE_P12_BASE64"),
        "IOS_PROVISIONING_PROFILE_BASE64": os.environ.get("IOS_PROVISIONING_PROFILE_BASE64"),
    }
    old_metadata = pipeline._profile_metadata
    try:
        os.environ["IOS_CERTIFICATE_P12_BASE64"] = "Y2VydA=="
        os.environ["IOS_PROVISIONING_PROFILE_BASE64"] = "cHJvZmlsZQ=="
        pipeline._profile_metadata = lambda profile: (_ for _ in ()).throw(
            pipeline.PipelineError("mock profile parse failure")
        )
        with tempfile.TemporaryDirectory() as temp:
            release_root = Path(temp) / "release-root"
            original_mkdtemp = pipeline.tempfile.mkdtemp
            pipeline.tempfile.mkdtemp = lambda prefix="": (release_root.mkdir() or str(release_root))
            try:
                try:
                    pipeline.build_release(Path(temp) / "output", upload=False)
                except pipeline.PipelineError:
                    pass
                else:
                    raise AssertionError("mock profile failure did not raise")
            finally:
                pipeline.tempfile.mkdtemp = original_mkdtemp
            assert not release_root.exists()
    finally:
        pipeline._profile_metadata = old_metadata
        for name, value in old_values.items():
            if value is None:
                os.environ.pop(name, None)
            else:
                os.environ[name] = value


def test_created_simulator_is_reused_without_booting() -> None:
    runtime = pipeline.DEFAULT_SIMULATOR_RUNTIME
    calls = []
    devices = []

    def fake_invoke(args, **kwargs):
        calls.append(args)
        if args[2] == "list":
            return SimpleNamespace(stdout=json.dumps({"devices": {runtime: devices}}))
        if args[2] == "create":
            devices.append({"name": args[3], "udid": "NEW-DEVICE", "isAvailable": True})
            return SimpleNamespace(stdout="NEW-DEVICE\n")
        raise AssertionError(f"unexpected simulator operation: {args}")

    with mock.patch.dict(os.environ, {"SIMULATOR_UDID": "", "SIMULATOR_RUNTIME": runtime}), \
         mock.patch.object(pipeline, "invoke", fake_invoke):
        assert pipeline.ensure_simulator("iPhone 12") == "NEW-DEVICE"
        assert pipeline.ensure_simulator("iPhone 12") == "NEW-DEVICE"
    assert sum(command[2] == "create" for command in calls) == 1


def main() -> int:
    tests = [
        test_preset_injection_does_not_mutate_source,
        test_preflight_mock_subprocess_contract,
        test_dry_run_never_prints_secret,
        test_command_contract_for_unsigned_build,
        test_export_project_consumes_direct_godot_xcode_output,
        test_matching_source_template_is_unsigned_simulator_only,
        test_matching_source_template_requires_absolute_existing_zip,
        test_build_number_uses_apple_shape_and_run_attempt,
        test_simulator_only_placeholders_never_enter_release,
        test_provisioning_profile_restores_same_uuid,
        test_keychain_failure_restores_search_list_and_deletes_keychain,
        test_keychain_search_list_failure_does_not_mutate,
        test_altool_uses_api_private_keys_dir_without_home_override,
        test_altool_write_failure_cleans_private_key_directory,
        test_release_decode_failure_removes_temp_root,
        test_created_simulator_is_reused_without_booting,
    ]
    for test in tests:
        test()
        print(f"PASS {test.__name__}")
    print(f"{len(tests)} iOS pipeline contract tests passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
