"""Make an editable low-poly Phido from measured reference proportions.

All geometry is constructed here; no mesh or texture is copied from the reference.
Run explicitly in Blender 5.1. Pass --overwrite to replace existing output files.
"""
import math
import os
import struct
import zlib
from pathlib import Path
import sys

import bpy
import bmesh
from mathutils import Vector

if '--out' in sys.argv:
    OUT = Path(sys.argv[sys.argv.index('--out') + 1])
elif '__file__' in globals() and Path(__file__).name == 'build_phido.py':
    OUT = Path(__file__).resolve().parent
else:
    OUT = Path(r'D:\repo\godot\godogen\docs\86\phido\lowpoly_v2')
OUT.mkdir(parents=True, exist_ok=True)
if '--overwrite' not in sys.argv and any((OUT / name).exists() for name in
        ('phido_lowpoly.blend', 'phido_lowpoly.glb', 'phido_palette.png')):
    raise RuntimeError('Existing low-poly outputs found; pass --overwrite to replace them')
for obj in list(bpy.data.objects):
    bpy.data.objects.remove(obj, do_unlink=True)
scene = bpy.context.scene
scene.render.fps = 30
bpy.context.preferences.filepaths.save_version = 0

# Colours are in sRGB, sampled to match the reference's painted panels and frame.
COLOURS = {
    'paint': (0.87, 0.60, 0.27, 1),
    'paint_edge': (0.76, 0.49, 0.21, 1),
    'paint_inset': (0.83, 0.55, 0.23, 1),
    'seam': (0.35, 0.23, 0.11, 1),
    'frame': (0.19, 0.20, 0.21, 1),
    'frame_light': (0.28, 0.29, 0.29, 1),
    'black': (0.105, 0.11, 0.115, 1),
    'rubber': (0.075, 0.08, 0.085, 1),
    'blue': (0.15, 0.17, 0.37, 1),
    'glass': (0.32, 0.36, 0.35, 1),
    'lens': (0.50, 0.055, 0.04, 1),
}
# A compact, embedded colour atlas keeps every part in one Godot material.
# Each swatch has padding so filtered samples do not bleed into neighbouring colours.
def png_chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)

palette_names = list(COLOURS)
raw = bytearray()
for y in range(128):
    raw.append(0)  # PNG scanline: no filter
    for x in range(128):
        # Blender UV origin is at the bottom left; PNG rows start at the top.
        index = (3 - y // 32) * 4 + x // 32
        tint = COLOURS[palette_names[index]] if index < len(palette_names) else (0, 0, 0, 1)
        raw.extend(round(value * 255) for value in tint)
png = (b'\x89PNG\r\n\x1a\n' + png_chunk(b'IHDR', struct.pack('>IIBBBBB', 128, 128, 8, 6, 0, 0, 0))
       + png_chunk(b'IDAT', zlib.compress(bytes(raw), 9)) + png_chunk(b'IEND', b''))
palette_path = OUT / 'phido_palette.png'
palette_path.write_bytes(png)
image = bpy.data.images.load(os.fspath(palette_path), check_existing=False)
image.name = 'Phido_Palette'
image.pack()
material = bpy.data.materials.new('Phido_Palette_PBR')
material.use_nodes = True
nodes = material.node_tree.nodes
bsdf = nodes.get('Principled BSDF')
bsdf.inputs['Roughness'].default_value = 0.55
bsdf.inputs['Metallic'].default_value = 0.12
texture = nodes.new('ShaderNodeTexImage')
texture.image = image
material.node_tree.links.new(texture.outputs['Color'], bsdf.inputs['Base Color'])

root = bpy.data.objects.new('Phido', None)
scene.collection.objects.link(root)
parts = []

def attach(obj, name, tint, parent=None, smooth=False):
    obj.name = name
    obj.data.name = name + '_mesh'
    obj.data.materials.clear()
    obj.data.materials.append(material)
    # Project each face into its colour swatch; unlike a single UV point this
    # keeps non-degenerate UVs and leaves space around every swatch.
    mesh = obj.data
    uv = mesh.uv_layers.get('UVMap') or mesh.uv_layers.new(name='UVMap')
    index = palette_names.index(tint)
    tile_x, tile_y = index % 4, index // 4
    bounds = [(min(v.co[i] for v in mesh.vertices), max(v.co[i] for v in mesh.vertices)) for i in range(3)]
    for face in mesh.polygons:
        axis = max(range(3), key=lambda i: abs(face.normal[i]))
        uv_axes = [i for i in range(3) if i != axis]
        for li in face.loop_indices:
            point = mesh.vertices[mesh.loops[li].vertex_index].co
            factors = []
            for component in uv_axes:
                lo, hi = bounds[component]
                factors.append((point[component] - lo) / (hi - lo) if hi - lo > 1e-8 else 0.5)
            uv.data[li].uv = ((tile_x + 0.10 + 0.80 * factors[0]) / 4,
                              (tile_y + 0.10 + 0.80 * factors[1]) / 4)
    for face in obj.data.polygons:
        face.use_smooth = smooth
    bpy.context.view_layer.update()
    world = obj.matrix_world.copy()
    obj.parent = parent or root
    obj.matrix_world = world
    parts.append(obj)
    return obj


def apply_bevel(obj, amount):
    if not amount:
        return
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bevel = obj.modifiers.new('Single bevel', 'BEVEL')
    bevel.width = amount
    bevel.segments = 1
    bpy.ops.object.modifier_apply(modifier=bevel.name)


def recalc(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()


def box(name, center, size, tint, bevel=0.0, parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    apply_bevel(obj, bevel)
    return attach(obj, name, tint, parent)


def prism_xy(name, outline, bottom, top, tint, bevel=0.0):
    n = len(outline)
    verts = [(x, y, bottom) for x, y in outline] + [(x, y, top) for x, y in outline]
    faces = [tuple(reversed(range(n))), tuple(range(n, 2*n))]
    faces += [(i, (i+1)%n, (i+1)%n+n, i+n) for i in range(n)]
    mesh = bpy.data.meshes.new(name + '_mesh')
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(obj)
    recalc(obj)
    apply_bevel(obj, bevel)
    return attach(obj, name, tint)


def prism_yz(name, outline, x1, x2, tint, bevel=0.0):
    n = len(outline)
    verts = [(x1, y, z) for y,z in outline] + [(x2, y, z) for y,z in outline]
    faces = [tuple(reversed(range(n))), tuple(range(n, 2*n))]
    faces += [(i, (i+1)%n, (i+1)%n+n, i+n) for i in range(n)]
    mesh = bpy.data.meshes.new(name + '_mesh')
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(obj)
    recalc(obj)
    apply_bevel(obj, bevel)
    return attach(obj, name, tint)


def panel_frame(name, outline, inner_scale, x1, x2, tint):
    """Closed narrow frame around an inset, viewed along X."""
    n = len(outline)
    center_y = sum(p[0] for p in outline) / n
    center_z = sum(p[1] for p in outline) / n
    inner = [(center_y + (y-center_y)*inner_scale,
              center_z + (z-center_z)*inner_scale) for y, z in outline]
    verts = ([(x1, y, z) for y,z in outline] + [(x1, y, z) for y,z in inner]
             + [(x2, y, z) for y,z in outline] + [(x2, y, z) for y,z in inner])
    faces = []
    for i in range(n):
        j = (i+1) % n
        faces.extend([(i,j,n+j,n+i), (2*n+i,3*n+i,3*n+j,2*n+j),
                      (i,2*n+i,2*n+j,j), (n+i,n+j,3*n+j,3*n+i)])
    mesh = bpy.data.meshes.new(name + '_mesh')
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(obj)
    recalc(obj)
    return attach(obj, name, tint)


def cylinder(name, a, b, radius, tint, segments=10, parent=None):
    a, b = Vector(a), Vector(b)
    direction = b - a
    bpy.ops.mesh.primitive_cylinder_add(vertices=segments, radius=radius, depth=direction.length,
                                        location=(a+b)*0.5)
    obj = bpy.context.object
    obj.rotation_euler = direction.to_track_quat('Z', 'Y').to_euler()
    return attach(obj, name, tint, parent, smooth=segments>=12)


def ellipsoid(name, center, scale, rotation, tint, parent=None, seg=16, rings=10):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, location=center)
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.rotation_euler = rotation
    return attach(obj, name, tint, parent, smooth=True)


def limb_parent(name, position):
    obj = bpy.data.objects.new(name, None)
    scene.collection.objects.link(obj)
    obj.parent = root
    obj.location = position
    obj.empty_display_type = 'SPHERE'
    obj.empty_display_size = 0.035
    bpy.context.view_layer.update()
    return obj

# Lower chassis, turntable and side protection.
chassis_outline = [(-.40,-.54),(.40,-.54),(.445,-.49),(.445,.46),(.38,.51),(-.38,.51),(-.445,.46),(-.445,-.49)]
prism_xy('Chassis', chassis_outline, .34, .48, 'frame', bevel=.012)
for side in (-1, 1):
    box(f'Chassis_SideRail_{side}', (side*.447,-.01,.405), (.014,.77,.085), 'frame_light')
    box(f'Chassis_SidePanel_{side}', (side*.457,-.01,.412), (.008,.57,.051), 'black')
    for y in (-.31,.31):
        box(f'Chassis_Reinforcement_{side}_{y}', (side*.46,y,.405), (.012,.045,.11), 'frame_light')
cylinder('Blue_Turntable', (0,-.12,.465), (0,-.12,.575), .205, 'blue', segments=20)
cylinder('Turret_Base', (0,-.12,.57), (0,-.12,.69), .172, 'black', segments=16)

# Orange front compartment: a U-shaped closed prism leaves the central bay open.
front = [(-.44,-.74),(-.44,-.18),(-.18,-.18),(-.18,-.50),(-.15,-.54),(.15,-.54),(.18,-.50),(.18,-.18),(.44,-.18),(.44,-.74),(.37,-.855),(-.37,-.855)]
prism_xy('Front_U_Shell', front, .79, 1.16, 'paint', bevel=.009)
box('Recess_Floor', (0,-.35,.865), (.35,.38,.025), 'glass')
box('Recess_RearWall', (0,-.175,.98), (.35,.02,.19), 'glass')

# Upper rear cargo lid, extending towards the back bumper.
rear_profile = [(-.25,1.06),(-.15,1.155),(.36,1.11),(.43,1.055),(.43,.91),(.24,.845),(-.10,.89)]
prism_yz('Rear_Upper_Shell', rear_profile, -.435, .435, 'paint', bevel=.009)

# The two sloped lower cheeks fill the sides around the recessed front sensor.
cheek_profile = [(-.81,.80),(-.69,.76),(-.44,.62),(-.28,.56),(-.08,.61),(-.08,.78)]
for side in (-1,1):
    xa,xb = sorted((side*.205,side*.438))
    prism_yz(f'Front_Lower_Cheek_{side}', cheek_profile, xa, xb, 'paint_edge', bevel=.004)

# Lower angular side plates provide the stepped, sloping side silhouette.
side_profile = [(-.83,.83),(-.78,1.105),(-.43,1.105),(-.27,.91),(.15,.79),(.10,.65),(-.24,.57),(-.39,.61),(-.56,.77)]
for side in (-1,1):
    xa,xb = sorted((side*.438,side*.452))
    prism_yz(f'Lower_Side_Armour_{side}', side_profile, xa, xb, 'paint', bevel=.004)
    frame_outline = [(-.75,1.08),(-.43,1.08),(-.29,.92),(-.49,.84),(-.74,.90)]
    xa,xb = sorted((side*.456,side*.462))
    panel_frame(f'Front_Side_Frame_{side}',frame_outline,.96,xa,xb,'paint_edge')
    border = [(-.115,1.055),(-.035,1.09),(.31,1.065),(.35,.99),(.25,.94),(.06,.945),(-.075,.99)]
    cx,cz = .10,1.015
    inset = [(cx+(y-cx)*.90,cz+(z-cz)*.83) for y,z in border]
    xa,xb = sorted((side*.443,side*.453))
    prism_yz(f'RearPanel_Border_{side}',border,xa,xb,'paint_edge')
    xa,xb = sorted((side*.454,side*.458))
    prism_yz(f'RearPanel_Inset_{side}',inset,xa,xb,'paint_inset')
    cylinder(f'Upper_Armour_Hinge_{side}', (side*.452,-.17,1.08), (side*.465,-.17,1.08), .043, 'paint_edge', segments=8)
    cylinder(f'Hinge_Cap_{side}', (side*.465,-.17,1.08), (side*.47,-.17,1.08), .027, 'paint', segments=8)

# Front sensor in the shadow under the cargo compartment.
box('Sensor_Housing', (0,-.635,.735), (.40,.18,.16), 'black', bevel=.018)
cylinder('Sensor_Bezel', (0,-.728,.755), (0,-.75,.755), .065, 'frame_light', segments=12)
cylinder('Sensor_Lens', (0,-.75,.755), (0,-.756,.755), .040, 'lens', segments=12)

# Rear bumper and the paired struts visible beneath the raised body.
box('Rear_Bumper', (0,.455,1.015), (.87,.14,.23), 'frame_light', bevel=.018)
for side in (-1,1):
    cylinder(f'Rear_Strut_{side}', (side*.315,.46,.46), (side*.315,.46,.945), .047, 'frame', segments=8)
    for z in (.48,.89):
        cylinder(f'Rear_Joint_{side}_{z}', (side*.35,.46,z), (side*.28,.46,z), .06, 'black', segments=6)
        cylinder(f'Rear_JointCap_{side}_{z}', (side*.354,.46,z), (side*.345,.46,z), .035, 'frame_light', segments=6)

# Row of dark sight slots on the roof, plus a few quiet panel seams.
for i,x in enumerate((-.31,-.105,0,.105,.31)):
    width=.085 if abs(x)>.2 else .045
    box(f'Roof_Slot_{i}', (x,-.205,1.162), (width,.042,.004), 'black')
for x in (-.22,.22):
    box(f'Front_Face_Seam_{x}', (x,-.861,.975), (.004,.004,.34), 'paint_edge')
    box(f'Front_Roof_Seam_{x}', (x,-.78,1.164), (.006,.15,.003), 'paint_edge')
    for y in (-.84,-.71):
        box(f'Front_Roof_Hinge_{x}_{y}', (x,y,1.169), (.045,.035,.012), 'paint_edge')

# Small front fastening plates and a lower seam, offset from the face.
box('Front_Lower_Seam', (0,-.86,.805), (.72,.004,.006), 'paint_edge')
for x in (-.22,.22):
    for z in (.82,1.13):
        box(f'Front_Fastener_{x}_{z}', (x,-.867,z), (.04,.008,.024), 'paint_edge')

# Four separate, pivoted feet. The covers are smooth ellipsoids, not decimated scans.
for side,lr in ((-1,'L'),(1,'R')):
    for front,fb in ((-1,'Front'),(1,'Back')):
        pivot=limb_parent('Leg_'+fb+'_'+lr, (side*.38,front*.42,.43))
        hip=(side*.38,front*.42,.43)
        ankle=(side*.50,front*.60,.25)
        cylinder(f'{fb}_{lr}_Leg_Link',hip,ankle,.059,'frame',segments=8,parent=pivot)
        cylinder(f'{fb}_{lr}_Hip', (side*.345,front*.42,.43), (side*.425,front*.42,.43), .082,'black',segments=10,parent=pivot)
        cylinder(f'{fb}_{lr}_HipCap', (side*.425,front*.42,.43), (side*.438,front*.42,.43), .052,'frame_light',segments=8,parent=pivot)
        foot = box(f'{fb}_{lr}_Foot', (side*.52,front*.71,.035), (.12,.16,.07), 'rubber',parent=pivot)
        # A tapered sole reads closer to the original joint than a flat cube.
        for vertex in foot.data.vertices:
            if vertex.co.z < 0:
                vertex.co.x *= .70
                vertex.co.y *= .75
        foot.data.update()
        ellipsoid(f'{fb}_{lr}_Orange_Cover', (side*.50,front*.65,.295), (.12,.145,.27),
                  (front*.48,-side*.28,0), 'paint',parent=pivot,seg=12,rings=8)
        cylinder(f'{fb}_{lr}_CoverBolt', (side*.605,front*.66,.20), (side*.62,front*.66,.20), .018,
                 'paint_edge',segments=6,parent=pivot)

# Keep separate source objects; export a disposable, joined duplicate as one surface.
scene.frame_set(0)
blender_path = OUT / 'phido_lowpoly.blend'
bpy.ops.wm.save_as_mainfile(filepath=os.fspath(blender_path))
for obj in parts: obj.select_set(False)
duplicates=[]
for obj in parts:
    dupe=obj.copy()
    dupe.data=obj.data.copy()
    scene.collection.objects.link(dupe)
    dupe.name='EXPORT_'+obj.name
    duplicates.append(dupe)
bpy.ops.object.select_all(action='DESELECT')
for obj in duplicates: obj.select_set(True)
bpy.context.view_layer.objects.active=duplicates[0]
bpy.ops.object.join()
merged=duplicates[0]
merged.name='Phido_Lowpoly'
merged.data.calc_loop_triangles()
triangles=len(merged.data.loop_triangles)
print('NEW_MODEL','parts',len(parts),'tris',triangles,'mesh_vertices',len(merged.data.vertices),'materials',len(merged.data.materials))
assert 2000 <= triangles <= 3000, f'Triangle budget not met: {triangles}'
bpy.ops.object.select_all(action='DESELECT')
merged.select_set(True)
bpy.context.view_layer.objects.active=merged
out=OUT/'phido_lowpoly.glb'
bpy.ops.export_scene.gltf(filepath=os.fspath(out), export_format='GLB', use_selection=True, export_yup=True, export_animations=False)
print('LOWPOLY_EXPORTED',str(out),'bytes',out.stat().st_size)
