"""Pixel sprites for weapons that have no icon art (docs/pixel-ui-plan.md, effects pass): drawn here on the art-pixel
grid with a 5-tone palette (outline, dark, mid, light, white) and saved 1:1 into assets/pixel/fx/.
The scenes draw them at the world pixel density (2 screen px per art px).

    uv run --no-project --with pillow python tools/make_fx_sprites.py
"""
import math, os

from PIL import Image

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(HERE, "assets/pixel/fx")
# Shockwave: night-market neon cyan.
WAVE = ["#10243a", "#1f5d86", "#3fb4e0", "#9fe8ff", "#ffffff"]


def rgba(hex_color):
    h = hex_color.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def outline(img, color):
    w, h = img.size
    px = img.load()
    edge = [(x, y) for y in range(h) for x in range(w) if px[x, y][3] == 0 and any(
        0 <= x + dx < w and 0 <= y + dy < h and px[x + dx, y + dy][3] and px[x + dx, y + dy] != color
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
    for x, y in edge:
        px[x, y] = color


def crescent():
    # A bow-shaped shockwave facing +x: the bright leading edge is the outer arc, it thins toward the tips.
    w, h = 13, 17
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    pal = [rgba(c) for c in WAVE]
    cx, cy, r = -1.5, h / 2 - 0.5, 11.5
    for y in range(h):
        for x in range(w):
            d = math.hypot(x - cx, y - cy)
            span = 1.0 - abs(y - cy) / (h / 2)
            thick = 1.8 + 4.2 * span
            if r - thick <= d <= r:
                depth = (r - d) / thick
                px[x, y] = pal[4] if depth < 0.25 else pal[3] if depth < 0.55 else pal[2] if depth < 0.8 else pal[1]
    out = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
    out.paste(img, (1, 1))
    outline(out, pal[0])
    return out


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    img = crescent()
    img.save(os.path.join(OUT, "wave.png"))
    print("wave.png", img.size)
