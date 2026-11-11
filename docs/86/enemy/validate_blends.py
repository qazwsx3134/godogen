"""Check the saved Blender sources without depending on their adjacent PNGs.

Blender 5.1: blender -b --factory-startup --python validate_blends.py
"""
import os
import bpy

here = os.path.dirname(os.path.abspath(__file__))
for kind in ("melee", "tank"):
    bpy.ops.wm.open_mainfile(filepath=os.path.join(here, kind, kind + ".blend"))
    mesh = bpy.data.objects[kind.capitalize()]
    rig = bpy.data.objects[kind.capitalize() + "Rig"]
    assert len(mesh.data.materials) == 1
    assert all(len(poly.vertices) == 3 and poly.area > 1.0e-10 for poly in mesh.data.polygons)
    assert len(rig.data.bones) == 19
    assert all(bpy.data.images[f"{kind}_{name}"].packed_file for name in ("albedo", "orm"))
    assert all(bpy.data.actions.get(name) for name in
               ("walk-loop", "idle-loop", "attack" if kind == "melee" else "fire"))
    foot_groups = {g.index for g in mesh.vertex_groups if g.name.endswith("_Lower")}
    foot_vertices = [v.index for v in mesh.data.vertices if v.co.z <= 0.13 and
                     any(g.group in foot_groups and g.weight > 0.999 for g in v.groups)]
    assert foot_vertices
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for action, end in (("walk-loop", 24), ("idle-loop", 60)):
        rig.animation_data.action = bpy.data.actions[action]
        lowest, highest = float("inf"), float("-inf")
        for frame in range(end + 1):
            bpy.context.scene.frame_set(frame)
            evaluated = mesh.evaluated_get(depsgraph)
            evaluated_mesh = evaluated.to_mesh()
            heights = [evaluated_mesh.vertices[i].co.z for i in foot_vertices]
            lowest, highest = min(lowest, *heights), max(highest, *heights)
            evaluated.to_mesh_clear()
        print(f"SOURCE {kind} {action}: foot vertices {lowest:.3f}..{highest:.3f} m")
        assert lowest >= -0.005, f"{kind} {action}: foot penetrates the ground"
    print(f"SOURCE {kind}: tris={len(mesh.data.polygons)} packed_images=2")
print("BLENDER_SOURCES PASSED")
