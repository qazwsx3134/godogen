from pathlib import Path
import argparse, json, sys
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parent
sys.path.insert(0,'/Users/peter/repo/agent-sprite-forge/skills/generate2dsprite/scripts')
from master_still import key_subject, contact_sheet, forge_core

def geometry(image):
    return image.getchannel('A').point(lambda a:255 if a>16 else 0).getbbox()

def prepare(cls):
    reference=ROOT.parent/'hd2'/cls/'candidate-01.png'
    base=Image.open(reference).convert('RGBA')
    baseline=geometry(base)[3]
    override_path=ROOT/'inputs/anchor-overrides.json'
    overrides=json.loads(override_path.read_text()) if override_path.exists() else {}
    rows=[(reference,'idle (hd2 candidate 01)')]
    qc=[]
    for action in ['run_a','run_b','strike','down','volley']:
        runs=sorted((ROOT/'inputs').glob(f'{cls}-{action}-*/run.json'))
        good=[(p,json.loads(p.read_text())) for p in runs if json.loads(p.read_text())['status']=='ok']
        if not good: continue
        path,run=good[0]
        record=next(t for t in run['takes'] if t['status']=='ok')
        raw_path=path.parent/record['artifact']['path']
        cache=ROOT/'inputs'/f'{cls}-{action}-clean.png'
        metadata=cache.with_suffix('.json')
        if not cache.exists():
            raw=Image.open(raw_path).convert('RGBA')
            keyed,matte=key_subject(np.asarray(raw),run['key'],'soft')
            image=Image.fromarray(keyed).convert('RGBa').resize(base.size,Image.Resampling.LANCZOS).convert('RGBA')
            image.save(cache)
            metadata.write_text(json.dumps({'matte':matte,'raw_size':raw.size,'source':str(raw_path.relative_to(ROOT))},indent=2)+'\n')
        image=Image.open(cache).convert('RGBA')
        clean_alpha=np.array(image.getchannel('A'));clean_alpha[clean_alpha<=4]=0
        image.putalpha(Image.fromarray(clean_alpha))
        info=json.loads(metadata.read_text())
        bbox=geometry(image)
        components=forge_core.connected_components(np.asarray(image.getchannel('A')),threshold=16)
        if action=='down':
            # Dropped weapons may extend below the fallen body; use the largest component.
            body=max(components,key=lambda p:p['area'])
            anchor=body['bbox'][3]
            method='largest body component'
        else:
            anchor=bbox[3]
            method='lowest visible subject point'
        override=overrides.get(cls,{}).get(action)
        if override is not None:
            anchor=override
            method='visually annotated foot/body baseline'
        # A few overhead weapons need a small uniform reduction to keep both safe
        # margins and the original baseline. Never stretch the character or crop.
        bounds=image.getbbox()
        fit_scale=min(1.0,(baseline-12)/max(1,anchor-bounds[1]),
                      (base.height-baseline-12)/max(1,bounds[3]-anchor),
                      (base.width-24)/max(1,bounds[2]-bounds[0]))
        if fit_scale<1:
            new_size=round(base.width*fit_scale)
            small=image.convert('RGBa').resize((new_size,new_size),Image.Resampling.LANCZOS).convert('RGBA')
            image=Image.new('RGBA',base.size)
            image.paste(small,((base.width-new_size)//2,0))
            anchor=round(anchor*new_size/base.width)
            bbox=geometry(image)
        desired=baseline-anchor
        dy=desired
        shifted=Image.new('RGBA',base.size)
        shifted.paste(image,(0,dy))
        alpha=np.array(shifted.getchannel('A'));alpha[alpha<=4]=0
        shifted.putalpha(Image.fromarray(alpha))
        final_bbox=shifted.getbbox()
        out=ROOT/cls/action/'candidate-01.png'
        out.parent.mkdir(parents=True,exist_ok=True)
        shifted.save(out)
        rows.append((out,action))
        warnings=[]
        if desired!=dy: warnings.append(f'baseline limited by canvas: {anchor+dy} instead of {baseline}')
        if final_bbox[0]<=0 or final_bbox[1]<=0 or final_bbox[2]>=base.width or final_bbox[3]>=base.height:
            warnings.append('source or faint alpha touches canvas edge')
        qc.append({'class':cls,'action':action,'run':str(path.relative_to(ROOT)),'command':run['command'],
                   'canvas_size':base.size,'raw_size':info['raw_size'],'canvas_scale':base.width/info['raw_size'][0],
                   'vertical_translation_px':dy,'source_anchor':anchor,'anchor_method':method,'baseline':anchor+dy,'containment_scale':fit_scale,
                   'target_baseline':baseline,'bbox':final_bbox,'matte':info['matte'],'warnings':warnings})
    sheet=Image.new('RGB',(320*len(rows),340),(32,32,32))
    for i,item in enumerate(rows):sheet.paste(contact_sheet([item]),(320*i,0))
    (ROOT/cls).mkdir(exist_ok=True)
    sheet.save(ROOT/cls/'poses-contact.png')
    (ROOT/'inputs'/f'{cls}-delivery-qc.json').write_text(json.dumps(qc,indent=2)+'\n')
    print(json.dumps({'class':cls,'poses':len(qc),'warnings':[{'action':q['action'],'warnings':q['warnings']} for q in qc if q['warnings']]}),flush=True)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--class',dest='cls');args=parser.parse_args()
    for cls in ([args.cls] if args.cls else ['shield','sword','spear','bow','mage','healer']): prepare(cls)
