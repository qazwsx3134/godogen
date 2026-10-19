#!/usr/bin/env python3
"""Draws the graybox pixel sprites: python3 tools/make_placeholder_art.py

Writes assets/sprites/atlas.png, a 4x2 grid of 32x32 cells, nearest-filtered in Godot.
Every sprite stands on the bottom edge of its cell (the billboard pivot is at the feet)
and gets a 1 px dark outline baked in, the way the reference game's sprites carry their own.
Replace the PNG with real art of the same layout; nothing else changes.

Cells (frame index = row * 4 + col):
  0 hero   1 slime   2 bat    3 brute
  4 elite  5 tree    6 rock   7 flower
"""
from pathlib import Path

from PIL import Image, ImageDraw

CELL = 32
COLS, ROWS = 4, 2
OUTLINE = (26, 20, 38, 255)
EYE = (20, 16, 30, 255)
WHITE = (250, 248, 240, 255)


def outlined(draw_fn):
    """Draws a sprite with draw_fn on a clean cell, then rings it with a 1 px outline."""
    body = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(body))
    out = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    src = body.load()
    dst = out.load()
    for y in range(CELL):
        for x in range(CELL):
            if src[x, y][3] > 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < CELL and 0 <= ny < CELL and src[nx, ny][3] > 0:
                    dst[x, y] = OUTLINE
                    break
    out.alpha_composite(body)
    return out


def eyes(d, cx, y, gap, size=2):
    for ex in (cx - gap, cx + gap - size):
        d.rectangle((ex, y, ex + size - 1, y + size), fill=EYE)
        d.point((ex, y), fill=WHITE)


def hero(d):
    d.ellipse((9, 13, 22, 30), fill=(70, 120, 220, 255))          # cloak
    d.ellipse((10, 4, 21, 16), fill=(245, 205, 165, 255))         # face
    d.pieslice((8, 2, 23, 18), 180, 360, fill=(60, 95, 200, 255))  # hood
    d.rectangle((12, 28, 14, 30), fill=(60, 50, 70, 255))
    d.rectangle((17, 28, 19, 30), fill=(60, 50, 70, 255))
    eyes(d, 16, 10, 3)


def slime(d):
    d.ellipse((5, 14, 26, 31), fill=(90, 200, 90, 255))
    d.rectangle((5, 24, 26, 30), fill=(90, 200, 90, 255))
    d.ellipse((9, 16, 14, 20), fill=(190, 250, 170, 255))          # shine
    eyes(d, 16, 21, 5)


def bat(d):
    d.polygon([(2, 12), (10, 16), (8, 22)], fill=(170, 50, 70, 255))
    d.polygon([(29, 12), (21, 16), (23, 22)], fill=(170, 50, 70, 255))
    d.ellipse((10, 12, 21, 25), fill=(210, 70, 80, 255))
    d.polygon([(11, 13), (12, 8), (14, 13)], fill=(210, 70, 80, 255))
    d.polygon([(17, 13), (19, 8), (20, 13)], fill=(210, 70, 80, 255))
    d.rectangle((15, 26, 16, 31), fill=(0, 0, 0, 0))
    eyes(d, 16, 16, 3)


def brute(d):
    d.rounded_rectangle((5, 6, 26, 30), radius=5, fill=(140, 90, 190, 255))
    d.rectangle((7, 26, 11, 31), fill=(110, 70, 160, 255))
    d.rectangle((20, 26, 24, 31), fill=(110, 70, 160, 255))
    d.rectangle((8, 9, 23, 11), fill=(170, 120, 220, 255))
    d.rectangle((11, 20, 20, 21), fill=EYE)                        # frown
    eyes(d, 16, 13, 5, 3)


def elite(d):
    d.ellipse((4, 9, 27, 31), fill=(240, 190, 60, 255))
    d.polygon([(6, 12), (4, 2), (11, 9)], fill=(250, 240, 220, 255))
    d.polygon([(25, 12), (27, 2), (20, 9)], fill=(250, 240, 220, 255))
    d.ellipse((9, 12, 14, 16), fill=(255, 235, 150, 255))
    d.rectangle((12, 24, 19, 25), fill=EYE)
    eyes(d, 16, 16, 5, 3)


def tree(d):
    d.rectangle((14, 20, 17, 31), fill=(120, 80, 50, 255))
    d.ellipse((4, 1, 27, 24), fill=(60, 150, 70, 255))
    d.ellipse((8, 3, 18, 12), fill=(110, 200, 90, 255))
    d.point([(20, 14), (11, 17), (22, 8)], fill=(40, 110, 55, 255))


def rock(d):
    d.polygon([(4, 31), (6, 18), (13, 12), (22, 13), (28, 22), (28, 31)], fill=(140, 140, 150, 255))
    d.polygon([(8, 20), (13, 14), (20, 15), (14, 19)], fill=(185, 185, 195, 255))
    d.rectangle((6, 28, 27, 31), fill=(110, 110, 120, 255))


def flower(d):
    d.rectangle((15, 18, 16, 31), fill=(70, 150, 60, 255))
    d.ellipse((9, 21, 15, 26), fill=(80, 170, 70, 255))
    for cx, cy in ((16, 9), (11, 13), (21, 13), (13, 18), (19, 18)):
        d.ellipse((cx - 3, cy - 3, cx + 3, cy + 3), fill=(245, 140, 180, 255))
    d.ellipse((13, 11, 18, 16), fill=(255, 220, 90, 255))


SPRITES = [hero, slime, bat, brute, elite, tree, rock, flower]


def main() -> None:
    atlas = Image.new("RGBA", (CELL * COLS, CELL * ROWS), (0, 0, 0, 0))
    for index, fn in enumerate(SPRITES):
        atlas.alpha_composite(outlined(fn), ((index % COLS) * CELL, (index // COLS) * CELL))
    path = Path(__file__).resolve().parent.parent / "assets" / "sprites" / "atlas.png"
    atlas.save(path)
    print("wrote", path)


if __name__ == "__main__":
    main()
