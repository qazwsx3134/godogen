"""Bake the editable Boss source to one static, single-material GLB in Blender.

Example: blender --background boss.blend --python export_boss.py -- --overwrite
The open source scene is never saved by this script. Preserve edits before reruns.
"""
import os
import sys
from pathlib import Path

import bpy

SCRIPT_DIR = Path(r'D:\repo\godot\godogen\docs\86\enemy\boss')
if '__file__' in globals() and Path(__file__).name == 'export_boss.py':
    SCRIPT_DIR = Path(__file__).resolve().parent
HERE = SCRIPT_DIR
if '--out' in sys.argv:
    HERE = Path(sys.argv[sys.argv.index('--out') + 1])
HERE.mkdir(parents=True, exist_ok=True)
outputs = [HERE / name for name in ('boss.glb', 'boss_albedo.png', 'boss_orm.png')]
if '--overwrite' not in sys.argv and any(p.exists() for p in outputs):
    raise RuntimeError('Export outputs exist; back them up or pass --overwrite')

sys.path.insert(0, os.fspath(SCRIPT_DIR.parent.parent))
from blender_kit import uv_atlas, bake_single_material  # noqa: E402


def is_boss_part(obj):
    if obj.type != 'MESH':
        return False
    node = obj.parent
    while node is not None:
        if node.name == 'Boss_40m':
            return True
        node = node.parent
    return False


source = [o for o in bpy.context.scene.objects if is_boss_part(o)]
if not source:
    raise RuntimeError('No editable meshes found under Boss_40m')
# Preserve edited scalar roughness/metallic values, and reject unsupported
# textured values instead of silently baking them as unrelated constants.
material_parameters = {}
for obj in source:
    if not obj.data.materials or any(mat is None for mat in obj.data.materials):
        raise RuntimeError(f'{obj.name} is missing a material')
    for mat in obj.data.materials:
        shader = mat.node_tree.nodes.get('Principled BSDF') if mat.use_nodes and mat.node_tree else None
        if shader is None:
            raise RuntimeError(f'{mat.name} needs a Principled BSDF')
        metal, rough = shader.inputs['Metallic'], shader.inputs['Roughness']
        if metal.is_linked or rough.is_linked:
            raise RuntimeError(f'{mat.name} has textured metallic/roughness; extend the exporter before baking')
        material_parameters[mat.name] = (metal.default_value, rough.default_value, None)
bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT')
copies = []
for original in source:
    copy = original.copy()
    copy.data = original.data.copy()
    bpy.context.scene.collection.objects.link(copy)
    world = original.matrix_world.copy()
    copy.parent = None
    copy.matrix_world = world
    copy.select_set(True)
    copies.append(copy)
bpy.context.view_layer.objects.active = copies[0]
bpy.ops.object.join()
runtime = copies[0]
runtime.name = runtime.data.name = 'Boss_Runtime'
runtime.data.transform(runtime.matrix_world)
runtime.matrix_world.identity()

# One UV layout and a single baked material keep the runtime surface count down.
uv_atlas([runtime], margin=.003)
material = bake_single_material([runtime], os.fspath(HERE), 'boss', material_parameters,
                                sizes=(1024, 512, 0))
# The source parts are closed and outward-facing; avoid shading backfaces at runtime.
material.use_backface_culling = True
bpy.ops.export_scene.gltf(filepath=os.fspath(outputs[0]), export_format='GLB',
                          use_selection=True, export_yup=True, export_animations=False,
                          export_apply=True)
runtime.data.calc_loop_triangles()
print('BOSS_EXPORT', 'parts', len(source), 'triangles', len(runtime.data.loop_triangles),
      'source_vertices', len(runtime.data.vertices), 'materials', len(runtime.data.materials),
      'glb', outputs[0])
