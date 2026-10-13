"""Shrinks original art into pixel art for the pixel pass (docs/pixel-ui-plan.md P1).

Reads art_src/pixel-style/jobs.json (written by tools/build_pixel_scenes.gd --plan) and writes each job's PNG:
area-average down to the target size -> hard alpha (no soft edges) -> at most COLORS colours -> 1 px dark outline
(the outline pads the image by 1 px on every side; the scene builder shifts sprite offsets to match).
Tiles ("kind": "tile") shrink with wrap-around so they stay seamless, and get no outline.

    uv run --no-project --with pillow --with numpy python tools/pixelize.py [--only <substring>]

One original at a chosen size: ... python tools/pixelize.py --src assets/art/map/cone.png --height 9 --out <png>
A redrawn sprite (generated on a flat green screen, P2) goes through the same steps after keying and cropping:
    ... python tools/pixelize.py --keyed <generated.png> --height 32 --out assets/pixel/heroes/man_32.png
"""
import argparse, json, os, sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
COLORS = 32
ALPHA_CUT = 110
OUTLINE = (27, 20, 32, 255)


def shrink(img: Image.Image, width: int, height: int) -> Image.Image:
    # Pillow resizes RGBA premultiplied, so transparent pixels don't bleed dark fringes.
    return img.resize((width, height), Image.BOX)


def quantize(img: Image.Image, colors: int) -> Image.Image:
    rgba = np.array(img)
    solid = rgba[..., 3] > 0
    if not solid.any():
        return img
    # Only opaque pixels pick the palette, so empty space doesn't use up a colour.
    strip = Image.fromarray(np.ascontiguousarray(rgba[solid][None, :, :3]))
    strip = strip.quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    rgba[solid, :3] = np.array(strip.convert("RGB"))[0]
    return Image.fromarray(rgba)


def outline(img: Image.Image) -> Image.Image:
    rgba = np.array(img)
    h, w = rgba.shape[:2]
    out = np.zeros((h + 2, w + 2, 4), np.uint8)
    out[1:-1, 1:-1] = rgba
    solid = out[..., 3] > 0
    edge = np.zeros_like(solid)
    edge[1:, :] |= solid[:-1, :]
    edge[:-1, :] |= solid[1:, :]
    edge[:, 1:] |= solid[:, :-1]
    edge[:, :-1] |= solid[:, 1:]
    edge &= ~solid
    out[edge] = OUTLINE
    return Image.fromarray(out)


def keyed(path: str) -> Image.Image:
    """Green screen to alpha, cropped to the sprite."""
    rgba = np.array(Image.open(path).convert("RGBA")).astype(int)
    r, g, b = rgba[..., 0], rgba[..., 1], rgba[..., 2]
    green = (g > 150) & (g > r + 60) & (g > b + 60)
    rgba[green, 3] = 0
    img = Image.fromarray(rgba.astype(np.uint8))
    return img.crop(img.getbbox())


def sprite(job: dict, source: Image.Image = None) -> Image.Image:
    source = source if source is not None else Image.open(job["src"]).convert("RGBA")
    img = shrink(source, job["width"], job["height"])
    rgba = np.array(img)
    rgba[..., 3] = np.where(rgba[..., 3] >= ALPHA_CUT, 255, 0)
    return outline(quantize(Image.fromarray(rgba), COLORS))


def tile(job: dict) -> Image.Image:
    src = Image.open(job["src"]).convert("RGB")
    w, h = src.size
    big = Image.new("RGB", (w * 3, h * 3))
    for x in range(3):
        for y in range(3):
            big.paste(src, (x * w, y * h))
    small = big.resize((job["width"] * 3, job["height"] * 3), Image.BOX)
    middle = small.crop((job["width"], job["height"], job["width"] * 2, job["height"] * 2))
    return quantize(middle.convert("RGBA"), COLORS)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--jobs", default=os.path.join(HERE, "art_src/pixel-style/jobs.json"))
    parser.add_argument("--only", default="")
    # Existing files may be hand-picked redraws (P2: heroes, enemies, vehicles), so they are kept unless --force.
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--keyed", help="a green-screen generation to turn into one pixel sprite")
    parser.add_argument("--src", help="a transparent original to shrink into one pixel sprite of --height")
    parser.add_argument("--height", type=int, default=32)
    parser.add_argument("--out")
    args = parser.parse_args()
    if args.keyed or args.src:
        source = keyed(args.keyed) if args.keyed else Image.open(args.src).convert("RGBA")
        width = max(1, round(source.width * args.height / source.height))
        sprite({"width": width, "height": args.height}, source).save(args.out)
        print(f"{width + 2}x{args.height + 2} {args.out}")
        return
    with open(args.jobs) as f:
        jobs = json.load(f)
    for job in jobs:
        if args.only not in job["out"] or (os.path.exists(job["out"]) and not args.force):
            continue
        img = tile(job) if job["kind"] == "tile" else sprite(job)
        os.makedirs(os.path.dirname(job["out"]), exist_ok=True)
        img.save(job["out"])
        print(f"{img.size[0]:4d}x{img.size[1]:<4d} {os.path.relpath(job['out'], HERE)}")


if __name__ == "__main__":
    sys.exit(main())
