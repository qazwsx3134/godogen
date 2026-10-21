from pathlib import Path
import json, sys
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, '/Users/peter/repo/agent-sprite-forge/skills/generate2dsprite/scripts')
from master_still import key_subject, contact_sheet

qc, lineup = [], []
for name in ['shield','sword','spear','bow','mage','healer']:
    run_path = ROOT/'inputs'/f'{name}-generate-1/run.json'
    if not run_path.exists(): continue
    run = json.loads(run_path.read_text())
    candidates = []
    for take in run['takes']:
        source_run, record = run_path, take
        if take['status'] != 'ok':
            retry = ROOT/'inputs'/f'{name}-retry-take{take["take"]}-1/run.json'
            if not retry.exists(): continue
            doc = json.loads(retry.read_text())
            if doc['status'] != 'ok': continue
            source_run, record = retry, doc['takes'][0]
        source = source_run.parent/record['artifact']['path']
        raw = Image.open(source).convert('RGBA')
        keyed, matte = key_subject(np.asarray(raw), run['key'], 'soft')
        image = Image.fromarray(keyed).convert('RGBa').resize((1024,1024), Image.Resampling.LANCZOS).convert('RGBA')
        bbox = image.getchannel('A').point(lambda a: 255 if a > 16 else 0).getbbox()
        dy = 926-bbox[3]
        assert bbox[1]+dy>0 and bbox[3]+dy<1024
        shifted = Image.new('RGBA',(1024,1024))
        shifted.paste(image,(0,dy))
        alpha = np.array(shifted.getchannel('A'))
        alpha[alpha<=4] = 0
        shifted.putalpha(Image.fromarray(alpha))
        # Crown annotations exclude weapons, quivers and raised staff crystals.
        crowns_path = ROOT/'inputs/body-crowns.json'
        crowns = json.loads(crowns_path.read_text()) if crowns_path.exists() else {}
        crown = crowns.get(name, {}).get(str(take['take']))
        body_scale = 1.0
        if crown is not None:
            body_scale = 720/(926-crown)
            new_size = round(1024*body_scale)
            scaled = shifted.convert('RGBa').resize((new_size,new_size), Image.Resampling.LANCZOS).convert('RGBA')
            dx2, dy2 = round((1024-new_size)/2), round(926-926*new_size/1024)
            scaled_bbox = scaled.getchannel('A').point(lambda a:255 if a>16 else 0).getbbox()
            assert scaled_bbox[0]+dx2>0 and scaled_bbox[1]+dy2>0 and scaled_bbox[2]+dx2<1024 and scaled_bbox[3]+dy2<1024, name
            shifted = Image.new('RGBA',(1024,1024))
            shifted.paste(scaled,(dx2,dy2))
            b = shifted.getchannel('A').point(lambda a:255 if a>16 else 0).getbbox()
            correction = 926-b[3]
            if correction:
                corrected = Image.new('RGBA',(1024,1024))
                corrected.paste(shifted,(0,correction))
                shifted = corrected
        bbox = shifted.getbbox()
        assert bbox[0]>0 and bbox[1]>0 and bbox[2]<1024 and bbox[3]<1024
        out = ROOT/name/f'candidate-{take["take"]:02d}.png'
        out.parent.mkdir(exist_ok=True)
        shifted.save(out)
        candidates.append((out,f'{name} {take["take"]:02d}'))
        if take['take']==1: lineup.append((out,name))
        qc.append({'class':name, 'take':take['take'], 'path':str(out.relative_to(ROOT)), 'raw_size':raw.size,
                   'canvas_scale':1024/raw.width, 'vertical_translation_px':dy, 'body_scale':body_scale, 'source_crown_y':crown, 'target_body_height':720, 'bbox':bbox,
                   'baseline_alpha_gt16':926, 'matte':matte, 'run':str(source_run.relative_to(ROOT))})
    if candidates: contact_sheet(candidates).save(ROOT/name/'candidates-contact.png')
if lineup:
    sheet = Image.new('RGB',(320*len(lineup),340),(32,32,32))
    for i, item in enumerate(lineup): sheet.paste(contact_sheet([item]),(320*i,0))
    sheet.save(ROOT/'lineup.png')
(ROOT/'inputs/delivery-qc.json').write_text(json.dumps(qc,indent=2)+'\n')
print(json.dumps({'candidates':len(qc),'lineup_classes':len(lineup),'baselines':926}))
