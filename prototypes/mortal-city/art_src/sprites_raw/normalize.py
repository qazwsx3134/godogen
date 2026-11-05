#!/usr/bin/env python3
# 用法：python3 art_src/sprites_raw/normalize.py（只讀 raw/，寫本資料夾的 10 張成品）
"""raw/ 原圖 → sprites_raw/ 規格化成品：精確尺寸、4×4 像素格、精確 #00FF00 綠幕。"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

DIR = Path('/Users/peter/repo/godot/godogen/prototypes/mortal-city/art_src/sprites_raw')
RAW = DIR / 'raw'
SCR = None
GREEN = np.array([0, 255, 0], np.uint8)
S = 1086 / 256  # 城市四層共用：raw 像素 / 一個像素格（1086 週期 → 256 格 → 1024 輸出）


def load(name):
    return np.asarray(Image.open(RAW / f'{name}.png').convert('RGB')).astype(np.float32)


def bg_mask(a):
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    return (g > 140) & (g > r * 1.45) & (g > b * 1.45)


def despill(a, bg):
    """只處理接近純綠的混色邊緣（r、b 都低），藤蔓的橄欖綠不動。"""
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mx = np.maximum(r, b)
    spill = (~bg) & (r < 110) & (b < 110) & (g > mx * 1.6) & (g > mx + 40)
    a = a.copy()
    a[..., 1] = np.where(spill, mx, g)
    return a


def reduce(a, box, cols, rows, keyed):
    """raw 區域 box=(x0,y0,x1,y1) → cols×rows 像素格；keyed 時覆蓋率 <0.5 的格子為精確綠。"""
    if keyed:
        bg = bg_mask(a)
        a = despill(a, bg)
        fg = (~bg).astype(np.float32)
    else:
        fg = np.ones(a.shape[:2], np.float32)

    def box_resize(ch):
        return np.asarray(Image.fromarray(ch, 'F').resize((cols, rows), Image.BOX, box=box))

    cov = box_resize(fg)
    out = np.stack([box_resize(a[..., i] * fg) for i in range(3)], -1) / np.maximum(cov, 1e-6)[..., None]
    out = np.clip(np.rint(out), 0, 255).astype(np.uint8)
    if keyed:
        out[cov < 0.5] = GREEN
    return out


def up4(small):
    return np.repeat(np.repeat(small, 4, 0), 4, 1)


def best_window(a, width, lo, hi, row_w=None):
    """在 [lo,hi] 找起點 x，使 x 與 x+width 兩欄（各取 3 欄平均）差最小，接縫直接切開。"""
    w = np.ones(a.shape[0], np.float32) if row_w is None else row_w
    best = None
    for x in range(lo, hi + 1):
        d = (np.abs(a[:, x:x + 3] - a[:, x + width:x + width + 3]).mean((1, 2)) * w).sum() / w.sum()
        if best is None or d < best[0]:
            best = (d, x)
    return best


def quilt(src, cols, O):
    """src 寬 cols+O：把超出右端的 O 欄與開頭 O 欄沿最小差異路徑切接，回傳可首尾相接的 cols 寬 tile。"""
    A = src[:, cols:cols + O].astype(np.float32)
    B = src[:, :O].astype(np.float32)
    e = np.abs(A - B).sum(-1)
    rows = e.shape[0]
    cost = e.copy()
    for y in range(1, rows):
        prev = cost[y - 1]
        m = np.minimum(prev, np.minimum(np.r_[np.inf, prev[:-1]], np.r_[prev[1:], np.inf]))
        cost[y] += m
    path = np.zeros(rows, int)
    path[-1] = int(np.argmin(cost[-1]))
    for y in range(rows - 2, -1, -1):
        p = path[y + 1]
        lo, hi = max(0, p - 1), min(O, p + 2)
        path[y] = lo + int(np.argmin(cost[y, lo:hi]))
    tile = src[:, :cols].copy()
    for y in range(rows):
        tile[y, :path[y]] = A[y, :path[y]].astype(np.uint8)
    return tile, float(e[np.arange(rows), path].mean() / 3)


def save(name, small):
    big = up4(small)
    Image.fromarray(big, 'RGB').save(DIR / f'{name}.png')
    return big


info = {}

# 等比例的整張圖 / kit
for name, cols, rows, keyed in [
    ('room_bg', 384, 160, True),
    ('window_city', 240, 88, False),
    ('furniture_kit', 384, 256, True),
    ('props_kit', 384, 256, True),
    ('hero_a_poses', 384, 192, True),
    ('vehicles_roof', 384, 192, True),
]:
    a = load(name)
    h, w = a.shape[:2]
    save(name, reduce(a, (0, 0, w, h), cols, rows, keyed))
    info[name] = {'box': [0, 0, w, h]}

# city_front：週期 1086，取綠色空隙起點的一段，平鋪 3 段；底部對齊保留原構圖
a = load('city_front')
fgcol = (~bg_mask(a)).sum(0)
gaps = [x for x in range(0, 2172 - 1086) if fgcol[x] == 0 and fgcol[x + 1086] == 0]
x0 = gaps[len(gaps) // 2] if gaps else 0
h = 160 * S
box = (x0, 724 - h, x0 + 1086, 724)
tile = reduce(a, box, 256, 160, True)
save('city_front', np.concatenate([tile] * 3, 1))
info['city_front'] = {'box': [round(v, 1) for v in box], 'tiles': 3, 'gap_cols': len(gaps)}

# roof_strip：週期 1086，平鋪 3 段；內容 553..723 放進 40 格高
a = load('roof_strip')
d, x0 = best_window(a[553:], 1086, 0, 2172 - 1086 - 3)
box = (x0, 724 - 40 * S, x0 + 1086, 724)
tile = reduce(a, box, 256, 40, True)
save('roof_strip', np.concatenate([tile] * 3, 1))
info['roof_strip'] = {'box': [round(v, 1) for v in box], 'tiles': 3, 'seam': round(float(d), 2)}

# city_far：無週期；寬 1629（=384 格）一段平鋪 2 段；保留鐵塔 1455-1585、全息女性 580-722、無人機 1118-1300；裁掉底部倒影
a = load('city_far')
W = int(round(384 * S))
O = 24
cands = range(0, min(580, 2172 - int((384 + O) * S) - 3) + 1, 2)
x0 = min(cands, key=lambda x: quilt(reduce(a, (x, 0, x + (384 + O) * S, 160 * S), 384 + O, 160, False), 384, O)[1])
box = (x0, 0, x0 + (384 + O) * S, 160 * S)
tile, qd = quilt(reduce(a, box, 384 + O, 160, False), 384, O)
save('city_far', np.concatenate([tile] * 2, 1))
info['city_far'] = {'box': [round(v, 1) for v in box], 'tiles': 2, 'seam_cut': round(qd, 2)}

# city_mid：無週期；需含紅燈 662 起、警衛 875-1130、神坂招牌到 1678；高 120 格＝509 raw 列，從 190 列起（只切天線尖）
a = load('city_mid')
y0 = 190
rows_raw = 120 * S
rw = np.linspace(1, 3, a.shape[0]).astype(np.float32)  # 街道列加權
O = 24
cands = range(1678 - W, min(662, 2172 - int((384 + O) * S) - 3) + 1, 2)
x0 = min(cands, key=lambda x: quilt(reduce(a, (x, y0, x + (384 + O) * S, y0 + rows_raw), 384 + O, 120, True), 384, O)[1])
box = (x0, y0, x0 + (384 + O) * S, y0 + rows_raw)
tile, qd = quilt(reduce(a, box, 384 + O, 120, True), 384, O)
save('city_mid', np.concatenate([tile] * 2, 1))
info['city_mid'] = {'box': [round(v, 1) for v in box], 'tiles': 2, 'seam_cut': round(qd, 2)}

print(json.dumps(info, indent=1))
