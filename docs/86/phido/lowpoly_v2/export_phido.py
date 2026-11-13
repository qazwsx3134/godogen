"""Export the saved editable Phido as a single-mesh GLB.

Run with Blender and --overwrite to replace an existing GLB. The source blend
is not saved or altered; temporary duplicates are discarded after export.
"""
import os
from pathlib import Path
import sys

import bpy

if not bpy.data.filepath:
    raise RuntimeError('Open phido_lowpoly.blend first')
out = Path(bpy.data.filepath).resolve().parent / 'phido_lowpoly.glb'
if out.exists() and '--overwrite' not in sys.argv:
    raise RuntimeError('GLB already exists; pass --overwrite to replace it')
root = bpy.data.objects.get('Phido')
if root is None:
    raise RuntimeError('Missing the Phido root object')

def belongs_to_phido(obj):
    parent = obj.parent
    while parent:
        if parent == root:
            return True
        parent = parent.parent
    return False

parts = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH' and belongs_to_phido(obj)]
if not parts:
    raise RuntimeError('No mesh parts found below Phido')
materials = {mat for obj in parts for mat in obj.data.materials if mat}
if len(materials) != 1:
    raise RuntimeError('The single-surface export requires one shared material')

scene = bpy.context.scene
duplicates = []
try:
    for obj in parts:
        duplicate = obj.copy()
        duplicate.data = obj.data.copy()
        scene.collection.objects.link(duplicate)
        duplicates.append(duplicate)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in duplicates:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = duplicates[0]
    bpy.ops.object.join()
    merged = duplicates[0]
    merged.name = 'Phido_Lowpoly'
    merged.data.calc_loop_triangles()
    triangles = len(merged.data.loop_triangles)
    if not 2000 <= triangles <= 3000:
        raise RuntimeError(f'Expected 2000–3000 triangles, found {triangles}')
    bpy.ops.object.select_all(action='DESELECT')
    merged.select_set(True)
    bpy.context.view_layer.objects.active = merged
    bpy.ops.export_scene.gltf(filepath=os.fspath(out), export_format='GLB',
                              use_selection=True, export_yup=True, export_animations=False)
    print(f'EXPORTED {out}: {triangles} triangles, {out.stat().st_size} bytes')
finally:
    for obj in duplicates:
        try:
            if obj.name in bpy.data.objects:
                bpy.data.objects.remove(obj, do_unlink=True)
        except ReferenceError:
            pass
