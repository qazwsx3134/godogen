"""Create an editable refinement of boss_v2.blend using the Meshy screenshots.

Run with the v2 source open. This never overwrites that source; an existing
refined source is protected unless --overwrite is explicitly supplied.
"""
import math
import os
import sys
from pathlib import Path

import bpy
from mathutils import Vector

HERE = Path(r'D:\repo\godot\godogen\docs\86\enemy\boss\rebuild\meshy_refined')
if '__file__' in globals() and Path(__file__).name == 'refine_boss.py':
    HERE = Path(__file__).resolve().parent
OUT = HERE / 'boss_meshy_refined.blend'
if OUT.exists() and '--overwrite' not in sys.argv:
    raise RuntimeError('Refined file already exists; preserve edits or pass --overwrite')
if Path(bpy.data.filepath).name != 'boss_v2.blend':
    raise RuntimeError('Open boss_v2.blend first, leaving the original source unchanged')
sys.path.insert(0, os.fspath(HERE.parent))
from boss_geometry import Builder, curved  # noqa: E402

b = Builder.__new__(Builder)  # Reuse the saved scene without calling the scene-clearing constructor.
b.scene = bpy.context.scene
b.root = bpy.data.objects.get('Boss_40m')
b.parts, b.groups = [], {}
if not b.root:
    raise RuntimeError('Missing Boss_40m parent')
for key, material_name in [('white','V2_Ice_White'),('pale','V2_Armor_Silver'),
                           ('blue','V2_Blue_Steel'),('frame','V2_Inner_Frame'),
                           ('black','V2_Recess'),('steel','V2_Bright_Metal')]:
    setattr(b,key,bpy.data.materials[material_name])

# The reference has cool polished metal and dark recesses, not matte white bars.
for material, color, metallic, roughness in [
    (b.white,(.78,.87,.94,1),.30,.30),
    (b.pale,(.62,.75,.84,1),.42,.31),
    (b.steel,(.57,.70,.78,1),.50,.27),
    (b.blue,(.19,.32,.41,1),.46,.34),
    (b.frame,(.045,.075,.105,1),.48,.4),
]:
    shader = material.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = color
    shader.inputs['Metallic'].default_value = metallic
    shader.inputs['Roughness'].default_value = roughness
    material.diffuse_color = color

# Widen the long front slightly, but preserve the U-shaped rim and 40 m length.
for name in ('Forward_Lance_Inner_Blade','Forward_Lance_Dark_Spine',
             'Yoke_Continuous_-1','Yoke_Continuous_1',
             'Yoke_Inner_Trim_-1','Yoke_Inner_Trim_1'):
    obj = bpy.data.objects.get(name)
    if not obj:
        raise RuntimeError('Missing expected source object: '+name)
    for vertex in obj.data.vertices:
        y = vertex.co.y
        amount = max(0.0, min(1.0, (-y-7.0)/7.0))
        vertex.co.x *= 1.0 + .26*amount
    obj.data.update()

# Broad pointed plates replace the v2 tail's rounded rectangular scales.
removed = 0
for obj in list(bpy.data.objects):
    if obj.name.startswith(('Tail_Armor_Scale_','Tail_Scale_Splice_',
                            'Tail_Arrow_Center_','Tail_Arrow_Wing_',
                            'Crown_Recess_Rib_')):
        bpy.data.objects.remove(obj,do_unlink=True)
        removed += 1

def folded(name, outline, peak, thickness, mat, parent):
    """Closed faceted armor with a raised centre, not a flat decal."""
    n = len(outline)
    verts = list(outline) + [peak] + [(x,y,z-thickness) for x,y,z in outline]
    faces = [(i,(i+1)%n,n) for i in range(n)]
    faces.append(tuple(reversed([n+1+i for i in range(n)])))
    faces.extend((i,(i+1)%n,n+1+(i+1)%n,n+1+i) for i in range(n))
    return b.mesh(name, verts, faces, mat, parent)

# Silvery and darker layers overlap along each wing, with distinct sharp corners.
body = bpy.data.objects['Body_Module']
for side in (-1,1):
    for layer in range(2):
        for i in range(7):
            y = -5.2 + i*1.55 + layer*.53
            falloff = max(.32, 1.0 - ((y-.05)/8.2)**2)
            edge = 5.30 * math.sqrt(falloff)
            z = 5.48 + .08*(y+5.2) - layer*.25
            x0 = edge - (1.42 if layer == 0 else .57)
            x1 = edge + (.20 if layer == 0 else .40)
            # The plate tips sweep towards the rear rather than forming bars.
            points = [(side*x0,y-1.13,z), (side*(x0+.78),y-1.05,z+.03),
                      (side*(x1+.27),y-.42,z-.04), (side*x1,y+.48,z),
                      (side*(x0+.45),y+.91,z+.06), (side*(x0-.10),y+.23,z+.02)]
            crest=(side*((x0+x1)*.52),y-.05,z+.11)
            folded(f'Meshy_Wing_Plate_{side}_{layer}_{i:02d}',points,crest,.10,
                   b.white if layer == 0 and i%3 != 1 else b.pale,body)
            # A short inset gives a dark mechanical seam between the armor pieces.
            if layer == 0:
                b.rod(f'Meshy_Wing_Seam_{side}_{i:02d}',
                      (side*(x0+.32),y-.73,z+.12),
                      (side*(x1-.05),y-.22,z+.10),.038,b.blue,body,sides=6)
    # Long, overlapping polished strips keep the wing silhouettes flowing.
    for lane in range(2):
        d=lane*.50
        stations=[(side*(3.05+d*.3),-6.2,5.38,.04,.05),
                  (side*(4.10+d*.5),-4.5,5.65,.20,.10),
                  (side*(4.80+d*.5),-2.0,5.82,.25,.12),
                  (side*(4.90+d*.4),.40,6.00,.25,.12),
                  (side*(4.20+d*.4),2.95,6.26,.20,.10),
                  (side*(3.25+d*.2),4.55,6.35,.035,.045)]
        b.beveled_band(f'Meshy_Long_Swept_Shell_{side}_{lane}',
                       curved(stations,2),b.white if lane==0 else b.pale,body)
    # Slender silver panels give the massive central body layered shoulders.
    for i in range(4):
        y=1.50+i*.77
        x=.75+i*.35
        z=6.62-i*.065
        pts=[(side*(x-.30),y-.80,z),(side*(x+.24),y-.80,z+.05),
             (side*(x+1.08),y+.10,z-.04),(side*(x+.92),y+.74,z-.07),
             (side*(x+.12),y+.33,z+.04)]
        folded(f'Meshy_Rear_Shoulder_{side}_{i}',pts,
               (side*(x+.38),y,z+.20),.14,b.white if i%2==0 else b.pale,body)

# Rebuild the toothed, overlapping armor on the two editable tail assemblies.
for side in (-1,1):
    group=bpy.data.objects['Tail_Left_Module' if side < 0 else 'Tail_Right_Module']
    def center(t):
        return side*(1.30+.58*t), 4.9+14.25*t, 6.45+2.15*t
    for i in range(17):
        t0=max(0,(i-.04)/17); tm=(i+.45)/17; t1=min(1,(i+1.10)/17)
        x0,y0,z0=center(t0); x1,y1,z1=center(t1); xm,ym,zm=center(tm)
        w=.83-.29*tm
        points=[(x0-w*.90,y0,z0+.27),(x0+w*.90,y0,z0+.27),
                (xm+w,ym,zm+.30),(x1+w*.52,y1-.09,z1+.29),
                (x1,y1+.14,z1+.32),(x1-w*.52,y1-.09,z1+.29),
                (xm-w,ym,zm+.30)]
        folded(f'Meshy_Tail_Scale_{side}_{i:02d}',points,(xm,ym,zm+.57),.14,
               b.white if i%4 == 0 else b.pale,group)
        # An outward-pointing triangular tooth echoes the spines in the photo.
        s=side
        rootx=xm+s*w*.70
        tooth=[(rootx,ym-.35,zm+.04),(rootx+s*.20,ym-.19,zm+.08),
               (rootx+s*.78,ym+.55,zm-.22),(rootx+s*.03,ym+.31,zm-.20)]
        folded(f'Meshy_Tail_Tooth_{side}_{i:02d}',tooth,
               (rootx+s*.18,ym+.06,zm+.12),.10,b.steel,group)
    ex,ey,ez=center(1)
    tip=[(ex-.47,ey-.85,ez+.12),(ex+.47,ey-.85,ez+.12),
         (ex+.78,ey-.17,ez+.18),(ex+.40,ey+.20,ez+.20),
         (ex,19.99,ez+.14),(ex-.40,ey+.20,ez+.20),(ex-.78,ey-.17,ez+.18)]
    folded(f'Meshy_Tail_Arrow_{side}',tip,(ex,ey-.18,ez+.47),.22,b.white,group)
    b.rod(f'Meshy_Tail_Arrow_Seam_{side}',(ex,ey-.52,ez+.48),
          (ex,19.80,ez+.22),.042,b.blue,group,sides=6,radius_end=.012)

# Make the existing needle-like radial legs more legible from a game camera.
for obj in bpy.data.objects:
    if obj.type != 'MESH' or not obj.name.startswith('Leg_Primary_'):
        continue
    verts=obj.data.vertices
    if len(verts) != 10:
        continue
    for first,factor in ((0,1.5),(5,1.15)):
        center=sum((verts[first+j].co for j in range(5)),Vector())/5
        for j in range(5):
            vertex=verts[first+j]
            vertex.co=center+(vertex.co-center)*factor
    obj.data.update()

def ellipse_ring(name,cx,cy,z,rx,ry,mat,parent):
    # Four profile rows close the ring and give it a narrow bevel.
    n=40
    profile=[(.80,-.06),(1.00,-.06),(1.00,.06),(.80,.06)]
    verts=[(cx+rx*r*math.cos(2*math.pi*i/n),
            cy+ry*r*math.sin(2*math.pi*i/n),z+dz)
           for r,dz in profile for i in range(n)]
    faces=[]
    for row in range(len(profile)):
        nextrow=(row+1)%len(profile)
        for i in range(n):
            j=(i+1)%n
            faces.append((row*n+i,row*n+j,nextrow*n+j,nextrow*n+i))
    return b.mesh(name,verts,faces,mat,parent,smooth=True)

def turbine(name,z,up,cy):
    cx=0.0
    parent=body
    ellipse_ring(name+'_Rim',cx,cy,z,1.76,2.03,b.steel,parent)
    b.rod(name+'_Hub',(cx,cy,z-.24),(cx,cy,z+.12),.38,b.frame,parent,sides=20)
    if up:
        b.rod(name+'_Center_Pylon',(cx,cy,z-.75),(cx,cy,z+.02),.23,b.frame,parent,sides=10)
    for i in range(18):
        a=2*math.pi*i/18
        def point(rad,angle,extra):
            return (cx+1.69*rad*math.cos(angle),cy+1.96*rad*math.sin(angle),z+extra)
        outline=[point(.23,a,-.015),point(.43,a-.16,.0),
                 point(.96,a-.21,.0),point(.90,a+.03,.0),point(.38,a+.20,.0)]
        peak=point(.64,a-.01,.10 if up else -.10)
        folded(f'{name}_Vane_{i:02d}',outline,peak,.075 if up else -.075,b.pale if i%3==0 else b.blue,parent)

# Two independent rotors correspond to the screenshots of the top and underside.
turbine('Meshy_Top_Turbine',6.24,True,-2.15)
turbine('Meshy_Underside_Turbine',2.47,False,-.25)
ellipse_ring('Meshy_Underside_Outer_Armor',0,-.25,2.50,2.75,3.2,b.pale,body)


bpy.context.view_layer.update()
all_meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
triangles=sum(len(p.vertices)-2 for o in all_meshes for p in o.data.polygons)
print('MESHY_REFINEMENT', 'removed',removed,'added',len(b.parts),'meshes',len(all_meshes),
      'triangles',triangles)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=os.fspath(OUT))
print('MESHY_REFINEMENT_SAVED',OUT)
