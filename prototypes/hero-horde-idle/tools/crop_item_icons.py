#!/usr/bin/env python3
"""Placeholder weapon and charm icons cut from the round3 道具 mockups (art_src/ui_concepts/round3*/), until they get
their own art batch (relics, materials and the 招募券 already have theirs: art_src/ui_icons2, packed by
pack_stage_art.py ui). Each crop sits on the mockup's dark panel: a flood fill from the crop's edge removes the pixels
close to that panel colour (the icons' dark outline stops it), the result is trimmed and fitted in a 96 px square.
  python3 tools/crop_item_icons.py   -> assets/ui/items/<name>.png and art_src/item_icons/contact.png
"""
from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "art_src/ui_concepts"
OUT = ROOT / "assets/ui/items"
SHEET = ROOT / "art_src/item_icons/contact.png"
SIZE = 96
TOLERANCE = 30
INSIDE = 7

# name: (mockup, (left, top, right, bottom)) in the 853 x 1844 mockup.
CROPS = {
    # 職業武庫 (round3 A, the armory row)
    "w_shield": ("round3/A_items.png", (44, 488, 176, 590)),
    "w_sword": ("round3/A_items.png", (202, 462, 336, 592)),
    "w_spear": ("round3/A_items.png", (362, 462, 494, 592)),
    "w_bow": ("round3/A_items.png", (520, 462, 652, 592)),
    "w_staff": ("round3/A_items.png", (680, 462, 810, 592)),
    "w_holy": ("round3/A_items.png", (44, 686, 176, 812)),
    # 專屬飾品
    "c_blue_ring": ("round3/A_items.png", (48, 1090, 172, 1186)),
    "c_red_pendant": ("round3/A_items.png", (204, 1060, 336, 1186)),
    "c_purple_ring": ("round3/A_items.png", (362, 1060, 494, 1186)),
    "c_tooth": ("round3/C_items.png", (374, 1342, 480, 1440)),
    "c_leaf": ("round3/C_items.png", (531, 1342, 637, 1440)),
    "c_red_bow": ("round3/B_items.png", (321, 1250, 390, 1320)),
    "c_gold_ring": ("round3/B_items.png", (323, 1463, 388, 1525)),
    # 金幣 (the 招募 mockup's top bar), for the reward lists
    "m_gold": ("round3/B_recruit.png", (558, 46, 602, 90)),
}


def cut(name: str, mockup: str, box: tuple) -> Image.Image:
    img = Image.open(SRC / mockup).convert("RGBA").crop(box)
    w, h = img.size
    px = img.load()
    edge = [px[x, y] for x in range(w) for y in (0, h - 1)] + [px[x, y] for y in range(h) for x in (0, w - 1)]
    edge.sort(key=lambda c: c[0] + c[1] + c[2])
    bg = edge[len(edge) // 2]
    seen = set()
    todo = deque((x, y) for x in range(w) for y in (0, h - 1))
    todo.extend((x, y) for y in range(h) for x in (0, w - 1))
    while todo:
        x, y = todo.popleft()
        if (x, y) in seen or not (0 <= x < w and 0 <= y < h):
            continue
        seen.add((x, y))
        c = px[x, y]
        if sum(abs(c[k] - bg[k]) for k in range(3)) > TOLERANCE * 3 // 2:
            continue
        px[x, y] = (0, 0, 0, 0)
        todo.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    # Panel showing through a closed shape (inside the bow's string, the ring): a stricter match anywhere.
    for y in range(h):
        for x in range(w):
            c = px[x, y]
            if c[3] and sum(abs(c[k] - bg[k]) for k in range(3)) <= INSIDE * 3:
                px[x, y] = (0, 0, 0, 0)
    img = img.crop(img.getbbox())
    scale = (SIZE - 4) / max(img.size)
    img = img.resize((max(1, round(img.width * scale)), max(1, round(img.height * scale))), Image.LANCZOS)
    out = Image.new("RGBA", (SIZE, SIZE))
    out.alpha_composite(img, ((SIZE - img.width) // 2, (SIZE - img.height) // 2))
    return out


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    SHEET.parent.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (SIZE * 6, SIZE * ((len(CROPS) + 5) // 6)), (40, 70, 60, 255))
    for k, (name, (mockup, box)) in enumerate(CROPS.items()):
        icon = cut(name, mockup, box)
        icon.save(OUT / f"{name}.png")
        sheet.alpha_composite(icon, (SIZE * (k % 6), SIZE * (k // 6)))
    sheet.save(SHEET)
    print(f"{len(CROPS)} icons -> {OUT}")


if __name__ == "__main__":
    main()
