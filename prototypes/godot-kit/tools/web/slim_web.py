#!/usr/bin/env python3
"""Slims a COPY of a Godot project before its web export, so the download shrinks while the sources stay untouched.

    uv run --with fonttools --with pillow --with soundfile python3 slim_web.py <scratch copy of the project>
    python3 slim_web.py --self-test

Run it on a throwaway copy (build_web.sh scripts rsync the project to .cache/web-slim first), never on the project:
it overwrites fonts, images, audio and .import files in place. Each step only touches files above a size floor.

  fonts     every imported .ttf/.otf/.ttc over 1 MB -> subset to the characters the project writes plus Big5 level 1
            (subset_font.py). A .ttc keeps only face 0, which is what Godot loads unless face_index is set.
            Done on every build, so new story text never misses a glyph.
  textures  every imported image over 64 KB that is stored lossless -> Lossy WebP at quality 0.9 (`.import` params).
  splash    application/boot_splash/image -> at most 1280 px wide (it ships twice: raw in the pck and as index.png).
  icon      application/config/icon -> at most 512 px (index.icon.png, apple-touch-icon).
  audio     every .ogg over 512 KB -> re-encoded at Vorbis quality 0.3 (about 110 kbps). Check by ear once.
"""
import os, re, sys

FONT_FLOOR = 1 << 20
TEXTURE_FLOOR = 64 << 10
OGG_FLOOR = 512 << 10
SKIP_DIRS = {".godot", ".cache", "build", "art_src", "tests", "tools", "test-results"}
IMAGE_EXT = (".png", ".jpg", ".jpeg", ".webp")


def files(root, exts):
    for folder, dirs, names in os.walk(root):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS and not d.startswith(".")]
        for n in names:
            if n.lower().endswith(exts):
                yield os.path.join(folder, n)


def lossy_import(text, quality=0.9):
    """Turns a lossless texture .import into Lossy WebP; returns None when there is nothing to change."""
    if 'importer="texture"' not in text or not re.search(r"^compress/mode=0$", text, re.M):
        return None
    text = re.sub(r"^compress/mode=0$", "compress/mode=1", text, flags=re.M)
    return re.sub(r"^compress/lossy_quality=.*$", "compress/lossy_quality=%s" % quality, text, flags=re.M)


def project_setting(root, key):
    m = re.search(r'^%s="res://([^"]+)"' % re.escape(key), open(os.path.join(root, "project.godot"), encoding="utf-8").read(), re.M)
    return os.path.join(root, m.group(1)) if m else None


def mb(n):
    return "%.1f MB" % (n / 1048576)


def slim_fonts(root):
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
    import subset_font as sf
    from fontTools.ttLib import TTFont
    used = sf.project_characters(root)
    for path in files(root, (".ttf", ".otf", ".ttc")):
        before = os.path.getsize(path)
        if before < FONT_FLOOR or not os.path.exists(path + ".import"):
            continue
        font = TTFont(path, fontNumber=0, recalcTimestamp=False) if path.endswith(".ttc") else TTFont(path, recalcTimestamp=False)
        cmap = font.getBestCmap()
        missing = "".join(sorted(c for c in used if ord(c) not in cmap))
        sf.subset_font(font, {c for c in sf.wanted_characters(used, False) if ord(c) in cmap})
        font.save(path)  # a .ttc path now holds one TTF face; FreeType reads it by content, the name keeps every reference
        print("font     %s  %s -> %s%s" % (os.path.relpath(path, root), mb(before), mb(os.path.getsize(path)),
              "  (font lacks: %s)" % missing[:40] if missing else ""))


def slim_textures(root):
    count = saved_from = 0
    for path in files(root, IMAGE_EXT):
        imp = path + ".import"
        if os.path.getsize(path) < TEXTURE_FLOOR or not os.path.exists(imp):
            continue
        new = lossy_import(open(imp, encoding="utf-8").read())
        if new:
            open(imp, "w", encoding="utf-8").write(new)
            count += 1
            saved_from += os.path.getsize(path)
    print("textures %d images (%s of source PNG) -> Lossy WebP 0.9" % (count, mb(saved_from)))


def shrink_image(path, limit, label):
    from PIL import Image
    if not path or not os.path.exists(path):
        return
    before = os.path.getsize(path)
    im = Image.open(path)
    if max(im.size) > limit:
        im.thumbnail((limit, limit), Image.LANCZOS)
    if im.mode == "RGBA" and im.getchannel("A").getextrema() == (255, 255):
        im = im.convert("RGB")
    im.save(path, optimize=True)
    print("%-8s %s  %s -> %s" % (label, os.path.relpath(path), mb(before), mb(os.path.getsize(path))))


def slim_audio(root):
    import soundfile
    total_before = total_after = 0
    for path in files(root, (".ogg",)):
        before = os.path.getsize(path)
        if before < OGG_FLOOR:
            continue
        data, rate = soundfile.read(path, always_2d=True)
        # libsndfile: Vorbis quality = 1 - compression_level. Write in blocks: one big write segfaults libsndfile's Vorbis encoder.
        with soundfile.SoundFile(path, "w", rate, data.shape[1], format="OGG", subtype="VORBIS", compression_level=0.7) as out:
            for i in range(0, len(data), 1 << 16):
                out.write(data[i:i + (1 << 16)])
        total_before += before
        total_after += os.path.getsize(path)
    print("audio    ogg %s -> %s" % (mb(total_before), mb(total_after)))


def self_test():
    lossless = 'importer="texture"\n[params]\ncompress/mode=0\ncompress/lossy_quality=0.7\n'
    out = lossy_import(lossless)
    assert "compress/mode=1" in out and "compress/lossy_quality=0.9" in out, out
    assert lossy_import(out) is None, "already lossy: untouched"
    assert lossy_import('importer="font_data_dynamic"\ncompress/mode=0\n') is None, "only textures"
    print("slim_web self-test PASSED")


def main():
    if sys.argv[1:] == ["--self-test"]:
        return self_test()
    if len(sys.argv) != 2 or not os.path.exists(os.path.join(sys.argv[1], "project.godot")):
        sys.exit(__doc__)
    root = os.path.abspath(sys.argv[1])
    if os.path.basename(root) != "web-slim":
        sys.exit("refusing to slim %s: run it on the scratch copy (.cache/web-slim), never on the project" % root)
    os.chdir(root)
    slim_fonts(root)
    slim_textures(root)
    shrink_image(project_setting(root, "boot_splash/image"), 1280, "splash")
    shrink_image(project_setting(root, "config/icon"), 512, "icon")
    slim_audio(root)


if __name__ == "__main__":
    main()
