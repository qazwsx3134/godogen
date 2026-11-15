"""Build the detailed modular Boss source in a disposable Blender scene.

Passing --save-source explicitly saves boss_v2.blend; --overwrite is required
when that file already exists. The reference and first version are untouched.
"""
import os
import sys
from pathlib import Path

import bpy

HERE = Path(r'D:\repo\godot\godogen\docs\86\enemy\boss\rebuild')
if '__file__' in globals() and Path(__file__).name == 'build_boss_v2.py':
    HERE = Path(__file__).resolve().parent
sys.path.insert(0, os.fspath(HERE))
from boss_geometry import Builder, triangle_count  # noqa: E402
from gun_module import build_cannon  # noqa: E402
from body_module import build_body  # noqa: E402
from leg_module import build_legs  # noqa: E402
from tail_module import build_tails  # noqa: E402

output = HERE / 'boss_v2.blend'
if '--save-source' in sys.argv and output.exists() and '--overwrite' not in sys.argv:
    raise RuntimeError('Source exists; preserve edits and explicitly pass --overwrite')
b = Builder()
build_cannon(b)
build_body(b)
build_legs(b)
build_tails(b)
bpy.context.view_layer.update()
print('BOSS_V2_BUILD', 'parts', len(b.parts), 'triangles', triangle_count(b.parts))
if '--save-source' in sys.argv:
    bpy.ops.wm.save_as_mainfile(filepath=os.fspath(output))
