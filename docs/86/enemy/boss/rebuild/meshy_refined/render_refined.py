"""Import the exported GLB into a disposable Blender scene and render it."""
import math
from pathlib import Path
import bpy
from mathutils import Quaternion, Vector

OUT = Path(r'D:\repo\godot\godogen\docs\86\enemy\boss\rebuild\meshy_refined')
if '__file__' in globals() and Path(__file__).name == 'render_refined.py':
    OUT = Path(__file__).resolve().parent
for obj in list(bpy.data.objects):
    bpy.data.objects.remove(obj,do_unlink=True)
bpy.ops.import_scene.gltf(filepath=str(OUT/'boss_meshy_refined.glb'))
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
if len(meshes)!=1:
    raise RuntimeError('Expected one imported game mesh')
scene=bpy.context.scene
scene.render.engine='BLENDER_EEVEE'
scene.eevee.taa_render_samples=32
scene.render.image_settings.file_format='PNG'
scene.render.resolution_percentage=100
scene.world.use_nodes=True
bg=scene.world.node_tree.nodes.get('Background')
bg.inputs['Color'].default_value=(.16,.18,.20,1)
bg.inputs['Strength'].default_value=1
scene.view_settings.view_transform='AgX'
for name,rotation,energy in [('Ref_Key',(25,-20,-30),2.5),('Ref_Fill',(-45,20,150),1.5),
                              ('Ref_Side',(0,70,0),1.4),('Ref_Front',(70,0,0),.8)]:
    data=bpy.data.lights.new(name,'SUN');data.energy=energy
    light=bpy.data.objects.new(name,data);scene.collection.objects.link(light)
    light.rotation_euler=tuple(math.radians(a) for a in rotation)
camera_data=bpy.data.cameras.new('Reference_Comparison_Camera')
camera=bpy.data.objects.new('Reference_Comparison_Camera',camera_data)
scene.collection.objects.link(camera);scene.camera=camera;camera_data.type='ORTHO'
center=Vector((0,0,4.8))
views={'front':((0,-1,0),21,900,900),
       'side':((1,0,0),44,1400,700),
       'top':((0,-.0001,1),44,1400,700),
       'underside':((0,-.0001,-1),44,1400,700),
       'three_quarter':((1.1,-1.35,.95),44,1400,900)}
for name,(direction,scale,width,height) in views.items():
    camera.location=center+Vector(direction).normalized()*80
    rotation=(center-camera.location).to_track_quat('-Z','Y')
    if name in ('top','underside'):
        rotation=rotation@Quaternion((0,0,1),math.pi/2)
    camera.rotation_euler=rotation.to_euler()
    camera_data.ortho_scale=scale;scene.render.resolution_x=width;scene.render.resolution_y=height
    scene.render.filepath=str(OUT/f'refined_{name}.png')
    bpy.ops.render.render(write_still=True)
    print('MESHY_RENDERED',name)
