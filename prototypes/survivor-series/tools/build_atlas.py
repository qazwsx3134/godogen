"""Packs the enemy and pickup pixel sprites into one atlas so y-sorted crowds batch into few draw calls.

Writes assets/pixel/atlas/sprites.png and one AtlasTexture per sprite (assets/pixel/atlas/<name>.tres).
The scenes point at the .tres files, so after replacing a sprite in assets/pixel/ just rerun this:
  uv run --no-project --with pillow python tools/build_atlas.py
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/pixel/atlas"
SOURCES = [
    "enemies/gangster_29.png", "enemies/fatty_30.png",
    *[f"vehicles/motorcycle-{d}_33.png" for d in ("s", "se", "e", "ne", "n")],
    *[f"vehicles/car-{d}_52.png" for d in ("s", "se", "e", "ne", "n")],
    *[f"icons/{n}.png" for n in ("gem_6", "gem_9", "gem_12", "coin_7", "rice_11", "vacuum_11", "chest_13")],
]
WIDTH = 256
PAD = 1  # ponytail: nearest filtering only, so 1 px keeps neighbours from bleeding; mipmaps would need more


def pack() -> dict[str, tuple[int, int, int, int]]:
    images = {s: Image.open(ROOT / "assets/pixel" / s).convert("RGBA") for s in SOURCES}
    regions, x, y, row = {}, 0, 0, 0
    for name in sorted(SOURCES, key=lambda s: -images[s].height):  # shelf packing, tallest first
        w, h = images[name].size
        if x + w > WIDTH:
            x, y, row = 0, y + row + PAD, 0
        regions[name] = (x, y, w, h)
        x, row = x + w + PAD, max(row, h)
    sheet = Image.new("RGBA", (WIDTH, y + row), (0, 0, 0, 0))
    for name, (rx, ry, _, _) in regions.items():
        sheet.paste(images[name], (rx, ry))
    OUT.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT / "sprites.png")
    for name, (rx, ry, w, h) in regions.items():
        (OUT / (Path(name).stem + ".tres")).write_text(
            '[gd_resource type="AtlasTexture" format=3]\n\n'
            '[ext_resource type="Texture2D" path="res://assets/pixel/atlas/sprites.png" id="1"]\n\n'
            f'[resource]\natlas = ExtResource("1")\nregion = Rect2({rx}, {ry}, {w}, {h})\n'
        )
    return regions


if __name__ == "__main__":
    regions = pack()
    sheet = Image.open(OUT / "sprites.png")
    for name, (rx, ry, w, h) in regions.items():  # self-check: every region reads back its source pixels
        assert sheet.crop((rx, ry, rx + w, ry + h)).tobytes() == Image.open(ROOT / "assets/pixel" / name).convert("RGBA").tobytes(), name
    print(f"{len(regions)} sprites -> {OUT / 'sprites.png'} {sheet.size}")
