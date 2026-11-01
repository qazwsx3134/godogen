"""Game-size check: each class row = human, elf, beast ready stance, packed like pack_stage_art.heroes() (ready height
40 px, 32 colours) and multiplied by the class tint from army.gd tint() (no per-hero jitter), shown 4x."""
from pathlib import Path
import colorsys, json, sys
import numpy as np
from PIL import Image
ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT.parents[1] / 'tools'))
from pack_stage_art import pixelate, HERO_BODY  # noqa: E402
CLASSES = ['shield', 'sword', 'spear', 'bow', 'mage', 'healer']
HUES = [0.6, 0.01, 0.09, 0.3, 0.76, 0.12]
SATS = [0.32, 0.3, 0.3, 0.3, 0.32, 0.08]
def sprite(path, c):
    im = Image.open(path).convert('RGBA'); im = im.crop(im.getchannel('A').point(lambda a: 255 if a > 24 else 0).getbbox())
    px = np.array(pixelate(im, HERO_BODY, 32)).astype(float)
    px[..., :3] *= colorsys.hsv_to_rgb(HUES[c], SATS[c], 1.0)
    return Image.fromarray(px.astype(np.uint8), 'RGBA')
sel = json.loads((ROOT / 'selected.json').read_text())
sheet = Image.new('RGBA', (3 * 60, 50 * len(CLASSES)), (88, 110, 70, 255))
for y, cls in enumerate(CLASSES):
    cells = [ROOT.parent / 'hd2' / cls / 'candidate-01.png'] + [
        ROOT / f'{r}_{cls}' / 'ready' / f'candidate-{sel[f"{r}_{cls}"]:02d}.png' for r in ['elf', 'beast']]
    for x, p in enumerate(cells):
        im = sprite(p, y); sheet.alpha_composite(im, (x * 60 + (60 - im.width) // 2, y * 50 + 5))
sheet.resize((sheet.width * 4, sheet.height * 4), Image.Resampling.NEAREST).save(ROOT / 'lineup-40px.png')
