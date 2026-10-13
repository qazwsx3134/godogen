"""Cuts a generated 3x3 icon sheet (flat green background) into one icon per cell.

For each cell: key out the green, crop to the icon, save the clean original as art_src/icons/<id>/selected.png and a
pixel version (tools/pixelize.py rules: area shrink, hard alpha, <= 32 colours, 1 px outline) as
assets/pixel/icons/<id>_<height>.png. Cell ids come from layout.json next to the sheets ({"a": [9 ids], ...}).

    uv run --no-project --with pillow --with numpy --with scipy python tools/slice_icon_sheet.py art_src/icons/sheets [--height 24]
"""
import argparse, importlib.util, json, os

import numpy as np
from PIL import Image
from scipy import ndimage

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
spec = importlib.util.spec_from_file_location("pixelize", os.path.join(HERE, "tools/pixelize.py"))
pixelize = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pixelize)


def key_green(img: Image.Image) -> Image.Image:
    rgba = np.array(img.convert("RGBA")).astype(int)
    r, g, b = rgba[..., 0], rgba[..., 1], rgba[..., 2]
    rgba[(g > 150) & (g > r + 60) & (g > b + 60), 3] = 0
    # Green fringe left on anti-aliased edges: pull green down to the other channels.
    spill = (g > r + 25) & (g > b + 25) & (rgba[..., 3] > 0)
    rgba[spill, 1] = np.maximum(r[spill], b[spill])
    return Image.fromarray(rgba.astype(np.uint8))


def drop_strays(cell: Image.Image) -> Image.Image:
    """Removes small bits near the cell border: pieces of the neighbouring icon that crossed the grid line."""
    rgba = np.array(cell)
    labels, count = ndimage.label(rgba[..., 3] > 0)
    band = round(min(cell.size) * 0.1)
    for k, piece in enumerate(ndimage.find_objects(labels), 1):
        rows, cols = piece
        near_edge = rows.start < band or cols.start < band or rows.stop > cell.height - band or cols.stop > cell.width - band
        if near_edge and (labels[piece] == k).sum() < cell.width * cell.height * 0.01:
            rgba[labels == k, 3] = 0
    return Image.fromarray(rgba)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("folder")
    parser.add_argument("--height", type=int, default=24)
    args = parser.parse_args()
    layout = json.load(open(os.path.join(args.folder, "layout.json")))
    for sheet, ids in layout.items():
        path = os.path.join(args.folder, f"gen-{sheet}", "generated.png")
        if not os.path.exists(path):
            print(f"missing sheet {sheet}")
            continue
        img = key_green(Image.open(path))
        cw, ch = img.width / 3, img.height / 3
        for i, icon_id in enumerate(ids):
            cell = img.crop((round(i % 3 * cw), round(i // 3 * ch), round((i % 3 + 1) * cw), round((i // 3 + 1) * ch)))
            cell = drop_strays(cell)
            box = cell.getbbox()
            if box is None:
                print(f"empty cell {sheet}{i} ({icon_id})")
                continue
            icon = cell.crop(box)
            out_dir = os.path.join(HERE, "art_src/icons", icon_id)
            os.makedirs(out_dir, exist_ok=True)
            icon.save(os.path.join(out_dir, "selected.png"))
            # Fit the longer side so wide icons don't come out huge.
            scale = args.height / max(icon.width, icon.height)
            job = {"width": max(1, round(icon.width * scale)), "height": max(1, round(icon.height * scale))}
            pixel = pixelize.sprite(job, icon)
            pixel.save(os.path.join(HERE, "assets/pixel/icons", f"{icon_id}_{args.height}.png"))
            print(f"{icon_id:15s} {icon.size} -> {pixel.size}")


if __name__ == "__main__":
    main()
