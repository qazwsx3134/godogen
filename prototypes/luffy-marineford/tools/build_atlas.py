#!/usr/bin/env python3
"""Builds assets/sprites/atlas.png: placeholders first, then the selected art over its cells.

    python3 tools/build_atlas.py

art_src/selected/atlas.json maps atlas frame -> image, or -> {"file", "group"}. Each image is trimmed to its opaque
pixels, scaled to fit the cell inside the gutters (aspect kept), centred horizontally and stood on the foot line, the same layout the
placeholders use (make_placeholder_art.py), so the billboard shader's foot_gutter still puts feet on the ground.
Frames not listed keep their placeholder (rocks, shrubs, free cells). Frames of one group share the smallest of
their fit scales, so a character's poses keep one size (a wide kick does not make him shrink).

Pixel mode ("_pixel" in atlas.json): the atlas is made of PIXEL_CELL-px cells sampled with nearest filtering. Each
image is shrunk to its in-game size with an area filter, snapped to a small palette and given binary alpha, so the
image model's pixel-style painting becomes clean in-game pixels at 1:1. An entry may take a sub-rectangle of its
source with "crop": [x, y, w, h] (one sheet holding several items, like the chakra orbs).
"""
import json
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_placeholder_art as placeholder  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
CELL = placeholder.CELL
GUTTER = placeholder.GUTTER
FOOT = placeholder.FOOT


PIXEL_CELL = 128


def pixelate(cell: Image.Image, colors: int) -> Image.Image:
    """Snaps a cell to `colors` colours and binary alpha (nearest-sampled pixel art)."""
    alpha = cell.getchannel("A").point(lambda a: 255 if a >= 128 else 0)
    rgb = cell.convert("RGB").quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    return out


def trim(image: Image.Image) -> Image.Image:
    image = image.convert("RGBA")
    box = image.getchannel("A").point(lambda a: 255 if a > 24 else 0).getbbox()
    return image.crop(box) if box else image


def fit_scale(image: Image.Image) -> float:
    return min((CELL - 2 * GUTTER) / image.width, (CELL - GUTTER - FOOT) / image.height)


def fit(image: Image.Image, scale: float, cell_size: int = CELL) -> Image.Image:
    size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
    small = image.resize(size, Image.BOX if cell_size != CELL else Image.LANCZOS)
    foot = FOOT * cell_size // CELL
    cell = Image.new("RGBA", (cell_size, cell_size), (0, 0, 0, 0))
    cell.alpha_composite(small, ((cell_size - size[0]) // 2, cell_size - foot - size[1]))
    return cell


def main() -> None:
    mapping = json.loads((ROOT / "art_src/selected/atlas.json").read_text())
    pixel = mapping.get("_pixel")
    cell = PIXEL_CELL if pixel else CELL
    atlas = placeholder.build()
    if pixel:
        atlas = atlas.resize((placeholder.COLS * cell, placeholder.ROWS * cell), Image.BOX)
    ratio = cell / CELL
    entries = {}
    for key, value in mapping.items():
        if key.startswith("_"):
            continue
        spec = value if isinstance(value, dict) else {"file": value}
        image = Image.open(ROOT / "art_src/selected" / spec["file"]).convert("RGBA")
        if "crop" in spec:
            x, y, w, h = spec["crop"]
            image = image.crop((x, y, x + w, y + h))
        image = trim(image)
        entries[int(key)] = (image, spec.get("group", "frame%s" % key), spec.get("fill", 1.0))
    group_scale = {}
    for image, group, fill in entries.values():
        group_scale[group] = min(group_scale.get(group, 99.0), fit_scale(image) * ratio * fill)
    for frame, (image, group, fill) in entries.items():
        x, y = (frame % placeholder.COLS) * cell, (frame // placeholder.COLS) * cell
        atlas.paste((0, 0, 0, 0), (x, y, x + cell, y + cell))
        art = fit(image, group_scale[group], cell)
        if pixel:
            art = pixelate(art, int(pixel.get("colors", 48)))
        atlas.alpha_composite(art, (x, y))
    out = ROOT / "assets/sprites/atlas.png"
    atlas.save(out)
    print("wrote", out, atlas.size)


if __name__ == "__main__":
    main()
