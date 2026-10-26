#!/usr/bin/env python3
"""Read-only client inventory; lists ZIP metadata without opening payloads."""
import argparse
from collections import Counter, defaultdict
import json
from pathlib import Path
import wave
import zipfile


def inventory(root):
    directories = defaultdict(lambda: {"files": 0, "bytes": 0, "extensions": Counter()})
    archives = []
    wav_formats = Counter()
    for path in sorted(root.rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(root)
        group = rel.parts[0] if len(rel.parts) > 1 else "(root)"
        row = directories[group]
        row["files"] += 1
        row["bytes"] += path.stat().st_size
        row["extensions"][path.suffix.lower()] += 1
        if path.suffix.lower() == ".wav":
            try:
                with wave.open(str(path)) as audio:
                    key = f"{audio.getframerate()}Hz/{audio.getnchannels()}ch/{audio.getsampwidth()*8}bit"
                wav_formats[key] += 1
            except (wave.Error, EOFError):
                wav_formats["not_readable_by_python_wave"] += 1
        if path.suffix.lower() != ".spak":
            continue
        with zipfile.ZipFile(path) as archive:
            entries = [i for i in archive.infolist() if not i.is_dir()]
            terms = ("pet", "quest", "refin", "costume", "guard", "aura", "guild", "couple", "party", "trade", "fish")
            archives.append({
                "path": rel.as_posix(),
                "bytes": path.stat().st_size,
                "entries": len(entries),
                "encrypted_flag_entries": sum(bool(i.flag_bits & 1) for i in entries),
                "declared_uncompressed_bytes": sum(i.file_size for i in entries),
                "extensions": dict(sorted(Counter(Path(i.filename).suffix.lower() for i in entries).items())),
                "filename_examples": [i.filename for i in entries[:12]],
                "name_matches": {term: [i.filename for i in entries if term in i.filename.lower()][:12] for term in terms},
            })
    shader_markers = {}
    for filename, terms in {
        "so3deffect.fx": ["VSScale", "VSSelect", "WorldView", "GlowThickness", "CullMode", "TOutLine"],
        "TextOutlineGlow.fx": ["PS_Glow", "PS_OutlineStacked", "PS_Combined"],
        "phase.fx": ["NoiseTex", "progress", "ps_dissolve", "PS_Combined"],
    }.items():
        lines = (root / filename).read_text(errors="replace").splitlines()
        shader_markers[filename] = {term: [n for n, line in enumerate(lines, 1) if term in line] for term in terms}
    return {
        "root": str(root),
        "method": "filesystem stat, ZIP central-directory metadata, WAV headers, plaintext shader markers; no payload decryption or game execution",
        "directories": dict(sorted(directories.items())),
        "archives": archives,
        "archive_entry_total": sum(a["entries"] for a in archives),
        "wav_formats": dict(sorted(wav_formats.items())),
        "shader_markers": shader_markers,
        "client_build_files": {name: (root / name).read_text(errors="replace") for name in ("version_usa.ver", "version_usa_x64.ver")},
        "capture_files": sum(p.is_file() for p in (root / "capture").rglob("*")),
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    root = args.root.resolve()
    output = args.output.resolve()
    if output == root or root in output.parents:
        parser.error("output must be outside the client directory")
    result = inventory(root)
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(f"{len(result['archives'])} archives, {result['archive_entry_total']} entries; saved {output}")
