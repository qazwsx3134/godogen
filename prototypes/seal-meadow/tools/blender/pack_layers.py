#!/usr/bin/env python3
"""Packs render_sprites.py output into one atlas (one sheet per paper-doll layer) plus a stacked preview.

    uv run --with pillow tools/blender/pack_layers.py <render dir>/render_index.json --out <atlas dir>

Each layer becomes a character "<name>_<layer>" in godot-kit's sprite_atlas.py manifest, aligned as "canvas" with
the ground row from the render and its scale pinned to 1: every layer keeps the render's pixel grid, so stacked
layers line up in the game exactly as they did in Blender. Also writes <atlas dir>/preview.png: per direction row,
every frame with all layers stacked in index order (body first), to eyeball alignment and the look.
"""
import argparse
import json
import sys
from pathlib import Path

from PIL import Image

KIT_TOOLS = Path(__file__).resolve().parents[3] / "godot-kit" / "tools"
# HD art on the web: lossy WebP with mipmaps (the sprite shader samples linear + mipmaps), no VRAM compression.
IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=1
compress/lossy_quality=0.9
mipmaps/generate=true
detect_3d/compress_to=0
"""
sys.path.insert(0, str(KIT_TOOLS))
import sprite_atlas  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("index", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--columns", type=int, default=10)
    args = parser.parse_args()
    index_path = args.index.resolve()
    base = index_path.parent
    index = json.loads(index_path.read_text(encoding="utf-8"))

    # One foot line for every layer (so they stay aligned): the lowest opaque row of any frame. Toes reaching toward
    # the camera sit below the ground origin on screen; the kit's shader wants nothing under the foot line.
    foot_y = index["ground_row"]
    for anim in index["anims"].values():
        for rows in anim["layers"].values():
            for row in rows:
                for rel in row:
                    box = sprite_atlas.opaque_box(Image.open(base / rel).convert("RGBA"))
                    if box:
                        foot_y = max(foot_y, box[3])
    print(f"foot line: render row {foot_y} (ground origin at {index['ground_row']})")

    # One atlas per layer: a whole character in one 4096 px atlas does not fit, and equipment swaps per layer anyway.
    for layer in index["layers"]:
        anims = {}
        for anim_name, anim in index["anims"].items():
            anims[anim_name] = {"d": anim["d"], "loop": anim["loop"], "rows": anim["layers"][layer]}
        first = next(iter(anims.values()))["rows"][0][0]
        box = sprite_atlas.opaque_box(Image.open(base / first).convert("RGBA"))
        if box is None:
            raise SystemExit(f"{layer}: reference frame {first} is empty; put an animation where it shows first")
        name = f"{index['name']}_{layer}"
        manifest = {"cell_px": index["cell_px"], "columns": args.columns, "foot_px": index["foot_px"],
                    "meters_per_px": index["meters_per_px"], "characters": {name: {
                        "height_px": box[3] - box[1],  # equals the reference height: scale 1, the render's grid
                        "directions": index["directions"], "mirror": True, "align": "canvas", "foot_y": foot_y,
                        "anims": anims}}}
        manifest_path = base / f"atlas_manifest_{layer}.json"
        manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
        data = sprite_atlas.build(manifest_path, (args.out / layer).resolve())
        import_file = args.out / layer / "atlas.png.import"
        if not import_file.exists():
            import_file.write_text(IMPORT, encoding="utf-8")
        print(f"{layer}: atlas {data['columns']}x{data['rows']} cells -> {args.out / layer / 'atlas.png'}")

    cell = index["cell_px"]
    columns = [(a, i) for a, anim in index["anims"].items() for i in range(len(anim["d"]))]
    sheet = Image.new("RGBA", (len(columns) * cell, len(index["rows"]) * cell), (64, 92, 60, 255))
    for r in range(len(index["rows"])):
        for c, (anim_name, i) in enumerate(columns):
            for layer in index["layers"]:
                frame = Image.open(base / index["anims"][anim_name]["layers"][layer][r][i]).convert("RGBA")
                sheet.alpha_composite(frame, (c * cell, r * cell))
    sheet.thumbnail((len(columns) * 160, len(index["rows"]) * 160))
    sheet.save(args.out / "preview.png")
    print(f"preview -> {args.out / 'preview.png'}")


if __name__ == "__main__":
    main()
