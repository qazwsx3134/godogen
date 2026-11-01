"""Packs the march backdrop layers (art_src/bg_layers, docs/bg-layer-prompts.md) into assets/backdrop/ at the
page's 1:1 layout pixels, for scenes/components/march_backdrop.tscn:

    ~/repo/agent-sprite-forge/.venv/bin/python tools/pack_backdrop.py      (from prototypes/hero-horde-idle)

  sky.png     941 x 425, opaque, does not scroll
  far.png     mountains, FAR_H tall, seamless (its width is the wrap width)
  mid.png     hills, MID_H tall, seamless
  props.png   the props laid out once along a PROPS_W strip by a fixed seed, feet on the strip's bottom edge
  ground.png  the grass edge and dirt, GROUND_H tall, seamless
Each layer is box-downscaled, cut to 32 colours and given a hard alpha edge, like tools/pack_stage_art.py.
"""
import random
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "art_src" / "bg_layers"
OUT = ROOT / "assets" / "backdrop"
W, H = 941, 425
FAR_H, MID_H, GROUND_H = 100, 150, 60
GROUND_SRC_ROWS = 260  # the grass edge and the top of the dirt; the rest of the generated strip is more dirt
PROPS_W, PROPS_H = 1882, 170
SEAM = 24  # px blended across a strip's wrap
# (prop, height px, how many on the strip); the trees are the tallest, the fence and bush sit low.
PROPS = [("prop_tree_a", 128, 2), ("prop_tree_b", 150, 2), ("prop_bush", 30, 3), ("prop_rock", 30, 2),
         ("prop_ruin", 84, 1), ("prop_lamp", 66, 2), ("prop_fence", 30, 2)]
SEED = 7


def subject(name: str, rows: int = 0) -> Image.Image:
    im = Image.open(SRC / f"{name}.png").convert("RGBA")
    box = im.getchannel("A").point(lambda a: 255 if a > 24 else 0).getbbox()
    if rows:
        box = (box[0], box[1], box[2], min(box[3], box[1] + rows))
    return im.crop(box)


def pixel(im: Image.Image, size: tuple, opaque: bool = False) -> Image.Image:
    small = np.array(im.resize(size, Image.BOX))
    rgb = Image.fromarray(small[..., :3]).quantize(32, method=Image.Quantize.MEDIANCUT,
                                                   dither=Image.Dither.NONE).convert("RGB")
    alpha = np.full(small.shape[:2], 255, np.uint8) if opaque else np.where(small[..., 3] >= 128, 255, 0).astype(np.uint8)
    return Image.fromarray(np.dstack([np.array(rgb), alpha]), "RGBA")


def seamless(im: Image.Image) -> Image.Image:
    """Cross-fades the last SEAM columns into the first ones and drops them, so the strip wraps without a step."""
    a = np.array(im).astype(float)
    n = a.shape[1] - SEAM
    out = a[:, :n].copy()
    for i in range(SEAM):
        w = (i + 1) / (SEAM + 1)
        out[:, i] = a[:, n + i] * (1 - w) + a[:, i] * w
    out[..., 3] = np.where(out[..., 3] >= 128, 255, 0)
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def band(name: str, height: int, rows: int = 0) -> Image.Image:
    im = subject(name, rows)
    return seamless(pixel(im, (round(im.width * height / im.height) + SEAM, height)))


def props() -> Image.Image:
    rng = random.Random(SEED)
    items = [(name, h) for name, h, n in PROPS for _ in range(n)]
    rng.shuffle(items)
    strip = Image.new("RGBA", (PROPS_W, PROPS_H))
    slot = PROPS_W / len(items)
    for k, (name, h) in enumerate(items):
        im = subject(name)
        px = pixel(im, (max(1, round(im.width * h / im.height)), h))
        x = round(slot * k + rng.uniform(0, max(0, slot - px.width)))
        strip.alpha_composite(px, (min(x, PROPS_W - px.width), PROPS_H - px.height))
    return strip


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    sky = Image.open(SRC / "sky.png").convert("RGBA")
    sky = sky.resize((W, round(sky.height * W / sky.width)), Image.LANCZOS).crop((0, 0, W, H))
    pixel(sky, (W, H), opaque=True).save(OUT / "sky.png")
    band("far", FAR_H).save(OUT / "far.png")
    band("mid", MID_H).save(OUT / "mid.png")
    props().save(OUT / "props.png")
    ground = band("ground", GROUND_H, GROUND_SRC_ROWS)
    ground.save(OUT / "ground.png")
    for f in sorted(OUT.glob("*.png")):
        print(f.name, Image.open(f).size)


if __name__ == "__main__":
    main()
