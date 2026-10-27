from pathlib import Path
import json
from PIL import Image,ImageDraw,ImageFont
r=Path(__file__).resolve().parent
styles={'A':'王城藍金','B':'旅人皮革','C':'戰旗布幔','D':'像素復古','E':'清爽手遊'}
font=ImageFont.truetype(str(r.parent.parent/'ui/fonts/NotoSansTC.ttf'),24)
records=[]
for view in ['growth','battle']:
    items=[(c,r/f'{c}_{view}.png') for c in styles if (r/f'{c}_{view}.png').exists()]
    if not items:continue
    sizes=[Image.open(p).size for c,p in items]
    heights=[round(h*320/w) for w,h in sizes]
    sheet=Image.new('RGB',(332*len(items)+12,max(heights)+66),(20,25,34))
    draw=ImageDraw.Draw(sheet)
    for i,((code,path),height) in enumerate(zip(items,heights)):
        image=Image.open(path).convert('RGB')
        draw.text((16+332*i,12),code+' '+styles[code],font=font,fill=(245,234,208))
        sheet.paste(image.resize((320,height),Image.Resampling.LANCZOS),(12+332*i,54))
        records.append({'name':path.name,'size':image.size,'bytes':path.stat().st_size})
    sheet.save(r/f'contact-{view}.png')
(r/'inputs/delivery-qc.json').write_text(json.dumps({'files':records},ensure_ascii=False,indent=2)+'\n')
print(json.dumps(records,ensure_ascii=False))
