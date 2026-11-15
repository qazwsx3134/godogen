"""Bake and export a single-mesh skinned GLB from boss_animated.blend."""
import os
import sys
from pathlib import Path

import bpy

HERE=Path(r'D:\repo\godot\godogen\docs\86\enemy\boss\rebuild\meshy_refined\mecha_details\animated')
if '__file__' in globals() and Path(__file__).name=='export_animated.py':
    HERE=Path(__file__).resolve().parent
outputs=[HERE/name for name in ('boss_animated.glb','boss_animated_albedo.png','boss_animated_orm.png')]
if '--overwrite' not in sys.argv and any(path.exists() for path in outputs):
    raise RuntimeError('Export exists; preserve it or pass --overwrite')
if Path(bpy.data.filepath).name!='boss_animated.blend':
    raise RuntimeError('Open boss_animated.blend first')
sys.path.insert(0,os.fspath(HERE.parents[5]))
from blender_kit import uv_atlas,bake_single_material  # noqa: E402

root=bpy.data.objects['Boss_40m']
rig=bpy.data.objects['Boss_Animated_Rig']


def belongs(obj):
    node=obj
    while node is not None:
        if node==root:
            return True
        node=node.parent
    return False


source=[obj for obj in bpy.context.scene.objects if obj.type=='MESH' and belongs(obj)]
if len(source)!=607 or len(rig.data.bones)!=11:
    raise RuntimeError('Unexpected source mesh or bone count')
parameters={}
for obj in source:
    if not obj.data.materials or any(mat is None for mat in obj.data.materials):
        raise RuntimeError(f'{obj.name} is missing a material')
    for mat in obj.data.materials:
        shader=mat.node_tree.nodes.get('Principled BSDF') if mat.use_nodes and mat.node_tree else None
        if not shader:
            raise RuntimeError(f'{mat.name} needs a Principled BSDF')
        metal,rough=shader.inputs['Metallic'],shader.inputs['Roughness']
        if metal.is_linked or rough.is_linked:
            raise RuntimeError(f'{mat.name} has textured metallic/roughness')
        parameters[mat.name]=(metal.default_value,rough.default_value,None)

rig.animation_data.action=None
for bone in rig.pose.bones:
    bone.location=(0,0,0)
    bone.rotation_euler=(0,0,0)
    bone.scale=(1,1,1)
bpy.context.scene.frame_set(0)
bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT')
copies=[]
for original in source:
    copy=original.copy()
    copy.data=original.data.copy()
    bpy.context.scene.collection.objects.link(copy)
    world=original.matrix_world.copy()
    copy.parent=None
    copy.matrix_world=world
    for modifier in list(copy.modifiers):
        if modifier.type=='ARMATURE':
            copy.modifiers.remove(modifier)
    copy.select_set(True)
    copies.append(copy)
bpy.context.view_layer.objects.active=copies[0]
with bpy.context.temp_override(active_object=copies[0],selected_editable_objects=copies,object=copies[0]):
    bpy.ops.object.join()
runtime=copies[0]
runtime.name=runtime.data.name='Boss_Animated_Runtime'
runtime.data.transform(runtime.matrix_world)
runtime.matrix_world.identity()
uv_atlas([runtime],margin=.0015)
material=bake_single_material([runtime],os.fspath(HERE),'boss_animated',parameters,sizes=(2048,1024,0))
material.use_backface_culling=True
runtime.parent=rig
modifier=runtime.modifiers.new('Boss_Armature','ARMATURE')
modifier.object=rig
modifier.use_vertex_groups=True
bpy.ops.object.select_all(action='DESELECT')
runtime.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=os.fspath(outputs[0]),export_format='GLB',use_selection=True,
                          export_yup=True,export_skins=True,export_animations=True,
                          export_animation_mode='ACTIONS',export_force_sampling=True,
                          export_apply=False)
runtime.data.calc_loop_triangles()
print('BOSS_ANIMATED_EXPORTED','parts',len(source),'triangles',len(runtime.data.loop_triangles),
      'source_vertices',len(runtime.data.vertices),'bones',len(rig.data.bones))
