"""Pixel sprites for weapons that have no icon art (docs/pixel-ui-plan.md, effects pass): drawn here on the art-pixel
grid and saved 1:1 into assets/pixel/fx/.
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


def hoop():
    """A chunky, tilted night-market plastic ring, drawn at the art-pixel grid."""
    width, height = 43, 24
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    px = img.load()
    cx, cy = 21.0, 11.5
    tilt = math.radians(-6.0)
    cos_t, sin_t = math.cos(tilt), math.sin(tilt)
    outer_rx, outer_ry = 18.3, 7.0
    inner_rx, inner_ry = 14.2, 4.4
    outline_color = rgba("#281c2a")
    shadow = rgba("#a84218")
    orange = rgba("#f2761b")
    bright = rgba("#ff9a27")
    gold = rgba("#ffc653")
    glint = rgba("#fff0b0")

    for y in range(height):
        for x in range(width):
            dx, dy = x - cx, y - cy
            u = dx * cos_t - dy * sin_t
            v = dx * sin_t + dy * cos_t
            angle = math.atan2(v / outer_ry, u / outer_rx)
            wobble = 1.0 + math.sin(angle * 5.0 + 0.3) * 0.018 + math.sin(angle * 9.0) * 0.012
            outer = math.hypot(u / (outer_rx * wobble), v / (outer_ry * wobble))
            inner = math.hypot(u / (inner_rx * wobble), v / (inner_ry * wobble))

            # One-pixel dark outer and inner edges keep the ring legible when scaled down.
            if outer > 1.13 or inner < 0.82:
                continue
            if outer > 0.97 or inner < 1.12:
                px[x, y] = outline_color
            elif v > 1.8 or (u > 7.0 and v > -1.0):
                px[x, y] = shadow
            elif v < -2.2 and -10.0 < u < 5.0:
                px[x, y] = gold
            elif v < -0.2 and u < 4.0:
                px[x, y] = bright
            else:
                px[x, y] = orange

    # Small reflected glints on the upper-left arc.
    for x, y in ((12, 4), (13, 4), (14, 5), (15, 5)):
        px[x, y] = glint
    return img


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, img in (("wave", crescent()), ("ring", hoop())):
        img.save(os.path.join(OUT, f"{name}.png"))
        print(f"{name}.png", img.size)
