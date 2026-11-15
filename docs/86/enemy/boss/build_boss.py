"""Build the 40 m boss from the supplied front / side / rear reference.

Blender 5.1. All geometry and materials are created here; the reference image is
never modified. The blend keeps named editable parts and the GLB is one surface.
"""
import math
import os
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Vector

SCRIPT_DIR = Path(r'D:\repo\godot\godogen\docs\86\enemy\boss')
if '__file__' in globals() and Path(__file__).name == 'build_boss.py':
    SCRIPT_DIR = Path(__file__).resolve().parent
HERE = SCRIPT_DIR
if '--out' in sys.argv:
    HERE = Path(sys.argv[sys.argv.index('--out') + 1])
HERE.mkdir(parents=True, exist_ok=True)
if '--overwrite' not in sys.argv and any((HERE / name).exists() for name in ('boss.blend', 'boss.glb')):
    raise RuntimeError('Boss outputs exist; pass --overwrite only after preserving manual edits')

# Do not factory-reset: this also keeps the installed Blender MCP connection alive.
for obj in list(bpy.data.objects):
    bpy.data.objects.remove(obj, do_unlink=True)
scene = bpy.context.scene
scene.render.fps = 30
bpy.context.preferences.filepaths.save_version = 0
sys.path.insert(0, os.fspath(SCRIPT_DIR.parent.parent))
from blender_kit import cyl, tube, tri_count, uv_atlas  # noqa: E402


def finish_material(name, base, metal, rough):
    """Subtle procedural variation, baked to the final atlas."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    shader = nodes.get('Principled BSDF')
    shader.inputs['Metallic'].default_value = metal
    shader.inputs['Roughness'].default_value = rough
    tex = nodes.new('ShaderNodeTexNoise')
    tex.inputs['Scale'].default_value = 3.0
    tex.inputs['Detail'].default_value = 2.0
    tex.inputs['Roughness'].default_value = .55
    coord = nodes.new('ShaderNodeTexCoord')
    links.new(coord.outputs['Generated'], tex.inputs['Vector'])
    ramp = nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position = .23
    ramp.color_ramp.elements[1].position = .78
    ramp.color_ramp.elements[0].color = tuple(min(1, c*.90) for c in base) + (1,)
    ramp.color_ramp.elements[1].color = tuple(min(1, c*1.07) for c in base) + (1,)
    links.new(tex.outputs['Fac'], ramp.inputs[0])
    links.new(ramp.outputs['Color'], shader.inputs['Base Color'])
    mat.diffuse_color = tuple(base) + (1,)
    return mat

PALE = finish_material('Boss_Porcelain', (.70,.81,.88), .50,.34)
HIGHLIGHT = finish_material('Boss_WhiteEdge', (.86,.92,.97), .45,.28)
BLUE = finish_material('Boss_BlueSteel', (.26,.42,.53), .72,.33)
MID = finish_material('Boss_Slate', (.13,.23,.30), .66,.42)
DARK = finish_material('Boss_DarkFrame', (.045,.080,.110), .58,.48)
BLACK = finish_material('Boss_Vent', (.012,.022,.032), .24,.70)
SILVER = finish_material('Boss_Silver', (.43,.55,.63), .78,.27)

parts = []
root = bpy.data.objects.new('Boss_40m', None)
scene.collection.objects.link(root)
root.empty_display_type = 'CIRCLE'
root.empty_display_size = .8


def group(name, location=(0,0,0)):
    ob = bpy.data.objects.new(name, None)
    scene.collection.objects.link(ob)
    ob.parent = root
    ob.location = location
    ob.empty_display_type = 'SPHERE'
    ob.empty_display_size = .35
    bpy.context.view_layer.update()
    return ob

BODY = group('Body')
RIM = group('Rim_Spikes')
CROWN = group('Crown_And_Cannon')
SPEAR = group('Forward_Spear')
TAILS = {s: group('Tail_L' if s<0 else 'Tail_R', (s*1.45,4.4,4.7)) for s in (-1,1)}


def part(obj, name, parent=BODY):
    obj.name = name
    obj.data.name = name + '_mesh'
    bpy.context.view_layer.update()
    world = obj.matrix_world.copy()
    obj.parent = parent
    obj.matrix_world = world
    parts.append(obj)
    return obj


def mesh_part(name, vertices, faces, mat, parent=BODY, smooth=False):
    mesh = bpy.data.meshes.new(name + '_mesh')
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    bm = bmesh.new(); bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(mesh); bm.free(); mesh.update()
    mesh.materials.append(mat)
    for face in mesh.polygons: face.use_smooth = smooth
    ob = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(ob)
    return part(ob, name, parent)


def slab(name, outline, thickness, mat, parent=BODY):
    """Extrude a deliberately authored polygon vertically; source keeps broad faces."""
    n = len(outline)
    verts = [(x,y,z-thickness*.5) for x,y,z in outline] + [(x,y,z+thickness*.5) for x,y,z in outline]
    faces = [tuple(reversed(range(n))), tuple(range(n,2*n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh_part(name, verts, faces, mat, parent)


def beam(name, points, sizes, mat, parent=BODY, sides=6, hint=Vector((1,0,0)), smooth=False):
    ob = tube(name, [Vector(p) for p in points], sizes, mat, hint, n=sides,
              phase=.5 if sides==4 else 0.0, smooth=smooth, sharp=40)
    return part(ob, name, parent)


def pin(name, a, b, radius, mat, parent=BODY, sides=8, radius_tip=None):
    return part(cyl(name, a, b, radius, mat, sides, r2=radius_tip, smooth=sides>=10), name, parent)


def ellipsoid(name, center, scale, mat, parent=BODY, segments=32, rings=10):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=center)
    obj = bpy.context.object; obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    for f in obj.data.polygons: f.use_smooth = True
    return part(obj, name, parent)


def ellipse_disk(name, cx, cy, rx, ry, z, mat, parent=BODY, segments=24, slope=0):
    # Close the recess beneath its visible top, rather than leaving an open rim.
    vertices = [(cx,cy,z)]
    vertices += [(cx+rx*math.cos(2*math.pi*i/segments), cy+ry*math.sin(2*math.pi*i/segments), z+slope*math.sin(2*math.pi*i/segments))
                 for i in range(segments)]
    vertices += [(cx,cy,z-.12)]
    vertices += [(x,y,height-.12) for x,y,height in vertices[1:segments+1]]
    bottom = segments+1
    faces=[]
    for i in range(segments):
        j=(i+1)%segments
        faces.extend([(0,1+i,1+j),(bottom,bottom+1+j,bottom+1+i),
                      (1+i,bottom+1+i,bottom+1+j,1+j)])
    return mesh_part(name, vertices, faces, mat, parent)


def ellipse_ring(name, cx, cy, outer, inner, z, thickness, mat, parent=BODY, segments=32, slope=0):
    """A closed annular armor band; the height changes slightly from front to back."""
    vertices=[]
    for rx,ry,dz in ((outer[0],outer[1],0),(inner[0],inner[1],0),
                      (outer[0],outer[1],-thickness),(inner[0],inner[1],-thickness)):
        for i in range(segments):
            a=2*math.pi*i/segments
            vertices.append((cx+rx*math.cos(a), cy+ry*math.sin(a), z+dz+slope*math.sin(a)))
    n=segments; faces=[]
    for i in range(n):
        j=(i+1)%n
        faces += [(i,j,n+j,n+i), (2*n+i,3*n+i,3*n+j,2*n+j),
                  (i,2*n+i,2*n+j,j), (n+i,n+j,3*n+j,3*n+i)]
    return mesh_part(name, vertices, faces, mat, parent, smooth=False)

# Main flattened hull, dark lower workings, and large layered armored shell.
ellipsoid('Armoured_Core', (0,.1,3.2), (5.6,6.2,1.55), PALE, segments=32, rings=12)
ellipsoid('Lower_Chassis', (0,.1,2.55), (5.0,5.4,.8), DARK, segments=28, rings=8)

# Back shell's raised central armor, assembled in separate facets.
slab('Rear_Central_Deck', [(-1.6,.7,5.05),(-1.7,3.8,5.55),(-.85,5.55,6.1),
                           (0,5.95,6.35),(.85,5.55,6.1),(1.7,3.8,5.55),(1.6,.7,5.05)], .35, PALE)
slab('Rear_Ridge', [(-.42,1.4,5.55),(-.5,4.7,6.1),(0,6.1,6.55),(.5,4.7,6.1),(.42,1.4,5.55)], .12, HIGHLIGHT)
for side in (-1,1):
    slab(f'Rear_Shoulder_{side}', [(side*.65,2.2,5.6),(side*1.8,2.0,5.45),
         (side*2.65,4.0,5.0),(side*1.5,5.6,5.8),(side*.65,4.6,6.15)], .22, PALE)
    for i in range(3):
        x=side*(.65 + .35*(i%2)); y=2.6+i*.68; z=5.76+i*.11
        pin(f'Rear_Vent_{side}_{i}', (x,y,z),(x,y,z+.04), .14, BLACK, sides=8)

# The raised pale ring, its recessed dark interior, radial ribs and front cannon.
ellipse_disk('Crown_Recess',0,-.35,2.25,3.9,5.10,BLACK,CROWN,segments=32,slope=.95)
ellipse_ring('Crown_InnerRim',0,-.35,(2.45,4.15),(2.23,3.88),5.28,.18,BLUE,CROWN,segments=32,slope=1.00)
ellipse_ring('Crown_WhiteRing',0,-.35,(3.55,5.15),(2.48,4.18),5.65,.36,HIGHLIGHT,CROWN,segments=32,slope=1.25)
for i in range(24):
    a=2*math.pi*i/24
    inner=(.68*math.cos(a),-.35+1.10*math.sin(a),5.12+.268*math.sin(a))
    outer=(2.20*math.cos(a),-.35+3.85*math.sin(a),5.12+.938*math.sin(a))
    pin(f'Crown_Rib_{i:02d}',inner,outer,.055,SILVER,CROWN,sides=4)
pin('Cannon_Mount',(0,-.55,5.05),(0,-.55,5.85),.42,DARK,CROWN,sides=8)
beam('Cannon_UpperShell',[(0,.0,6.0),(0,-1.7,5.9),(0,-2.55,5.7)],
     [(1.30,1.05),(1.05,.92),(.95,.82)],PALE,CROWN,sides=8)
pin('Cannon_Barrel',(0,-1.8,5.78),(0,-3.65,5.58),.43,MID,CROWN,sides=12)
pin('Cannon_MuzzleRing',(0,-3.62,5.59),(0,-3.78,5.57),.52,SILVER,CROWN,sides=16)
pin('Cannon_MuzzleBlack',(0,-3.78,5.57),(0,-3.795,5.568),.34,BLACK,CROWN,sides=16)

# Slender forward weapon: tip at -20 m, continuous visual line from the ring.
beam('Forward_Lance',[(0,-6.5,5.12),(0,-9.0,4.78),(0,-14.5,4.22),(0,-20.0,3.82)],
     [(1.25,.60),(1.12,.46),(.58,.24),(.025,.025)],PALE,SPEAR,sides=4)
beam('Lance_DarkInset',[(0,-7.0,5.30),(0,-10.0,4.86),(0,-17.8,4.03),(0,-19.92,3.84)],
     [(.33,.075),(.30,.065),(.13,.035),(.012,.012)],MID,SPEAR,sides=4)

# Continuous swept side armor bands retain the light silhouette around the vents.
def wing_band(side):
    ys = [-5.9,-5.0,-3.8,-2.2,-.4,1.4,3.0,4.4,5.5]
    outer=[]; inner=[]
    for y in ys:
        x=5.85*math.sqrt(max(.13,1-(y/6.8)**2))
        outer.append((side*x,y,3.55+.16*y/5.5))
        inner.append((side*(x-1.20),y,4.25+.16*y/5.5))
    n=len(ys); thickness=.25
    verts=outer+inner+[(x,y,z-thickness) for x,y,z in outer+inner]
    faces=[]
    for i in range(n-1):
        j=i+1
        faces += [(i,j,n+j,n+i),(2*n+i,3*n+i,3*n+j,2*n+j),
                  (i,2*n+i,2*n+j,j),(n+i,n+j,3*n+j,3*n+i)]
    faces += [(0,n,3*n,2*n),(n-1,2*n-1,4*n-1,3*n-1)]
    mesh_part(f'Wing_SweptOuterBand_{side}',verts,faces,PALE)
for side in (-1,1): wing_band(side)

# Paired wing vents and concentric ribs, overlaid with distinct white fin plates.
for side in (-1,1):
    x=side*3.45
    ellipse_disk(f'WingVent_{side}',x,-.25,1.65,2.8,5.05,BLACK,segments=28,slope=.66)
    ellipse_ring(f'WingVent_Rim_{side}',x,-.25,(1.82,3.0),(1.60,2.76),5.17,.12,BLUE,segments=28,slope=.66)
    for i in range(16):
        a=2*math.pi*i/16
        p0=(x+.38*math.cos(a),-.25+.62*math.sin(a),5.06+.146*math.sin(a))
        p1=(x+1.57*math.cos(a),-.25+2.70*math.sin(a),5.06+.636*math.sin(a))
        pin(f'WingVent_Rib_{side}_{i:02d}',p0,p1,.060,SILVER,sides=4)
    # Structural spar intersects the body and the roots of the outer plates.
    beam(f'Wing_InnerSupport_{side}',[(side*2.9,-5.1,3.8),(side*3.55,-3.4,4.42),
         (side*4.0,0,4.48),(side*3.6,3.2,4.55),(side*2.5,5.0,4.55)],
         [(.86,.72),(.86,.72),(.86,.72),(.86,.72),(.86,.72)],MID,sides=6)
    # Five overlapping vanes, shaped as broad, thin quads rather than tiny fasteners.
    for i in range(5):
        y=-4.10+i*1.92
        span=math.sqrt(max(.25,1-(y/6.7)**2))
        outer=5.35*span
        inner=2.25+.24*abs(y)
        profile=[(side*inner,y+.85,4.68),(side*(inner+.65),y+1.18,4.98),
                 (side*(outer+.25),y+.52,4.53),(side*(outer+.48),y-1.32,3.96),
                 (side*(outer-.38),y-.50,4.08),(side*(inner+.18),y-.45,4.42)]
        slab(f'Wing_Armour_{side}_{i:02d}',profile,.22,PALE)
        # Seat the highlight into the underlying plate/spar even at the tapered tip.
        edge=[(side*(inner+.15),y+.78,4.88),(side*(outer+.25),y+.40,4.44),
              (side*(outer+.04),y+.20,4.38),(side*(inner+.10),y+.52,4.80)]
        slab(f'Wing_WhiteRidge_{side}_{i:02d}',edge,.06,HIGHLIGHT)

# Closed rim rail seats the roots of the skirt needles inside a solid part.
ellipse_ring('Rim_SpineRail',0,0,(5.60,7.30),(4.55,6.35),2.98,.43,MID,RIM,segments=48)
# Outer needles. Their varying lengths form the reference's broad jagged skirt.
for side in (-1,1):
    for i in range(25):
        y=-5.5+11.0*i/24
        x=5.45*math.sqrt(max(.20,1-(y/7.1)**2))
        root=(side*x,y,2.74 + .10*math.cos(i*.7))
        end=(side*(x+1.65+.42*math.cos(i*.48)),y-.42, .04+.32*(i%3)/2)
        pin(f'Rim_Needle_{side}_{i:02d}',root,end,.105,SILVER,RIM,sides=4,radius_tip=.009)
        # A shorter rib behind each large needle is still visible at gameplay range.
        if i%2==0:
            end2=(side*(x+1.22),y+.24,.55)
            pin(f'Rim_ShortNeedle_{side}_{i:02d}',(side*(x-.1),y+.17,2.68),end2,.065,MID,RIM,sides=4,radius_tip=.008)
# Forward underside ribs distribute the points across the front silhouette.
for i in range(-8,9):
    x=i*.53
    start=(x,-5.20+.12*abs(x),2.85)
    end=(x*1.10,-6.25+.10*abs(x),.16+.12*(abs(i)%3))
    pin(f'Front_Skirt_Needle_{i:+03d}',start,end,.075,SILVER,RIM,sides=4,radius_tip=.008)
# Central fangs make the front projection's paired vertical spear silhouette.
for side in (-1,1):
    beam(f'Ventral_Fang_{side}',[(side*.35,-5.05,5.00),(side*.28,-5.52,2.10),(side*.19,-5.85,.04)],
         [(.60,.34),(.40,.23),(.025,.025)],HIGHLIGHT,RIM,sides=4)

# Two armored, rising segmented tails. Their rise is a compromise between the
# perspective side image and the tall rear silhouettes in the supplied sheet.
for side in (-1,1):
    tail=TAILS[side]
    def tail_point(t):
        return Vector((side*(1.45+.48*t), 4.4+14.55*t, 4.70+3.25*t))
    p0,p1=tail_point(0),tail_point(1)
    beam(f'Tail_Mount_{side}',[(side*.90,2.2,4.1),(side*1.45,4.8,4.75)],
         [(1.3,1.0),(1.3,1.0)],MID,tail,sides=8)
    beam(f'Tail_Core_{side}',[p0,p1],[(1.18,.82),(.85,.64)],DARK,tail,sides=8,smooth=True)
    for i in range(16):
        t0=(i+.08)/16; t1=(i+.88)/16; tm=(t0+t1)*.5
        a,b=tail_point(t0),tail_point(t1)
        mid=a.lerp(b,.5)+Vector((0,0,.10))
        w=1.23-.35*tm; h=.84-.20*tm
        beam(f'Tail_Scale_{side}_{i:02d}',[a,mid,b],[(w*.92,h*.90),(w,h),(w*.80,h*.78)],
             PALE,tail,sides=6)
        if i%1==0:
            origin=tail_point((i+.48)/16)+Vector((side*(w*.28),0,-h*.08))
            tip=origin+Vector((side*(.65+.18*(1-tm)),.32,-.45))
            pin(f'Tail_Rib_{side}_{i:02d}',origin,tip,.07,SILVER,tail,sides=4,radius_tip=.008)
    end=tail_point(1)
    # Flat arrow fins and a central tip reach exactly y=20 m.
    beam(f'Tail_Arrow_{side}',[end,(side*1.97,19.45,8.08),(side*2.00,20.0,8.24)],
         [(.98,.64),(1.35,.42),(.04,.04)],BLUE,tail,sides=4)
    for wing in (-1,1):
        slab(f'Tail_ArrowWing_{side}_{wing}',[(side*1.95,18.7,8.05),
             (side*1.95+wing*.92,19.18,8.13),(side*1.95+wing*1.25,19.9,8.25),
             (side*1.95,19.56,8.18)],.12,PALE,tail)

# The supplied side view has a long armored midsection. Stretch that coherent
# subassembly together; tail bases and the 40 m end points remain fixed.
from mathutils import Matrix
long_body = Matrix.Translation((0,-1.2,0)) @ Matrix.Diagonal((1,1.32,1,1))
bpy.context.view_layer.update()
for ob in parts:
    if ob.parent in (BODY, RIM, CROWN):
        ob.matrix_world = long_body @ ob.matrix_world
bpy.context.view_layer.update()

print('BOSS_GEOMETRY', 'parts',len(parts),'triangles',tri_count(parts))
if '--save-source' in sys.argv:
    bpy.ops.wm.save_as_mainfile(filepath=os.fspath(HERE / 'boss.blend'))
