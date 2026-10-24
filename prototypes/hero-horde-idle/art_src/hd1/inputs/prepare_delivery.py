from pathlib import Path
import json, subprocess, sys, shutil
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
FORGE = Path('/Users/peter/repo/agent-sprite-forge/skills/generate2dsprite/scripts')
sys.path.insert(0, str(FORGE))
from master_still import contact_sheet

results = []
for name, count in [('boss', 3)]+[('props/'+n, 1) for n in ['pine','oak','boulder','pillar','gate','brazier','banner','fern']]:
    delivered = []
    for n in range(1, count+1):
        slug = name.replace('/', '-')+f'-{n:02d}'
        runs = sorted((ROOT/'inputs').glob(slug+'-attempt*/run.json'))
        good = [p.parent for p in runs if json.loads(p.read_text())['status'] == 'ok']
        if not good: continue
        out = ROOT/'inputs'/(slug+'-pad')
        if not out.exists():
            subprocess.run([sys.executable, str(FORGE/'master_still.py'), 'pad', '--run', str(good[0]),
                            '--take', '1', '--output-dir', str(out)], check=True)
        target = ROOT/name/f'candidate-{n:02d}.png'
        target.parent.mkdir(parents=True, exist_ok=True)
        if not target.exists(): shutil.copyfile(out/'padded_rgba.png', target)
        image = Image.open(target).convert('RGBA')
        bbox = image.getbbox()
        assert bbox and bbox[0] > 0 and bbox[1] > 0 and bbox[2] < image.width and bbox[3] < image.height
        assert image.getextrema()[3][0] == 0
        delivered.append((target, f'candidate {n:02d}'))
        results.append({'path': str(target.relative_to(ROOT)), 'size': image.size, 'bbox': bbox,
                        'pad_warnings': json.loads((out/'pad.json').read_text()).get('warnings', [])})
    if delivered:
        contact_sheet(delivered).save(ROOT/name/'candidates-contact.png')
(ROOT/'inputs/delivery-qc.json').write_text(json.dumps(results, indent=2)+'\n')
print(json.dumps({'delivered': len(results), 'qc': 'inputs/delivery-qc.json'}))
