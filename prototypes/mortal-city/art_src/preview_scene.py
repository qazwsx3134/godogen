#!/usr/bin/env python3
"""依 src/content/scene_layout.json 把場景組成一張預覽圖（放大 3 倍），方便調版面。
  python3 art_src/preview_scene.py room|street <輸出.png>"""
import json, sys
from pathlib import Path
from PIL import Image
R = Path(__file__).resolve().parent.parent
lay = json.load(open(R / 'src/content/scene_layout.json'))
man = json.load(open(R / 'src/content/sprites.json'))
scene, out = sys.argv[1], sys.argv[2]
bg = Image.new('RGBA', (384, 160), (2, 4, 8, 255))
for p in lay[scene]:
    im = Image.open(R / 'public' / man[p['id']]['src'].lstrip('/')).convert('RGBA')
    bg.alpha_composite(im, (p['x'], p['y'])) if p['x'] >= 0 and p['y'] >= 0 else bg.paste(im, (p['x'], p['y']), im)
bg.resize((1152, 480), Image.NEAREST).save(out)
