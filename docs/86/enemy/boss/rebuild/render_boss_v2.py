"""Render the currently open v2 model in a disposable Blender scene."""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Quaternion, Vector

OUT = Path(r'D:\repo\godot\godogen\docs\86\enemy\boss\rebuild')
if '__file__' in globals() and Path(__file__).name == 'render_boss_v2.py':
    OUT = Path(__file__).resolve().parent
if '--glb' in sys.argv:
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    bpy.ops.import_scene.gltf(filepath=str(OUT / 'boss_v2.glb'))
    meshes=[o for o in bpy.context.scene.objects if o.type == 'MESH']
    if len(meshes) != 1:
        raise RuntimeError('Expected one imported game mesh')
    meshes[0].data.calc_loop_triangles()
    print('BOSS_V2_RENDER_GLB',len(meshes[0].data.loop_triangles),'triangles')
s=bpy.context.scene
s.render.engine='BLENDER_EEVEE'
s.eevee.taa_render_samples=48
s.render.image_settings.file_format='PNG'
s.render.resolution_percentage=100
s.world.use_nodes=True
bg=s.world.node_tree.nodes.get('Background')
bg.inputs['Color'].default_value=(.16,.18,.20,1)
bg.inputs['Strength'].default_value=1
s.view_settings.view_transform='AgX'
for name,rotation,energy in [('V2_Key',(25,-20,-30),2.5),('V2_Fill',(-45,20,150),1.5),
                              ('V2_Side',(0,70,0),1.4),('V2_Front',(70,0,0),.8)]:
    data=bpy.data.lights.new(name,'SUN'); data.energy=energy
    light=bpy.data.objects.new(name,data); s.collection.objects.link(light)
    light.rotation_euler=tuple(math.radians(a) for a in rotation)
camera_data=bpy.data.cameras.new('V2_Inspection_Camera')
camera=bpy.data.objects.new('V2_Inspection_Camera',camera_data)
s.collection.objects.link(camera);s.camera=camera;camera_data.type='ORTHO'
center=Vector((0,0,4.9))
views={'front':((0,-1,0),21,900,900),'rear':((0,1,0),21,900,900),
       'side':((1,0,0),44,1500,700),'top':((0,-.0001,1),44,1500,700),
       'side_reference':((1,-.24,.22),44,1500,700),
       'three_quarter':((1.1,-1.35,.95),44,1400,900)}
for name,(direction,scale,width,height) in views.items():
    camera.location=center+Vector(direction).normalized()*80
    rotation=(center-camera.location).to_track_quat('-Z','Y')
    if name=='top':
        rotation=rotation @ Quaternion((0,0,1),math.pi/2)
    camera.rotation_euler=rotation.to_euler()
    camera_data.ortho_scale=scale;s.render.resolution_x=width;s.render.resolution_y=height
    s.render.filepath=str(OUT / f'v2_{name}.png')
    bpy.ops.render.render(write_still=True)
    print('BOSS_V2_RENDERED',name)
