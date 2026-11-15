"""Export separately inspectable, editable static component GLBs from v2 source."""
import os
import sys
from pathlib import Path

import bpy

HERE = Path(r'D:\repo\godot\godogen\docs\86\enemy\boss\rebuild')
if '__file__' in globals() and Path(__file__).name == 'export_modules.py':
    HERE = Path(__file__).resolve().parent
components = {
    'cannon_v2.glb': {'Cannon_Module'},
    'body_v2.glb': {'Body_Module', 'Forward_Yokes'},
    'legs_v2.glb': {'Leg_And_Spine_Module'},
    'tails_v2.glb': {'Tail_Left_Module', 'Tail_Right_Module'},
}
if '--overwrite' not in sys.argv and any((HERE / filename).exists() for filename in components):
    raise RuntimeError('Component outputs exist; preserve edits or pass --overwrite')
for filename, parents in components.items():
    objects = [o for o in bpy.context.scene.objects
               if o.type == 'MESH' and o.parent and o.parent.name in parents]
    if not objects:
        raise RuntimeError(f'{filename} has no source parts')
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.export_scene.gltf(filepath=os.fspath(HERE / filename), export_format='GLB',
                              use_selection=True, export_yup=True, export_animations=False)
    triangles = sum(sum(len(p.vertices)-2 for p in ob.data.polygons) for ob in objects)
    print('V2_COMPONENT_EXPORTED', filename, 'parts', len(objects), 'triangles', triangles)
