"""Cuts the item, material, relic and talent icons out of the reference sheets with their backgrounds removed
(2026-10-28: the author saw the beige squares behind every item). For each listed assets/atlas/<name>.tres it crops
the region, flood-fills the background from the border (colours close to the border's), drops loose bits that are not
part of the drawing (the baked "Lv" text), writes assets/ui/items_clean/<name>.png and points the .tres at it.
    uv run --with pillow --with numpy tools/cut_item_icons.py           # from prototypes/hero-horde-idle
"""
import re
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
NAMES = ([f"equipment_item_{k}" for k in range(15)] + [f"item_{k}" for k in range(10)] + [f"product_{k}" for k in range(4)]
         + [f"training_{k}" for k in range(4)] + ["gift", "coin", "shop_coin", "shop_gem", "gem", "heart", "sword", "shield",
         "paw", "gear", "practice_dummy"])
TOLERANCE = 34.0   # colour distance from a border colour that still counts as background
## Icons whose drawing is close to the background colour: a tighter tolerance.
TIGHT = {"paw": 10.0, "item_7": 14.0}
## Rings and pendants: background showing through the hole is cut too (not only what touches the border).
HOLES = {"equipment_item_6", "equipment_item_7", "equipment_item_10", "equipment_item_13"}
HOLE_MIN = 30      # a hole smaller than this many pixels stays (specks inside the drawing)
KEEP_SHARE = 0.08  # a separate blob is kept if it has at least this share of the largest one


def region(tres: str):
    path = re.search(r'path="res://([^"]+)"', tres).group(1)
    x, y, w, h = (float(v) for v in re.search(r"region = Rect2\(([^)]*)\)", tres).group(1).split(","))
    return ROOT / path, (int(x), int(y), int(x + w), int(y + h))


def cut(img: Image.Image, tolerance: float = TOLERANCE, holes: bool = False) -> Image.Image:
    a = np.asarray(img.convert("RGBA")).astype(np.float32)
    h, w = a.shape[:2]
    border = np.concatenate([a[0, :, :3], a[-1, :, :3], a[:, 0, :3], a[:, -1, :3]])
    # A few representative background colours: the border's most common ones.
    keys, counts = np.unique((border // 8).astype(np.int32), axis=0, return_counts=True)
    bg = keys[np.argsort(-counts)[:6]] * 8 + 4
    dist = np.min(np.linalg.norm(a[:, :, None, :3] - bg[None, None, :, :], axis=3), axis=2)
    near = (dist < tolerance) | (a[:, :, 3] < 20)
    gone = np.zeros((h, w), bool)
    q = deque((y, x) for y in range(h) for x in (0, w - 1)) 
    q.extend((y, x) for x in range(w) for y in (0, h - 1))
    while q:
        y, x = q.popleft()
        if gone[y, x] or not near[y, x]:
            continue
        gone[y, x] = True
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and not gone[ny, nx]:
                q.append((ny, nx))
    if holes:
        # Background-coloured pockets not reached from the border: flood each, drop the big ones.
        seen = gone.copy()
        for y in range(h):
            for x in range(w):
                if near[y, x] and not seen[y, x]:
                    pocket = []
                    q = deque([(y, x)])
                    seen[y, x] = True
                    while q:
                        cy, cx = q.popleft()
                        pocket.append((cy, cx))
                        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                            ny, nx = cy + dy, cx + dx
                            if 0 <= ny < h and 0 <= nx < w and near[ny, nx] and not seen[ny, nx]:
                                seen[ny, nx] = True
                                q.append((ny, nx))
                    if len(pocket) >= HOLE_MIN:
                        for cy, cx in pocket:
                            gone[cy, cx] = True
    solid = ~gone
    # Connected blobs of what is left; keep the big ones.
    label = np.zeros((h, w), np.int32)
    sizes = [0]
    for y in range(h):
        for x in range(w):
            if solid[y, x] and label[y, x] == 0:
                n = len(sizes)
                size = 0
                q = deque([(y, x)])
                label[y, x] = n
                while q:
                    cy, cx = q.popleft()
                    size += 1
                    for dy in (-1, 0, 1):
                        for dx in (-1, 0, 1):
                            ny, nx = cy + dy, cx + dx
                            if 0 <= ny < h and 0 <= nx < w and solid[ny, nx] and label[ny, nx] == 0:
                                label[ny, nx] = n
                                q.append((ny, nx))
                sizes.append(size)
    biggest = max(sizes) if len(sizes) > 1 else 0
    keep = np.isin(label, [k for k, s in enumerate(sizes) if k > 0 and s >= biggest * KEEP_SHARE])
    a[:, :, 3] = np.where(keep, a[:, :, 3], 0)
    out = Image.fromarray(a.astype(np.uint8), "RGBA")
    box = out.getbbox()
    return out.crop(box) if box else out


def main() -> None:
    out_dir = ROOT / "assets/ui/items_clean"
    out_dir.mkdir(parents=True, exist_ok=True)
    for name in NAMES:
        tres_path = ROOT / "assets/atlas" / f"{name}.tres"
        tres = tres_path.read_text()
        if "items_clean" in tres:
            continue
        sheet, box = region(tres)
        icon = cut(Image.open(sheet).crop(box), TIGHT.get(name, TOLERANCE), name in HOLES)
        # Square canvas, centred, so icons keep their size relation inside square slots.
        side = max(icon.size)
        canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        canvas.paste(icon, ((side - icon.width) // 2, (side - icon.height) // 2))
        canvas.save(out_dir / f"{name}.png")
        tres_path.write_text(
            '[gd_resource type="AtlasTexture" format=3]\n\n'
            f'[ext_resource type="Texture2D" path="res://assets/ui/items_clean/{name}.png" id="1_clean"]\n\n'
            "[resource]\n"
            'atlas = ExtResource("1_clean")\n'
            f"region = Rect2(0, 0, {side}, {side})\n")
        print(name, icon.size)


if __name__ == "__main__":
    main()
