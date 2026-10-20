"""Placeholder pixel art for the boss-push slice: 6 class bodies x 9 frames, the boss, and a ground tile.

    uv run --with pillow tools/make_placeholder_art.py      (from prototypes/hero-horde-idle)

Writes assets/sprites/heroes.png + heroes.json (sprite3d sheets.json format), boss.png and ground.png.
Heroes face right; one direction, mirror off. Per-hero colour variety comes from the MultiMesh tint, so clothes
are drawn light. ponytail: throwaway art, replaced by the paperdoll module once the slice is validated.
"""
import json
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "assets" / "sprites"
CELL = 32
FOOT = 1  # transparent foot strip; feet stand on row CELL - FOOT - 1
FRAMES = 9  # run 0-3, attack 4-6, down 7, volley 8
CLASSES = ["shield", "sword", "spear", "bow", "mage", "healer"]
# Light clothes per class so arc ranks read apart; the per-hero tint multiplies these.
CLOTH = {
    "shield": (150, 180, 230), "sword": (235, 140, 130), "spear": (240, 190, 120),
    "bow": (150, 220, 140), "mage": (195, 150, 235), "healer": (245, 245, 235),
}
SKIN = (250, 220, 190)
DARK = (40, 34, 48)
STEEL = (210, 215, 225)
WOOD = (150, 105, 60)
GOLD = (255, 215, 90)
METERS_PER_PX = 0.0375


def hero(cls: str, frame: int) -> Image.Image:
    img = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    ground = CELL - FOOT - 1
    run = frame < 4
    step = [0, 1, 0, -1][frame] if run else 0
    bob = 1 if run and frame % 2 == 1 else 0
    # legs
    d.rectangle([12 + step, ground - 5, 14 + step, ground], fill=DARK)
    d.rectangle([17 - step, ground - 5, 19 - step, ground], fill=DARK)
    top = ground - 21 - bob
    # body
    d.rectangle([11, top + 11, 20, top + 17], fill=CLOTH[cls], outline=DARK)
    # head
    d.ellipse([10, top, 21, top + 11], fill=SKIN, outline=DARK)
    d.chord([10, top - 1, 21, top + 8], 180, 360, fill=CLOTH[cls], outline=DARK)
    if frame == 7:
        d.point([(17, top + 6), (19, top + 6), (18, top + 7), (17, top + 8), (19, top + 8)], fill=DARK)
    else:
        d.point([(18, top + 6), (18, top + 7)], fill=DARK)
    hand = (21, top + 13)
    attack = frame - 4 if 4 <= frame <= 6 else -1
    raised = frame == 8
    if raised:
        hand = (20, top + 4)
    d.line([(17, top + 12), hand], fill=SKIN, width=2)

    if cls == "shield":
        dx = [0, 2, 1][attack] if attack >= 0 else 0
        d.rectangle([21 + dx, top + 9, 25 + dx, top + 20], fill=STEEL, outline=DARK)
        d.point([(23 + dx, top + 14)], fill=GOLD)
    elif cls == "sword":
        tips = [(24, top - 2), (29, top + 8), (27, top + 18)]
        tip = (22, top - 6) if raised else (tips[attack] if attack >= 0 else (26, top + 4))
        d.line([hand, tip], fill=STEEL, width=2)
    elif cls == "spear":
        dx = [0, 4, 2][attack] if attack >= 0 else 0
        if raised:
            d.line([(20, top + 14), (22, top - 8)], fill=WOOD, width=1)
            d.polygon([(21, top - 11), (23, top - 8), (21, top - 7)], fill=STEEL)
        else:
            d.line([(8 + dx, top + 14), (27 + dx, top + 12)], fill=WOOD, width=1)
            d.polygon([(27 + dx, top + 10), (31, top + 12), (27 + dx, top + 14)], fill=STEEL)
    elif cls == "bow":
        pull = [1, 3, 0][attack] if attack >= 0 else 0
        d.arc([20, top + 4, 28, top + 22], 270, 90, fill=WOOD, width=2)
        d.line([(24 - pull, top + 5), (24 - pull, top + 21)], fill=STEEL, width=1)
        if attack == 1:
            d.line([(18, top + 13), (30, top + 13)], fill=WOOD, width=1)
    elif cls in ("mage", "healer"):
        lean = [0, 3, 1][attack] if attack >= 0 else 0
        base = (22 + lean, top + 20)
        head = (24 + lean, top + 1) if not raised else (22, top - 6)
        d.line([base, head], fill=WOOD, width=1)
        if cls == "mage":
            glow = (255, 120, 220) if attack == 1 or raised else (190, 120, 255)
            d.ellipse([head[0] - 2, head[1] - 3, head[0] + 2, head[1] + 1], fill=glow, outline=DARK)
        else:
            d.line([(head[0] - 2, head[1] - 1), (head[0] + 2, head[1] - 1)], fill=GOLD, width=1)
            d.line([(head[0], head[1] - 3), (head[0], head[1] + 1)], fill=GOLD, width=1)
    if raised:
        d.point([(24, top - 4), (26, top), (19, top - 8), (27, top - 6)], fill=GOLD)
    return img


def boss(frame: int) -> Image.Image:
    """128 px ogre facing left. 0 idle, 1 winding up the sweep, 2 broken (dazed)."""
    size = 128
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    g = size - 2
    skin = (120, 170, 110) if frame != 1 else (190, 120, 100)
    slump = 10 if frame == 2 else 0
    d.rectangle([40, g - 22, 56, g], fill=DARK)
    d.rectangle([72, g - 22, 88, g], fill=DARK)
    d.ellipse([28, g - 92 + slump, 100, g - 16], fill=skin, outline=DARK, width=2)
    d.ellipse([20, g - 112 + slump, 64, g - 70 + slump], fill=skin, outline=DARK, width=2)
    d.polygon([(26, g - 104 + slump), (18, g - 124 + slump), (34, g - 108 + slump)], fill=(240, 235, 220), outline=DARK)
    d.polygon([(52, g - 108 + slump), (58, g - 126 + slump), (60, g - 104 + slump)], fill=(240, 235, 220), outline=DARK)
    if frame == 2:
        for x in (32, 46):
            d.line([(x, g - 96 + slump), (x + 6, g - 90 + slump)], fill=DARK, width=2)
            d.line([(x + 6, g - 96 + slump), (x, g - 90 + slump)], fill=DARK, width=2)
        for i, x in enumerate((30, 44, 58)):
            d.ellipse([x, g - 124 + i % 2 * 4, x + 6, g - 118 + i % 2 * 4], fill=GOLD)
    else:
        d.rectangle([30, g - 96, 36, g - 90], fill=(255, 240, 80) if frame == 1 else (250, 250, 250))
        d.rectangle([44, g - 96, 50, g - 90], fill=(255, 240, 80) if frame == 1 else (250, 250, 250))
    d.line([(30, g - 80 + slump), (50, g - 78 + slump)], fill=DARK, width=2)
    # club arm
    if frame == 1:
        d.line([(80, g - 70), (110, g - 118)], fill=WOOD, width=10)
        d.ellipse([98, g - 127, 124, g - 104], fill=WOOD, outline=DARK, width=2)
    else:
        d.line([(36, g - 50 + slump), (8, g - 28 + slump)], fill=WOOD, width=10)
        d.ellipse([1, g - 40 + slump, 24, g - 16 + slump], fill=WOOD, outline=DARK, width=2)
    return img


def ground() -> Image.Image:
    img = Image.new("RGBA", (64, 64), (104, 160, 86, 255))
    d = ImageDraw.Draw(img)
    for i in range(90):
        x, y = (i * 37) % 64, (i * 23 + i * i) % 64
        d.point([(x, y), (x, (y + 1) % 64)], fill=(88, 140, 74, 255) if i % 3 else (128, 182, 100, 255))
    return img


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (CELL * FRAMES, CELL * len(CLASSES)), (0, 0, 0, 0))
    characters = {}
    for row, cls in enumerate(CLASSES):
        for f in range(FRAMES):
            sheet.paste(hero(cls, f), (f * CELL, row * CELL))
        base = row * FRAMES
        characters[cls] = {
            "directions": 1, "mirror": False,
            "anims": {
                "run": {"cell": base, "n": 4, "d": [6, 6, 6, 6], "loop": True},
                "attack": {"cell": base + 4, "n": 3, "d": [10, 6, 14], "loop": True},
                "down": {"cell": base + 7, "n": 1, "d": [60], "loop": False},
                "volley": {"cell": base + 8, "n": 1, "d": [60], "loop": False},
            },
        }
    sheet.save(OUT / "heroes.png")
    meta = {"atlas": "heroes.png", "cell_px": CELL, "columns": FRAMES, "rows": len(CLASSES), "foot_px": FOOT,
            "meters_per_px": METERS_PER_PX, "characters": characters}
    (OUT / "heroes.json").write_text(json.dumps(meta, indent=1))
    strip = Image.new("RGBA", (128 * 3, 128), (0, 0, 0, 0))
    for f in range(3):
        strip.paste(boss(f), (f * 128, 0))
    strip.save(OUT / "boss.png")
    ground().save(OUT / "ground.png")
    print("wrote", OUT)


if __name__ == "__main__":
    main()
