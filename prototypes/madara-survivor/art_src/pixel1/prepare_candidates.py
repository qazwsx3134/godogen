from pathlib import Path
import json,sys,hashlib
import numpy as np
from PIL import Image,ImageDraw,ImageOps
sys.path.insert(0,'/Users/peter/repo/agent-sprite-forge/skills/generate2dsprite/scripts')
import master_still
ROOT=Path('/Users/peter/repo/godot/godogen/prototypes/madara-survivor/art_src/pixel1')
MIRROR={}
for name in sys.argv[1:]:
 d=ROOT/name;run=json.loads((d/'run.json').read_text());spec=json.loads((d/'spec.json').read_text());assert spec['finish']=='pixel'
 key=run['key'];good=[v for v in run['takes']if v.get('status')=='ok'];records=[];images=[]
 for record in good:
  assert record['route']=='local:codex-cli';source=d/record['artifact']['path'];im=Image.open(source).convert('RGBA')
  keyed,matte=master_still.key_subject(np.asarray(im),key,'soft');out=Image.fromarray(keyed,'RGBA')
  mirrored=record['take']in MIRROR.get(name,[])
  if mirrored:out=ImageOps.mirror(out)
  target=d/f"candidate-{record['take']:02d}.png";out.save(target);a=out.getchannel('A');b=a.getbbox();warnings=[]
  if not b:warnings.append('empty matte')
  elif b[0]<=0 or b[1]<=0 or b[2]>=out.width or b[3]>=out.height:warnings.append('subject touches source edge; possible clipping')
  if a.getextrema()!=(0,255):warnings.append('unexpected alpha range')
  records.append({'take':record['take'],'source':str(source),'candidate':str(target),'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'size':out.size,'bbox':b,'alpha_range':a.getextrema(),'matte':matte,'warnings':warnings,'mirrored':mirrored,'transform':'chroma removal only; original canvas, pixel shapes and scale retained; all disconnected objects retained'})
  images.append((out,record['take']))
 (d/'candidate-qc.json').write_text(json.dumps(records,indent=2)+'\n')
 if images:
  cell=400;sheet=Image.new('RGB',(len(images)*cell,424),(242,242,242));draw=ImageDraw.Draw(sheet)
  for idx,(im,take)in enumerate(images):
   x=idx*cell
   for py in range(24,424,16):
    for px in range(x,x+cell,16):
     if((px-x)//16+(py-24)//16)%2:draw.rectangle((px,py,px+15,py+15),fill=(208,208,208))
   thumb=im.copy();thumb.thumbnail((392,392),Image.Resampling.NEAREST);sheet.paste(thumb,(x+(cell-thumb.width)//2,24+(cell-thumb.height)//2),thumb)
   draw.text((x+8,7),f'{name} / candidate {take:02d}',fill=(20,20,20))
  sheet.save(d/'candidates-contact.png')
 print(name+': '+str(len(images))+' transparent candidates + contact; '+str(sum(len(v['warnings'])for v in records))+' QC warnings',flush=True)
