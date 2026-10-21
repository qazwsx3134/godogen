"""Packs the picked HD-2D art (art_src/selected.json) into game textures at one pixel density, so the boss, the props
and the floor read as one pixel world (0.025 m per texel; the next hero batch uses 48 px cells = 1.2 m).

    uv run --with pillow --with numpy tools/pack_stage_art.py      (from prototypes/hero-horde-idle)

Generated stills are 1024 px paintings without a pixel grid: each is cropped to its subject, box-downscaled to its
in-game height, reduced to a small palette and given a hard alpha edge. Writes
  assets/stage/boss.png         4 square cells (idle, windup, stunned, slam); a missing pose repeats idle
  assets/stage/props/<name>.png one per prop
  assets/stage/<tile>.png       grass, arena, cliff: downscaled and made seamless
  assets/heroes/heroes.png+json one row per class, 9 cells of 48 px in the sprite3d sheets.json layout
                                (run 4, attack 3, down, volley); a missing pose uses the class's ready stance
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "stage"
M_PER_PX = 0.025
BOSS_CELL = 200  # px; boss.tres frames = (4, 1), the quad is 4.8 m -> 0.024 m/px
BOSS_POSES = ["idle", "windup", "stunned", "slam"]
FOOT = 2  # transparent strip under the feet in every boss cell
PALETTE = 48


def subject(path: Path) -> Image.Image:
    img = Image.open(ROOT / path).convert("RGBA")
    return img.crop(img.getchannel("A").point(lambda a: 255 if a > 24 else 0).getbbox())


def pixelate(img: Image.Image, height_px: int, colors: int = PALETTE) -> Image.Image:
    w = max(1, round(img.width * height_px / img.height))
    small = img.resize((w, height_px), Image.BOX)
    a = np.array(small)
    alpha = a[..., 3] >= 128
    rgb = Image.fromarray(a[..., :3]).quantize(colors, method=Image.Quantize.MEDIANCUT,
                                               dither=Image.Dither.NONE).convert("RGB")
    out = np.dstack([np.array(rgb), np.where(alpha, 255, 0).astype(np.uint8)])
    return Image.fromarray(out, "RGBA")


def boss(poses: dict) -> None:
    """The poses share one crop box (the union of their subjects), so the feet the generator aligned on its canvas
    stay on one line and a pose never jumps in the cell."""
    sheet = Image.new("RGBA", (BOSS_CELL * len(BOSS_POSES), BOSS_CELL), (0, 0, 0, 0))
    srcs = [Image.open(ROOT / (poses.get(p) or poses["idle"])).convert("RGBA") for p in BOSS_POSES]
    boxes = [im.getchannel("A").point(lambda a: 255 if a > 24 else 0).getbbox() for im in srcs]
    box = (min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes))
    side = max(box[2] - box[0], box[3] - box[1])
    cx = (box[0] + box[2]) // 2
    crop = (cx - side // 2, box[3] - side, cx - side // 2 + side, box[3])
    inner = BOSS_CELL - FOOT - 2
    for k, im in enumerate(srcs):
        px = pixelate(im.crop(crop), inner)
        sheet.alpha_composite(px, (k * BOSS_CELL + (BOSS_CELL - px.width) // 2, BOSS_CELL - FOOT - px.height))
    sheet.save(OUT / "boss.png")


HERO_CELL = 48
HERO_FOOT = 2
HERO_BODY = 40  # px from feet to the top of the head in the ready stance (1.0 m)
HERO_CLASSES = ["shield", "sword", "spear", "bow", "mage", "healer"]
# The 9 cells of a class row, by pose.
HERO_CELLS = ["run_a", "run_b", "run_a", "run_b", "ready", "windup", "strike", "down", "volley"]
HERO_ANIMS = {
    "run": {"cell": 0, "n": 4, "d": [6, 6, 6, 6], "loop": True},
    "attack": {"cell": 4, "n": 3, "d": [10, 6, 14], "loop": True},
    "down": {"cell": 7, "n": 1, "d": [60], "loop": False},
    "volley": {"cell": 8, "n": 1, "d": [60], "loop": False},
}


def alpha_box(im: Image.Image) -> tuple:
    return im.getchannel("A").point(lambda a: 255 if a > 24 else 0).getbbox()


def heroes(classes: dict) -> None:
    """Every pose of a class shares one crop box and one scale (feet stay on one line); the ready stance sets the
    scale so every class is HERO_BODY px tall, shrunk only if a pose would not fit the cell."""
    out_dir = ROOT / "assets" / "heroes"
    out_dir.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (HERO_CELL * len(HERO_CELLS), HERO_CELL * len(HERO_CLASSES)), (0, 0, 0, 0))
    chars = {}
    for row, cls in enumerate(HERO_CLASSES):
        poses = classes.get(cls)
        if not poses or not poses.get("ready"):
            continue
        srcs = {name: Image.open(ROOT / (poses.get(name) or poses["ready"])).convert("RGBA") for name in set(HERO_CELLS)}
        boxes = [alpha_box(im) for im in srcs.values()]
        box = (min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes))
        ready = alpha_box(srcs["ready"])
        scale = HERO_BODY / (ready[3] - ready[1])
        room = HERO_CELL - HERO_FOOT - 1
        scale = min(scale, room / (box[3] - box[1]), (HERO_CELL - 2) / (box[2] - box[0]))
        for k, name in enumerate(HERO_CELLS):
            im = srcs[name].crop(box)
            px = pixelate(im, max(1, round(im.height * scale)), 32)
            x = k * HERO_CELL + (HERO_CELL - px.width) // 2
            y = row * HERO_CELL + HERO_CELL - HERO_FOOT - px.height
            sheet.alpha_composite(px, (x, y))
        chars[cls] = {"directions": 1, "mirror": False, "anims": {
            k: dict(v, cell=v["cell"] + row * len(HERO_CELLS)) for k, v in HERO_ANIMS.items()}}
    sheet.save(out_dir / "heroes.png")
    (out_dir / "heroes.json").write_text(json.dumps({
        "atlas": "heroes.png", "cell_px": HERO_CELL, "columns": len(HERO_CELLS), "rows": len(HERO_CLASSES),
        "foot_px": HERO_FOOT, "meters_per_px": M_PER_PX, "characters": chars}, indent=1) + "\n")


def prop(name: str, spec: dict) -> None:
    img = pixelate(subject(Path(spec["src"])), round(spec["height_m"] / M_PER_PX))
    (OUT / "props").mkdir(parents=True, exist_ok=True)
    img.save(OUT / "props" / f"{name}.png")


def tile(name: str, spec: dict) -> None:
    img = Image.open(ROOT / spec["src"]).convert("RGB")
    n = round(spec["tile_m"] / M_PER_PX)
    small = np.array(img.resize((n, n), Image.BOX)).astype(float)
    # Seamless: blend each border band with the opposite side so the repeat has no seam.
    band = max(4, n // 8)
    for axis in (0, 1):
        a = small.copy()
        for i in range(band):
            w = 0.5 * (1.0 - i / band)
            lo = np.take(a, i, axis=axis)
            hi = np.take(a, n - 1 - i, axis=axis)
            mixed_lo = lo * (1 - w) + hi * w
            mixed_hi = hi * (1 - w) + lo * w
            idx_lo = [slice(None)] * 2
            idx_hi = [slice(None)] * 2
            idx_lo[axis], idx_hi[axis] = i, n - 1 - i
            small[tuple(idx_lo)] = mixed_lo
            small[tuple(idx_hi)] = mixed_hi
    # Optional grade: pull saturation toward grey and shift toward blue (the arena must not compete with the red
    # telegraph).
    sat = spec.get("saturation", 1.0)
    grey = small.mean(axis=2, keepdims=True)
    small = grey + (small - grey) * sat
    small += np.array([-1.0, 0.0, 1.0]) * 255.0 * spec.get("cool", 0.0)
    out = Image.fromarray(small.clip(0, 255).astype(np.uint8)).quantize(
        spec.get("colors", 24), method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    out.save(OUT / f"{name}.png")


if __name__ == "__main__":
    sel = json.loads((ROOT / "art_src" / "selected.json").read_text())
    OUT.mkdir(parents=True, exist_ok=True)
    boss(sel["boss"])
    for name, spec in sel.get("props", {}).items():
        prop(name, spec)
    for name, spec in sel.get("tiles", {}).items():
        tile(name, spec)
    if sel.get("heroes"):
        heroes(sel["heroes"])
    print("packed into", OUT)
