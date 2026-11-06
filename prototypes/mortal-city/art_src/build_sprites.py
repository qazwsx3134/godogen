#!/usr/bin/env python3
"""把 art_src/sprites_raw/raw/ 的 Codex 原圖做成遊戲用 sprite（public/sprites/）與尺寸清單（src/content/sprites.json）。

  python3 art_src/build_sprites.py          # 全部（要有 raw/ 的全部原圖）
  python3 art_src/build_sprites.py heroes   # 只重做主角（男女的三姿勢與跑步循環）

每個物件：去綠 → 依目標寬度縮小（BOX 取平均＋透明度二值化，保持像素邊緣）。
目標尺寸以 384×160 的場景為準；要調大小就改下面的 TARGET，再跑一次。
"""
import json
from pathlib import Path

from PIL import Image

from slice_sprites import components, key_green, shrink

ROOT = Path(__file__).resolve().parent
RAW = ROOT / 'sprites_raw' / 'raw'
OUT = ROOT.parent / 'public' / 'sprites'
MANIFEST = ROOT.parent / 'src' / 'content' / 'sprites.json'

# 組圖裡每塊的名稱（依 slice_sprites 的編號順序：由上而下、由左而右）與目標寬度（場景像素）
KITS = {
    'furniture_kit': [('sofa', 250), ('bed', 96), ('laptop', 54), ('fox_monitor', 34), ('cabinet', 46), ('table', 150)],
    'props_kit': [
        ('blanket', 48), ('ramen', 24), ('can', 10), ('cat', 42), ('ashtray', 20), ('phone', 22),
        ('console', 26), ('mug', 14), ('gun', 44), ('banner', 30), ('vines', 26), ('fox_figure', 14),
    ],
    'vehicles_roof': [('drone', 30), ('train', 220)],
}

# 主角姿勢組（由左而右：躺、跑、站）：原圖 → 輸出前綴。用高度定大小，男女主角一樣高。
# 女主角 A 用補好右腳的 hero_a_poses_fix（2026-11-06）。
HEROES = {'hero_a_poses_fix': 'hero_', 'hero_b_poses': 'hero_b_'}
HERO_POSES = [('lying', 98), ('run', 71), ('stand', 75)]

SOFA_W = 250  # 沙發在場景裡的寬度（furniture_kit 的 sofa）

# 跑步循環：原圖、輸出名、格數、目標每格高度（場景像素）
RUN_CYCLES = [('hero_run_cycle', 'hero_run_strip', 8, 72), ('hero_b_run_cycle', 'hero_b_run_strip', 8, 72)]

# 整張圖層：目標高度（寬度依比例）
LAYERS = {'city_far': 160, 'city_mid': 160, 'city_front': 160, 'roof_strip': 160}


def tileable(im: Image.Image, band=48) -> Image.Image:
    """讓圖層左右可無縫接：把最右邊 band 寬的一段交叉淡化進最左邊，再切掉右邊那段。"""
    w, h = im.size
    out = im.crop((0, 0, w - band, h))
    left = im.crop((0, 0, band, h))
    right = im.crop((w - band, 0, w, h))
    mask = Image.linear_gradient('L').rotate(90, expand=True).resize((band, h))  # 左 0 → 右 255
    out.paste(Image.composite(left, right, mask), (0, 0))  # 左邊接上原本的右段，往右漸變回原本的左段
    return out


def align_frames(full: Image.Image, n: int):
    """切出 n 個姿勢，腳底對齊同一條線、身體重心水平置中，排成等寬的一條。回傳 (strip, 每格寬, 高)。"""
    boxes = sorted(components(shrink(full, 4)), key=lambda b: b[0])
    assert len(boxes) == n, f'跑步圖切出 {len(boxes)} 塊，預期 {n}'
    crops = [full.crop(tuple(v * 4 for v in b)) for b in boxes]

    def center_x(im):
        a = im.split()[3].load()
        w, h = im.size
        xs = [x for y in range(0, h, 2) for x in range(0, w, 2) if a[x, y]]
        return sum(xs) / len(xs) if xs else w / 2

    cxs = [center_x(c) for c in crops]
    left = max(cx for cx in cxs)
    right = max(c.size[0] - cx for c, cx in zip(crops, cxs))
    cw = int(left + right) + 2
    ch = max(c.size[1] for c in crops) + 2
    strip = Image.new('RGBA', (cw * n, ch), (0, 0, 0, 0))
    for i, (c, cx) in enumerate(zip(crops, cxs)):
        strip.alpha_composite(c, (int(i * cw + left - cx) + 1, ch - 1 - c.size[1]))
    return strip, cw, ch


def save(name: str, im: Image.Image, man: dict):
    OUT.mkdir(parents=True, exist_ok=True)
    im.save(OUT / f'{name}.png')
    man[name] = {'src': f'/sprites/{name}.png', 'w': im.size[0], 'h': im.size[1]}
    print(f'{name:12s} {im.size}')


def heroes(man: dict):
    """主角的三個姿勢與跑步循環（原圖不在的就跳過，保留 manifest 裡原本的）。"""
    for src, prefix in HEROES.items():
        if not (RAW / f'{src}.png').exists():
            continue
        full = key_green(Image.open(RAW / f'{src}.png'))
        boxes = sorted(components(shrink(full, 4)), key=lambda b: b[0])  # 由左而右
        assert len(boxes) == len(HERO_POSES), f'{src}: 切出 {len(boxes)} 塊，預期 {len(HERO_POSES)}'
        for (pose, th), b in zip(HERO_POSES, boxes):
            crop = full.crop(tuple(v * 4 for v in b))
            save(f'{prefix}{pose}', shrink(crop, crop.size[1] / th), man)
    # 休息姿勢：沙發＋人一起畫的整張（2026-11-06），縮到跟沙發一樣寬；遊戲休息時用它取代沙發與躺姿
    for look in ('a', 'b'):
        src = RAW / f'sofa_rest_{look}.png'
        if src.exists():
            im = key_green(Image.open(src))
            im = im.crop(im.getbbox())
            save(f'sofa_rest_{look}', shrink(im, im.size[0] / SOFA_W), man)
    for src, name, n, th in RUN_CYCLES:
        if not (RAW / f'{src}.png').exists():
            continue
        strip, cw, ch = align_frames(key_green(Image.open(RAW / f'{src}.png')), n)
        k = ch / th
        small = shrink(strip, k).resize((round(cw / k) * n, th), Image.NEAREST)
        save(name, small, man)
        man[name].update({'frames': n, 'w': small.size[0] // n})


def main():
    man: dict = {}
    # 公寓背景＝整個場景；窗洞（原本的綠色）變透明
    room = shrink(key_green(Image.open(RAW / 'room_bg.png')), 1)
    room = shrink(room, room.size[0] / 384)
    room = room.resize((384, 160), Image.NEAREST)
    save('room_bg', room, man)
    # 找窗洞位置，讓窗外夜景剛好鋪滿（cover），放在背景後面
    a = room.split()[3]
    hole = Image.eval(a, lambda v: 255 if v == 0 else 0).getbbox()
    x0, y0, x1, y1 = hole
    city = Image.open(RAW / 'window_city.png').convert('RGBA')
    k = max((x1 - x0) / city.size[0], (y1 - y0) / city.size[1])
    city = shrink(city, 1 / k)
    cx, cy = (city.size[0] - (x1 - x0)) // 2, (city.size[1] - (y1 - y0)) // 2
    save('window_city', city.crop((cx, cy, cx + x1 - x0, cy + y1 - y0)), man)
    man['window_city'].update({'x': x0, 'y': y0})

    for kit, names in KITS.items():
        full = key_green(Image.open(RAW / f'{kit}.png'))
        boxes = components(shrink(full, 4))
        assert len(boxes) == len(names), f'{kit}: {len(boxes)} 塊，但 KITS 列了 {len(names)} 個名稱'
        for (name, tw), b in zip(names, boxes):
            crop = full.crop(tuple(v * 4 for v in b))
            save(name, shrink(crop, crop.size[0] / tw), man)

    heroes(man)

    for layer, th in LAYERS.items():
        im = key_green(Image.open(RAW / f'{layer}.png'))
        save(layer, tileable(shrink(im, im.size[1] / th)), man)

    MANIFEST.write_text(json.dumps(man, indent=1, ensure_ascii=False))
    print(f'→ {MANIFEST}')


if __name__ == '__main__':
    import sys

    if sys.argv[1:] == ['heroes']:
        # 只重做主角：其他素材的原圖不在也能跑，結果併進現有的 sprites.json
        man = json.loads(MANIFEST.read_text())
        heroes(man)
        MANIFEST.write_text(json.dumps(man, indent=1, ensure_ascii=False))
        print(f'→ {MANIFEST}')
    else:
        main()
