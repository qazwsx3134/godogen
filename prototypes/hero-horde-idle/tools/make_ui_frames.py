#!/usr/bin/env python3
"""Pixel-art 9-slice frames for buttons and dialogs, drawn by code in the 墨綠暖白 look the author approved
(art_src/ui_concepts/detail_refinement_v2/hero_detail.png: a double bronze outline with notched corners and a small
ornament at each corner; the main action on parchment). Every art pixel is PX screen pixels, so the frames read as
pixel art next to the icons. tools/style_theme.gd puts them in ui/theme.tres.
  python3 tools/make_ui_frames.py   -> assets/ui/frame/*.png
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/ui/frame"
PX = 2  # screen pixels per art pixel

BRONZE = (169, 135, 90)
BRONZE_DARK = (107, 88, 62)
GOLD = (217, 178, 110)
PANEL = (19, 32, 28)
PANEL_TOP = (27, 44, 38)
PAPER = (221, 213, 198)
PAPER_TOP = (233, 226, 212)
PAPER_LOW = (203, 191, 169)
INK_LINE = (143, 112, 72)
GREY = (62, 64, 57)
GREY_LINE = (79, 84, 70)


def frame(size: int, notch: int, fill_top, fill_low, outer, inner, ornament, inset: int = 3, alpha: int = 245,
          corner: str = "diamond") -> Image.Image:
    """size x size art pixels: a filled octagon (corners cut by `notch`), an outer line, an inner line `inset` in,
    and an ornament in each corner. Scaled up by PX."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    last = size - 1

    def inside(x: int, y: int, cut: int) -> bool:
        dx = min(x, last - x)
        dy = min(y, last - y)
        return dx + dy >= cut

    for y in range(size):
        t = y / last
        fill = tuple(round(fill_top[k] * (1 - t) + fill_low[k] * t) for k in range(3))
        for x in range(size):
            if not inside(x, y, notch):
                continue
            edge = min(x, y, last - x, last - y) == 0 or (min(x, last - x) + min(y, last - y) == notch)
            px[x, y] = (*outer, 255) if edge else (*fill, alpha)
    # Inner line, `inset` pixels in, with its own (smaller) notch.
    lo, hi = inset, last - inset
    for y in range(lo, hi + 1):
        for x in range(lo, hi + 1):
            dx = min(x - lo, hi - x)
            dy = min(y - lo, hi - y)
            on_edge = (x in (lo, hi) or y in (lo, hi)) and dx + dy >= max(notch - inset, 1)
            on_cut = dx + dy == max(notch - inset, 1)
            if on_edge or on_cut:
                px[x, y] = (*inner, 255)
    # Corner ornaments: a small diamond just inside each notch.
    if corner == "diamond":
        for cx, cy in ((inset + 1, inset + 1), (last - inset - 1, inset + 1), (inset + 1, last - inset - 1),
                       (last - inset - 1, last - inset - 1)):
            for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
                px[cx + dx, cy + dy] = (*ornament, 255)
    return img.resize((size * PX, size * PX), Image.NEAREST)


def rule() -> Image.Image:
    """The diamond in the middle of a dialog's title rule (the lines either side are plain)."""
    img = Image.new("RGBA", (7, 7), (0, 0, 0, 0))
    px = img.load()
    for y in range(7):
        for x in range(7):
            d = abs(x - 3) + abs(y - 3)
            if d == 3:
                px[x, y] = (*BRONZE, 255)
            elif d < 3:
                px[x, y] = (*GOLD, 255)
    return img.resize((7 * PX, 7 * PX), Image.NEAREST)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    out = {
        # Secondary buttons: dark green, bronze double line.
        "button": frame(16, 3, PANEL_TOP, PANEL, BRONZE, BRONZE_DARK, BRONZE),
        "button_hover": frame(16, 3, tuple(c + 10 for c in PANEL_TOP), PANEL, GOLD, BRONZE, GOLD),
        "button_pressed": frame(16, 3, PANEL, PANEL_TOP, GOLD, BRONZE, GOLD),
        "button_disabled": frame(16, 3, GREY, GREY, GREY_LINE, GREY_LINE, GREY_LINE, alpha=200, corner="none"),
        # The main action: parchment.
        "primary": frame(16, 3, PAPER_TOP, PAPER_LOW, INK_LINE, (179, 154, 114), INK_LINE),
        "primary_hover": frame(16, 3, (242, 236, 224), PAPER, INK_LINE, (179, 154, 114), INK_LINE),
        "primary_pressed": frame(16, 3, PAPER_LOW, PAPER, INK_LINE, (160, 134, 96), INK_LINE),
        "primary_disabled": frame(16, 3, (74, 75, 67), (66, 67, 60), GREY_LINE, GREY_LINE, GREY_LINE, corner="none"),
        # Dialogs: a bigger notch, the inner line further in.
        "dialog": frame(32, 5, PANEL_TOP, PANEL, BRONZE, BRONZE_DARK, GOLD, inset=4, alpha=250),
        "rule_diamond": rule(),
    }
    for name, img in out.items():
        img.save(OUT / f"{name}.png")
    print(f"{len(out)} frames -> {OUT}")


if __name__ == "__main__":
    main()
