#!/usr/bin/env python3
"""Breaks a Godot .pck (pack format v3/v4) down by kind of file, to see what the web download is made of.

    python3 pck_size.py build/web/index.pck
    python3 pck_size.py --self-test

The big three are usually fonts, textures and audio. `index.wasm` (the engine, about 39.5 MB for Godot 4.7) is not in the pck.
Imported resources are listed by their cached name (.fontdata, .ctex, .oggvorbisstr, .sample); everything else is "other".
"""
import collections, struct, sys

KINDS = [(".fontdata", "font"), (".ctex", "textures"), (".oggvorbisstr", "ogg audio"), (".sample", "wav audio"),
         (".mp3str", "mp3 audio"), (".gd", "scripts"), (".gdc", "scripts"), (".tscn", "scenes/resources"),
         (".scn", "scenes/resources"), (".tres", "scenes/resources"), (".res", "scenes/resources")]


def read_pack(data):
    """(version, (major, minor, patch), [(path, size), ...])."""
    if data[:4] != b"GDPC":
        raise ValueError("not a Godot pack")
    version, major, minor, patch, flags = struct.unpack_from("<5I", data, 4)
    pos = 24
    pos += 8                                   # file_base
    directory = None
    if version >= 3:
        directory = struct.unpack_from("<Q", data, pos)[0]
        pos += 8
    pos = directory if directory else pos + 64      # older packs: 16 reserved words, then the directory
    count = struct.unpack_from("<I", data, pos)[0]
    pos += 4
    files = []
    for _ in range(count):
        n = struct.unpack_from("<I", data, pos)[0]
        pos += 4
        path = data[pos:pos + n].rstrip(b"\0").decode("utf-8")
        pos += n
        offset, size = struct.unpack_from("<QQ", data, pos)
        pos += 16 + 16 + 4                     # offset, size, md5, flags
        files.append((path.replace("res://", ""), size))
    return version, (major, minor, patch), files


def kind(path):
    name = path.split("/")[-1]
    return next((k for ext, k in KINDS if name.endswith(ext)), "other")


def report(path, top=12):
    with open(path, "rb") as f:
        version, engine, files = read_pack(f.read())
    total = collections.Counter()
    for p, size in files:
        total[kind(p)] += size
    lines = ["pack v%d, engine %d.%d.%d, %d files, %.2f MB" % (version, *engine, len(files), sum(s for _, s in files) / 1e6)]
    lines += ["  %-18s %7.2f MB" % (k, s / 1e6) for k, s in total.most_common()]
    lines.append("biggest files:")
    lines += ["  %7.2f MB  %s" % (size / 1e6, p.replace(".godot/imported/", "")[:90]) for p, size in sorted(files, key=lambda f: -f[1])[:top]]
    return "\n".join(lines)


def build_test_pack(entries, version=4):
    """A minimal pack with the layout read_pack expects: header, file data, directory at dir_offset."""
    body = b"".join(content for _, content in entries)
    header_size = 24 + 8 + (8 if version >= 3 else 0) + 64
    directory_at = header_size + len(body)
    out = bytearray(b"GDPC")
    out += struct.pack("<5I", version, 4, 7, 0, 0)
    out += struct.pack("<Q", header_size)
    if version >= 3:
        out += struct.pack("<Q", directory_at)
    out += b"\0" * 64
    out += body
    out += struct.pack("<I", len(entries))
    offset = header_size
    for path, content in entries:
        raw = ("res://" + path).encode("utf-8")
        padded = raw + b"\0" * (-len(raw) % 4)
        out += struct.pack("<I", len(padded)) + padded + struct.pack("<QQ", offset, len(content)) + b"\0" * 16 + struct.pack("<I", 0)
        offset += len(content)
    return bytes(out)


def self_test():
    ok = True
    def expect(condition, label):
        nonlocal ok
        print(("ok   " if condition else "FAIL ") + label)
        ok = ok and condition
    entries = [(".godot/imported/font.ttf-abc.fontdata", b"f" * 3000), (".godot/imported/bg.png-abc.ctex", b"t" * 2000),
               (".godot/imported/a.ogg-abc.oggvorbisstr", b"o" * 1000), ("main.gdc", b"g" * 10), ("ui/title.tscn", b"s" * 20),
               ("project.binary", b"b" * 5)]
    for version in (3, 4):
        v, engine, files = read_pack(build_test_pack(entries, version))
        expect(v == version and engine == (4, 7, 0) and len(files) == 6, "reads a v%d pack header and directory" % version)
        expect([s for _, s in files] == [3000, 2000, 1000, 10, 20, 5], "v%d: sizes come back in order" % version)
    import os, tempfile
    with tempfile.NamedTemporaryFile(suffix=".pck", delete=False) as f:
        f.write(build_test_pack(entries))
    text = report(f.name)
    os.unlink(f.name)
    lines = text.splitlines()
    expect(lines[0].startswith("pack v4, engine 4.7.0, 6 files"), "the header line names version, engine and file count (%s)" % lines[0])
    expect([l.split()[0] for l in lines[1:4]] == ["font", "textures", "ogg"], "kinds come largest first: font, textures, ogg audio")
    expect(any(l.split()[0] == "other" for l in lines[1:8]), "files without a known kind are 'other'")
    expect(lines[lines.index("biggest files:") + 1].split()[-1] == "font.ttf-abc.fontdata", "the biggest file is listed first, without the .godot/imported prefix")
    try:
        read_pack(b"NOTAPACK" + b"\0" * 100)
        raised = False
    except ValueError:
        raised = True
    expect(raised, "a file that is not a pack is refused")
    print("pck_size self-test", "PASSED" if ok else "FAILED")
    return 0 if ok else 1


if __name__ == "__main__":
    if sys.argv[1:] == ["--self-test"]:
        sys.exit(self_test())
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    print(report(sys.argv[1]))
