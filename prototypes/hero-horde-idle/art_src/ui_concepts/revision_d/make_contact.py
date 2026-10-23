from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json
r=Path(__file__).resolve().parent
items=[('growth_roster','養成總覽'),('growth_detail','英雄詳情'),('battle','D 向戰鬥')]
items=[v for v in items if (r/(v[0]+'.png')).exists()]
if not items:raise SystemExit('No generated images yet')
font=ImageFont.truetype(str(r.parents[2]/'ui/fonts/NotoSansTC.ttf'),26)
width=380;gap=16;head=58
heights=[round(Image.open(r/(n+'.png')).height*width/Image.open(r/(n+'.png')).width) for n,label in items]
canvas=Image.new('RGB',((width+gap)*len(items)+gap,max(heights)+head+gap),(21,25,29))
draw=ImageDraw.Draw(canvas)
records=[]
for i,((name,label),height) in enumerate(zip(items,heights)):
    path=r/(name+'.png');image=Image.open(path).convert('RGB')
    draw.text((gap+i*(width+gap),14),label,font=font,fill=(242,232,209))
    canvas.paste(image.resize((width,height),Image.Resampling.LANCZOS),(gap+i*(width+gap),head))
    records.append({'name':path.name,'size':image.size,'bytes':path.stat().st_size})
canvas.save(r/'contact.png')
(r/'inputs/delivery-qc.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(records,ensure_ascii=False))
