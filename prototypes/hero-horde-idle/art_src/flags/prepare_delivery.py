from pathlib import Path
import argparse,json,subprocess,sys
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parent
FORGE=Path('/Users/peter/repo/agent-sprite-forge/skills/generate2dsprite/scripts')
sys.path.insert(0,str(FORGE))
from master_still import contact_sheet

def tip(image):
 alpha=np.asarray(image.getchannel('A'))
 ys,xs=np.nonzero(alpha>16)
 bottom=int(ys.max())
 xx=np.nonzero(alpha[bottom]>16)[0]
 return (int(round(float(np.median(xx)))),bottom)

def prepare(team):
 rows=[];qc=[];anchor=None
 for frame in ['frame_a','frame_b']:
  runs=sorted((ROOT/'inputs').glob(f'{team}-{frame}-*/run.json'))
  good=[(p,json.loads(p.read_text())) for p in runs if json.loads(p.read_text())['status']=='ok']
  if not good:continue
  run_path,run=good[0]
  pad=ROOT/'inputs'/f'{team}-{frame}-pad'
  if not pad.exists():
   subprocess.run([sys.executable,str(FORGE/'master_still.py'),'pad','--run',str(run_path.parent),'--take','1',
                   '--output-dir',str(pad)],check=True)
  meta=json.loads((pad/'pad.json').read_text())
  image=Image.open(pad/'padded_rgba.png').convert('RGBA')
  point=tip(image)
  if frame=='frame_a':anchor=point
  if anchor is None:raise ValueError('frame_b requires delivered frame_a')
  dx,dy=anchor[0]-point[0],anchor[1]-point[1]
  bounds=image.getbbox()
  assert bounds[0]+dx>0 and bounds[1]+dy>0 and bounds[2]+dx<image.width and bounds[3]+dy<image.height
  shifted=Image.new('RGBA',image.size)
  shifted.paste(image,(dx,dy))
  assert tip(shifted)==anchor
  out=ROOT/team/frame/'candidate-01.png';out.parent.mkdir(parents=True,exist_ok=True)
  shifted.save(out)
  rows.append((out,frame))
  qc.append({'team':team,'frame':frame,'mode':run['command'],'run':str(run_path.relative_to(ROOT)),
             'canvas_size':image.size,'bbox':shifted.getbbox(),'iron_tip_anchor':anchor,
             'translation_px':[dx,dy],'pole_height_normalized':meta['framing']['subject_height_px'],
             'pad_scale':meta['transform']['scale'],'matte':meta['matte'],'warnings':meta['warnings']})
 if rows:contact_sheet(rows).save(ROOT/team/'frames-contact.png')
 (ROOT/'inputs'/f'{team}-delivery-qc.json').write_text(json.dumps(qc,indent=2)+'\n')
 print(json.dumps({'team':team,'frames':len(qc),'anchors':[q['iron_tip_anchor'] for q in qc],
                  'warnings':[q['warnings'] for q in qc if q['warnings']]}),flush=True)

def preview():
 canvas=Image.new('RGBA',(288,112))
 count=0
 for i,team in enumerate(['melee','ranged','support']):
  path=ROOT/team/'frame_a/candidate-01.png'
  if not path.exists():continue
  image=Image.open(path).convert('RGBA')
  bbox=image.getbbox();image=image.crop(bbox)
  width=round(image.width*96/image.height)
  small=image.convert('RGBa').resize((width,96),Image.Resampling.LANCZOS).convert('RGBA')
  canvas.paste(small,(96*i+(96-width)//2,8))
  count+=1
 if count:canvas.save(ROOT/'flags-40px.png')

if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--team');args=parser.parse_args()
 for team in ([args.team] if args.team else ['melee','ranged','support']):prepare(team)
 preview()
