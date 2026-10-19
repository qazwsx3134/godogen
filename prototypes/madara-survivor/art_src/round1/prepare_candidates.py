from pathlib import Path
import json,subprocess,shutil,sys
from PIL import Image,ImageDraw,ImageOps
ROOT=Path('/Users/peter/repo/godot/godogen/prototypes/madara-survivor/art_src/round1')
PYTHON='/Users/peter/repo/agent-sprite-forge/.venv/bin/python'
MASTER='/Users/peter/repo/agent-sprite-forge/skills/generate2dsprite/scripts/master_still.py'
# Only populate after visual review. Originals always remain under takes/.
MIRROR={}
for name in sys.argv[1:]:
 d=ROOT/name;run=json.loads((d/'run.json').read_text());records=run.get('takes',[])
 if len(records)!=3 or any(r.get('status')!='ok'for r in records):raise SystemExit(name+': not three successful takes')
 qa=[];items=[]
 for take in [1,2,3]:
  pad=d/f'cutout-{take:02d}'
  if not pad.exists():
   cmd=[PYTHON,MASTER,'pad','--run',str(d),'--take',str(take),'--output-dir',str(pad)]
   p=subprocess.run(cmd,text=True,capture_output=True)
   (d/f'cutout-{take:02d}.log').write_text(p.stdout+p.stderr)
   if p.returncode:raise SystemExit(name+': cutout failed '+p.stderr[-500:])
  target=d/f'candidate-{take:02d}.png'
  image=Image.open(pad/'padded_rgba.png').convert('RGBA')
  if take in MIRROR.get(name,[]):image=ImageOps.mirror(image)
  image.save(target)
  alpha=image.getchannel('A');bbox=alpha.getbbox();extrema=alpha.getextrema()
  if not bbox or extrema[0]!=0 or bbox[0]<=0 or bbox[1]<=0 or bbox[2]>=image.width or bbox[3]>=image.height:raise SystemExit(name+': empty/edge/opaque candidate')
  meta=json.loads((pad/'pad.json').read_text());qa.append({'take':take,'file':str(target),'size':image.size,'alpha_range':extrema,'bbox':bbox,'mirrored':take in MIRROR.get(name,[]),'warnings':meta.get('warnings',[])})
  items.append(image)
 sheet=Image.new('RGB',(1080,390),(242,242,242));draw=ImageDraw.Draw(sheet)
 for idx,image in enumerate(items):
  left=idx*360
  for y in range(30,390,16):
   for x in range(left,left+360,16):
    if ((x-left)//16+(y-30)//16)%2:draw.rectangle((x,y,min(x+15,left+359),min(y+15,389)),fill=(211,211,211))
  thumb=image.copy();thumb.thumbnail((352,352),Image.Resampling.LANCZOS);sheet.paste(thumb,(left+(360-thumb.width)//2,30+(360-thumb.height)//2),thumb)
  draw.text((left+10,8),f'{name} candidate {idx+1:02d}',fill=(20,20,20))
 sheet.save(d/'candidates-contact.png')
 (d/'candidate-qc.json').write_text(json.dumps(qa,indent=2)+'\n')
 print(name+': 3 transparent candidates + candidates-contact.png',flush=True)
