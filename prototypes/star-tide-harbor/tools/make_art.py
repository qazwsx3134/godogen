"""Original SVG pixel-art authoring tool. No downloaded game artwork."""
from pathlib import Path
import random, math
OUT = Path(__file__).resolve().parents[1] / 'assets'
random.seed(732)

class Art:
    def __init__(self,w,h):
        self.w,self.h=w,h
        self.p=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}" shape-rendering="crispEdges">']
    def rect(self,x,y,w,h,c,opacity=1):
        self.p.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{c}" opacity="{opacity}"/>')
    def poly(self,pts,c,opacity=1):
        self.p.append(f'<polygon points="{" ".join(f"{x},{y}" for x,y in pts)}" fill="{c}" opacity="{opacity}"/>')
    def ellipse(self,x,y,rx,ry,c,opacity=1):
        self.p.append(f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="{c}" opacity="{opacity}"/>')
    def save(self,name):
        (OUT/name).write_text(''.join(self.p)+'</svg>',encoding='utf8')

a=Art(1280,720)
a.p.append('<defs><linearGradient id="sky" x2="0" y2="1"><stop stop-color="#303f75"/><stop offset=".55" stop-color="#9d8fb1"/><stop offset="1" stop-color="#edbca5"/></linearGradient></defs>')
a.rect(0,0,1280,720,'url(#sky)')
for _ in range(145):
    x=random.randrange(0,1280,3);y=random.randrange(0,365,3)
    a.rect(x,y,2,2,random.choice(['#fbebce','#d6e7df','#aec4d4']),random.uniform(.3,.9))
a.ellipse(295,222,127,127,'#b7cec9',.22)
a.ellipse(295,222,113,113,'#d0d9ce',.72)
for k in range(20):
    y=125+k*10; width=math.sqrt(max(0,110**2-(y-222)**2))*2
    a.rect(295-width/2,y,width,3,'#e1e3d0',.3)
a.ellipse(312,194,24,11,'#9ebbbd',.4);a.ellipse(248,243,31,17,'#9ebbbd',.3)
a.p.append('<ellipse cx="295" cy="222" rx="171" ry="24" transform="rotate(-22 295 222)" fill="none" stroke="#f7d6ba" stroke-width="7" opacity=".4"/>')
for x,y,s in [(12,280,1),(470,200,.8),(815,290,1.3),(1090,145,.8)]:
    for j,(dx,dy,w,h) in enumerate([(0,18,180,12),(25,0,84,30),(80,7,126,20),(164,22,75,8)]):
        a.rect(x+dx*s,y+dy*s,w*s,h*s,'#dbb6bc',.4)
a.save('sky.svg')

a=Art(2400,720)
for layer,(base,c,step) in enumerate([(408,'#778aa5',170),(447,'#527d96',140),(485,'#386d80',100)]):
    pts=[(0,550),(0,base)]
    for x in range(0,2420,12):
        y=round((base-30-18*math.sin(x/97+layer)-22*math.sin(x/214+layer))/4)*4
        pts.extend([(x,y),(x+12,y)])
    pts.extend([(2400,550)]);a.poly(pts,c)
    for x in range(30,2400,220):
        y=base-random.randrange(15,45)
        a.rect(x,y-38,6,55,c)
        a.poly([(x-45,y-35),(x-45,y-43),(x-15,y-43),(x-15,y-47),(x+25,y-47),(x+25,y-39),(x+58,y-39),(x+58,y-29)],c)
    for _ in range(460):
        x=random.randrange(0,2400,4);y=random.randrange(base-20,base+30,4)
        a.rect(x,y,random.randrange(4,22,4),3,['#8b9baa','#66969d','#45818a'][layer],.55)
a.save('islands.svg')

a=Art(2400,240)
a.p.append('<defs><linearGradient id="water" x2="0" y2="1"><stop stop-color="#82b7bb"/><stop offset=".22" stop-color="#4b909f"/><stop offset="1" stop-color="#234f70"/></linearGradient></defs>')
a.rect(0,0,2400,240,'url(#water)')
for _ in range(780):
    x=random.randrange(0,2400,4);y=random.randrange(0,240,3)
    a.rect(x,y,random.randrange(5,45,4),random.choice([1,2,3]),random.choice(['#c1dbcb','#73b9b7','#a2d0bd','#377c96']),random.uniform(.2,.55))
for y in range(8,160,8):
    x=290+random.randrange(-y//2,y//2+1)
    a.rect(x,y,random.randrange(20,110),2,'#ffe0ac',.4*(1-y/180))
a.save('water.svg')

a=Art(2400,220)
for x in range(0,2400,65):
    a.rect(x+12,18,14,140,'#343e56');a.rect(x+12,18,4,140,'#745e66')
    a.rect(x,0,65,17,'#5c5366');a.rect(x,0,64,4,'#d7b4a4');a.rect(x,17,65,5,'#333c54')
    for j in range(3):a.rect(x+7+j*18,6,12,2,'#ac8c86')
for x in [70,300,730,1080,1450,1870,2240]:
    a.rect(x,30,3,60,'#35485b');a.rect(x-10,34,24,3,'#486376')
    for k in range(3):a.rect(x-7+k*7,40,2,8,'#a5c9bf',.7)
a.save('pier.svg')

a=Art(390,230)
a.ellipse(195,216,189,12,'#193b54',.4)
a.poly([(8,174),(374,174),(352,207),(46,207),(24,196)],'#35465b')
a.rect(26,173,333,10,'#d4b98c');a.rect(50,186,293,8,'#d28776');a.rect(71,199,251,4,'#738e97')
a.rect(62,65,236,108,'#dfcab1');a.rect(62,153,236,20,'#839da0')
a.poly([(48,63),(75,33),(276,33),(312,63)],'#855c70');a.rect(49,62,264,7,'#d19488')
for x in range(78,281,19):a.rect(x,40,3,20,'#b2797d')
for y in range(76,153,13):a.rect(64,y,232,1,'#c1af9d',.55)
for x in range(84,272,14):a.rect(x,42,11,2,'#d3a092',.6)
a.rect(162,81,51,92,'#5e6275');a.rect(170,86,35,83,'#bb8577');a.rect(197,130,4,4,'#ffdf9c')
for x in [80,233]:
    a.rect(x,83,49,46,'#354c64');a.rect(x+5,88,39,36,'#ebce98');a.rect(x+23,88,4,36,'#887571');a.rect(x+5,104,39,4,'#887571')
a.rect(320,127,9,48,'#746575');a.rect(311,120,28,15,'#f0d59c')
a.rect(104,16,17,22,'#5c6476');a.rect(101,15,23,5,'#b6a69e')
a.rect(248,8,37,23,'#334d67')
for x in range(253,282,9):a.rect(x,11,2,17,'#72b0bd')
a.rect(343,152,18,22,'#a47770');a.rect(340,150,24,5,'#d7b69a')
for x,y in [(350,136),(341,141),(359,140)]:
    a.rect(x,y,3,15,'#83a797');a.rect(x-3,y-3,8,5,'#e8b9b3')
a.rect(68,144,65,7,'#68786e')
for x in range(70,132,7):a.rect(x,134-random.randrange(0,10),5,12,'#a7c59b')
a.ellipse(60,190,11,14,'#253b50');a.ellipse(319,190,11,14,'#253b50')
a.save('boat.svg')

a=Art(220,290)
a.poly([(100,280),(111,96),(123,96),(127,280)],'#4a5267')
a.poly([(111,217),(71,151),(77,146),(119,193),(166,119),(172,126),(122,225)],'#4a5267')
for x,y,w in [(111,105,101),(70,154,63),(164,125,76),(117,72,68)]:
    a.poly([(x-w,y),(x-w,y-7),(x-w*.8,y-7),(x-w*.8,y-15),(x-20,y-15),(x-20,y-25),(x+21,y-25),(x+21,y-18),(x+w*.7,y-18),(x+w*.7,y-6),(x+w,y-6),(x+w,y+4),(x+w*.6,y+4),(x+w*.6,y+9),(x-w*.5,y+9)],'#66918f')
    for _ in range(70):
        dx=random.randrange(round(-w*.7),round(w*.7),3);dy=random.randrange(-14,9,3)
        a.rect(x+dx,y+dy,random.choice([3,6,9]),3,random.choice(['#89b5a3','#9ebfaa','#547a80','#739f94']))
    a.rect(x-w*.7,y-10,w*1.2,4,'#b1c99d');a.rect(x-w*.4,y+5,w*.7,3,'#d1dcac')
for _ in range(35):
    x=random.randrange(35,194);y=random.randrange(140,277)
    a.rect(x,y,2,3,'#efdca5',.7)
a.save('tree.svg')

for i in range(4):
    a=Art(96,150)
    for j in range(13):
        x=random.randrange(4,90,3);h=random.randrange(30,125,3)
        a.rect(x,150-h,2,h,random.choice(['#557d81','#6a9c8e','#83b5a1']))
        a.poly([(x,150-h+20),(x-12,150-h+8),(x-2,150-h+11)],'#7ca89a')
        a.rect(x-4,150-h-4,10,6,['#e9c78f','#cc9fc3','#9cdae0','#eda5a1'][i])
        a.rect(x-1,150-h-7,4,12,'#fae6b8')
    a.save(f'reeds{i}.svg')

def actor(name,coat,hair):
    a=Art(48,76)
    a.ellipse(24,72,21,4,'#273d58',.45)
    a.rect(13,54,9,17,'#303d56');a.rect(27,54,9,17,'#303d56')
    a.rect(9,68,14,5,'#e8c3a0');a.rect(27,68,14,5,'#e8c3a0')
    a.poly([(12,28),(34,28),(41,56),(7,56)],coat)
    a.rect(10,30,7,22,coat);a.rect(33,32,7,20,coat)
    a.rect(8,49,7,8,'#f0c4aa');a.rect(34,49,7,8,'#f0c4aa')
    a.rect(15,12,20,21,'#f0c4aa');a.rect(12,5,25,14,hair)
    a.rect(11,12,7,16,hair);a.rect(29,8,9,9,hair)
    a.rect(27,20,3,4,'#34465b');a.rect(30,27,5,2,'#cc8f87')
    a.rect(13,32,22,5,'#f6dba4');a.rect(24,37,4,16,'#d5ac80')
    a.save(name)
actor('player.svg','#c69b75','#b9d4c7')
actor('mira.svg','#a995bd','#455472')
for i,(body,fin) in enumerate([('#90d3c6','#3e939c'),('#e1a6c4','#9f6f9f'),('#e8cd86','#be905d'),('#99c9de','#5d82bd'),('#e7b6a1','#c67a8c'),('#beb7e9','#827db1')]):
    a=Art(100,56)
    a.poly([(68,28),(94,11),(94,45)],fin)
    a.poly([(17,16),(39,7),(67,11),(82,28),(64,45),(33,46),(9,32)],body)
    a.poly([(39,13),(49,1),(62,12)],fin);a.poly([(38,40),(53,54),(60,39)],fin)
    a.rect(20,21,7,7,'#293e5b');a.rect(22,21,2,2,'#fff4d6')
    for k in range(3):a.rect(39+k*11,21,3,13,fin,.5)
    a.rect(29,13,28,3,'#f5ebcb',.7);a.save(f'fish{i}.svg')
print('Authored',len(list(OUT.glob('*.svg'))),'original SVG assets')
