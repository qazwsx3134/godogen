"""Render isolated component GLBs in disposable Blender scenes."""
import contextlib
import io
import math
from pathlib import Path

import bpy
from mathutils import Vector

HERE=Path(r'D:\repo\godot\godogen\docs\86\enemy\boss\rebuild')
if '__file__' in globals() and Path(__file__).name == 'render_modules.py':
    HERE=Path(__file__).resolve().parent
components={
    'body': ((0,-4.5,5.0), (1.1,-1.4,.95), 30),
    'legs': ((0,0,1.9), (1.0,-1.4,1.3), 20),
    'tails': ((0,12.0,7.5), (1.1,-1.35,1.0), 20),
}
for name,(center,direction,scale) in components.items():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj,do_unlink=True)
    with contextlib.redirect_stdout(io.StringIO()):
        bpy.ops.import_scene.gltf(filepath=str(HERE / f'{name}_v2.glb'))
    mesh_count=sum(o.type=='MESH' for o in bpy.context.scene.objects)
    if not mesh_count:
        raise RuntimeError(f'No meshes in {name}_v2.glb')
    s=bpy.context.scene
    s.render.engine='BLENDER_EEVEE';s.eevee.taa_render_samples=48
    s.render.image_settings.file_format='PNG';s.render.resolution_percentage=100
    s.render.resolution_x=1400;s.render.resolution_y=900
    s.world.use_nodes=True
    bg=s.world.node_tree.nodes.get('Background')
    bg.inputs['Color'].default_value=(.16,.18,.20,1)
    bg.inputs['Strength'].default_value=1
    s.view_settings.view_transform='AgX'
    for label,angles,energy in [('Key',(25,-20,-30),2.5),('Fill',(-45,20,150),1.5),
                                ('Side',(0,70,0),1.4),('Front',(70,0,0),.8)]:
        data=bpy.data.lights.new(label,'SUN');data.energy=energy
        light=bpy.data.objects.new(label,data);s.collection.objects.link(light)
        light.rotation_euler=tuple(math.radians(a) for a in angles)
    data=bpy.data.cameras.new('ComponentCamera')
    camera=bpy.data.objects.new('ComponentCamera',data);s.collection.objects.link(camera)
    s.camera=camera;data.type='ORTHO';data.ortho_scale=scale
    center=Vector(center);camera.location=center+Vector(direction).normalized()*80
    camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler()
    s.render.filepath=str(HERE / f'module_{name}.png')
    bpy.ops.render.render(write_still=True)
    print('MODULE_PREVIEW',name,'meshes',mesh_count)
