#!/usr/bin/env python3
"""把 art_src/sprites_raw/raw/ 的 node_*.png 與 story_*.png（Codex 原圖，約 1942×809）做成橫幅背景 public/sprites/（384×160）。

  python3 art_src/build_nodes.py

先置中裁成 384:160（2.4:1），再用 BOX 取平均縮小 4 倍附近：每個像素格變成一個像素，保持像素風。
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent
RAW = ROOT / 'sprites_raw' / 'raw'
OUT = ROOT.parent / 'public' / 'sprites'
W, H = 384, 160

for src in sorted([*RAW.glob('node_*.png'), *RAW.glob('story_*.png')]):
    im = Image.open(src).convert('RGB')
    w, h = im.size
    if w / h > W / H:  # 太寬：左右裁
        nw = round(h * W / H)
        im = im.crop(((w - nw) // 2, 0, (w - nw) // 2 + nw, h))
    else:  # 太高：上下裁（保留下面的地面）
        nh = round(w * H / W)
        im = im.crop((0, h - nh, w, h))
    out = im.resize((W, H), Image.BOX)
    out.save(OUT / src.name, optimize=True)
    print(f'{src.name}: {w}x{h} -> {W}x{H}')
