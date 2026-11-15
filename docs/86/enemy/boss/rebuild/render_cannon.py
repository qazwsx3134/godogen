"""Render the cannon module in a disposable Blender session."""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

OUT = Path(r'D:\repo\godot\godogen\docs\86\enemy\boss\rebuild')
if '__file__' in globals() and Path(__file__).name == 'render_cannon.py':
    OUT = Path(__file__).resolve().parent
if '--glb' in sys.argv:
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    bpy.ops.import_scene.gltf(filepath=str(OUT / 'cannon_v2.glb'))
    print('CANNON_IMPORTED_PARTS',sum(o.type == 'MESH' for o in bpy.context.scene.objects))
s = bpy.context.scene
s.render.engine = 'BLENDER_EEVEE'
s.eevee.taa_render_samples = 48
s.render.image_settings.file_format = 'PNG'
s.render.resolution_percentage = 100
s.world.use_nodes = True
background = s.world.node_tree.nodes.get('Background')
background.inputs['Color'].default_value = (.15,.17,.19,1)
background.inputs['Strength'].default_value = 1.0
s.view_settings.view_transform = 'AgX'
for name, rotation, energy in [('Key',(22,-25,-35),2.7), ('Fill',(-40,30,150),1.5),
                               ('Front',(70,0,0),1.4), ('Side',(0,70,0),1.4)]:
    light = bpy.data.lights.new(name,'SUN')
    light.energy = energy
    obj = bpy.data.objects.new(name,light)
    s.collection.objects.link(obj)
    obj.rotation_euler = tuple(math.radians(x) for x in rotation)
camera_data = bpy.data.cameras.new('Cannon_Inspection_Camera')
camera = bpy.data.objects.new('Cannon_Inspection_Camera',camera_data)
s.collection.objects.link(camera)
s.camera = camera
camera_data.type = 'ORTHO'
center = Vector((0,-.25,6.95))
views = {'front': ((0,-1,.05),3.6), 'side': ((1,0,.08),6.2),
         'three_quarter': ((1.15,-1.3,.8),6.6)}
for label, (direction, size) in views.items():
    camera.location = center + Vector(direction).normalized()*20
    camera.rotation_euler = (center-camera.location).to_track_quat('-Z','Y').to_euler()
    camera_data.ortho_scale = size
    s.render.resolution_x, s.render.resolution_y = (1100, 800)
    s.render.filepath = str(OUT / ('cannon_'+label+'.png'))
    bpy.ops.render.render(write_still=True)
    print('CANNON_PREVIEW', label)
