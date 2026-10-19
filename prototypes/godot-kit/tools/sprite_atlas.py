#!/usr/bin/env python3
"""Packs characters' direction x frame sprites into one atlas for addons/proto_kit/sprite3d.gdshader.

    uv run --with pillow godot-kit/tools/sprite_atlas.py <manifest.json> --out <folder>
    uv run --with pillow godot-kit/tools/sprite_atlas.py --self-test

Writes <folder>/atlas.png and <folder>/sheets.json; a game loads a character with
    Sprite3DSheet.from_json("res://.../sheets.json", "luffy")      (addons/proto_kit/sprite3d_sheet.gd)
Spec and the reasons behind each rule: skill sprite-actors-3d (godot-kit/skills/sprite-actors-3d/SKILL.md).

Manifest (paths relative to it):
{
  "cell_px": 96,              every cell is cell_px square; the atlas is `columns` cells wide
  "columns": 16,
  "foot_px": 4,               transparent strip under the feet (the shader cuts it off: feet touch the ground)
  "meters_per_px": 0.025,     one world size per source pixel for the whole game (copied into sheets.json)
  "pixel": {"colors": 48},    optional pixel-art mode: area downscale, one palette per character, binary alpha
  "characters": {
    "luffy": {
      "height_px": 72,        in-game height of the reference frame (first animation, front row, first frame);
                              every frame of the character gets the same scale, so poses keep one size
      "directions": 8,        1, 4 or 8
      "mirror": true,         only the camera-right half is drawn (8: front, front-right, right, back-right, back;
                              4: front, right, back; 1: one row drawn facing right); the rest is flipped in game
      "align": "trim",        trim: each frame cropped to its pixels, centred, lowest pixel on the foot line
                              canvas: frames share one canvas (video or sprite-tool output); the canvas is placed
                              whole, its foot line (`foot_y`, default the reference frame's lowest pixel) on the
                              cell's foot line, so a jump or a lunge keeps its offset
      "anims": {
        "idle": {"d": [40, 6, 6], "loop": true,
                 "rows": [["idle/s0.png", "idle/s1.png", "idle/s2.png"], ...]},   one list per drawn direction
        "walk": {"d": [4, 4, 4, 4, 4, 4], "loop": true,
                 "sheet": {"file": "walk.png", "fw": 256, "fh": 256}}             or one strip: rows = directions
      }
    }
  }
}
`d` is ticks (1/60 s of game time) per frame. Drawn rows: directions (mirror off) or directions // 2 + 1
(mirror on); 1 for one direction.

Checks (an error, never a silent shrink: one pixel density per game is the point):
  - a frame's pixels must fit the cell inside a 1-texel transparent border (the shader draws its outline there)
    and above the foot strip;
  - every row of an animation has the same number of frames as `d`;
  - the atlas stays within 4096 px (phones) and 2048 cells (the web packs instance data into 16 bits).
"""
import argparse
import json
import sys
import tempfile
from pathlib import Path

from PIL import Image

MAX_ATLAS = 4096
# The web renderer (Compatibility) packs MultiMesh custom data and colours into 16 bits per channel, so the cell
# index sent in INSTANCE_CUSTOM.x is exact only up to 2048 (half float).
MAX_CELLS = 2048


class AtlasError(Exception):
    pass


def drawn_rows(directions: int, mirror: bool) -> int:
    if directions == 1:
        return 1
    return directions // 2 + 1 if mirror else directions


def opaque_box(image: Image.Image):
    return image.getchannel("A").point(lambda a: 255 if a >= 128 else 0).getbbox()


def load_frames(base: Path, anim: dict, rows: int) -> list:
    if "sheet" in anim:
        sheet = anim["sheet"]
        strip = Image.open(base / sheet["file"]).convert("RGBA")
        fw, fh = int(sheet["fw"]), int(sheet["fh"])
        if fw <= 0 or fh <= 0 or strip.width % fw or strip.height % fh:
            raise AtlasError(f"{sheet['file']} is {strip.width}x{strip.height}, not a whole number of {fw}x{fh} frames")
        n = strip.width // fw
        grid = [[strip.crop((x * fw, y * fh, (x + 1) * fw, (y + 1) * fh)) for x in range(n)] for y in range(strip.height // fh)]
    else:
        grid = [[Image.open(base / f).convert("RGBA") for f in row] for row in anim["rows"]]
    if len(grid) != rows:
        raise AtlasError(f"{len(grid)} direction rows, expected {rows}")
    n = len(anim.get("d", grid[0]))
    for r, row in enumerate(grid):
        if len(row) != n:
            raise AtlasError(f"row {r} has {len(row)} frames, expected {n} (length of d)")
    return grid


def place(image: Image.Image, scale: float, cell: int, foot: int, align: str, foot_y: float, label: str) -> Image.Image:
    out = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
    line = cell - foot  # first row of the foot strip; the lowest pixel goes just above it
    if align == "trim":
        box = opaque_box(image)
        if box is None:
            return out
        image = image.crop(box)
        anchor_x, anchor_y = image.width / 2, image.height
    else:
        anchor_x, anchor_y = image.width / 2, foot_y
    size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
    small = image.resize(size, Image.BOX if scale < 1 else Image.NEAREST)
    x = round(cell / 2 - anchor_x * scale)
    y = round(line - anchor_y * scale)
    layer = Image.new("RGBA", out.size, (0, 0, 0, 0))
    layer.paste(small, (x, y))  # paste clips; a canvas may hang over the cell where it is transparent
    out.alpha_composite(layer)
    pixels = opaque_box(small)
    if pixels:
        need = (pixels[0] + x, pixels[1] + y, pixels[2] + x, pixels[3] + y)
        if need[0] < 1 or need[1] < 1 or need[2] > cell - 1 or need[3] > line:
            raise AtlasError(f"{label}: pixels {need} leave the cell (1-texel border, foot line {line}); "
                             f"raise cell_px or lower height_px")
    return out


def pixelate(cells: list, colors: int) -> list:
    """One palette for all of a character's cells (per-cell palettes make colours flicker between frames)."""
    if not cells:
        return cells
    w = cells[0].width
    strip = Image.new("RGBA", (w * len(cells), cells[0].height), (0, 0, 0, 0))
    for i, c in enumerate(cells):
        strip.paste(c, (i * w, 0))
    alpha = strip.getchannel("A").point(lambda a: 255 if a >= 128 else 0)
    rgb = strip.convert("RGB").quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    strip = rgb.convert("RGBA")
    strip.putalpha(alpha)
    return [strip.crop((i * w, 0, (i + 1) * w, strip.height)) for i in range(len(cells))]


def build(manifest_path: Path, out_dir: Path) -> dict:
    manifest = json.loads(manifest_path.read_text())
    base = manifest_path.parent
    cell = int(manifest.get("cell_px", 96))
    columns = int(manifest.get("columns", 16))
    foot = int(manifest.get("foot_px", 4))
    pixel = manifest.get("pixel")
    if foot < 1:
        raise AtlasError("foot_px must be at least 1")
    placed = []  # (cell index, image)
    sheets = {}
    x = y = shelf = 0
    for name, ch in manifest["characters"].items():
        directions = int(ch.get("directions", 1))
        if directions not in (1, 4, 8):
            raise AtlasError(f"{name}: directions must be 1, 4 or 8")
        mirror = bool(ch.get("mirror", True))
        rows = drawn_rows(directions, mirror)
        align = ch.get("align", "trim")
        grids = {}
        for anim_name, anim in ch["anims"].items():
            try:
                grids[anim_name] = load_frames(base, anim, rows)
            except AtlasError as e:
                raise AtlasError(f"{name}.{anim_name}: {e}") from None
        ref = grids[next(iter(grids))][0][0]
        ref_box = opaque_box(ref)
        if ref_box is None:
            raise AtlasError(f"{name}: the reference frame is empty")
        scale = float(ch["height_px"]) / (ref_box[3] - ref_box[1])
        foot_y = float(ch.get("foot_y", ref_box[3]))
        anims_out = {}
        cells = []
        for anim_name, grid in grids.items():
            anim = ch["anims"][anim_name]
            n = len(grid[0])
            if n > columns:
                raise AtlasError(f"{name}.{anim_name}: {n} frames, more than {columns} columns")
            if x + n > columns:
                x, y, shelf = 0, y + shelf, 0
            first = y * columns + x
            for r, row in enumerate(grid):
                for f, image in enumerate(row):
                    label = f"{name}.{anim_name} row {r} frame {f}"
                    cells.append(((y + r) * columns + x + f, place(image, scale, cell, foot, align, foot_y, label)))
            anims_out[anim_name] = {"cell": first, "n": n, "d": list(anim.get("d", [6] * n)),
                                    "loop": bool(anim.get("loop", True))}
            x += n
            shelf = max(shelf, rows)
        if pixel:
            images = pixelate([c for _, c in cells], int(pixel.get("colors", 48)))
            cells = [(i, img) for (i, _), img in zip(cells, images)]
        placed.extend(cells)
        sheets[name] = {"directions": directions, "mirror": mirror, "anims": anims_out}
    total_rows = y + shelf
    if columns * total_rows > MAX_CELLS:
        raise AtlasError(f"{columns * total_rows} cells, over {MAX_CELLS} (16-bit instance data on the web); split the atlas")
    if columns * cell > MAX_ATLAS or total_rows * cell > MAX_ATLAS:
        raise AtlasError(f"atlas {columns * cell}x{total_rows * cell} px is over {MAX_ATLAS}")
    atlas = Image.new("RGBA", (columns * cell, total_rows * cell), (0, 0, 0, 0))
    for index, image in placed:
        atlas.paste(image, ((index % columns) * cell, (index // columns) * cell))
    out_dir.mkdir(parents=True, exist_ok=True)
    atlas.save(out_dir / "atlas.png")
    data = {"atlas": "atlas.png", "cell_px": cell, "columns": columns, "rows": total_rows, "foot_px": foot,
            "meters_per_px": manifest.get("meters_per_px", 0.025), "characters": sheets}
    (out_dir / "sheets.json").write_text(json.dumps(data, indent=2) + "\n")
    return data


def self_test() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)

        def body(h: int, w: int = 20, canvas: tuple = (64, 80), bottom: int = 70) -> str:
            img = Image.new("RGBA", canvas, (0, 0, 0, 0))
            for yy in range(bottom - h, bottom):
                for xx in range(32 - w // 2, 32 + w // 2):
                    img.putpixel((xx, yy), (200, 60, 40, 255))
            path = root / f"b{h}_{w}_{bottom}.png"
            img.save(path)
            return path.name

        manifest = {
            "cell_px": 32, "columns": 8, "foot_px": 2, "meters_per_px": 0.05,
            "characters": {
                "hero": {"height_px": 20, "directions": 8, "mirror": True, "anims": {
                    "idle": {"d": [10, 5], "rows": [[body(40), body(40)]] * 5},
                    "jump": {"d": [4], "loop": False, "rows": [[body(30, bottom=50)]] * 5}}},
                "crab": {"height_px": 10, "directions": 1, "align": "canvas",
                         "anims": {"walk": {"d": [4, 4], "rows": [[body(20), body(20, bottom=60)]]}}},
            },
        }
        (root / "m.json").write_text(json.dumps(manifest))
        data = build(root / "m.json", root / "out")
        atlas = Image.open(root / "out" / "atlas.png")
        hero = data["characters"]["hero"]
        assert atlas.size == (8 * 32, 5 * 32), atlas.size
        assert hero["anims"]["idle"] == {"cell": 0, "n": 2, "d": [10, 5], "loop": True}, hero
        assert hero["anims"]["jump"]["cell"] == 2 and hero["anims"]["jump"]["loop"] is False, hero
        assert data["rows"] == 5, data["rows"]  # crab fits on hero's shelf, right of it
        assert data["characters"]["crab"]["anims"]["walk"]["cell"] == 3, data["characters"]["crab"]

        def cell_box(index: int):
            c = atlas.crop(((index % 8) * 32, (index // 8) * 32, (index % 8 + 1) * 32, (index // 8 + 1) * 32))
            return opaque_box(c)

        box = cell_box(0)
        assert box[3] == 32 - 2 and box[3] - box[1] == 20, box   # feet on the foot line, height_px tall
        jump = cell_box(2)
        assert jump[3] == 30 and jump[3] - jump[1] == 15, jump     # trim: same scale, lowest pixel on the line
        crab = [cell_box(3), cell_box(4)]
        assert crab[0][3] == 30 and crab[1][3] == 30 - 5, crab     # canvas: a frame 10 px higher stays higher
        manifest["characters"]["hero"]["height_px"] = 31
        (root / "m.json").write_text(json.dumps(manifest))
        try:
            build(root / "m.json", root / "out2")
            raise AssertionError("an oversize frame must fail")
        except AtlasError as e:
            assert "leave the cell" in str(e), e
        manifest["characters"]["hero"]["height_px"] = 20
        manifest["characters"]["hero"]["anims"]["idle"]["rows"] = [[body(40)]] * 5
        (root / "m.json").write_text(json.dumps(manifest))
        try:
            build(root / "m.json", root / "out3")
            raise AssertionError("a row shorter than d must fail")
        except AtlasError as e:
            assert "expected 2" in str(e), e
        for size in [(65, 32), (64, 33)]:
            Image.new("RGBA", size, (255, 0, 0, 255)).save(root / "strip.png")
            try:
                load_frames(root, {"d": [1, 1], "sheet": {"file": "strip.png", "fw": 32, "fh": 32}}, 1)
                raise AssertionError(f"a {size} strip of 32 px frames must fail")
            except AtlasError as e:
                assert "whole number" in str(e), e
    print("sprite_atlas self-test OK")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("manifest", nargs="?", type=Path)
    parser.add_argument("--out", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return 0
    if not args.manifest or not args.out:
        parser.error("manifest and --out are required")
    try:
        data = build(args.manifest, args.out)
    except AtlasError as e:
        print(f"sprite_atlas: {e}", file=sys.stderr)
        return 1
    print(f"{args.out / 'atlas.png'}: {data['columns']}x{data['rows']} cells of {data['cell_px']} px, "
          f"{len(data['characters'])} characters")
    return 0


if __name__ == "__main__":
    sys.exit(main())
