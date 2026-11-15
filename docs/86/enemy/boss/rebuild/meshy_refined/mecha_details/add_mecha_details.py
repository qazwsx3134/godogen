"""Add straight-edged mechanical details to the saved Meshy-reference Boss.

The source is opened separately; this script saves a new .blend and refuses to
replace an existing output unless --overwrite is explicitly supplied.
"""
import math
import os
import sys
from pathlib import Path

import bpy
from mathutils import Vector

HERE = Path(r'D:\repo\godot\godogen\docs\86\enemy\boss\rebuild\meshy_refined\mecha_details')
if '__file__' in globals() and Path(__file__).name == 'add_mecha_details.py':
    HERE = Path(__file__).resolve().parent
OUTPUT=HERE/'boss_mecha.blend'
if OUTPUT.exists() and '--overwrite' not in sys.argv:
    raise RuntimeError('Mecha output exists: preserve edits or pass --overwrite')
if Path(bpy.data.filepath).name != 'boss_meshy_refined.blend':
    raise RuntimeError('Open boss_meshy_refined.blend first')
sys.path.insert(0,os.fspath(HERE.parents[1]))
from boss_geometry import Builder  # noqa: E402

b=Builder.__new__(Builder)
b.scene=bpy.context.scene
b.root=bpy.data.objects['Boss_40m']
b.parts=[]
body=bpy.data.objects['Body_Module']
yokes=bpy.data.objects['Forward_Yokes']
cannon=bpy.data.objects['Cannon_Module']
white=bpy.data.materials['V2_Ice_White']
silver=bpy.data.materials['V2_Armor_Silver']
dark=bpy.data.materials['V2_Blue_Steel']
frame=bpy.data.materials['V2_Inner_Frame']
bright=bpy.data.materials['V2_Bright_Metal']


def bar(name, start, end, width, height, material, parent):
    """Straight-edged rectangular bar with closed ends, in world coordinates."""
    a,c=Vector(start),Vector(end)
    axis=(c-a).normalized()
    helper=Vector((0,0,1)) if abs(axis.z)<.95 else Vector((1,0,0))
    across=axis.cross(helper).normalized()*width*.5
    up=axis.cross(across).normalized()*height*.5
    vertices=[]
    for p in (a,c):
        vertices.extend((p-across-up,p+across-up,p+across+up,p-across+up))
    faces=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    return b.mesh(name,vertices,faces,material,parent)


# Angular seam rails track the inside of the curved yokes in straight segments.
# Each segment is sunk into the parent shell; its corners stay visibly faceted.
stations=[(.40,-16.5,4.12,.12,.11),(.64,-12.7,4.42,.19,.15),
          (.97,-9.1,4.90,.30,.18),(1.55,-6.3,5.56,.44,.23),
          (2.28,-4.0,6.20,.56,.28),(2.86,-1.6,6.90,.61,.34),
          (2.92,.8,7.30,.59,.36),(2.50,2.8,7.35,.52,.31),
          (1.65,4.20,7.04,.39,.23),(.66,4.93,6.73,.28,.17)]
for side in (-1,1):
    points=[]
    for x,y,z,w,h in stations:
        amount=max(0.0,min(1.0,(-y-7.0)/7.0))
        points.append((side*(x-w*.23)*(1+.26*amount),y,z+h*.92))
    for i in range(len(points)-1):
        bar(f'Mecha_Yoke_Long_Seam_{side}_{i:02d}',points[i],points[i+1],.090,.080,dark,yokes)
    for i in range(2,len(stations)-1):
        x,y,z,w,h=stations[i]
        amount=max(0.0,min(1.0,(-y-7.0)/7.0))
        seam_x=x-w*.23
        edge_x=x+(w*.52 if i%2 else -w*.52)
        p=(side*seam_x*(1+.26*amount),y,z+h*.96)
        q=(side*edge_x*(1+.26*amount),y,z+h*.96)
        bar(f'Mecha_Yoke_Cross_Seam_{side}_{i:02d}',p,q,.072,.075,dark,yokes)

# Long double rails on the lance turn the smooth nose into a layered blade.
for side in (-1,1):
    sections=[(-18.0,4.13,.13),(-14.0,4.46,.23),(-10.0,4.89,.32),
              (-7.25,5.34,.45)]
    for i in range(len(sections)-1):
        y0,z0,x0=sections[i];y1,z1,x1=sections[i+1]
        bar(f'Mecha_Lance_Rail_{side}_{i}',(side*x0,y0,z0),(side*x1,y1,z1),
            .095,.085,dark,yokes)

# Straight mechanical panel lines follow each wing's swept outer armor.
for side in (-1,1):
    path=[(3.55,-5.20,5.56),(4.12,-4.10,5.68),(4.65,-2.60,5.81),
          (4.88,-.70,5.96),(4.77,1.05,6.10),(4.31,2.70,6.25),
          (3.60,4.00,6.33)]
    path=[(side*x,y,z+.10) for x,y,z in path]
    for i in range(len(path)-1):
        bar(f'Mecha_Wing_Armor_Rail_{side}_{i:02d}',path[i],path[i+1],.13,.11,dark,body)
    # Brushed-metal rectangular rib segments cross the darker panel gaps.
    for i in range(6):
        y=-4.35+i*1.45
        falloff=max(.32,1.0-((y-.05)/8.2)**2)
        edge=5.30*math.sqrt(falloff)
        z=5.48+.08*(y+5.2)
        p=(side*(edge-1.20),y-.28,z+.11)
        q=(side*(edge-.35),y+.20,z+.11)
        bar(f'Mecha_Wing_Armor_Joint_{side}_{i:02d}',p,q,.11,.095,dark,body)
        # A short inset next to alternate joints reads as a mechanical latch.
        if i%2==0:
            bar(f'Mecha_Wing_Latch_{side}_{i:02d}',
                (side*(edge-.66),y-.43,z+.16),(side*(edge-.32),y-.24,z+.16),
                .085,.085,bright,body)

# Fine axial struts and an angular rim reveal construction around the rotor.
# They live in the dark recess rather than crossing the spinning fan visually.
for side in (-1,1):
    for lane in range(2):
        x=side*(.52+lane*.52)
        bar(f'Mecha_Center_Strut_{side}_{lane}',(x,-5.45,5.40),(x*1.27,-3.55,5.65),
            .12,.12,bright,body)
    for i in range(3):
        y=-5.0+i*.42
        bar(f'Mecha_Center_Grille_{side}_{i}',(side*.44,y,5.46+i*.055),
            (side*1.28,y+.05,5.46+i*.055),.080,.09,frame,body)

# Flat hard-edged rails and cross-straps reinforce the central cannon housing.
for side in (-1,1):
    bar(f'Mecha_Cannon_Top_Rail_{side}',(side*.21,-1.13,7.51),
        (side*.31,.70,7.71),.095,.085,dark,cannon)
    for i in range(3):
        y=-.65+i*.55
        bar(f'Mecha_Cannon_Plate_Joint_{side}_{i}',(side*.18,y,7.63),
            (side*.46,y+.09,7.57),.075,.075,bright,cannon)

# Two longitudinal side rails and periodically repeated straight couplings on
# each tail preserve the tapered silhouette while making its construction clear.
for side in (-1,1):
    group=bpy.data.objects['Tail_Left_Module' if side<0 else 'Tail_Right_Module']
    def center(t):
        return side*(1.30+.58*t),4.9+14.25*t,6.45+2.15*t
    for inner in (-1,1):
        x0,y0,z0=center(0);x1,y1,z1=center(1)
        bar(f'Mecha_Tail_Side_Rail_{side}_{inner}',
            (x0+inner*.60,y0,z0+.32),(x1+inner*.40,y1,z1+.32),
            .115,.115,dark,group)
    for i in range(1,17,2):
        t=(i+.42)/17
        x,y,z=center(t);w=.70-.23*t
        bar(f'Mecha_Tail_Armor_Seam_{side}_{i:02d}',
            (x-w*.55,y,z+.48),(x+w*.55,y,z+.48),.075,.085,dark,group)

bpy.context.view_layer.update()
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
triangles=sum(len(face.vertices)-2 for obj in meshes for face in obj.data.polygons)
print('MECHA_DETAIL_BUILD','new_parts',len(b.parts),'parts',len(meshes),'triangles',triangles)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=os.fspath(OUTPUT))
print('MECHA_DETAIL_SAVED',OUTPUT)
