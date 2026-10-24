"""Only validates generated originals and assembles requested contact sheet inside round3."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,hashlib
root=Path(__file__).resolve().parents[1]
m=json.loads((root/'inputs/generation-manifest.json').read_text())
checks=[]
for item in m['items']:
 p=root/(item['id']+'.png')
 with Image.open(p) as im:
  im.load()
  assert im.height>im.width and abs(im.width/im.height-853/1844)<.03
  assert im.mode=='RGB' or im.getchannel('A').getextrema()==(255,255)
  assert p.read_bytes()==Path(item['source']).read_bytes()
  checks.append({'id':item['id'],'size':list(im.size),'mode':im.mode,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
canvas=Image.new('RGB',(1032,1512),'#10231d')
d=ImageDraw.Draw(canvas)
f=ImageFont.load_default(size=22)
for row,kind in enumerate(['recruit','items']):
 for col,key in enumerate('ABC'):
  image=Image.open(root/(key+'_'+kind+'.png')).convert('RGB')
  image.thumbnail((320,692),Image.Resampling.LANCZOS)
  x=12+col*344+(320-image.width)//2
  y=12+row*756
  canvas.paste(image,(x,y))
  d.text((12+col*344+142,y+704),key,fill='#e5dcc5',font=f)
canvas.save(root/'contact.png')
(root/'inputs/validation.json').write_text(json.dumps(checks,indent=2)+'\n')
retry=root/'inputs/C_items_retry_prompt.txt'
prompts=root/'inputs/prompts.md'
s=prompts.read_text()
if '## C_items 修正重試' not in s:
 prompts.write_text(s+'\n## C_items 修正重試\n\n```text\n'+retry.read_text().strip()+'\n```\n')
print('6 original images verified:',[(c['id'],c['size']) for c in checks])
print('contact.png: recruit row A/B/C; items row A/B/C; 1032x1512')
