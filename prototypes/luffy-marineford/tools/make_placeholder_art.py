#!/usr/bin/env python3
"""Draws the HD placeholder sprites: python3 tools/make_placeholder_art.py

Writes assets/sprites/atlas.png, a 4x6 grid of 256x256 cells (1024x1536), linear-filtered with mipmaps in Godot.
Each sprite is drawn at 4x and scaled down, so its edges are smooth, and gets a thick dark outline baked in so it
still reads at about 100 px on a phone. Every sprite stands on the cell's bottom gutter line (FOOT px above the
bottom edge; the billboard shader's foot_gutter matches) and keeps GUTTER px clear on the other sides, so mipmaps
never bleed one cell into the next. Replace the PNG with real art of the same layout; nothing else changes.

Frames (index = row * 4 + col):
  0 Madara (player)   1 ninja (flak vest)   2 ninja (masked)   3 heavy ninja
  4 elite (cloak)     5 hoodoo pillar       6 boulder          7 dry shrub
  8 fire caster       9 water caster        10 earth caster    11-17 Madara poses, 18-23 free
(tools/build_atlas.py lays the selected real art over these cells)
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

CELL = 256
SCALE = 4
BIG = CELL * SCALE
GUTTER = 12
FOOT = 12
COLS, ROWS = 4, 6
OUTLINE = (22, 16, 24, 255)
OUTLINE_PX = 5  # at 256 px


def ground_y() -> int:
    return BIG - FOOT * SCALE


def finish(draw_fn) -> Image.Image:
    body = Image.new("RGBA", (BIG, BIG), (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(body), ground_y())
    alpha = body.getchannel("A").point(lambda a: 255 if a > 0 else 0)
    grown = alpha.filter(ImageFilter.MaxFilter(OUTLINE_PX * SCALE * 2 + 1))
    out = Image.new("RGBA", (BIG, BIG), (0, 0, 0, 0))
    out.paste(Image.new("RGBA", (BIG, BIG), OUTLINE), (0, 0), grown)
    out.alpha_composite(body)
    small = out.resize((CELL, CELL), Image.LANCZOS)
    # Keep the gutter clear whatever the outline did.
    clear = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    clear.paste(small.crop((GUTTER, GUTTER, CELL - GUTTER, CELL - FOOT + 1)), (GUTTER, GUTTER))
    return clear


def s(*values):
    """Scales coordinates written for a 256 px cell to the 4x drawing."""
    return tuple(v * SCALE for v in values)


def madara(d, g):
    hair = (24, 22, 30, 255)
    # Long spiky hair mass behind the body.
    d.polygon([s(70, 70), s(40, 150), s(58, 140), s(48, 200), s(80, 170), s(84, 215), s(110, 150),
               s(150, 150), s(176, 215), s(180, 168), s(212, 198), s(200, 140), s(222, 150), s(190, 68),
               s(128, 30)], fill=hair)
    d.polygon([s(84, 46), s(70, 20), s(104, 38), s(112, 12), s(132, 36), s(150, 10), s(160, 40), s(192, 24),
               s(178, 60)], fill=hair)
    # Legs: dark trousers, white bandaged shins.
    d.rectangle(s(100, 190, 122, 232), fill=(52, 48, 66, 255))
    d.rectangle(s(136, 190, 158, 232), fill=(52, 48, 66, 255))
    d.rectangle(s(102, 214, 120, 238), fill=(226, 222, 214, 255))
    d.rectangle(s(138, 214, 156, 238), fill=(226, 222, 214, 255))
    # Body and red armor.
    d.rounded_rectangle(s(90, 92, 168, 196), radius=14 * SCALE, fill=(56, 50, 72, 255))
    d.polygon([s(96, 110), s(162, 110), s(156, 170), s(102, 170)], fill=(178, 40, 40, 255))
    for y in (128, 146, 164):
        d.line([s(100, y), s(158, y)], fill=(120, 24, 28, 255), width=3 * SCALE)
    d.polygon([s(92, 168), s(120, 168), s(116, 206), s(88, 200)], fill=(166, 36, 36, 255))
    d.polygon([s(138, 168), s(166, 168), s(170, 200), s(142, 206)], fill=(166, 36, 36, 255))
    d.rounded_rectangle(s(70, 96, 104, 120), radius=6 * SCALE, fill=(190, 46, 44, 255))
    d.rounded_rectangle(s(154, 96, 188, 120), radius=6 * SCALE, fill=(190, 46, 44, 255))
    # Face with a red eye, hair over one side.
    d.ellipse(s(106, 52, 152, 100), fill=(238, 214, 190, 255))
    d.polygon([s(102, 50), s(156, 50), s(150, 70), s(128, 60), s(108, 84)], fill=hair)
    d.ellipse(s(132, 72, 142, 80), fill=(214, 30, 36, 255))
    # Gunbai: a war fan held at the side.
    d.line([s(196, 120), s(214, 210)], fill=(90, 60, 40, 255), width=6 * SCALE)
    d.ellipse(s(178, 64, 244, 134), fill=(230, 222, 200, 255))
    d.ellipse(s(196, 82, 226, 116), fill=(178, 40, 40, 255))


def ninja(vest, cloth, masked=False, wide=0):
    def draw(d, g):
        d.rectangle(s(104 - wide, 178, 124 - wide // 2, 238), fill=cloth)
        d.rectangle(s(134 + wide // 2, 178, 154 + wide, 238), fill=cloth)
        d.rectangle(s(104 - wide, 222, 124 - wide // 2, 240), fill=(210, 206, 196, 255))
        d.rectangle(s(134 + wide // 2, 222, 154 + wide, 240), fill=(210, 206, 196, 255))
        d.rounded_rectangle(s(88 - wide, 96, 170 + wide, 190), radius=16 * SCALE, fill=cloth)
        d.rounded_rectangle(s(94 - wide, 100, 164 + wide, 176), radius=12 * SCALE, fill=vest)
        d.line([s(129, 104), s(129, 174)], fill=tuple(int(c * 0.7) for c in vest[:3]) + (255,), width=3 * SCALE)
        d.ellipse(s(102, 42, 156, 100), fill=(232, 204, 176, 255))
        d.pieslice(s(100, 36, 158, 92), 180, 360, fill=(30, 26, 32, 255))
        d.rectangle(s(100, 58, 158, 70), fill=(64, 70, 92, 255))           # headband
        d.rectangle(s(118, 58, 140, 70), fill=(196, 204, 214, 255))        # metal plate
        d.ellipse(s(114, 76, 122, 84), fill=(30, 26, 32, 255))
        d.ellipse(s(136, 76, 144, 84), fill=(30, 26, 32, 255))
        if masked:
            d.rectangle(s(104, 84, 154, 100), fill=(50, 52, 60, 255))
        d.line([s(170 + wide, 140), s(196 + wide, 120)], fill=(170, 176, 186, 255), width=5 * SCALE)  # kunai
    return draw


def elite(d, g):
    d.polygon([s(76, 236), s(96, 100), s(160, 100), s(182, 236)], fill=(232, 230, 222, 255))
    d.polygon([s(96, 236), s(112, 120), s(146, 120), s(162, 236)], fill=(70, 66, 84, 255))
    d.line([s(129, 120), s(129, 236)], fill=(190, 160, 60, 255), width=4 * SCALE)
    d.ellipse(s(102, 40, 156, 100), fill=(232, 204, 176, 255))
    d.pieslice(s(92, 26, 166, 104), 180, 360, fill=(232, 230, 222, 255))
    d.rectangle(s(100, 60, 158, 72), fill=(160, 40, 40, 255))
    d.ellipse(s(114, 76, 122, 84), fill=(30, 26, 32, 255))
    d.ellipse(s(136, 76, 144, 84), fill=(30, 26, 32, 255))


def hoodoo(d, g):
    bands = [(212, 156, 104), (196, 136, 88), (220, 170, 118), (186, 124, 80)]
    top, bottom = 60, 240
    for i, y in enumerate(range(top, bottom, 22)):
        w = 32 + (i % 2) * 6 + (y - top) // 12
        d.rectangle(s(128 - w, y, 128 + w, min(y + 22, bottom)), fill=bands[i % len(bands)] + (255,))
    d.ellipse(s(70, 30, 186, 82), fill=(150, 98, 66, 255))                  # cap rock
    d.ellipse(s(82, 36, 170, 64), fill=(176, 120, 82, 255))
    d.polygon([s(70, 240), s(186, 240), s(176, 222), s(80, 222)], fill=(196, 140, 92, 255))


def boulder(d, g):
    d.ellipse(s(40, 120, 216, 244), fill=(198, 142, 96, 255))
    d.ellipse(s(66, 128, 170, 196), fill=(222, 170, 120, 255))
    d.arc(s(56, 150, 200, 236), 20, 160, fill=(160, 106, 70, 255), width=5 * SCALE)


def shrub(d, g):
    for a, b in ((128, 120), (90, 150), (166, 150), (110, 110), (150, 110)):
        d.line([s(128, 238), s(a, b)], fill=(120, 92, 60, 255), width=5 * SCALE)
    d.ellipse(s(70, 120, 186, 236), outline=(140, 112, 70, 255), width=6 * SCALE)
    d.ellipse(s(96, 150, 160, 220), outline=(160, 130, 84, 255), width=5 * SCALE)


def caster(coat, glow):
    def draw(d, g):
        ninja(coat, (40, 36, 44, 255))(d, g)
        d.polygon([s(84, 100), s(174, 100), s(166, 186), s(92, 186)], fill=coat)
        d.ellipse(s(106, 112, 152, 150), fill=glow)
        d.ellipse(s(118, 120, 140, 142), fill=(255, 250, 230, 255))
    return draw


SPRITES = [
    madara,
    ninja((92, 120, 72, 255), (46, 50, 62, 255)),
    ninja((74, 80, 88, 255), (40, 42, 50, 255), masked=True),
    ninja((122, 96, 64, 255), (52, 46, 44, 255), wide=14),
    elite, hoodoo, boulder, shrub,
    caster((150, 40, 32, 255), (255, 140, 40, 255)),
    caster((40, 80, 160, 255), (90, 190, 255, 255)),
    caster((120, 86, 50, 255), (210, 170, 90, 255)),
]


def build() -> Image.Image:
    atlas = Image.new("RGBA", (CELL * COLS, CELL * ROWS), (0, 0, 0, 0))
    for index, fn in enumerate(SPRITES):
        atlas.alpha_composite(finish(fn), ((index % COLS) * CELL, (index // COLS) * CELL))
    return atlas


def main() -> None:
    atlas = build()
    path = Path(__file__).resolve().parent.parent / "assets" / "sprites" / "atlas.png"
    atlas.save(path)
    print("wrote", path)


if __name__ == "__main__":
    main()
