#!/usr/bin/env python3
"""把 art_src/sprites_raw/raw/enemies_{1,2,3}.png（Codex 原圖，4 欄×2 列綠底胸像）切成敵人頭像 public/sprites/enemy_*.png，
並寫 src/content/enemy_portraits.json（對手名稱 → 圖檔）。

  uv run --with pillow python art_src/build_enemies.py

每格：去綠 → 裁到內容 → 縮成 64 px 高（像素格約 4×4，BOX 取平均、透明度二值化）。
"""
import json
from pathlib import Path

from PIL import Image

from slice_sprites import key_green, shrink

ROOT = Path(__file__).resolve().parent
RAW = ROOT / 'sprites_raw' / 'raw'
OUT = ROOT.parent / 'public' / 'sprites'
MAP = ROOT.parent / 'src' / 'content' / 'enemy_portraits.json'
H = 64

# 依派工單 ENEMY_BRIEF.md 的順序（由左而右、由上而下）：(遊戲裡的對手名稱, 檔名)
SHEETS = {
    'enemies_1': [('街頭混混', 'punk'), ('幫派打手', 'thug'), ('幫派幹部', 'boss'), ('倉庫私兵', 'merc'),
                  ('趕來的保全', 'guard'), ('企業保全', 'corp'), ('企業保全小隊', 'squad'), ('黑冰反制小組', 'ice')],
    'enemies_2': [('巡邏保全', 'patrol'), ('武裝巡邏', 'armed'), ('研究所警衛', 'lab'), ('MPD 臨檢巡警', 'mpd'),
                  ('神坂保全', 'kamisaka'), ('診療所保全', 'clinic'), ('神坂回收小組', 'reclaim'), ('港務部私兵', 'port')],
    'enemies_3': [('堆場保全小組', 'yard'), ('港務部外骨骼', 'exo'), ('港務部增援外骨骼', 'exo2')],
}

out = json.loads(MAP.read_text()) if MAP.exists() else {}
for sheet, names in SHEETS.items():
    src = RAW / f'{sheet}.png'
    if not src.exists():
        print(f'{sheet}: 沒有原圖，跳過')
        continue
    im = key_green(Image.open(src))
    cw, ch = im.size[0] // 4, im.size[1] // 2
    for i, (name, slug) in enumerate(names):
        cell = im.crop(((i % 4) * cw, (i // 4) * ch, (i % 4 + 1) * cw, (i // 4 + 1) * ch))
        box = cell.getbbox()
        if not box:
            print(f'{sheet} 第 {i + 1} 格是空的（{name}）')
            continue
        cell = cell.crop(box)
        small = shrink(cell, cell.size[1] / H)
        small.save(OUT / f'enemy_{slug}.png')
        out[name] = f'/sprites/enemy_{slug}.png'
        print(f'{name:10s} → enemy_{slug}.png {small.size}')
MAP.write_text(json.dumps(out, ensure_ascii=False, indent=1) + '\n')
print(f'→ {MAP}')
