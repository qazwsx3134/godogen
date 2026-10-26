"""Original code-authored pixel-style props and cabin; no game assets or AI images."""
from pathlib import Path
import random
BASE = Path(__file__).resolve().parents[1] / 'assets'
def save(name, body, w=128, h=160):
    (BASE/name).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" shape-rendering="crispEdges">{body}</svg>',encoding='utf-8')
def r(x,y,w,h,c,opacity=1):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{c}" opacity="{opacity}"/>'
def p(points,c):
    return f'<polygon points="{points}" fill="{c}"/>'
lamp=r(48,150,38,8,'#273c48')+r(56,143,22,8,'#b7956d')+r(64,52,6,94,'#c3b796')
lamp+=r(61,55,3,90,'#796757')+p('43,34 83,34 99,67 28,67','#d19b69')+r(34,63,60,8,'#76564e')+p('48,38 78,38 88,61 39,61','#ffe8a6')+r(61,24,11,10,'#745852')
save('prop_lamp.svg',lamp)
plant=r(37,125,56,9,'#c6b79a')+p('41,134 90,134 83,156 49,156','#9a6b60')+r(49,138,8,14,'#c69375')+r(62,40,5,87,'#638e83')
for x,y,s in [(31,58,1),(65,40,1),(20,90,1),(69,82,1),(50,18,1)]:
    plant+=p(f'{x},{y+18} {x},{y+5} {x+10},{y+5} {x+10},{y} {x+30},{y} {x+30},{y+10} {x+39},{y+10} {x+39},{y+21} {x+11},{y+21}', '#75aa96')
    plant+=r(x+9,y+3,16,4,'#c5d6a4')+r(x+24,y+17,10,4,'#426a72')
save('prop_plant.svg',plant)
chair=p('27,84 38,81 68,131 104,131 104,142 62,142','#ad8066')+r(64,118,44,13,'#d3b78a')+r(37,80,9,23,'#d3b78a')+r(61,140,8,17,'#765c53')+r(96,140,8,17,'#765c53')+p('31,81 37,77 73,124 67,129','#e1cc9c')+r(72,114,30,5,'#70978a')+r(76,116,22,5,'#a8c3a1')
save('prop_chair.svg',chair)
shelf=r(22,66,8,90,'#765b54')+r(98,66,8,90,'#765b54')
for y in [73,113,147]:shelf+=r(19,y,91,8,'#b39470')+r(23,y+1,83,3,'#e1c19a')
for x,h,c in [(33,24,'#678e91'),(43,29,'#ba9c7b'),(55,22,'#9b8491')]:shelf+=r(x,73-h,8,h,c)+r(x+2,73-h+3,3,3,'#e0d8ac')
shelf+=r(74,94,19,19,'#bb9b7b')+r(76,90,15,7,'#83b4a0')+r(36,129,47,14,'#5a7c89')+p('42,136 48,129 65,129 74,136 65,142 48,142','#a6d2bf')+r(64,133,3,3,'#274d61')
save('prop_shelf.svg',shelf)
glow=''.join(r(64-i*4,64-i*4,128+i*8,128+i*8,'#ffcf83',.015+i*.0003) for i in range(14))
save('prop_glow.svg',glow,256,256)
# Cabin wall, portholes and wood floor in a consistent, limited palette.
room=r(0,0,1280,720,'#142e45')+r(112,134,1056,472,'#514d50')+r(128,148,1024,444,'#7e7469')
for x in range(132,1152,64):room+=r(x,150,2,440,'#625a58')+r(x+4,150,2,440,'#938673')
room+=r(128,352,1024,240,'#9f8066')
for y in range(352,592,32):
    room+=r(128,y,1024,3,'#625758')
    for x in range(128+(y%64)*4,1152,192):room+=r(x,y,2,32,'#7e6458')
for x in [240,566,892]:
    room+=r(x-8,178,184,142,'#4a4950')+r(x,186,168,126,'#b2a68a')+r(x+8,194,152,110,'#294f6c')
    room+=r(x+12,265,144,34,'#3c7481')+r(x+16,276,32,3,'#84b6b1')+r(x+100,287,43,3,'#84b6b1')
    room+=r(x+76,194,7,110,'#c2b899')+r(x+8,248,152,7,'#c2b899')+r(x-4,312,179,8,'#d2b68e')
room+=r(112,134,1056,14,'#b19677')+r(112,588,1056,18,'#4d454b')
room+=r(146,340,986,8,'#d1b48c')
save('cabin.svg',room,1280,720)
# Foreground and midground, authored at their native scale.
near=''
for i in range(44):
    x=i*72;h=28+(i*17)%62
    near+=p(f'{x},180 {x+8},180 {x+13},{180-h} {x+6},{180-h-12}','#183c4b')
    near+=p(f'{x+9},{180-h+25} {x-9},{180-h+10} {x-15},{180-h+12} {x+7},{180-h+34}','#275663')
    if i%3==0:near+=r(x+3,180-h-15,10,7,'#739e91')+r(x+5,180-h-15,5,3,'#b7c79c')
save('foreground.svg',near,3200,180)
mid=''
for i in range(18):
    x=i*170; y=80+(i%3)*10
    mid+=r(x+40,y,6,100,'#476879')+p(f'{x},{y} {x},{y-9} {x+16},{y-9} {x+16},{y-18} {x+74},{y-18} {x+74},{y-10} {x+96},{y-10} {x+96},{y+3}', '#57798a')
mid+=r(0,174,3200,12,'#658b92')
save('midshore.svg',mid,3200,190)
print('Authored 8 original SVG assets')
