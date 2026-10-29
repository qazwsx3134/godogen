"""Stack the layers the way docs/bg-layer-prompts.md lays them out (941 wide, y=100..525) -> preview.png, shown 2x."""
from pathlib import Path
from PIL import Image
ROOT = Path(__file__).resolve().parent
W, H = 941, 425
def band(name, height):
    im = Image.open(ROOT / f'{name}.png').convert('RGBA'); im = im.crop(im.getbbox())
    return im.resize((round(im.width * height / im.height), height), Image.Resampling.LANCZOS)
sky = Image.open(ROOT / 'sky.png').convert('RGBA')
canvas = sky.resize((W, round(sky.height * W / sky.width)), Image.Resampling.LANCZOS).crop((0, 0, W, H))
for name, h, bottom in [('far', 95, 300), ('mid', 150, 380)]:
    b = band(name, h)
    for x in range(0, W, b.width): canvas.alpha_composite(b, (x, bottom - h))
props = [('prop_tree_b', 150, 40), ('prop_ruin', 85, 170), ('prop_tree_a', 130, 300), ('prop_rock', 34, 450),
         ('prop_lamp', 70, 540), ('prop_fence', 34, 600), ('prop_bush', 36, 700), ('prop_tree_a', 120, 800)]
for name, h, x in props:
    p = band(name, h); canvas.alpha_composite(p, (x, 375 - h))
g = band('ground', 60)
for x in range(0, W, g.width): canvas.alpha_composite(g, (x, H - 60))
canvas.save(ROOT / 'preview.png')
