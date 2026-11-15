"""Render inspection views of boss.glb in an otherwise empty Blender scene.

Run in a disposable scene: blender --background --python render_boss.py
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

HERE = Path(r'D:\repo\godot\godogen\docs\86\enemy\boss')
if '__file__' in globals() and Path(__file__).name == 'render_boss.py':
    HERE = Path(__file__).resolve().parent
if '--out' in sys.argv:
    HERE = Path(sys.argv[sys.argv.index('--out') + 1])
for obj in list(bpy.data.objects):
    bpy.data.objects.remove(obj, do_unlink=True)
bpy.ops.import_scene.gltf(filepath=str(HERE / 'boss.glb'))
meshes = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
if len(meshes) != 1:
    raise RuntimeError(f'Expected one imported mesh; got {len(meshes)}')
meshes[0].data.calc_loop_triangles()
print('PREVIEW_GLB', 'meshes', len(meshes), 'triangles', len(meshes[0].data.loop_triangles),
      'materials', len(meshes[0].data.materials))
scene = bpy.context.scene
scene.render.engine = 'BLENDER_EEVEE'
scene.eevee.taa_render_samples = 48
scene.render.image_settings.file_format = 'PNG'
scene.render.resolution_percentage = 100
scene.world.use_nodes = True
background = scene.world.node_tree.nodes.get('Background')
background.inputs['Color'].default_value = (.16, .18, .20, 1)
background.inputs['Strength'].default_value = 1.0
scene.view_settings.view_transform = 'AgX'
for name, rotation, energy in [
    ('Key', (25, -20, -30), 2.4),
    ('Fill', (-45, 20, 150), 1.2),
    ('Side_Fill', (0, 70, 0), 1.4),
]:
    data = bpy.data.lights.new(name, 'SUN')
    data.energy = energy
    light = bpy.data.objects.new(name, data)
    scene.collection.objects.link(light)
    light.rotation_euler = tuple(math.radians(angle) for angle in rotation)
camera_data = bpy.data.cameras.new('Inspection_Camera')
camera = bpy.data.objects.new('Inspection_Camera', camera_data)
scene.collection.objects.link(camera)
scene.camera = camera
camera_data.type = 'ORTHO'
center = Vector((0, 0, 4.6))
views = {
    'front': ((0, -1, 0), 20, 900, 900),
    'rear': ((0, 1, 0), 20, 900, 900),
    'side': ((1, 0, 0), 44, 1500, 700),
    'three_quarter': ((1.1, -1.3, .9), 44, 1400, 900),
}
for label, (direction, scale, width, height) in views.items():
    camera.location = center + Vector(direction).normalized() * 80
    camera.rotation_euler = (center - camera.location).to_track_quat('-Z', 'Y').to_euler()
    camera_data.ortho_scale = scale
    scene.render.resolution_x, scene.render.resolution_y = width, height
    scene.render.filepath = str(HERE / f'preview_{label}.png')
    bpy.ops.render.render(write_still=True)
    print('PREVIEW_RENDERED', label)
