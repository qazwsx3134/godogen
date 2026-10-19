from pathlib import Path
import json,sys,hashlib
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0,'/Users/peter/repo/agent-sprite-forge/skills/generate2dsprite/scripts')
import master_still
ROOT=Path('/Users/peter/repo/godot/godogen/prototypes/madara-survivor/art_src/pixel2')
NAMES=['idle','run_a','run_b','punch','kick','fan','seal']
for name in sys.argv[1:]:
 d=ROOT/name
 run=json.loads((d/'run.json').read_text());spec=json.loads((d/'spec.json').read_text())
 assert spec['finish']=='pixel' and run['key']=='#00FF00',name
 assert len(run['takes'])==1 and run['takes'][0]['status']=='ok',name
 take=run['takes'][0];assert take['route']=='local:codex-cli',name
 source=d/take['artifact']['path'];im=Image.open(source).convert('RGBA')
 pixels,matte=master_still.key_subject(np.asarray(im),run['key'],'soft')
 out=Image.fromarray(pixels,'RGBA');target=d/'candidate-01.png';out.save(target)
 alpha=out.getchannel('A');bbox=alpha.getbbox();warnings=[]
 if not bbox:warnings.append('empty subject')
 elif bbox[0]<=0 or bbox[1]<=0 or bbox[2]>=out.width or bbox[3]>=out.height:warnings.append('subject touches original canvas edge')
 if alpha.getextrema()!=(0,255):warnings.append('unexpected alpha range')
 record={'pose':name,'source':str(source),'candidate':str(target),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'candidate_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'size':out.size,'bbox':bbox,'alpha_range':alpha.getextrema(),'matte':matte,'warnings':warnings,'processing':'green key removal only; original canvas, scale and pixel shapes retained; no redrawing or per-pose scale normalization'}
 (d/'candidate-qc.json').write_text(json.dumps(record,indent=2)+'\n')
 print(name+': transparent candidate, '+str(len(warnings))+' warnings',flush=True)
ready=[n for n in NAMES if (ROOT/n/'candidate-01.png').exists()]
if ready:
 cell=400;rowh=424;sheet=Image.new('RGB',(cell*4,rowh*2),(242,242,242));draw=ImageDraw.Draw(sheet)
 for i,n in enumerate(NAMES):
  x=(i%4)*cell;y=(i//4)*rowh
  for py in range(y+24,y+rowh,16):
   for px in range(x,x+cell,16):
    if((px-x)//16+(py-y-24)//16)%2:draw.rectangle((px,py,px+15,py+15),fill=(208,208,208))
  draw.text((x+8,y+7),n,fill=(20,20,20))
  if n in ready:
   thumb=Image.open(ROOT/n/'candidate-01.png').convert('RGBA');thumb.thumbnail((392,392),Image.Resampling.NEAREST)
   sheet.paste(thumb,(x+(cell-thumb.width)//2,y+24+(cell-thumb.height)//2),thumb)
 sheet.save(ROOT/'poses-contact.png')
 print('Contact: '+str(len(ready))+'/7 poses',flush=True)
