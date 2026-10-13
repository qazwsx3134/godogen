"""Draws the pixel UI frames (docs/pixel-ui-plan.md P3) into assets/ui/: each is drawn in art pixels and saved 2x,
so one art pixel is 2 screen px like the sprites. tools/build_pixel_ui.gd turns them into 9-slice StyleBoxTextures;
MARGIN (art px) is the corner area that must not stretch. Night-market palette: deep indigo, lantern gold and red.

    uv run --no-project --with pillow python tools/make_ui_frames.py
"""
import os

from PIL import Image

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(HERE, "assets/ui")
SCALE = 2

INK = (18, 12, 30, 255)
GOLD = (255, 211, 107, 255)
GOLD_DARK = (201, 138, 43, 255)
PANEL = (35, 26, 62, 245)
PANEL_LIGHT = (52, 41, 92, 245)
BUTTON = (59, 47, 110, 255)
BUTTON_LIGHT = (78, 64, 140, 255)
BUTTON_DEPTH = (26, 20, 51, 255)
PRIMARY = (255, 200, 72, 255)
PRIMARY_LIGHT = (255, 232, 140, 255)
PRIMARY_DEPTH = (154, 90, 18, 255)
LANTERN = (217, 72, 59, 255)
MUTED = (88, 78, 120, 255)
GLASS = (18, 12, 30, 150)
GLASS_EDGE = (255, 255, 255, 90)
CLEAR = (0, 0, 0, 0)


def rect(img, x0, y0, x1, y1, color, cut=0):
    """Fills x0..x1, y0..y1 (inclusive) with stair-stepped corners `cut` px deep."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if min(x - x0, x1 - x) + min(y - y0, y1 - y) < cut:
                continue
            img.putpixel((x, y), color)


def save(name, img):
    os.makedirs(OUT, exist_ok=True)
    img.resize((img.width * SCALE, img.height * SCALE), Image.NEAREST).save(os.path.join(OUT, name + ".png"))
    print(f"{name}.png {img.width * SCALE}x{img.height * SCALE}")


def box():
    # Dark outline, gold rim, a darker gold bevel, indigo fill with a lighter top line. MARGIN 5.
    img = Image.new("RGBA", (16, 16), CLEAR)
    rect(img, 0, 0, 15, 15, INK, 3)
    rect(img, 1, 1, 14, 14, GOLD, 3)
    rect(img, 2, 2, 13, 13, GOLD_DARK, 2)
    rect(img, 3, 3, 12, 12, PANEL, 1)
    rect(img, 4, 4, 11, 4, PANEL_LIGHT)
    save("box", img)


def button(name, body, light, depth, rim, pressed=False):
    # A raised button: rim, body with a highlight row and a 2 px darker "thickness" below. Pressed drops 2 px.
    img = Image.new("RGBA", (16, 18), CLEAR)
    top = 2 if pressed else 0
    rect(img, 0, top, 15, 17, INK, 3)
    if not pressed:
        rect(img, 1, 12, 14, 16, depth, 2)
    rect(img, 1, top + 1, 14, top + 13 if not pressed else 16, rim, 2)
    rect(img, 2, top + 2, 13, top + 12 if not pressed else 15, body, 1)
    rect(img, 3, top + 3, 12, top + 3, light)
    save(name, img)


def glass(name, edge):
    img = Image.new("RGBA", (12, 12), CLEAR)
    rect(img, 0, 0, 11, 11, edge, 2)
    rect(img, 1, 1, 10, 10, GLASS, 1)
    save(name, img)


def bar(name, colors):
    # Bar fill: stepped horizontal gradient through `colors`, a light top row. MARGIN 1.
    img = Image.new("RGBA", (len(colors) * 4, 4), CLEAR)
    for i, color in enumerate(colors):
        rect(img, i * 4, 0, i * 4 + 3, 3, color)
        lighter = tuple(min(255, c + 50) for c in color[:3]) + (255,)
        rect(img, i * 4, 0, i * 4 + 3, 0, lighter)
    save(name, img)


def bar_back():
    img = Image.new("RGBA", (6, 6), CLEAR)
    rect(img, 0, 0, 5, 5, INK, 1)
    rect(img, 1, 1, 4, 4, (42, 32, 64, 255))
    save("bar_back", img)


def slot(name, rim):
    img = Image.new("RGBA", (12, 12), CLEAR)
    rect(img, 0, 0, 11, 11, INK, 2)
    rect(img, 1, 1, 10, 10, rim, 2)
    rect(img, 2, 2, 9, 9, (18, 12, 30, 200), 1)
    save(name, img)


def pill():
    img = Image.new("RGBA", (6, 6), CLEAR)
    rect(img, 0, 0, 5, 5, (255, 255, 255, 255), 1)
    save("pill", img)


if __name__ == "__main__":
    box()
    button("button", BUTTON, BUTTON_LIGHT, BUTTON_DEPTH, GOLD)
    button("button_hover", BUTTON_LIGHT, (98, 84, 168, 255), BUTTON_DEPTH, GOLD)
    button("button_pressed", BUTTON, BUTTON_LIGHT, BUTTON_DEPTH, GOLD, pressed=True)
    button("button_disabled", (48, 42, 66, 255), (58, 52, 78, 255), BUTTON_DEPTH, MUTED)
    button("primary", PRIMARY, PRIMARY_LIGHT, PRIMARY_DEPTH, LANTERN)
    button("primary_hover", PRIMARY_LIGHT, (255, 244, 190, 255), PRIMARY_DEPTH, LANTERN)
    button("primary_pressed", PRIMARY, PRIMARY_LIGHT, PRIMARY_DEPTH, LANTERN, pressed=True)
    glass("glass", GLASS_EDGE)
    glass("glass_hover", GOLD)
    bar_back()
    bar("bar_xp", [(79, 209, 255, 255), (110, 186, 255, 255), (140, 160, 255, 255), (169, 139, 255, 255)])
    bar("bar_hp", [(255, 95, 109, 255)])
    bar("bar_elite", [(255, 203, 61, 255)])
    slot("slot", MUTED)
    slot("slot_new", GOLD)
    pill()
