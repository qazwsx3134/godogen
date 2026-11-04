#!/usr/bin/env python3
"""把 Codex 生成的綠底素材切成 sprite，縮成遊戲像素尺寸。

用法：
  python3 art_src/slice_sprites.py kit  <輸入.png> <輸出前綴>   # 綠底上分開排的多個物件 → 每個物件一張
  python3 art_src/slice_sprites.py layer <輸入.png> <輸出.png>    # 整張圖層（綠色部分變透明）

- 去背：接近 #00FF00 的像素變透明（綠色明顯大於紅藍）。
- 縮小：預設 1/4（素材約 4×4 畫面像素＝1 個像素格），用 BOX 取平均後把透明度二值化，邊緣保持銳利。
- kit 模式會輸出 <前綴>_NN.png，以及 <前綴>_sheet.png（每塊標號的總覽）與 <前綴>.json（每塊的尺寸與在原圖的位置），之後再依總覽替每塊取名。
"""
import json
import sys
from collections import deque

from PIL import Image, ImageDraw

SCALE = 4


def key_green(im: Image.Image) -> Image.Image:
    im = im.convert('RGBA')
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if g > 140 and g > r * 1.45 and g > b * 1.45:
                px[x, y] = (0, 0, 0, 0)
    return im


def shrink(im: Image.Image, scale=SCALE) -> Image.Image:
    w, h = im.size
    small = im.resize((max(1, w // scale), max(1, h // scale)), Image.BOX)
    p = small.load()
    for y in range(small.size[1]):
        for x in range(small.size[0]):
            r, g, b, a = p[x, y]
            if a < 128:
                p[x, y] = (0, 0, 0, 0)
            else:
                # 半透明邊緣恢復成不透明，並去掉混進來的綠色
                k = 255 / a
                r, g, b = min(255, int(r * k)), min(255, int(g * k)), min(255, int(b * k))
                if g > r * 1.3 and g > b * 1.3:
                    g = max(r, b)
                p[x, y] = (r, g, b, 255)
    return small


def components(im: Image.Image, grow=2, min_px=12):
    w, h = im.size
    a = im.split()[3].load()
    solid = [[a[x, y] > 0 for x in range(w)] for y in range(h)]
    seen = [[False] * w for _ in range(h)]
    boxes = []
    for y in range(h):
        for x in range(w):
            if not solid[y][x] or seen[y][x]:
                continue
            q = deque([(x, y)])
            seen[y][x] = True
            x0 = x1 = x
            y0 = y1 = y
            n = 0
            while q:
                cx, cy = q.popleft()
                n += 1
                x0, x1, y0, y1 = min(x0, cx), max(x1, cx), min(y0, cy), max(y1, cy)
                # 允許 grow 格內的小縫（例如筷子和杯子）連成同一塊
                for dy in range(-grow, grow + 1):
                    for dx in range(-grow, grow + 1):
                        nx, ny = cx + dx, cy + dy
                        if 0 <= nx < w and 0 <= ny < h and solid[ny][nx] and not seen[ny][nx]:
                            seen[ny][nx] = True
                            q.append((nx, ny))
            if n >= min_px:
                boxes.append((x0, y0, x1 + 1, y1 + 1))
    boxes.sort(key=lambda b: (b[1] // 40, b[0]))
    return boxes


def do_kit(src: str, prefix: str):
    small = shrink(key_green(Image.open(src)))
    boxes = components(small)
    meta = []
    for i, b in enumerate(boxes):
        piece = small.crop(b)
        piece.save(f'{prefix}_{i:02d}.png')
        meta.append({'i': i, 'file': f'{prefix.split("/")[-1]}_{i:02d}.png', 'w': piece.size[0], 'h': piece.size[1], 'box': b})
    sheet = small.convert('RGBA').resize((small.size[0] * 3, small.size[1] * 3), Image.NEAREST)
    bg = Image.new('RGBA', sheet.size, (40, 30, 50, 255))
    bg.alpha_composite(sheet)
    d = ImageDraw.Draw(bg)
    for m in meta:
        x0, y0, x1, y1 = [v * 3 for v in m['box']]
        d.rectangle([x0, y0, x1, y1], outline=(0, 255, 255, 255))
        d.text((x0 + 2, y0 + 2), str(m['i']), fill=(255, 255, 0, 255))
    bg.save(f'{prefix}_sheet.png')
    json.dump(meta, open(f'{prefix}.json', 'w'), indent=1)
    print(f'{src}: {len(meta)} pieces → {prefix}_NN.png')


def do_layer(src: str, out: str):
    small = shrink(key_green(Image.open(src)))
    small.save(out)
    print(f'{src} → {out} {small.size}')


if __name__ == '__main__':
    mode, src, out = sys.argv[1:4]
    (do_kit if mode == 'kit' else do_layer)(src, out)
