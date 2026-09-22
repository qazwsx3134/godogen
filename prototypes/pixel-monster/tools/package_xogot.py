#!/usr/bin/env python3
"""Package the standard Godot project, without generated files or any player saves."""
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

project = Path(__file__).resolve().parents[1]
destination = project / "build" / "pixel-monster-xogot.zip"
destination.parent.mkdir(exist_ok=True)
(destination.parent / ".gdignore").touch()
excluded = {".godot", "build", ".git", "__pycache__", "evidence"}
with ZipFile(destination, "w", compression=ZIP_DEFLATED) as archive:
    for source in sorted(project.rglob("*")):
        relative = source.relative_to(project)
        if not source.is_file() or excluded.intersection(relative.parts):
            continue
        if source.suffix in {".log", ".tmp", ".bak", ".p12", ".p8", ".mobileprovision", ".key"}:
            continue
        if source.name.startswith(".env"):
            continue
        archive.write(source, Path("pixel-monster") / relative)
print(destination)
print(f"{destination.stat().st_size / 1024 / 1024:.1f} MiB")
