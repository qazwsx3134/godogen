"""Export the two assemblies in enemy_modular_kit.blend as single-mesh GLBs.

Run explicitly with Blender and --overwrite; this never runs on project import.
The blend remains unchanged on disk. Each GLB keeps one material and rig.
"""
import os
from pathlib import Path
import sys

import bpy

if not bpy.data.filepath:
    raise RuntimeError("Open the saved enemy_modular_kit.blend first")
output_dir = Path(bpy.data.filepath).resolve().parent
outputs = [output_dir / f"{kind}_reassembled.glb" for kind in ("melee", "tank")]
if "--overwrite" not in sys.argv and any(path.exists() for path in outputs):
    raise RuntimeError("Exports already exist. Pass --overwrite to replace them.")

scene = bpy.context.scene
if scene.render.fps != 30 or scene.render.fps_base != 1.0:
    raise RuntimeError("The imported animation keys use 30 fps")

for kind, output in zip(("melee", "tank"), outputs):
    title = kind.capitalize()
    rig = bpy.data.objects[title + "Rig"]
    assembly = bpy.data.collections[title + "_Assembly"]
    unique = bpy.data.objects[title]
    parts = [obj for obj in assembly.objects if obj.name.startswith(title + "_shared_")]
    if len(parts) != 17:
        raise RuntimeError(f"{title}: expected 17 shared modules, got {len(parts)}")
    source = [unique, *parts]
    previous_location = rig.location.copy()
    rig.location.x = 0.0  # The saved file places the assemblies apart for editing.
    duplicates = []
    try:
        for obj in source:
            duplicate = obj.copy()
            duplicate.data = obj.data.copy()
            duplicate.name = "TMP_" + obj.name
            scene.collection.objects.link(duplicate)
            duplicates.append(duplicate)
        bpy.ops.object.select_all(action="DESELECT")
        for obj in duplicates:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = duplicates[0]
        bpy.ops.object.join()
        merged = duplicates[0]
        merged.name = title + "_reassembled"
        for layer in list(merged.data.uv_layers):
            if layer.name != "UV_" + title:
                merged.data.uv_layers.remove(layer)
        if len(merged.data.uv_layers) != 1:
            raise RuntimeError(f"{title}: expected UV_{title}")
        bpy.ops.object.select_all(action="DESELECT")
        merged.select_set(True)
        rig.select_set(True)
        bpy.context.view_layer.objects.active = rig
        bpy.ops.export_scene.gltf(
            filepath=os.fspath(output), export_format="GLB", use_selection=True,
            export_yup=True, export_skins=True, export_animations=True,
            export_animation_mode="NLA_TRACKS", export_force_sampling=True,
            export_anim_slide_to_zero=True,
        )
        print(f"EXPORTED {output} tris={len(merged.data.polygons)}")
    finally:
        # join() consumes duplicates except the first one; don't touch original parts.
        for obj in duplicates:
            try:
                if obj.name in bpy.data.objects:
                    bpy.data.objects.remove(obj, do_unlink=True)
            except ReferenceError:
                pass
        rig.location = previous_location
