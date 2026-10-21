from pathlib import Path
import json, sys
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent
FORGE = Path('/Users/peter/repo/agent-sprite-forge/skills/generate2dsprite/scripts')
sys.path.insert(0, str(FORGE))
from master_still import key_subject, contact_sheet

reference = ROOT.parent/'hd1/boss/candidate-01.png'
base = Image.open(reference).convert('RGBA')
baseline = base.getchannel('A').point(lambda a: 255 if a > 16 else 0).getbbox()[3]
rows = [(reference, 'idle (hd1 candidate 01)')]
qc = []
for name in ['windup', 'slam', 'stunned']:
    runs = sorted((ROOT/'inputs').glob(name+'-*/run.json'))
    good = [(p.parent, json.loads(p.read_text())) for p in runs if json.loads(p.read_text())['status']=='ok']
    if not good: continue
    folder, run = good[0]
    raw = Image.open(folder/run['takes'][0]['artifact']['path']).convert('RGBA')
    keyed, matte = key_subject(np.asarray(raw), '#FF00FF', 'soft')
    image = Image.fromarray(keyed)
    # Preserve canvas-relative anatomical scale; never fit each pose's silhouette.
    image = image.convert('RGBa').resize(base.size, Image.Resampling.LANCZOS).convert('RGBA')
    bbox = image.getchannel('A').point(lambda a: 255 if a > 16 else 0).getbbox()
    # Impact chips can extend below the soles; measure the near foot separately.
    foot_window = {'slam': (820, 690, 1000, 1024)}.get(name)
    if foot_window:
        foot_bbox = image.getchannel('A').crop(foot_window).point(lambda a: 255 if a > 16 else 0).getbbox()
        foot_bottom = foot_window[1]+foot_bbox[3]
    else:
        foot_bottom = bbox[3]
    dy = baseline-foot_bottom
    assert bbox[1]+dy > 0 and bbox[3]+dy < base.height
    shifted = Image.new('RGBA', base.size)
    shifted.paste(image, (0, dy))
    alpha = np.array(shifted.getchannel('A'))
    alpha[alpha <= 4] = 0
    shifted.putalpha(Image.fromarray(alpha))
    final_bbox = shifted.getbbox()
    assert final_bbox[0] > 0 and final_bbox[1] > 0 and final_bbox[2] < base.width and final_bbox[3] < base.height
    out = ROOT/name/'candidate-01.png'
    out.parent.mkdir(exist_ok=True)
    shifted.save(out)
    rows.append((out, name))
    qc.append({'pose':name, 'raw_size':raw.size, 'canvas_size':shifted.size, 'uniform_canvas_scale':base.width/raw.width,
               'vertical_translation_px':dy, 'baseline_alpha_gt16':baseline, 'foot_window':foot_window, 'bbox':final_bbox, 'matte':matte,
               'run':str(folder.relative_to(ROOT))})
contact_sheet(rows).save(ROOT/'poses-contact.png')
(ROOT/'inputs/delivery-qc.json').write_text(json.dumps(qc, indent=2)+'\n')
print(json.dumps({'poses':len(qc), 'baseline':baseline, 'translations':{v['pose']:v['vertical_translation_px'] for v in qc}}))
