#!/usr/bin/env python3
"""Pack approved character art into one-row atlases for resources/sheets/*.tres.

    ~/repo/agent-sprite-forge/.venv/bin/python tools/pack_sprites.py [--only captain,guardian] [--check]

Inputs (art_src/chars/<art>/): master/master_rgba.png (idle) and poses/<pose>/takes/take-NN/generated.png
(magenta key, keyed here). art_src/chars/selection.json picks the take per pose and optional per-frame
scale/offset fixes: {"captain": {"walk_a": {"take": 2, "scale": 1.0, "dx": 0}}}.

Every frame of a character uses one scale, set so the idle pose stands height_m tall at METERS_PER_PX
(the value in tools/build_slice.gd): a lying or leaping pose keeps its true size. Feet sit FOOT_PX above
the cell bottom. A frame that does not fit its cell is shrunk to fit and reported, never silently.
Writes assets/sprites/<art>.png, a minimal .import (lossy WebP + mipmaps, no VRAM compression: HD art on
the web) and art_src/chars/<art>/atlas-preview.png.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image

FORGE = Path.home() / "repo/agent-sprite-forge/shared"
sys.path.insert(0, str(FORGE))
import forge_matte  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
CHARS = ROOT / "art_src/chars"
OUT = ROOT / "assets/sprites"
CELL_PX = 512
FOOT_PX = 8
METERS_PER_PX = 0.0042
PARTY = ["idle", "walk_a", "walk_b", "attack", "down", "skill"]
MOB = ["idle", "walk_a", "walk_b", "attack", "down"]
ARTS = {
    "captain": {"height_m": 1.78, "frames": PARTY},
    "guardian": {"height_m": 1.84, "frames": PARTY},
    "medic": {"height_m": 1.74, "frames": PARTY},
    "meadow_slime": {"height_m": 0.78, "frames": MOB},
    "briar_boar": {"height_m": 1.12, "frames": MOB},
    "ruin_hound": {"height_m": 1.08, "frames": MOB},
}
IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=1
compress/lossy_quality=0.9
mipmaps/generate=true
detect_3d/compress_to=0
"""


def bbox_crop(img: Image.Image) -> Image.Image:
    box = img.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
    if box is None:
        raise ValueError("empty frame")
    return img.crop(box)


def keyed(path: Path) -> Image.Image:
    image, info = forge_matte.key_still(Image.open(path).convert("RGBA"), key="magenta")
    return image


def pack(art: str, spec: dict, selection: dict, problems: list[str]) -> None:
    base = CHARS / art
    master = Image.open(base / "master/master_rgba.png").convert("RGBA")
    idle = bbox_crop(master)
    target_px = spec["height_m"] / METERS_PER_PX
    scale_master = target_px / idle.height
    atlas = Image.new("RGBA", (CELL_PX * len(spec["frames"]), CELL_PX), (0, 0, 0, 0))
    for col, pose in enumerate(spec["frames"]):
        fix = selection.get(art, {}).get(pose, {})
        if pose == "idle":
            frame, scale = idle, scale_master
        else:
            take = int(fix.get("take", 1))
            src = base / f"poses/{pose}/takes/take-{take:02d}/generated.png"
            if not src.exists():
                problems.append(f"{art}/{pose}: missing {src.relative_to(ROOT)}")
                continue
            raw = keyed(src)
            # Edits reproduce the master's framing (subject/canvas) on their own canvas size.
            scale = scale_master * master.width / raw.width
            frame = bbox_crop(raw)
        scale *= float(fix.get("scale", 1.0))
        w, h = max(1, round(frame.width * scale)), max(1, round(frame.height * scale))
        room_w, room_h = CELL_PX - 4, CELL_PX - FOOT_PX - 2
        if w > room_w or h > room_h:
            shrink = min(room_w / w, room_h / h)
            problems.append(f"{art}/{pose}: {w}x{h} px does not fit the cell, shrunk x{shrink:.2f}")
            w, h = max(1, int(w * shrink)), max(1, int(h * shrink))
        frame = frame.resize((w, h), Image.LANCZOS)
        x = col * CELL_PX + (CELL_PX - w) // 2 + int(fix.get("dx", 0))
        y = CELL_PX - FOOT_PX - h
        atlas.alpha_composite(frame, (max(col * CELL_PX, x), y))
    OUT.mkdir(parents=True, exist_ok=True)
    atlas.save(OUT / f"{art}.png", optimize=True)
    imp = OUT / f"{art}.png.import"
    if not imp.exists():
        imp.write_text(IMPORT)
    preview = Image.new("RGBA", atlas.size, (70, 104, 66, 255))
    preview.alpha_composite(atlas)
    preview.convert("RGB").resize((atlas.width // 2, atlas.height // 2), Image.LANCZOS).save(base / "atlas-preview.png")
    print(f"packed {art}: {len(spec['frames'])} cells, idle {target_px:.0f} px tall")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", default="")
    args = parser.parse_args()
    selection_path = CHARS / "selection.json"
    selection = json.loads(selection_path.read_text()) if selection_path.exists() else {}
    names = [n for n in args.only.split(",") if n] or list(ARTS)
    problems: list[str] = []
    for art in names:
        pack(art, ARTS[art], selection, problems)
    for p in problems:
        print("WARN", p)
    return 0


if __name__ == "__main__":
    sys.exit(main())
