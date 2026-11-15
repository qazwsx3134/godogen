"""Export a single-surface game GLB from the editable v2 Blender source."""
import os
import sys
from pathlib import Path

import bpy

HERE = Path(r'D:\repo\godot\godogen\docs\86\enemy\boss\rebuild\meshy_refined')
if '__file__' in globals() and Path(__file__).name == 'export_refined.py':
    HERE = Path(__file__).resolve().parent
outputs = [HERE / n for n in ('boss_meshy_refined.glb','boss_meshy_refined_albedo.png','boss_meshy_refined_orm.png')]
if '--overwrite' not in sys.argv and any(path.exists() for path in outputs):
    raise RuntimeError('Game outputs exist; preserve edits or pass --overwrite')
sys.path.insert(0,os.fspath(HERE.parents[3]))
from blender_kit import uv_atlas, bake_single_material  # noqa: E402


def belongs(obj):
    if obj.type != 'MESH':
        return False
    node=obj.parent
    while node:
        if node.name == 'Boss_40m':
            return True
        node=node.parent
    return False


source=[o for o in bpy.context.scene.objects if belongs(o)]
if not source:
    raise RuntimeError('No editable v2 meshes under Boss_40m')
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
            raise RuntimeError(f'{mat.name} has textured metallic/roughness; extend exporter first')
        parameters[mat.name]=(metal.default_value,rough.default_value,None)
bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT')
copies=[]
for obj in source:
    copy=obj.copy()
    copy.data=obj.data.copy()
    bpy.context.scene.collection.objects.link(copy)
    world=obj.matrix_world.copy()
    copy.parent=None
    copy.matrix_world=world
    copy.select_set(True)
    copies.append(copy)
bpy.context.view_layer.objects.active=copies[0]
bpy.ops.object.join()
runtime=copies[0]
runtime.name=runtime.data.name='Boss_Meshy_Refined_Runtime'
runtime.data.transform(runtime.matrix_world)
runtime.matrix_world.identity()
uv_atlas([runtime],margin=.0015)
mat=bake_single_material([runtime],os.fspath(HERE),'boss_meshy_refined',parameters,sizes=(2048,1024,0))
mat.use_backface_culling=True
bpy.ops.export_scene.gltf(filepath=os.fspath(outputs[0]),export_format='GLB',
                          use_selection=True,export_yup=True,export_animations=False,
                          export_apply=True)
runtime.data.calc_loop_triangles()
print('BOSS_MESHY_EXPORTED','parts',len(source),'triangles',len(runtime.data.loop_triangles),
      'source_vertices',len(runtime.data.vertices),'materials',len(runtime.data.materials))
