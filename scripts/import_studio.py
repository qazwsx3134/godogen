"""Vendor a pinned CCGS checkout into host-neutral Godogen sources (no network)."""
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


def import_checkout(checkout: Path, destination: Path) -> None:
    revision = subprocess.check_output(
        ["git", "-C", str(checkout), "rev-parse", "HEAD"], text=True
    ).strip()
    if destination.exists():
        raise ValueError(f"Destination already exists: {destination}; import to a new directory and review the diff")
    files = {}
    mappings = {".claude": "framework", "docs": "project/docs",
                "design": "project/design", "src": "project/src",
                "CCGS Skill Testing Framework": "testing"}
    for source_dir, target_dir in mappings.items():
        for source in sorted((checkout / source_dir).rglob("*")):
            if not source.is_file():
                continue
            relative = source.relative_to(checkout).as_posix()
            target = destination / target_dir / source.relative_to(checkout / source_dir)
            if target.name == "CLAUDE.md":
                target = target.with_name("manifest.md")
            target.parent.mkdir(parents=True, exist_ok=True)
            raw = source.read_bytes()
            text = raw.decode("utf-8").replace(".claude", "{{STUDIO_DIR}}")
            text = text.replace("CLAUDE.md", "{{MANIFEST}}")
            target.write_text(text, encoding="utf-8")
            target.chmod(source.stat().st_mode & 0o777)
            files[relative] = {"sha256": hashlib.sha256(raw).hexdigest(),
                               "destination": target.relative_to(destination).as_posix()}
    for name in ("LICENSE", "project.yaml", "CLAUDE.md", "UPGRADING.md"):
        source = checkout / name
        target = destination / ("manifest.md" if name == "CLAUDE.md" else name)
        raw = source.read_bytes()
        target.write_text(raw.decode().replace(".claude", "{{STUDIO_DIR}}")
                          .replace("CLAUDE.md", "{{MANIFEST}}"), encoding="utf-8")
        files[name] = {"sha256": hashlib.sha256(raw).hexdigest(), "destination": target.name}
    provenance = {"repository": "https://github.com/Donchitos/Claude-Code-Game-Studios",
                  "revision": revision, "license": "MIT", "files": files}
    (destination / "provenance.json").write_text(json.dumps(provenance, indent=2) + "\n")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--upstream", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()
    import_checkout(args.upstream.resolve(), args.out.resolve())


if __name__ == "__main__":
    main()
