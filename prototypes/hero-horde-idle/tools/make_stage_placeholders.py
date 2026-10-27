"""Placeholder stage textures until the hd1 art batch lands: trampled arena dirt with flagstones, and a layered rock
face for the cliffs. 64 px, seamless (everything wraps), dusk palette.

    uv run --with pillow tools/make_stage_placeholders.py      (from prototypes/hero-horde-idle)

Writes assets/stage/arena.png and assets/stage/cliff.png. ponytail: replaced by the generated tiles.
"""
import random
from pathlib import Path

from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "assets" / "stage"
N = 64


def arena() -> Image.Image:
    rng = random.Random(3)
    img = Image.new("RGB", (N, N))
    px = img.load()
    # Cool grey-olive packed earth: the red telegraph must pop against it.
    dirt = [(112, 112, 96), (104, 104, 90), (120, 118, 102), (96, 98, 86)]
    for y in range(N):
        for x in range(N):
            px[x, y] = rng.choice(dirt)
    stone, edge, light = (138, 140, 140), (86, 88, 92), (164, 166, 164)
    for sx, sy, w, h in [(4, 6, 12, 9), (22, 3, 10, 8), (40, 10, 13, 10), (8, 30, 10, 11), (30, 26, 14, 9),
                         (50, 34, 10, 12), (18, 48, 12, 9), (38, 50, 11, 10)]:
        for y in range(h):
            for x in range(w):
                if (x in (0, w - 1) and y in (0, h - 1)) or rng.random() < 0.06:
                    continue
                c = edge if x in (0, w - 1) or y in (0, h - 1) else (light if y == 1 else stone)
                px[(sx + x) % N, (sy + y) % N] = c
    return img


def cliff() -> Image.Image:
    rng = random.Random(5)
    img = Image.new("RGB", (N, N))
    px = img.load()
    bands = [(96, 100, 112), (110, 114, 124), (86, 90, 104), (120, 122, 130), (100, 104, 116), (80, 84, 98)]
    for y in range(N):
        band = bands[(y // 6) % len(bands)]
        for x in range(N):
            j = rng.randint(-6, 6)
            px[x, y] = tuple(max(0, min(255, c + j)) for c in band)
        if y % 6 == 5:
            for x in range(N):
                px[x, y] = (62, 64, 80)
    for _ in range(14):
        x, y = rng.randrange(N), rng.randrange(N)
        for k in range(rng.randint(3, 7)):
            px[(x + k // 2) % N, (y + k) % N] = (54, 56, 70)
    for _ in range(40):
        x, y = rng.randrange(N), rng.randrange(N)
        px[x, y] = (84, 112, 70)
    return img


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    arena().save(OUT / "arena.png")
    cliff().save(OUT / "cliff.png")
    print("wrote", OUT)
