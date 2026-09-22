#!/usr/bin/env python3
"""Offline tests for the arm64 simulator template preparer.

The fake command runner reports architectures from small marker files and
pretends to run SCons/lipo. No network, Godot source build, Xcode, or actual
Apple archive tool is used.
"""

from __future__ import annotations

import importlib.util
import io
import json
from pathlib import Path
import tarfile
import tempfile
import unittest
from typing import Optional
from unittest import mock
from zipfile import ZIP_DEFLATED, ZipFile


SCRIPT = Path(__file__).resolve().parents[1] / "tools" / "ios" / "prepare_simulator_template.py"
SPEC = importlib.util.spec_from_file_location("pixel_monster_simulator_template", SCRIPT)
assert SPEC and SPEC.loader
preparer = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(preparer)


class FakeToolchain:
    def __init__(self, scons: Path, xcrun: Path) -> None:
        self.scons = scons
        self.xcrun = xcrun
        self.scons_calls = 0
        self.lipo_create_calls = 0
        self.commands: list[list[str]] = []
        self.bad_artifact = False
        self.xcodebuild_version = "Xcode 16.4\nBuild version 16F6"
        self.sdk_version = "18.5"

    def run(self, args, *, cwd=None, capture=False):
        command = [str(value) for value in args]
        self.commands.append(command)
        if Path(command[0]).resolve() == self.xcrun.resolve() and command[1:] == ["xcodebuild", "-version"]:
            return _result(stdout=self.xcodebuild_version + "\n")
        if Path(command[0]).resolve() == self.xcrun.resolve() and command[1:] == ["--sdk", "iphonesimulator", "--show-sdk-version"]:
            return _result(stdout=self.sdk_version + "\n")
        if Path(command[0]).resolve() == self.xcrun.resolve() and command[1:] == ["lipo", "-version"]:
            return _result(stdout="Apple lipo version 1\n")
        if Path(command[0]).resolve() == self.xcrun.resolve() and command[1:3] == ["lipo", "-info"]:
            path = Path(command[3])
            return _result(stdout=self._info(path))
        if Path(command[0]).resolve() == self.xcrun.resolve() and command[1:3] == ["lipo", "-create"]:
            self.lipo_create_calls += 1
            output = Path(command[command.index("-output") + 1])
            output.write_bytes(b"universal-output")
            return _result()
        if Path(command[0]).resolve() == self.scons.resolve():
            self.scons_calls += 1
            self.scons_command = command
            source_dir = Path(cwd)
            output_dir = source_dir / "bin"
            output_dir.mkdir(parents=True, exist_ok=True)
            for artifact in preparer.BUILD_ARTIFACTS.values():
                marker = b"wrong-i386" if self.bad_artifact else b"arm64-output"
                (output_dir / artifact).write_bytes(marker)
            return _result(stdout="fake build log\n")
        raise AssertionError(f"unexpected command: {command}")

    @staticmethod
    def _info(path: Path) -> str:
        payload = path.read_bytes()
        if payload.startswith(b"universal"):
            return f"Architectures in the fat file: {path} are: arm64 x86_64\n"
        if payload.startswith(b"arm64"):
            return f"Non-fat file: {path} is architecture: arm64\n"
        if payload.startswith(b"x86"):
            return f"Non-fat file: {path} is architecture: x86_64\n"
        if payload.startswith(b"wrong-i386"):
            return f"Non-fat file: {path} is architecture: i386\n"
        raise AssertionError(f"unknown fake archive payload: {payload!r}")


def _result(*, stdout: str = "", stderr: str = "", returncode: int = 0):
    class Result:
        pass

    result = Result()
    result.stdout = stdout
    result.stderr = stderr
    result.returncode = returncode
    return result


def _source_fixture(root: Path, *, commit: str = preparer.GODOT_COMMIT, version=None) -> Path:
    source = root / "godot-source"
    source.mkdir(parents=True)
    source_version = version or preparer.EXPECTED_VERSION
    (source / "version.py").write_text(
        "\n".join(
            [
                f"major = {source_version['major']}",
                f"minor = {source_version['minor']}",
                f"patch = {source_version['patch']}",
                f"status = {source_version['status']!r}",
            ]
        )
        + "\n",
        encoding="utf-8",
    )
    (source / preparer.SOURCE_MARKER_NAME).write_text(commit + "\n", encoding="utf-8")
    return source


def _template_fixture(
    root: Path,
    *,
    complete: bool = False,
    wrong_arch: bool = False,
    missing: Optional[str] = None,
) -> Path:
    root.mkdir(parents=True, exist_ok=True)
    template = root / "official-ios.zip"
    members = {
        preparer.ENGINE_MEMBER: b"universal-engine" if complete else (b"wrong-i386" if wrong_arch else b"x86-engine"),
        preparer.CAMERA_MEMBER: b"universal-camera" if complete else b"x86-camera",
        "libgodot.ios.release.xcframework/ios-arm64/libgodot.a": b"device-engine-bytes",
        "libgodot_camera.ios.release.xcframework/ios-arm64/libgodot_camera.a": b"device-camera-bytes",
        "preserve/other-member.bin": b"untouched-member-bytes",
    }
    if missing is not None:
        members.pop(missing, None)
    with ZipFile(template, "w", compression=ZIP_DEFLATED) as archive:
        for name, payload in members.items():
            archive.writestr(name, payload)
    return template


class SimulatorTemplateTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.scons = self.root / "scons"
        self.scons.write_bytes(b"fake-scons-compiler-provenance")
        self.xcrun = self.root / "xcrun"
        self.xcrun.write_bytes(b"fake-xcrun-toolchain-provenance")
        self.source = _source_fixture(self.root)
        self.fake = FakeToolchain(self.scons, self.xcrun)
        self.patches = mock.patch.multiple(
            preparer,
            run_command=self.fake.run,
            _resolve_xcrun=lambda: self.xcrun,
        )
        self.patches.start()

    def tearDown(self) -> None:
        self.patches.stop()
        self.temp.cleanup()

    def _prepare(self, template: Path, output: Optional[Path] = None) -> Path:
        return preparer.prepare_template(
            template,
            output or (self.root / "prepared-ios.zip"),
            source_dir=self.source,
            scons=self.scons,
            jobs=3,
        )

    def test_merge_preserves_non_simulator_members_and_cache_reuses(self) -> None:
        template = _template_fixture(self.root)
        output = self._prepare(template)

        self.assertEqual(self.fake.scons_calls, 1)
        self.assertEqual(self.fake.lipo_create_calls, 2)
        self.assertEqual(self.fake.scons_command[1:], ["-j", "3", *preparer.BUILD_FLAGS])
        with ZipFile(template) as original, ZipFile(output) as prepared:
            self.assertEqual(original.namelist(), prepared.namelist())
            for name in original.namelist():
                if name not in preparer.TARGET_MEMBERS:
                    self.assertEqual(prepared.read(name), original.read(name), name)
            self.assertEqual(prepared.read(preparer.ENGINE_MEMBER), b"universal-output")
            self.assertEqual(prepared.read(preparer.CAMERA_MEMBER), b"universal-output")
            self.assertEqual(prepared.read("libgodot.ios.release.xcframework/ios-arm64/libgodot.a"), b"device-engine-bytes")
            self.assertEqual(
                prepared.read("libgodot_camera.ios.release.xcframework/ios-arm64/libgodot_camera.a"),
                b"device-camera-bytes",
            )

        manifest_path = Path(str(output) + preparer.PROVENANCE_SUFFIX)
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        self.assertEqual(manifest["source"]["commit"], preparer.GODOT_COMMIT)
        self.assertEqual(manifest["build"]["jobs"], 3)
        self.assertEqual(manifest["build"]["command"][3:], list(preparer.BUILD_FLAGS))
        self.assertEqual(manifest["build"]["toolchain"]["xcodebuild_version"], self.fake.xcodebuild_version)
        self.assertEqual(manifest["build"]["toolchain"]["iphonesimulator_sdk_version"], self.fake.sdk_version)

        output_before_cache = output.read_bytes()
        scons_before_cache = self.fake.scons_calls
        lipo_before_cache = self.fake.lipo_create_calls
        self._prepare(template, output)
        self.assertEqual(self.fake.scons_calls, scons_before_cache)
        self.assertEqual(self.fake.lipo_create_calls, lipo_before_cache)
        self.assertEqual(output.read_bytes(), output_before_cache)

    def test_complete_input_is_copied_without_build_and_wrong_output_is_refused(self) -> None:
        template = _template_fixture(self.root, complete=True)
        output = self._prepare(template)
        self.assertEqual(self.fake.scons_calls, 0)
        self.assertEqual(output.read_bytes(), template.read_bytes())

        with self.assertRaises(preparer.TemplatePreparationError):
            self._prepare(template, template)

    def test_wrong_or_missing_simulator_architecture_is_rejected(self) -> None:
        wrong_template = _template_fixture(self.root, wrong_arch=True)
        with self.assertRaises(preparer.TemplatePreparationError):
            self._prepare(wrong_template)
        self.assertFalse((self.root / "prepared-ios.zip").exists())

        missing_template = _template_fixture(self.root, missing=preparer.CAMERA_MEMBER)
        with self.assertRaises(preparer.TemplatePreparationError):
            self._prepare(missing_template)

        artifact_template = _template_fixture(self.root)
        self.fake.bad_artifact = True
        with self.assertRaises(preparer.TemplatePreparationError):
            self._prepare(artifact_template)

    def test_source_pin_and_version_are_verified(self) -> None:
        wrong_commit_source = _source_fixture(self.root / "wrong-commit", commit="deadbeef")
        with self.assertRaises(preparer.TemplatePreparationError):
            preparer.prepare_template(
                _template_fixture(self.root / "wrong-commit-template"),
                self.root / "wrong-commit-output.zip",
                source_dir=wrong_commit_source,
                scons=self.scons,
                jobs=1,
            )

        wrong_version_source = _source_fixture(
            self.root / "wrong-version",
            version={"major": 4, "minor": 6, "patch": 0, "status": "stable"},
        )
        with self.assertRaises(preparer.TemplatePreparationError):
            preparer.prepare_template(
                _template_fixture(self.root / "wrong-version-template"),
                self.root / "wrong-version-output.zip",
                source_dir=wrong_version_source,
                scons=self.scons,
                jobs=1,
            )

    def test_cache_invalidates_on_input_hash_or_manifest_pin_change(self) -> None:
        template = _template_fixture(self.root)
        output = self._prepare(template)
        self.assertEqual(self.fake.scons_calls, 1)

        with ZipFile(template, "a", compression=ZIP_DEFLATED) as archive:
            archive.writestr("preserve/cache-input-change.bin", b"changed-input")
        self._prepare(template, output)
        self.assertEqual(self.fake.scons_calls, 2)

        manifest_path = Path(str(output) + preparer.PROVENANCE_SUFFIX)
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        manifest["source"]["commit"] = "wrong-pin"
        manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
        self._prepare(template, output)
        self.assertEqual(self.fake.scons_calls, 3)

    def test_safe_tar_extraction_rejects_path_escape(self) -> None:
        archive = self.root / "malicious-source.tar.gz"
        with tarfile.open(archive, "w:gz") as tar:
            payload = b"outside"
            member = tarfile.TarInfo("../escaped.txt")
            member.size = len(payload)
            tar.addfile(member, io.BytesIO(payload))
        destination = self.root / "extracted"
        with self.assertRaises(preparer.TemplatePreparationError):
            preparer._safe_extract(archive, destination)
        self.assertFalse((self.root / "escaped.txt").exists())

    def test_version_diagnostics_do_not_invalidate_cache(self) -> None:
        template = _template_fixture(self.root)
        output = self._prepare(template)
        original_runner = self.fake.run

        def noisy_query(args, **kwargs):
            result = original_runner(args, **kwargs)
            if "--show-sdk-version" in args or "-version" in args:
                result.stderr = "2026-09-22 Xcode: Failed to start fs event stream.\n"
            return result

        with mock.patch.object(preparer, "run_command", noisy_query), \
             mock.patch.object(preparer, "_download", side_effect=AssertionError("cache must be offline")):
            preparer.prepare_template(template, output, source_dir=None, scons=self.scons, jobs=3)
        self.assertEqual(self.fake.scons_calls, 1)


if __name__ == "__main__":
    unittest.main()
