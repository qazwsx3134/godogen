"""Deterministic, original procedural textures. No packages or AI service required.
8 padded/repeating 256px tiles: soil, asphalt, grass, concrete, rust,
painted steel, moss, burnt metal. Writes color, normal and ORM atlases.
"""
from pathlib import Path
import math, random, struct, zlib
N=256
OUT=Path(__file__).resolve().parents[1]/'assets/environment'

def png(path,w,h,data):
    def chunk(name,body):
        return struct.pack('>I',len(body))+name+body+struct.pack('>I',zlib.crc32(name+body)&0xffffffff)
    raw=b''.join(b'\0'+bytes(data[y*w*3:(y+1)*w*3]) for y in range(h))
    path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(raw,9))+chunk(b'IEND',b''))

def clamp(x): return max(0,min(255,int(x)))

rng=random.Random(86315)
grids={k:[[rng.random() for x in range(k)] for y in range(k)] for k in (4,16,64)}
def noise(x,y,k):
    x=x/N*k; y=y/N*k
    ix=int(x); iy=int(y); fx=x-ix; fy=y-iy
    fx=fx*fx*(3-2*fx); fy=fy*fy*(3-2*fy)
    g=grids[k]
    a=g[iy%k][ix%k]*(1-fx)+g[iy%k][(ix+1)%k]*fx
    b=g[(iy+1)%k][ix%k]*(1-fx)+g[(iy+1)%k][(ix+1)%k]*fx
    return a*(1-fy)+b*fy

W,H=1024,512
color=bytearray(W*H*3); normals=bytearray(W*H*3); orm=bytearray(W*H*3)
for tile in range(8):
    heights=[]; colors=[]; rough=[]
    for y in range(N):
        for x in range(N):
            a=noise(x,y,4); b=noise(x,y,16); c=noise(x,y,64)
            grain=rng.random(); h=.45*b+.25*c+.04*grain
            crack=abs(math.sin(x*.0245+math.sin(y*.049)*.6))<.025
            palettes=[(91,73,48),(58,58,52),(78,91,44),(139,133,115),(121,61,30),(66,76,61),(64,79,35),(40,43,38)]
            base=palettes[tile]
            value=.72+.35*a+.25*c+.12*grain
            metal=0
            if tile==1:
                value *= .45 if crack else 1
                h -= .15 if crack else 0
                if grain>.975: value+=.55
            elif tile==3:
                joint=(y%128<3 or (x+(128 if y//128 else 0))%256<3)
                value *= .68 if (crack and b>.45) else 1
                h -= .12 if (crack and b>.45) else 0
            elif tile in (4,5,7):
                rusty=(a*.65+b*.35)>.47
                if rusty:
                    base=(96,53,31); value=.7+.5*c; h+=c*.18
                else:
                    metal=.6; value*=.85
                if x%64<2: value*=.55; h-=.12
                if (x%64-7)**2+(y%64-7)**2<6: value=1.5; h+=.15
            elif tile in (2,6):
                value*=.7+.5*b
                h+=.15*c
            colors.append(tuple(clamp(v*value) for v in base))
            heights.append(h)
            rough.append((255,clamp((.93 if metal==0 else .7)*255),clamp(metal*255)))
    for y in range(N):
        for x in range(N):
            i=y*N+x
            dx=(heights[y*N+(x+1)%N]-heights[y*N+(x-1)%N])*1.4
            dy=(heights[((y+1)%N)*N+x]-heights[((y-1)%N)*N+x])*1.4
            length=math.sqrt(dx*dx+dy*dy+1)
            normal=(clamp(128-dx/length*127),clamp(128+dy/length*127),clamp(128+127/length))
            dst=(((tile//4)*N+y)*W+(tile%4)*N+x)*3
            color[dst:dst+3]=bytes(colors[i]); normals[dst:dst+3]=bytes(normal); orm[dst:dst+3]=bytes(rough[i])
OUT.mkdir(parents=True,exist_ok=True)
for name,data in [('albedo',color),('normal',normals),('orm',orm)]: png(OUT/f'battlefield_{name}.png',W,H,data)
print('Wrote 3 original 1024x512 atlases to',OUT)
