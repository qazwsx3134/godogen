#!/usr/bin/env python3
"""Shrinks a CJK UI font to what a game needs, for small web builds.

    python3 godot-kit/tools/subset_font.py --project prototypes/<name> \\
        --source prototypes/<name>/art_src/fonts/NotoSansTC-VF.ttf \\
        --out    prototypes/<name>/ui/fonts/NotoSansTC.ttf --weight 700
    python3 godot-kit/tools/subset_font.py --project . --source <font> --check     # report only, write nothing
    python3 godot-kit/tools/subset_font.py --self-test

Why: a full CJK font is 10-17 MB; the web download of a small game is mostly that font (sugarcane-tanks:
8.9 MB of a 21.6 MB .pck; pixel-monster and seichi-pov each carry the same 11.9 MB file; taskbar-hero 33 MB).
Keep the source font OUT of the build (a folder with a .gdignore, e.g. art_src/fonts/) and ship only the output.

What stays in the font
  - ASCII
  - every non-ASCII character found in the project's scripts, scenes, resources AND data files
    (default extensions: gd tscn tres json txt cfg csv ds dialogue yaml yml ini toml; add more with --ext).
    Games keep their text in data files (JSON, dialogue, config); a scanner that only reads scripts
    silently drops those glyphs and they show as blank boxes on the web, where there is no system font.
  - common symbol blocks (punctuation, arrows, shapes, full-width forms)
  - the 5,401 most common Traditional Chinese characters (Big5 level 1), so ordinary new text just works.
    --minimal drops this margin and the symbol blocks (about 0.2 MB instead of about 2 MB).
A variable font is baked at --weight (the wght axis); without --weight it is kept variable. A static
font (TTF or OTF/CFF) is only subset.

Make the game's tests fail when a character has no glyph: addons/proto_kit/font_check.gd.
Licence: SIL OFL fonts may be modified; keep the licence file next to the font and the name table's
copyright and licence records (this tool keeps every name record). Check a font's Reserved Font Name:
Noto Sans TC's is 'Source', which the family name does not use, so no rename is needed.
Needs fonttools: pip install fonttools   (brotli is not needed for TTF/OTF output).
"""
import argparse, os, sys, tempfile

DEFAULT_EXTENSIONS = ("gd", "tscn", "tres", "json", "txt", "cfg", "csv", "ds", "dialogue", "yaml", "yml", "ini", "toml")
DEFAULT_SKIP_DIRS = ("addons", "art_src", "tests", "tools", "build", "docs", "publishing", "node_modules", "test-results")
SYMBOL_BLOCKS = [(0x00A0, 0x00FF), (0x2000, 0x206F), (0x2190, 0x21FF), (0x2460, 0x24FF), (0x25A0, 0x25FF),
                 (0x2600, 0x26FF), (0x3000, 0x303F), (0xFF00, 0xFFEF)]


def project_characters(project, extensions=DEFAULT_EXTENSIONS, skip_dirs=DEFAULT_SKIP_DIRS):
    """{character: first file that wrote it} for every non-ASCII character in the project's text files."""
    found = {}
    wanted = tuple("." + e.lstrip(".") for e in extensions)
    for folder, dirs, files in os.walk(project):
        dirs[:] = sorted(d for d in dirs if d not in skip_dirs and not d.startswith("."))
        for name in sorted(files):
            if not name.endswith(wanted):
                continue
            path = os.path.join(folder, name)
            try:
                with open(path, encoding="utf-8") as f:
                    text = f.read()
            except (UnicodeDecodeError, OSError):
                continue
            for c in text:
                if ord(c) > 0x7E and c != "﻿" and c not in found:
                    found[c] = os.path.relpath(path, project)
    return found


def big5_level1():
    out = set()
    for hi in range(0xA4, 0xC7):
        for lo in list(range(0x40, 0x7F)) + list(range(0xA1, 0xFF)):
            try:
                out.add(bytes([hi, lo]).decode("big5"))
            except UnicodeDecodeError:
                pass
    return out


def wanted_characters(used, minimal):
    wanted = {chr(c) for c in range(0x20, 0x7F)} | set(used)
    if not minimal:
        wanted |= {chr(c) for a, b in SYMBOL_BLOCKS for c in range(a, b + 1)} | big5_level1()
    return wanted


def load_font(path, weight):
    from fontTools.ttLib import TTFont
    from fontTools.varLib import instancer
    # recalcTimestamp=False: keep the source's own head.modified, so the same inputs always give the same bytes.
    font = TTFont(path, recalcTimestamp=False)
    if weight is not None and "fvar" in font:
        try:
            font = instancer.instantiateVariableFont(font, {"wght": weight}, inplace=False, updateFontNames=True)
        except Exception:   # a font without a usable STAT table cannot rename itself; the outlines are what matter
            font = instancer.instantiateVariableFont(TTFont(path, recalcTimestamp=False), {"wght": weight}, inplace=False)
    font.recalcTimestamp = False
    return font


def subset_font(font, characters):
    """Subsets `font` (modified in place) to `characters`, keeping every name record and the OpenType features."""
    from fontTools import subset
    cmap = font.getBestCmap()
    options = subset.Options()
    options.name_IDs = ["*"]
    options.name_languages = ["*"]
    options.name_legacy = True
    options.notdef_outline = True
    options.layout_features = ["*"]
    options.drop_tables += ["DSIG", "vhea", "vmtx", "VORG", "BASE"]
    subsetter = subset.Subsetter(options)
    subsetter.populate(unicodes=sorted(ord(c) for c in characters if ord(c) in cmap))
    subsetter.subset(font)
    return font


def run(args):
    project = os.path.abspath(args.project)
    used = project_characters(project, args.ext, args.skip_dir)
    font = load_font(args.source, args.weight)
    cmap = font.getBestCmap()
    missing = sorted(c for c in used if ord(c) not in cmap)
    keep = {c for c in wanted_characters(used, args.minimal) if ord(c) in cmap}
    print("%s writes %d non-ASCII characters; keeping %d; the source font lacks: %s"
          % (os.path.basename(project) or project, len(used), len(keep), "".join(missing) or "none"))
    for c in missing[:10]:
        print("  U+%04X %s  first written in %s" % (ord(c), c, used[c]))
    if args.check:
        return 1 if missing else 0
    if not args.out:
        sys.exit("--out is required (the source font is never overwritten)")
    if os.path.abspath(args.out) == os.path.abspath(args.source):
        sys.exit("--out must differ from --source: keep the full font as the source")
    subset_font(font, keep)
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    font.save(args.out)
    print("wrote %s: %d glyphs, %.2f MB (source %.2f MB)" % (args.out, len(font.getGlyphOrder()),
          os.path.getsize(args.out) / 1e6, os.path.getsize(args.source) / 1e6))
    return 1 if missing else 0


def make_test_font(path, characters):
    """A tiny TrueType font where every glyph is a square: enough to test scanning and subsetting."""
    from fontTools.fontBuilder import FontBuilder
    from fontTools.pens.ttGlyphPen import TTGlyphPen
    names = [".notdef"] + ["glyph%04X" % ord(c) for c in characters]
    pen = TTGlyphPen(None)
    pen.moveTo((0, 0)); pen.lineTo((0, 500)); pen.lineTo((500, 500)); pen.lineTo((500, 0)); pen.closePath()
    square = pen.glyph()
    fb = FontBuilder(1000, isTTF=True)
    fb.setupGlyphOrder(names)
    fb.setupCharacterMap({ord(c): "glyph%04X" % ord(c) for c in characters})
    fb.setupGlyf({n: square for n in names})
    fb.setupHorizontalMetrics({n: (600, 0) for n in names})
    fb.setupHorizontalHeader(ascent=800, descent=-200)
    fb.setupNameTable({"familyName": "Test", "styleName": "Regular", "copyright": "(c) test, SIL OFL 1.1"})
    fb.setupOS2()
    fb.setupPost()
    fb.save(path)


def self_test():
    from fontTools.ttLib import TTFont
    ok = True
    def expect(condition, label):
        nonlocal ok
        print(("ok   " if condition else "FAIL ") + label)
        ok = ok and condition
    with tempfile.TemporaryDirectory() as tmp:
        for rel, text in {"game/a.gd": 'var s = "安A"', "data/story.json": '{"line": "國"}', "ui/t.tres": 'text = "安"',
                          "tests/skip.gd": 'var s = "蔣"', "addons/kit/skip.gd": 'var s = "鑿"', ".godot/skip.gd": 'var s = "驫"',
                          "notes.md": "龍"}.items():
            os.makedirs(os.path.dirname(os.path.join(tmp, rel)), exist_ok=True)
            with open(os.path.join(tmp, rel), "w", encoding="utf-8") as f:
                f.write(text)
        used = project_characters(tmp)
        expect(set(used) == {"安", "國"}, "scans scripts, scenes and data files, skips tests/addons/hidden folders and .md (found %s)" % "".join(sorted(used)))
        expect(used["國"].replace(os.sep, "/") == "data/story.json", "reports where a character was first written")
        expect(set(project_characters(tmp, extensions=("gd",))) == {"安"}, "--ext narrows the scan")
        source = os.path.join(tmp, "src.ttf")
        make_test_font(source, "AB安國蔣龍 ")
        out = os.path.join(tmp, "out.ttf")
        args = argparse.Namespace(project=tmp, source=source, out=out, weight=None, minimal=True, check=False,
                                  ext=DEFAULT_EXTENSIONS, skip_dir=DEFAULT_SKIP_DIRS)
        expect(run(args) == 0, "a font that has every used character exits 0")
        cmap = TTFont(out).getBestCmap()
        expect(set(chr(c) for c in cmap) == set("AB 安國"), "--minimal keeps ASCII that exists in the font plus the used characters (got %s)" % "".join(sorted(chr(c) for c in cmap)))
        expect(os.path.getsize(out) < os.path.getsize(source), "the output is smaller than the source")
        again = os.path.join(tmp, "again.ttf")
        args.out = again
        run(args)
        args.out = out
        with open(out, "rb") as f1, open(again, "rb") as f2:
            expect(f1.read() == f2.read(), "the same inputs give the same bytes (reproducible)")
        name = TTFont(out)["name"]
        expect(any("SIL OFL" in r.toUnicode() for r in name.names), "the copyright and licence name records survive")
        with open(os.path.join(tmp, "game/b.gd"), "w", encoding="utf-8") as f:
            f.write('var s = "鬱"')   # a character the source font does not have
        args.check = True
        expect(run(args) == 1, "--check exits 1 and names a character the font lacks")
        args.check = False; args.out = source
        try:
            run(args); refused = False
        except SystemExit:
            refused = True
        expect(refused, "refuses to overwrite the source font")
        expect(len(big5_level1()) in range(5300, 5500), "Big5 level 1 has about 5,401 characters (%d)" % len(big5_level1()))
    print("subset_font self-test", "PASSED" if ok else "FAILED")
    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--project", default=".", help="the Godot project whose text decides which characters stay (default: .)")
    ap.add_argument("--source", help="the full font (kept; never overwritten)")
    ap.add_argument("--out", help="where to write the subset font")
    ap.add_argument("--weight", type=int, help="bake this wght value into a variable font (the game's theme weight, e.g. 700)")
    ap.add_argument("--minimal", action="store_true", help="only the characters the project writes")
    ap.add_argument("--check", action="store_true", help="report characters the source font lacks; write nothing")
    ap.add_argument("--ext", type=lambda s: tuple(x for x in s.split(",") if x), default=DEFAULT_EXTENSIONS, help="text file extensions to scan, comma separated")
    ap.add_argument("--skip-dir", action="append", help="folder name to skip (repeatable; replaces the default list)")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    if args.self_test:
        return self_test()
    args.skip_dir = tuple(args.skip_dir) if args.skip_dir else DEFAULT_SKIP_DIRS
    if not args.source:
        ap.error("--source is required")
    return run(args)


if __name__ == "__main__":
    sys.exit(main())
