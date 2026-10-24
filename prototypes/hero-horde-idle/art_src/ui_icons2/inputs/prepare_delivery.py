"""Only validate raw image_gen outputs and assemble requested thumbnails within ui_icons2.
No painting, background removal, colour correction or generated-asset replacement.
"""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont,ImageStat
import json,hashlib
root=Path(__file__).resolve().parents[1]
plan=json.loads((root/'inputs/generation-plan-final.json').read_text())
manifest=json.loads((root/'inputs/generation-manifest.json').read_text())
canvas=Image.new('RGB',(1040,382),'#132820')
draw=ImageDraw.Draw(canvas)
font=ImageFont.load_default(size=14)
draw.text((16,12),'ITEMS | 96 px thumbnails',fill='#e9e5d6',font=font)
draw.text((16,190),'NAVIGATION | actual 40 px thumbnails                                     TAVERN BACKGROUND',fill='#e9e5d6',font=font)
checks=[]
for n,item in enumerate(plan):
 path=root/(item['id']+'.png')
 image=Image.open(path)
 image.load()
 assert image.mode=='RGB' or image.getchannel('A').getextrema()==(255,255)
 assert path.read_bytes()==Path(manifest['items'][n]['source']).read_bytes()
 im=image.convert('RGB')
 if n<12:
  assert image.width==image.height
 else:
  assert abs(image.height/image.width-1.75)<.03
 check={'id':item['id'],'size':list(image.size),'mode':image.mode,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
 if n<12:
  # Exterior four corner patches do not include the centered object.
  patches=[im.crop(b) for b in [(0,0,24,24),(im.width-24,0,im.width,24),(0,im.height-24,24,im.height),(im.width-24,im.height-24,im.width,im.height)]]
  pixels=[v for p in patches for v in p.getdata()]
  check['corner_mean_rgb']=[round(sum(p[c] for p in pixels)/len(pixels),2) for c in range(3)]
  check['exact_ff00ff_corner_ratio']=round(sum(p==(255,0,255) for p in pixels)/len(pixels),4)
  check['corner_unique_rgb_count']=len(set(pixels))
 else:
  check['bottom_30_percent_mean_rgb']=ImageStat.Stat(im.crop((0,int(im.height*.7),im.width,im.height))).mean
 thumb=im.copy()
 if n<7:
  col=n
  thumb.thumbnail((96,96),Image.Resampling.LANCZOS)
  x=16+col*144+(96-thumb.width)//2
  y=40
 elif n<12:
  col=n-7
  thumb.thumbnail((40,40),Image.Resampling.LANCZOS)
  x=16+col*144+(96-thumb.width)//2
  y=240
 else:
  col=5
  thumb.thumbnail((80,140),Image.Resampling.LANCZOS)
  x=16+col*144+(96-thumb.width)//2
  y=218
 canvas.paste(thumb,(x,y))
 label_y=146 if n<7 else 290 if n<12 else 360
 draw.text((16+col*144,label_y),item['id'],fill='#d9c7a5',font=font)
 checks.append(check)
canvas.save(root/'contact.png')
(root/'inputs/validation.json').write_text(json.dumps(checks,ensure_ascii=False,indent=2)+'\n')
(root/'inputs/prompts.md').write_text('# ui_icons2 完整實際提示詞\n\n使用 Codex 內建 image_gen。A_items、B_recruit、ui_icons/contact 已目視作風格依據；導覽 growth/recruit/items/stages 額外以本批 nav/camp.png 作模板（每張一次），其餘為新圖。所有 PNG 保留工具原始輸出，不修色、不去背。\n\n'+'\n\n'.join('## '+i['id']+'\n\n```text\n'+i['prompt']+'\n```' for i in plan)+'\n')
print('Validated',len(checks),'original opaque PNGs, contact.png=',canvas.size)
print('Dimensions:',[(c['id'],c['size']) for c in checks])
print('Corner exact-magenta ratios:',[(c['id'],c.get('exact_ff00ff_corner_ratio')) for c in checks[:-1]])
print('Background bottom-30% mean RGB:',checks[-1]['bottom_30_percent_mean_rgb'])
