#!/usr/bin/env python3
"""Build the missing arm64 slices into a new Godot iOS simulator template."""

from __future__ import annotations

import argparse
import ast
import copy
import datetime
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import subprocess
import sys
import tarfile
import tempfile
from typing import Any, Mapping, Optional, Sequence, Union
import urllib.error
import urllib.request
from zipfile import BadZipFile, ZipFile, ZipInfo


GODOT_COMMIT = "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88"
GODOT_CODELOAD_URL = f"https://codeload.github.com/godotengine/godot/tar.gz/{GODOT_COMMIT}"
EXPECTED_VERSION = {"major": 4, "minor": 7, "patch": 0, "status": "stable"}
BUILD_FLAGS = ("platform=ios", "target=template_release", "arch=arm64", "ios_simulator=yes")
ENGINE_MEMBER = "libgodot.ios.release.xcframework/ios-arm64_x86_64-simulator/libgodot.a"
CAMERA_MEMBER = "libgodot_camera.ios.release.xcframework/ios-arm64_x86_64-simulator/libgodot_camera.a"
TARGET_MEMBERS = (ENGINE_MEMBER, CAMERA_MEMBER)
BUILD_ARTIFACTS = {
    ENGINE_MEMBER: "libgodot.ios.template_release.arm64.simulator.a",
    CAMERA_MEMBER: "libgodot_camera.ios.template_release.arm64.simulator.a",
}
SOURCE_MARKER_NAME = ".godot-source-commit"
PROVENANCE_SUFFIX = ".provenance.json"
MAX_OUTPUT = 6000


class TemplatePreparationError(RuntimeError):
    """A safe, actionable preparation failure."""


def run_command(args: Sequence[str], *, cwd: Optional[Path] = None, capture: bool = False) -> Any:
    """The only subprocess seam; tests replace it without invoking native tools."""

    return subprocess.run(
        [str(value) for value in args],
        cwd=str(cwd) if cwd else None,
        text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture else None,
        check=False,
    )


def _log(message: str) -> None:
    print(f"[prepare_simulator_template] {message}", file=sys.stderr)


def _tail(value: Optional[str], limit: int = MAX_OUTPUT) -> str:
    text = (value or "").strip()
    return text if len(text) <= limit else "... " + text[-limit:]


def _failure(command: Sequence[str], result: Any) -> TemplatePreparationError:
    command_text = " ".join(str(part) for part in command)
    detail = _tail("\n".join(part for part in (result.stdout, result.stderr) if part))
    suffix = ":\n" + detail if detail else ""
    return TemplatePreparationError(f"command failed ({result.returncode}): {command_text}{suffix}")


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    try:
        with path.open("rb") as source:
            for chunk in iter(lambda: source.read(1024 * 1024), b""):
                digest.update(chunk)
    except OSError as error:
        raise TemplatePreparationError(f"cannot hash {path}: {error}") from error
    return digest.hexdigest()


def _atomic_bytes(path: Path, payload: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary_name = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=path.parent)
    os.close(fd)
    temporary = Path(temporary_name)
    try:
        with temporary.open("wb") as target:
            target.write(payload)
            target.flush()
            os.fsync(target.fileno())
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def _atomic_json(path: Path, value: Mapping[str, Any]) -> None:
    _atomic_bytes(path, (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8"))


def _path(value: Union[str, Path]) -> Path:
    return Path(value).expanduser().resolve(strict=False)


def _positive_int(value: str) -> int:
    try:
        result = int(value)
    except ValueError as error:
        raise argparse.ArgumentTypeError("must be an integer") from error
    if result < 1:
        raise argparse.ArgumentTypeError("must be >= 1")
    return result


def _resolve_xcrun() -> Path:
    configured = os.environ.get("XCRUN_PATH")
    found = Path(configured).expanduser() if configured else None
    if found is None:
        located = shutil.which("xcrun")
        found = Path(located) if located else None
    if found is None or not found.is_file():
        raise TemplatePreparationError("xcrun is required; install Xcode command-line tools or set XCRUN_PATH")
    return found.resolve(strict=False)


def _resolve_scons(value: Union[str, Path]) -> Path:
    result = _path(value)
    if not result.is_file():
        raise TemplatePreparationError(f"--scons is not a file: {result}")
    return result


def _version(path: Path) -> dict[str, Any]:
    try:
        tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    except (OSError, SyntaxError, UnicodeError) as error:
        raise TemplatePreparationError(f"cannot parse {path}: {error}") from error
    values: dict[str, Any] = {}
    for node in tree.body:
        if isinstance(node, ast.Assign):
            targets, value = node.targets, node.value
        elif isinstance(node, ast.AnnAssign):
            targets, value = [node.target], node.value
        else:
            continue
        if not isinstance(value, ast.Constant):
            continue
        for target in targets:
            if isinstance(target, ast.Name) and target.id in EXPECTED_VERSION:
                values[target.id] = value.value
    if any(values.get(key) != expected for key, expected in EXPECTED_VERSION.items()):
        raise TemplatePreparationError(f"Godot version.py is not pinned 4.7 stable: {path}")
    return {key: values[key] for key in EXPECTED_VERSION}


def _source_info(source_dir: Path, marker: Optional[Path] = None) -> dict[str, Any]:
    source_dir = _path(source_dir)
    if not source_dir.is_dir():
        raise TemplatePreparationError(f"source directory is not a directory: {source_dir}")
    version_path = source_dir / "version.py"
    version = _version(version_path)
    git_dir = source_dir / ".git"
    if git_dir.exists():
        command = ["git", "-C", str(source_dir), "rev-parse", "HEAD"]
        result = run_command(command, capture=True)
        if result.returncode != 0:
            raise _failure(command, result)
        commit = (result.stdout or "").strip()
        status_command = ["git", "-C", str(source_dir), "status", "--porcelain", "--untracked-files=no"]
        status = run_command(status_command, capture=True)
        if status.returncode != 0:
            raise _failure(status_command, status)
        if (status.stdout or "").strip():
            raise TemplatePreparationError(f"source checkout has tracked changes: {source_dir}")
        provenance = "git-head"
    else:
        marker_path = marker or source_dir / SOURCE_MARKER_NAME
        if not marker_path.is_file():
            raise TemplatePreparationError(
                f"source pin is unverifiable; provide git HEAD or {SOURCE_MARKER_NAME}: {source_dir}"
            )
        try:
            commit = marker_path.read_text(encoding="utf-8").strip()
        except OSError as error:
            raise TemplatePreparationError(f"cannot read source marker {marker_path}: {error}") from error
        provenance = "commit-marker"
    if commit != GODOT_COMMIT:
        raise TemplatePreparationError(f"source commit {commit!r} != pinned {GODOT_COMMIT}")
    return {
        "commit": commit,
        "version": version,
        "version_sha256": _sha256(version_path),
        "provenance": provenance,
    }


def _safe_tar_target(root: Path, name: str) -> Path:
    relative = PurePosixPath(name)
    if not name or "\x00" in name or relative.is_absolute() or ".." in relative.parts:
        raise TemplatePreparationError(f"unsafe source archive member: {name!r}")
    target = (root.joinpath(*relative.parts)).resolve(strict=False)
    root = root.resolve(strict=False)
    if target != root and root not in target.parents:
        raise TemplatePreparationError(f"source archive member escapes root: {name!r}")
    return target


def _safe_extract(archive: Path, destination: Path) -> Path:
    destination.mkdir(parents=True, exist_ok=True)
    try:
        opened = tarfile.open(archive, "r:gz")
    except (OSError, tarfile.TarError) as error:
        raise TemplatePreparationError(f"cannot open source archive: {error}") from error
    try:
        for member in opened.getmembers():
            target = _safe_tar_target(destination, member.name)
            if member.issym() or member.islnk() or member.isdev() or not (member.isdir() or member.isfile()):
                raise TemplatePreparationError(f"unsupported source archive member: {member.name}")
            if member.isdir():
                target.mkdir(parents=True, exist_ok=True)
                os.chmod(target, member.mode & 0o777)
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            content = opened.extractfile(member)
            if content is None:
                raise TemplatePreparationError(f"source archive member has no content: {member.name}")
            with content, target.open("xb") as destination_file:
                shutil.copyfileobj(content, destination_file)
            os.chmod(target, member.mode & 0o777)
    except (OSError, tarfile.TarError) as error:
        raise TemplatePreparationError(f"cannot safely extract source archive: {error}") from error
    finally:
        opened.close()
    roots = list(destination.iterdir())
    if len(roots) != 1 or not roots[0].is_dir():
        raise TemplatePreparationError("source archive must contain one top-level directory")
    return roots[0]


def _download(archive: Path) -> None:
    fd, temporary_name = tempfile.mkstemp(prefix=f".{archive.name}.", suffix=".tmp", dir=archive.parent)
    os.close(fd)
    temporary = Path(temporary_name)
    try:
        request = urllib.request.Request(GODOT_CODELOAD_URL, headers={"User-Agent": "pixel-monster-template-preparer"})
        try:
            response = urllib.request.urlopen(request, timeout=60)
        except (OSError, urllib.error.URLError) as error:
            raise TemplatePreparationError(f"cannot download pinned Godot source: {error}") from error
        with response, temporary.open("wb") as target:
            while chunk := response.read(1024 * 1024):
                target.write(chunk)
            target.flush()
            os.fsync(target.fileno())
        os.replace(temporary, archive)
    finally:
        temporary.unlink(missing_ok=True)


def _source_workspace(output: Path) -> Path:
    return output.parent / f".{output.name}.godot-source-{GODOT_COMMIT[:12]}"


def _downloaded_source(output: Path) -> tuple[Path, dict[str, Any]]:
    workspace = _source_workspace(output)
    workspace.mkdir(parents=True, exist_ok=True)
    source = workspace / "source"
    archive = workspace / f"godot-{GODOT_COMMIT}.tar.gz"
    marker = source / SOURCE_MARKER_NAME
    if not source.exists():
        if not archive.exists():
            _log(f"downloading immutable Godot commit {GODOT_COMMIT}")
            _download(archive)
        extraction = Path(tempfile.mkdtemp(prefix=".extract-", dir=workspace))
        try:
            extracted = _safe_extract(archive, extraction)
            os.replace(extracted, source)
        finally:
            shutil.rmtree(extraction, ignore_errors=True)
        marker.write_text(GODOT_COMMIT + "\n", encoding="utf-8")
    info = _source_info(source)
    info["archive_sha256"] = _sha256(archive) if archive.exists() else None
    info["provenance"] = "codeload-commit"
    return source, info


def _norm_zip_name(name: str) -> str:
    name = name.replace("\\", "/")
    relative = PurePosixPath(name)
    if not name or "\x00" in name or relative.is_absolute() or ".." in relative.parts:
        raise TemplatePreparationError(f"unsafe template zip member: {name!r}")
    return "/".join(part for part in relative.parts if part not in ("", "."))


def _symlink(info: ZipInfo) -> bool:
    mode = (info.external_attr >> 16) & 0o177777
    return stat.S_IFMT(mode) == stat.S_IFLNK


def _target_info(archive: ZipFile, member: str) -> ZipInfo:
    matches = [info for info in archive.infolist() if _norm_zip_name(info.filename) == member]
    if len(matches) != 1:
        raise TemplatePreparationError(
            f"template zip {'missing' if not matches else 'duplicates'} required member: {member}"
        )
    if _symlink(matches[0]):
        raise TemplatePreparationError(f"required member is a symlink: {member}")
    return matches[0]


def _arches(path: Path, xcrun: Path) -> frozenset[str]:
    command = [str(xcrun), "lipo", "-info", str(path)]
    result = run_command(command, capture=True)
    if result.returncode != 0:
        raise _failure(command, result)
    text = "\n".join(part for part in (result.stdout, result.stderr) if part)
    fat = re.search(r"\bare:\s*(.+)", text)
    thin = re.search(r"\bis architecture:\s*([A-Za-z0-9_]+)", text)
    found = frozenset(fat.group(1).split()) if fat else frozenset({thin.group(1)}) if thin else frozenset()
    if not found:
        raise TemplatePreparationError(f"cannot determine architectures for {path}: {_tail(text, 1000)}")
    return found


def _inspect(archive_path: Path, xcrun: Path, scratch: Path) -> dict[str, dict[str, Any]]:
    scratch.mkdir(parents=True, exist_ok=True)
    states: dict[str, dict[str, Any]] = {}
    try:
        archive = ZipFile(archive_path, "r")
    except (BadZipFile, OSError, ValueError) as error:
        raise TemplatePreparationError(f"cannot open template zip {archive_path}: {error}") from error
    with archive:
        for index, member in enumerate(TARGET_MEMBERS):
            info = _target_info(archive, member)
            extracted = scratch / f"target-{index}.a"
            extracted.write_bytes(archive.read(info))
            architectures = _arches(extracted, xcrun)
            complete = {"arm64", "x86_64"}.issubset(architectures)
            if architectures != {"x86_64"} and not complete:
                raise TemplatePreparationError(f"wrong architectures for {member}: {sorted(architectures)}")
            states[member] = {"path": extracted, "architectures": architectures, "complete": complete}
    return states


def _build_command(scons: Path, jobs: int) -> list[str]:
    return [str(scons), "-j", str(jobs), *BUILD_FLAGS]


def _tool_output(command: Sequence[str], label: str) -> str:
    result = run_command(command, capture=True)
    if result.returncode != 0:
        raise _failure(command, result)
    # Successful Xcode queries can emit timestamped diagnostics on stderr.
    # Those diagnostics are not part of the toolchain version or cache key.
    output = _tail(result.stdout, 1000)
    if not output:
        raise TemplatePreparationError(f"{label} returned no version information")
    return output


def _toolchain(scons: Path, xcrun: Path) -> dict[str, str]:
    return {
        "scons_path": str(scons),
        "scons_sha256": _sha256(scons),
        "xcrun_path": str(xcrun),
        "xcrun_sha256": _sha256(xcrun),
        "xcodebuild_version": _tool_output(
            [str(xcrun), "xcodebuild", "-version"], "xcodebuild"
        ),
        "iphonesimulator_sdk_version": _tool_output(
            [str(xcrun), "--sdk", "iphonesimulator", "--show-sdk-version"],
            "iphonesimulator SDK",
        ),
    }


def _run_scons(source: Path, command: Sequence[str]) -> None:
    _log("building arm64 simulator archives")
    result = run_command(command, cwd=source, capture=True)
    if result.returncode != 0:
        raise _failure(command, result)
    captured = _tail("\n".join(part for part in (result.stdout, result.stderr) if part))
    _log(f"SCons completed ({len(captured.splitlines()) if captured else 0} captured lines; output bounded)")


def _artifact(source: Path, name: str) -> Path:
    direct = source / "bin" / name
    if direct.is_file():
        return direct
    try:
        matches = [path for path in source.rglob(name) if path.is_file()]
    except OSError as error:
        raise TemplatePreparationError(f"cannot search SCons output: {error}") from error
    if len(matches) == 1:
        return matches[0]
    raise TemplatePreparationError(f"expected one SCons archive {name}; found {matches}")


def _merge(xcrun: Path, arm64: Path, x86: Path, destination: Path) -> None:
    command = [str(xcrun), "lipo", "-create", str(arm64), str(x86), "-output", str(destination)]
    result = run_command(command, capture=True)
    if result.returncode != 0:
        raise _failure(command, result)
    if not destination.is_file() or not {"arm64", "x86_64"}.issubset(_arches(destination, xcrun)):
        raise TemplatePreparationError(f"lipo did not produce a universal archive: {destination}")


def _rewrite_zip(template: Path, output: Path, replacements: Mapping[str, Path]) -> None:
    fd, temporary_name = tempfile.mkstemp(prefix=f".{output.name}.", suffix=".tmp", dir=output.parent)
    os.close(fd)
    temporary = Path(temporary_name)
    seen: set[str] = set()
    try:
        with ZipFile(template, "r") as source, ZipFile(temporary, "w") as destination:
            destination.comment = source.comment
            for info in source.infolist():
                member = _norm_zip_name(info.filename)
                if member in replacements:
                    data = replacements[member].read_bytes()
                    seen.add(member)
                else:
                    if _symlink(info):
                        raise TemplatePreparationError(f"template zip contains a symlink: {member}")
                    data = source.read(info)
                destination.writestr(copy.copy(info), data)
            if seen != set(replacements):
                raise TemplatePreparationError("replacement member disappeared while rewriting the zip")
        with temporary.open("rb") as source:
            os.fsync(source.fileno())
        os.replace(temporary, output)
    except (BadZipFile, OSError, RuntimeError, ValueError) as error:
        raise TemplatePreparationError(f"cannot atomically write {output}: {error}") from error
    finally:
        temporary.unlink(missing_ok=True)


def _copy_atomic(source: Path, output: Path) -> None:
    fd, temporary_name = tempfile.mkstemp(prefix=f".{output.name}.", suffix=".tmp", dir=output.parent)
    os.close(fd)
    temporary = Path(temporary_name)
    try:
        with source.open("rb") as source_file, temporary.open("wb") as destination:
            shutil.copyfileobj(source_file, destination)
            destination.flush()
            os.fsync(destination.fileno())
        os.replace(temporary, output)
    except OSError as error:
        raise TemplatePreparationError(f"cannot atomically copy {source} to {output}: {error}") from error
    finally:
        temporary.unlink(missing_ok=True)


def _manifest_path(output: Path) -> Path:
    return output.with_name(output.name + PROVENANCE_SUFFIX)


def _load_manifest(path: Path) -> Optional[dict[str, Any]]:
    if not path.is_file():
        return None
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError):
        return None
    return value if isinstance(value, dict) else None


def _cache_match(
    manifest: Optional[Mapping[str, Any]],
    *,
    input_hash: str,
    source: Optional[Mapping[str, Any]],
    toolchain: Mapping[str, str],
    command: Sequence[str],
    jobs: int,
) -> bool:
    if not manifest or manifest.get("schema") != 1 or manifest.get("input_sha256") != input_hash:
        return False
    saved_source = manifest.get("source")
    if not isinstance(saved_source, dict) or saved_source.get("commit") != GODOT_COMMIT:
        return False
    if saved_source.get("version") != EXPECTED_VERSION:
        return False
    if source is not None and saved_source.get("version_sha256") != source.get("version_sha256"):
        return False
    build = manifest.get("build")
    return (
        isinstance(build, dict)
        and build.get("jobs") == jobs
        and build.get("command") == list(command)
        and build.get("toolchain") == dict(toolchain)
        and isinstance(manifest.get("output_sha256"), str)
    )


def _cache_output_valid(output: Path, manifest: Mapping[str, Any], xcrun: Path, scratch: Path) -> bool:
    if not output.is_file() or _sha256(output) != manifest.get("output_sha256"):
        return False
    try:
        states = _inspect(output, xcrun, scratch)
    except TemplatePreparationError:
        return False
    return all(state["complete"] for state in states.values())


def prepare_template(
    template_zip: Union[str, Path],
    output: Union[str, Path],
    *,
    source_dir: Optional[Union[str, Path]],
    scons: Union[str, Path],
    jobs: int,
) -> Path:
    """Prepare an output zip without changing the official input zip."""

    template = _path(template_zip)
    destination = _path(output)
    if not template.is_file():
        raise TemplatePreparationError(f"template zip is not a file: {template}")
    if template == destination:
        raise TemplatePreparationError("--output must differ from --template-zip")
    if jobs < 1:
        raise TemplatePreparationError("jobs must be >= 1")
    destination.parent.mkdir(parents=True, exist_ok=True)
    scons_path = _resolve_scons(scons)
    xcrun = _resolve_xcrun()
    command = _build_command(scons_path, jobs)
    toolchain = _toolchain(scons_path, xcrun)
    input_hash = _sha256(template)
    source = _source_info(_path(source_dir)) if source_dir is not None else None

    with tempfile.TemporaryDirectory(prefix=".inspect-", dir=destination.parent) as scratch_name:
        scratch = Path(scratch_name)
        input_states = _inspect(template, xcrun, scratch / "input")
        manifest = _load_manifest(_manifest_path(destination))
        if _cache_match(
            manifest,
            input_hash=input_hash,
            source=source,
            toolchain=toolchain,
            command=command,
            jobs=jobs,
        ) and _cache_output_valid(destination, manifest, xcrun, scratch / "cache"):
            _log(f"cache hit: {destination}")
            return destination

        modes: dict[str, str] = {}
        if all(state["complete"] for state in input_states.values()):
            _copy_atomic(template, destination)
            modes = {member: "reused-complete-input" for member in TARGET_MEMBERS}
            mode = "reuse-complete-input"
        else:
            if source_dir is None:
                build_source, source = _downloaded_source(destination)
            else:
                build_source = _path(source_dir)
                assert source is not None
            _run_scons(build_source, command)
            replacements: dict[str, Path] = {}
            for member, artifact_name in BUILD_ARTIFACTS.items():
                state = input_states[member]
                if state["complete"]:
                    modes[member] = "reused-complete-input"
                    continue
                artifact = _artifact(build_source, artifact_name)
                if _arches(artifact, xcrun) != {"arm64"}:
                    raise TemplatePreparationError(f"SCons archive is not arm64-only: {artifact}")
                merged = scratch / f"merged-{len(replacements)}.a"
                _merge(xcrun, artifact, state["path"], merged)
                replacements[member] = merged
                modes[member] = "merged-arm64-with-x86_64"
            _rewrite_zip(template, destination, replacements)
            mode = "build-and-merge"

        manifest_value = {
            "schema": 1,
            "tool": "prepare_simulator_template",
            "generated_at_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
            "input_sha256": input_hash,
            "source": source or {
                "commit": GODOT_COMMIT,
                "version": EXPECTED_VERSION,
                "version_sha256": None,
                "provenance": "complete-input",
            },
            "build": {"mode": mode, "jobs": jobs, "command": command, "toolchain": toolchain},
            "members": modes,
            "output_sha256": _sha256(destination),
        }
        _atomic_json(_manifest_path(destination), manifest_value)
    _log(f"wrote new simulator template: {destination}")
    return destination


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--template-zip", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--source-dir", type=Path)
    parser.add_argument("--scons", required=True, type=Path)
    parser.add_argument("--jobs", required=True, type=_positive_int)
    return parser


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        prepare_template(
            args.template_zip,
            args.output,
            source_dir=args.source_dir,
            scons=args.scons,
            jobs=args.jobs,
        )
    except TemplatePreparationError as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
