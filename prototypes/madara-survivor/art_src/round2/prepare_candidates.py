from pathlib import Path
import json,sys,hashlib
import numpy as np
from PIL import Image,ImageDraw,ImageOps
sys.path.insert(0,'/Users/peter/repo/agent-sprite-forge/skills/generate2dsprite/scripts')
import master_still
ROOT=Path('/Users/peter/repo/godot/godogen/prototypes/madara-survivor/art_src/round2')
NAMES=['idle','run-a','run-b','punch','kick','fan-swing','seal']
MIRROR={}
for name in sys.argv[1:]:
 d=ROOT/name;source_run=d
 if(d/'candidate-source.json').exists():source_run=Path(json.loads((d/'candidate-source.json').read_text())['source_run'])
 run=json.loads((source_run/'run.json').read_text());assert run['status']=='ok'and len(run['takes'])==2
 records=[]
 for take in run['takes']:
  assert take['status']=='ok'and take['route']=='local:codex-cli'
  source=source_run/take['artifact']['path'];pixels=np.asarray(Image.open(source).convert('RGBA'))
  cut,matte=master_still.key_subject(pixels,'#00FF00','soft')
  image=Image.fromarray(cut,'RGBA');mirrored=take['take']in MIRROR.get(name,[])
  if mirrored:image=ImageOps.mirror(image)
  out=d/f"candidate-{take['take']:02d}.png";image.save(out)
  bbox=image.getchannel('A').getbbox();assert bbox and 0<bbox[0]<bbox[2]<image.width and 0<bbox[1]<bbox[3]<image.height
  assert image.getchannel('A').getextrema()==(0,255)
  records.append({'take':take['take'],'source':str(source),'candidate':str(out),'sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'size':image.size,'bbox':bbox,'matte':matte,'mirrored':mirrored,'transform':'identity: original generated canvas, scale and placement preserved; chroma key only'})
 (d/'candidate-qc.json').write_text(json.dumps(records,indent=2)+'\n')
 print(name+': 2 transparent candidates, original framing preserved',flush=True)
if all((ROOT/n/'candidate-02.png').exists()for n in NAMES):
 cell=320;header=24;rows=4;sheet=Image.new('RGB',(4*cell,rows*(cell+header)),(240,240,240));draw=ImageDraw.Draw(sheet)
 for idx,(name,take)in enumerate((n,t)for n in NAMES for t in [1,2]):
  x=(idx%4)*cell;y=(idx//4)*(cell+header)
  for py in range(y+header,y+header+cell,16):
   for px in range(x,x+cell,16):
    if ((px-x)//16+(py-y-header)//16)%2:draw.rectangle((px,py,px+15,py+15),fill=(208,208,208))
  im=Image.open(ROOT/name/f'candidate-{take:02d}.png').convert('RGBA');im.thumbnail((cell-8,cell-8),Image.Resampling.LANCZOS)
  sheet.paste(im,(x+(cell-im.width)//2,y+header+(cell-im.height)//2),im)
  draw.text((x+8,y+7),f'{name} / candidate {take:02d}',fill=(20,20,20))
 sheet.save(ROOT/'poses-contact.png');print('poses-contact.png: all 14 candidates',flush=True)
