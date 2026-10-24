"""Validate untouched image_gen outputs and assemble the explicitly requested contact sheet.
Only writes within art_src/ui_icons; no generation, repainting or background removal.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageStat
import hashlib,json
ROOT=Path(__file__).resolve().parents[1]
plan=json.loads((ROOT/'inputs/generation-plan.json').read_text())
manifest=json.loads((ROOT/'inputs/generation-manifest.json').read_text())
canvas=Image.new('RGB',(928,360),'#132820')
draw=ImageDraw.Draw(canvas)
font=ImageFont.load_default(size=13)
draw.text((16,10),'SIGNATURE SKILLS  |  96 px thumbnails',fill='#e9e5d6',font=font)
draw.text((16,180),'CLASS PENNANTS + HERO BACKGROUND  |  96 px thumbnails',fill='#e9e5d6',font=font)
checks=[]
for n,item in enumerate(plan):
    path=ROOT/(item['id']+'.png')
    with Image.open(path) as image:
        image.load()
        assert image.mode=='RGB' or image.getchannel('A').getextrema()==(255,255),str(path)
        if n<13:
            assert image.width==image.height,str(path)
        else:
            assert abs(image.height/image.width-1.75)<.03,str(path)
        row,col=divmod(n,7)
        thumb=image.convert('RGB')
        thumb.thumbnail((96,96),Image.Resampling.LANCZOS)
        x=16+col*128+(96-thumb.width)//2
        y=36+row*170
        canvas.paste(thumb,(x,y))
        draw.text((16+col*128,y+104),item['id'],fill='#d9c7a5',font=font)
        check={'id':item['id'],'size':list(image.size),'mode':image.mode,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
        if item['id'].startswith('class/'):
            # Sampling confined to the exterior margins, never the emblem.
            samples=[image.convert('RGB').getpixel((x,y)) for x in (0,image.width//2,image.width-1) for y in (0,image.height-1)]
            check['exterior_samples_rgb']=samples
            check['exact_ff00ff_samples']=sum(p==(255,0,255) for p in samples)
        if n==13:
            crop=image.crop((0,int(image.height*.6),image.width,image.height)).convert('RGB')
            stat=ImageStat.Stat(crop)
            check['bottom_40_percent_mean_rgb']=stat.mean
        source=Path(manifest['items'][n]['source'])
        assert path.read_bytes()==source.read_bytes(),f'Output differs from original generation: {path}'
        checks.append(check)
canvas.save(ROOT/'contact.png')
(ROOT/'inputs/validation.json').write_text(json.dumps(checks,ensure_ascii=False,indent=2)+'\n')
prompts='# UI 圖示完整提示詞\n\n工具：Codex 內建 image_gen。每項一次；shield 與背景各修正重試一次。\n旗徽 sword/spear/bow/mage/healer 以本批 class/shield.png 為編輯模板，只換中央圖案。\n\n'
prompts+='\n\n'.join('## '+i['id']+'\n\n```text\n'+i['prompt']+'\n```' for i in plan)
for key,title in [('shield-retry-prompt.txt','class/shield 修正重試'),('background-retry-prompt.txt','bg/hero_page 修正重試')]:
    prompts+='\n\n## '+title+'\n\n```text\n'+(ROOT/'inputs'/key).read_text().strip()+'\n```'
(ROOT/'inputs/prompts.md').write_text(prompts+'\n')
print(f'Validated {len(checks)} opaque originals; contact.png = {canvas.size}; no runtime files modified.')
print('Background lower-40% mean RGB:',checks[-1]['bottom_40_percent_mean_rgb'])
