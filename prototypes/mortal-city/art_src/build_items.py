#!/usr/bin/env python3
"""把 art_src/sprites_raw/raw/items_{berserker,gunslinger,netrunner,nomad}.png（Codex 原圖，4 欄×2 列綠底）切成道具圖示
public/sprites/item_<kind>.png，並寫 src/content/item_icons.json（道具種類 → 圖檔）。

  uv run --with pillow python art_src/build_items.py

每格：去綠（INNER_GREEN 的道具改成只去掉跟格子邊緣相連的綠，保留被包住的綠色藥液）→ 裁到內容 → 長邊縮成 48 px（BOX 取平均、透明度二值化）。順序照 ITEM_BRIEF.md。
"""
import json
from pathlib import Path

from PIL import Image

from collections import deque

from slice_sprites import key_green, shrink

ROOT = Path(__file__).resolve().parent
RAW = ROOT / 'sprites_raw' / 'raw'
OUT = ROOT.parent / 'public' / 'sprites'
MAP = ROOT.parent / 'src' / 'content' / 'item_icons.json'
SIZE = 48
# 道具本身有綠色、不能整片去綠的（環形、握把孔這類被包住的空隙仍要用一般去綠）
INNER_GREEN = {'roadMed'}

SHEETS = {
    'items_berserker': ['tendon', 'knife', 'ironFists', 'subdermal', 'shotgun', 'monoblade', 'adrenal', 'boneLace'],
    'items_gunslinger': ['gun', 'smartgun', 'pairedPistols', 'trigger', 'twinSmart', 'gyroArm', 'reflexes'],
    'items_netrunner': ['deck', 'coproc', 'milDeck', 'shockNode', 'icepick', 'quickDeck', 'neuralBuffer'],
    'items_nomad': ['camo', 'silencer', 'dampener', 'ghostWeave', 'scavEye', 'roadMed', 'dustCloak', 'nomadRifle'],
}

def green(p):
    r, g, b, _ = p
    return g > 140 and g > r * 1.45 and g > b * 1.45


def key_outside(cell: Image.Image) -> Image.Image:
    """只去掉跟格子邊緣連在一起的綠色。"""
    px = cell.load()
    w, h = cell.size
    seen = bytearray(w * h)
    q: deque = deque()
    for x in range(w):
        q.extend(((x, 0), (x, h - 1)))
    for y in range(h):
        q.extend(((0, y), (w - 1, y)))
    while q:
        x, y = q.popleft()
        k = y * w + x
        if seen[k] or not green(px[x, y]):
            continue
        seen[k] = 1
        px[x, y] = (0, 0, 0, 0)
        if x > 0: q.append((x - 1, y))
        if x < w - 1: q.append((x + 1, y))
        if y > 0: q.append((x, y - 1))
        if y < h - 1: q.append((x, y + 1))
    return cell


out = json.loads(MAP.read_text()) if MAP.exists() else {}
for sheet, kinds in SHEETS.items():
    src = RAW / f'{sheet}.png'
    if not src.exists():
        print(f'{sheet}: 沒有原圖，跳過')
        continue
    im = Image.open(src).convert('RGBA')
    cw, ch = im.size[0] // 4, im.size[1] // 2
    for i, kind in enumerate(kinds):
        cell = im.crop(((i % 4) * cw, (i // 4) * ch, (i % 4 + 1) * cw, (i // 4 + 1) * ch))
        cell = key_outside(cell) if kind in INNER_GREEN else key_green(cell)
        box = cell.getbbox()
        if not box:
            print(f'{sheet} 第 {i + 1} 格是空的（{kind}）')
            continue
        cell = cell.crop(box)
        if kind in INNER_GREEN:
            # 一般的縮圖會把偏綠的像素去色；這種道具的綠是本色，只縮圖、二值化透明度
            sc = max(cell.size) / SIZE
            small = cell.resize((max(1, round(cell.size[0] / sc)), max(1, round(cell.size[1] / sc))), Image.BOX)
            small.putalpha(small.getchannel('A').point(lambda v: 255 if v >= 128 else 0))
        else:
            small = shrink(cell, max(cell.size) / SIZE)
        small.save(OUT / f'item_{kind}.png')
        out[kind] = f'/sprites/item_{kind}.png'
        print(f'{kind:13s} → item_{kind}.png {small.size}')
MAP.write_text(json.dumps(out, ensure_ascii=False, indent=1) + '\n')
print(f'→ {MAP}')
