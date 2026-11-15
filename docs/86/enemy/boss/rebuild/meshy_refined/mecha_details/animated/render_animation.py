"""Render PNG frames from a fresh GLB import for three animated previews."""
import math
from pathlib import Path
import bpy
from mathutils import Vector

OUT=Path(r'D:\repo\godot\godogen\docs\86\enemy\boss\rebuild\meshy_refined\mecha_details\animated')
if '__file__' in globals() and Path(__file__).name=='render_animation.py':
    OUT=Path(__file__).resolve().parent
for obj in list(bpy.data.objects):
    bpy.data.objects.remove(obj,do_unlink=True)
scene=bpy.context.scene
scene.render.fps=30
scene.render.fps_base=1
bpy.ops.import_scene.gltf(filepath=str(OUT/'boss_animated.glb'),disable_bone_shape=True)
rigs=[obj for obj in scene.objects if obj.type=='ARMATURE']
meshes=[obj for obj in scene.objects if obj.type=='MESH']
if len(rigs)!=1 or len(meshes)!=1:
    raise RuntimeError('Expected one rigged mesh after GLB import')
rig,mesh=rigs[0],meshes[0]
print('PREVIEW_IMPORT','bones',len(rig.data.bones),'actions',[a.name for a in bpy.data.actions])
scene.render.engine='BLENDER_EEVEE'
scene.eevee.taa_render_samples=12
scene.render.resolution_x=720
scene.render.resolution_y=450
scene.render.resolution_percentage=100
scene.world.use_nodes=True
bg=scene.world.node_tree.nodes.get('Background')
bg.inputs['Color'].default_value=(.16,.18,.20,1)
bg.inputs['Strength'].default_value=1
scene.view_settings.view_transform='AgX'
for name,rotation,energy in [('Anim_Key',(25,-20,-30),2.5),('Anim_Fill',(-45,20,150),1.5),
                              ('Anim_Side',(0,70,0),1.4),('Anim_Front',(70,0,0),.8)]:
    light_data=bpy.data.lights.new(name,'SUN');light_data.energy=energy
    light=bpy.data.objects.new(name,light_data);scene.collection.objects.link(light)
    light.rotation_euler=tuple(math.radians(a) for a in rotation)
camera_data=bpy.data.cameras.new('Animation_Preview_Camera')
camera=bpy.data.objects.new('Animation_Preview_Camera',camera_data)
scene.collection.objects.link(camera);scene.camera=camera;camera_data.type='ORTHO'
center=Vector((0,0,4.9))
camera.location=center+Vector((1.1,-1.35,.95)).normalized()*80
camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler()
camera_data.ortho_scale=42
scene.render.image_settings.color_mode='RGB'
scene.render.image_settings.file_format='PNG'
# WSL/Windows shared temporary directory. --frames-dir can override it.
FRAME_DIR=Path(r"\\wsl.localhost\Ubuntu\tmp\boss-animated-preview-20261115")
if '--frames-dir' in __import__('sys').argv:
    args=__import__('sys').argv
    FRAME_DIR=Path(args[args.index('--frames-dir')+1])
FRAME_DIR.mkdir(parents=True,exist_ok=True)
for action_name,end,prefix in [('idle-loop',90,'idle'),('fly-loop',54,'fly'),('fire',36,'fire')]:
    action=bpy.data.actions.get(action_name)
    if action is None:
        raise RuntimeError('Imported GLB lacks action '+action_name)
    rig.animation_data.action=action
    target=Vector((0,-.6,6.8)) if prefix=='fire' else Vector((0,0,4.9))
    camera.location=target+Vector((1.1,-1.35,.95)).normalized()*80
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    camera_data.ortho_scale=13 if prefix=='fire' else 42
    for count,frame in enumerate(range(0,end,3)):
        scene.frame_set(frame)
        scene.render.filepath=str(FRAME_DIR/f'{prefix}_{count:03d}.png')
        bpy.ops.render.render(write_still=True)
    print('BOSS_ANIM_FRAMES',action_name,'frames',count+1,'directory',FRAME_DIR)
