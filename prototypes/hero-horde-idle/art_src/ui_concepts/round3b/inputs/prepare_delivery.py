"""Validate original image_gen files and make the requested contact; writes only round3b."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json,hashlib
root=Path(__file__).resolve().parents[1]
m=json.loads((root/'inputs/generation-manifest.json').read_text())
contact=Image.new('RGB',(1032,744),'#10231d')
draw=ImageDraw.Draw(contact)
font=ImageFont.load_default(size=18)
checks=[]
for n,item in enumerate(m['items']):
 p=root/(item['id']+'.png')
 im=Image.open(p)
 im.load()
 assert im.height>im.width and abs(im.width/im.height-853/1844)<.03
 assert im.mode=='RGB' or im.getchannel('A').getextrema()==(255,255)
 assert p.read_bytes()==Path(item['source']).read_bytes()
 thumb=im.convert('RGB')
 thumb.thumbnail((320,692),Image.Resampling.LANCZOS)
 x=12+n*344+(320-thumb.width)//2
 contact.paste(thumb,(x,12))
 label=item['id']+' (frame warning)' if item['id']=='team' else item['id']
 draw.text((12+n*344,712),label,fill='#e5dcc5',font=font)
 checks.append({'id':item['id'],'size':list(im.size),'mode':im.mode,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'status':item['status']})
contact.save(root/'contact.png')
(root/'inputs/validation.json').write_text(json.dumps(checks,indent=2)+'\n')
p=root/'inputs/prompts.md'
s=p.read_text()
if '## team 修正重試' not in s:
 s+='\n## team 修正重試\n\n實際參考順序：ref_team、style_target、current_roster、current_camp、team-attempt-01；首個六參考圖參數被工具拒絕，未產生圖。\n\n```text\n'+(root/'inputs/team-retry-prompt.txt').read_text().strip()+'\n```\n'
 p.write_text(s)
print([(x['id'],x['size']) for x in checks])
print('3 originals verified; contact.png assembled.')
