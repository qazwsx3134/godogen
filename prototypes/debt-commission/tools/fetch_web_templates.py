#!/usr/bin/env python3
"""Fetch only Godot 4.7's two single-thread Web templates from the official ZIP.

Uses ZIP byte ranges so this small prototype doesn't download every desktop/mobile
exporter. Each extracted entry is checked against its ZIP CRC before installation.
All cache files stay inside this prototype. Requires curl and Python 3.
"""

from pathlib import Path
import json
import struct
import subprocess
import tempfile
import zlib

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / ".cache/export-data/godot/export_templates/4.7.stable"
API = "https://api.github.com/repos/godotengine/godot-builds/releases/tags/4.7-stable"
ASSET = "Godot_v4.7-stable_export_templates.tpz"
WANTED = {"templates/web_nothreads_debug.zip", "templates/web_nothreads_release.zip"}


def fetch(url, target, byte_range=None):
    command = ["curl", "--fail", "--silent", "--show-error", "--location",
               "--retry", "2", "--connect-timeout", "30", "--max-time", "240"]
    if byte_range is not None:
        start, end = byte_range
        command.extend(["--range", f"{start}-{end}"])
    command.extend(["--output", str(target), url])
    subprocess.run(command, check=True)
    data = target.read_bytes()
    if byte_range is not None and len(data) != end - start + 1:
        raise RuntimeError("Server did not honor the requested ZIP byte range")
    return data


def main():
    if all((DEST / Path(name).name).is_file() for name in WANTED):
        print(f"Web templates already present: {DEST}")
        return
    with tempfile.TemporaryDirectory(prefix="debt-templates-") as temporary:
        temp = Path(temporary)
        release = json.loads(fetch(API, temp / "release.json"))
        asset = next(item for item in release["assets"] if item["name"] == ASSET)
        url, size = asset["browser_download_url"], asset["size"]
        start = max(0, size - 131072)
        tail = fetch(url + "?debt=directory", temp / "tail", (start, size - 1))
        footer_at = tail.rfind(b"PK\x05\x06")
        if footer_at < 0:
            raise RuntimeError("Official template ZIP has no supported directory")
        footer = struct.unpack_from("<4s4H2IH", tail, footer_at)
        offset = footer[-2] - start
        entries = []
        while offset >= 0 and tail[offset:offset + 4] == b"PK\x01\x02":
            fields = struct.unpack_from("<4s6H3I5H2I", tail, offset)
            name_length, extra_length, comment_length = fields[10:13]
            name = tail[offset + 46:offset + 46 + name_length].decode()
            if name in WANTED:
                entries.append((name, fields[4], fields[7], fields[8], fields[9], fields[-1]))
            offset += 46 + name_length + extra_length + comment_length
        if {entry[0] for entry in entries} != WANTED:
            raise RuntimeError("Expected single-thread Web templates are missing")
        DEST.mkdir(parents=True, exist_ok=True)
        for name, method, crc, compressed_size, original_size, entry_at in entries:
            print(f"Fetching {name} ({compressed_size / 1048576:.1f} MiB)", flush=True)
            # ZIP local headers have variable-length extra fields; read the fixed part first.
            header = fetch(url + "?debt=" + Path(name).name + "-header", temp / "header",
                           (entry_at, entry_at + 29))
            if header[:4] != b"PK\x03\x04":
                raise RuntimeError("Invalid ZIP local header")
            name_len, extra_len = struct.unpack_from("<HH", header, 26)
            data_at = entry_at + 30 + name_len + extra_len
            compressed = fetch(url + "?debt=" + Path(name).name, temp / "entry",
                               (data_at, data_at + compressed_size - 1))
            if method == 8:
                payload = zlib.decompress(compressed, -15)
            elif method == 0:
                payload = compressed
            else:
                raise RuntimeError(f"Unsupported ZIP compression: {method}")
            if len(payload) != original_size or zlib.crc32(payload) != crc:
                raise RuntimeError("Template ZIP checksum mismatch")
            (DEST / Path(name).name).write_bytes(payload)
        (DEST / "version.txt").write_text("4.7.stable\n")
        print(f"Installed Web templates: {DEST}")


if __name__ == "__main__":
    main()
