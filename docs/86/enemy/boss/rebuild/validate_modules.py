"""Reimport the four component GLBs and compare them with the full GLB.

This checks triangle placement at 0.1 mm precision, independent of UV seams.
Run in a disposable Blender scene.
"""
import collections
import contextlib
import io
from pathlib import Path

import bpy

HERE=Path(r'D:\repo\godot\godogen\docs\86\enemy\boss\rebuild')
if '__file__' in globals() and Path(__file__).name == 'validate_modules.py':
    HERE=Path(__file__).resolve().parent


def clear_scene():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj,do_unlink=True)


def load_glb(filename):
    with contextlib.redirect_stdout(io.StringIO()):
        bpy.ops.import_scene.gltf(filepath=str(HERE / filename))
    bpy.context.view_layer.update()


def signatures():
    result=collections.Counter()
    for obj in bpy.context.scene.objects:
        if obj.type != 'MESH':
            continue
        obj.data.calc_loop_triangles()
        vertices=[obj.matrix_world @ v.co for v in obj.data.vertices]
        for tri in obj.data.loop_triangles:
            corners=tuple(sorted(tuple(round(vertices[v][axis],4) for axis in range(3))
                                 for v in tri.vertices))
            result[corners]+=1
    return result


clear_scene()
for name in ('cannon_v2.glb','body_v2.glb','legs_v2.glb','tails_v2.glb'):
    load_glb(name)
assembled=signatures()
clear_scene()
load_glb('boss_v2.glb')
full=signatures()
missing=sum((full-assembled).values())
extra=sum((assembled-full).values())
print('MODULE_ASSEMBLY','triangles',sum(assembled.values()),
      'full_triangles',sum(full.values()),'missing',missing,'extra',extra)
if missing or extra:
    raise RuntimeError('Component GLBs do not reproduce the full model positions')
print('MODULE_ASSEMBLY_PASS')
