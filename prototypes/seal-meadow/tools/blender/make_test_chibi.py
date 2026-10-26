"""Builds a throwaway chibi test rig to prove the 3D -> sprite pipeline before real models exist.

    blender -b --factory-startup -P tools/blender/make_test_chibi.py -- <out.blend>

Same contract a real character .blend must follow (see design/pipeline/3d-to-sprite.md):
  - an armature object "Rig" at the origin, model facing -Y, feet on Z = 0, 1 Blender unit = 1 m;
  - one collection per paper-doll layer (body, hair, weapon_sword), every part parented to a bone;
  - one action per animation (idle, walk, attack), fake user on, frames counted from 1;
  - toon materials (Shader to RGB -> constant ColorRamp), so the look does not depend on the renderer's tonemapping.
"""
import math
import sys

import bpy
from mathutils import Vector

BONES = {  # name: (head, tail, parent)
    "hips": ((0, 0, 0.55), (0, 0, 0.72), None),
    "spine": ((0, 0, 0.72), (0, 0, 0.98), "hips"),
    "head": ((0, 0, 0.98), (0, 0, 1.5), "spine"),
    "arm.L": ((0.24, 0, 0.94), (0.28, 0, 0.6), "spine"),
    "arm.R": ((-0.24, 0, 0.94), (-0.28, 0, 0.6), "spine"),
    "leg.L": ((0.1, 0, 0.55), (0.1, 0, 0.08), "hips"),
    "leg.R": ((-0.1, 0, 0.55), (-0.1, 0, 0.08), "hips"),
}


def toon(name, color):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    diffuse = nt.nodes.new("ShaderNodeBsdfDiffuse")
    to_rgb = nt.nodes.new("ShaderNodeShaderToRGB")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "CONSTANT"
    shade = [c * 0.72 for c in color]
    ramp.color_ramp.elements[0].color = (*shade, 1.0)
    ramp.color_ramp.elements[1].position = 0.32
    ramp.color_ramp.elements[1].color = (*color, 1.0)
    emit = nt.nodes.new("ShaderNodeEmission")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(diffuse.outputs["BSDF"], to_rgb.inputs["Shader"])
    nt.links.new(to_rgb.outputs["Color"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], emit.inputs["Color"])
    nt.links.new(emit.outputs["Emission"], out.inputs["Surface"])
    return mat


def srgb(hex_color):
    def lin(c):
        c /= 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return [lin(int(hex_color[i:i + 2], 16)) for i in (0, 2, 4)]


def collection(name):
    coll = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(coll)
    return coll


def add(coll, mesh_op, name, mat, loc, scale=(1, 1, 1), rot=(0, 0, 0), **kw):
    mesh_op(location=loc, **kw)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    obj.rotation_euler = [math.radians(a) for a in rot]
    for c in obj.users_collection:
        c.objects.unlink(obj)
    coll.objects.link(obj)
    obj.data.materials.append(mat)
    bpy.ops.object.shade_smooth()
    return obj


def parent_to_bone(obj, rig, bone):
    world = obj.matrix_world.copy()
    obj.parent = rig
    obj.parent_type = "BONE"
    obj.parent_bone = bone
    bpy.context.view_layer.update()
    obj.matrix_world = world


def key(rig, frame, poses):
    """poses: {bone: (rot_x_deg, loc_z)}"""
    for bone, (rot_x, loc_z) in poses.items():
        pb = rig.pose.bones[bone]
        pb.rotation_euler = (math.radians(rot_x), 0, 0)
        pb.keyframe_insert("rotation_euler", frame=frame)
        if loc_z is not None:
            pb.location = (0, loc_z, 0)  # a bone's local Y is along the bone: up for hips
            pb.keyframe_insert("location", frame=frame)


def action(rig, name, frames):
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    rig.animation_data.action = act
    for frame, poses in frames:
        key(rig, frame, poses)
    for fc in getattr(act, "fcurves", []):
        for kp in fc.keyframe_points:
            kp.interpolation = "BEZIER"


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.frame_start, scene.frame_end = 1, 24

    arm_data = bpy.data.armatures.new("Rig")
    rig = bpy.data.objects.new("Rig", arm_data)
    scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for name, (head, tail, parent) in BONES.items():
        b = arm_data.edit_bones.new(name)
        b.head, b.tail = head, tail
        if parent:
            b.parent = arm_data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in rig.pose.bones:
        pb.rotation_mode = "XYZ"

    skin, grey, dark = toon("skin", srgb("ffd9b8")), toon("undies", srgb("c9c6d2")), toon("eye", srgb("2a1f1f"))
    blush, hair_c = toon("blush", srgb("ff9aa8")), toon("hair", srgb("8a5a32"))
    steel, brass, grip = toon("steel", srgb("d7dde6")), toon("brass", srgb("e2b34a")), toon("grip", srgb("6b4426"))
    iron, ruby = toon("iron", srgb("9aa4b4")), toon("ruby", srgb("c8323c"))
    cloth, belt = toon("cloth", srgb("c8a36b")), toon("belt", srgb("5a3a22"))

    body, hair, sword = collection("body"), collection("hair"), collection("weapon_sword")
    iron_sword, tunic = collection("weapon_iron"), collection("outfit_tunic")
    sphere, cyl, cube, cone = (bpy.ops.mesh.primitive_uv_sphere_add, bpy.ops.mesh.primitive_cylinder_add,
                               bpy.ops.mesh.primitive_cube_add, bpy.ops.mesh.primitive_cone_add)
    parts = [  # (collection, op, name, material, loc, scale, rot, bone, kwargs)
        (body, sphere, "Head", skin, (0, 0, 1.2), (1, 0.95, 0.92), (0, 0, 0), "head", {"radius": 0.33, "segments": 24, "ring_count": 16}),
        (body, sphere, "EyeL", dark, (0.11, -0.29, 1.2), (0.7, 0.4, 1.3), (0, 0, 0), "head", {"radius": 0.045}),
        (body, sphere, "EyeR", dark, (-0.11, -0.29, 1.2), (0.7, 0.4, 1.3), (0, 0, 0), "head", {"radius": 0.045}),
        (body, sphere, "BlushL", blush, (0.19, -0.26, 1.11), (1, 0.4, 0.6), (0, 0, 0), "head", {"radius": 0.04}),
        (body, sphere, "BlushR", blush, (-0.19, -0.26, 1.11), (1, 0.4, 0.6), (0, 0, 0), "head", {"radius": 0.04}),
        (body, cyl, "Torso", grey, (0, 0, 0.75), (1, 0.85, 1), (0, 0, 0), "spine", {"radius": 0.19, "depth": 0.42}),
        (body, cyl, "ArmL", skin, (0.26, 0, 0.78), (1, 1, 1), (0, 6, 0), "arm.L", {"radius": 0.055, "depth": 0.32}),
        (body, cyl, "ArmR", skin, (-0.26, 0, 0.78), (1, 1, 1), (0, -6, 0), "arm.R", {"radius": 0.055, "depth": 0.32}),
        (body, sphere, "HandL", skin, (0.28, 0, 0.6), (1, 1, 1), (0, 0, 0), "arm.L", {"radius": 0.065}),
        (body, sphere, "HandR", skin, (-0.28, 0, 0.6), (1, 1, 1), (0, 0, 0), "arm.R", {"radius": 0.065}),
        (body, cyl, "LegL", grey, (0.1, 0, 0.32), (1, 1, 1), (0, 0, 0), "leg.L", {"radius": 0.07, "depth": 0.44}),
        (body, cyl, "LegR", grey, (-0.1, 0, 0.32), (1, 1, 1), (0, 0, 0), "leg.R", {"radius": 0.07, "depth": 0.44}),
        (body, cube, "FootL", skin, (0.1, -0.04, 0.05), (0.08, 0.13, 0.05), (0, 0, 0), "leg.L", {}),
        (body, cube, "FootR", skin, (-0.1, -0.04, 0.05), (0.08, 0.13, 0.05), (0, 0, 0), "leg.R", {}),
        (hair, sphere, "HairCap", hair_c, (0, 0.03, 1.27), (1.05, 1.0, 0.9), (0, 0, 0), "head", {"radius": 0.34, "segments": 24, "ring_count": 16}),
        (sword, cube, "Blade", steel, (-0.28, -0.42, 0.6), (0.018, 0.34, 0.045), (0, 0, 0), "arm.R", {}),
        (sword, cube, "Guard", brass, (-0.28, -0.08, 0.6), (0.03, 0.025, 0.11), (0, 0, 0), "arm.R", {}),
        (sword, cyl, "Grip", grip, (-0.28, 0.0, 0.6), (1, 1, 1), (90, 0, 0), "arm.R", {"radius": 0.025, "depth": 0.14}),
        # iron sword: longer, wider blade, red guard (equipment layer "iron")
        (iron_sword, cube, "IronBlade", iron, (-0.28, -0.5, 0.6), (0.026, 0.43, 0.06), (0, 0, 0), "arm.R", {}),
        (iron_sword, cube, "IronGuard", ruby, (-0.28, -0.08, 0.6), (0.04, 0.03, 0.15), (0, 0, 0), "arm.R", {}),
        (iron_sword, cyl, "IronGrip", grip, (-0.28, 0.0, 0.6), (1, 1, 1), (90, 0, 0), "arm.R", {"radius": 0.028, "depth": 0.16}),
        # cloth tunic over the torso, with a belt (equipment layer "tunic")
        (tunic, cyl, "Tunic", cloth, (0, 0, 0.73), (1, 0.85, 1), (0, 0, 0), "spine", {"radius": 0.215, "depth": 0.48}),
        (tunic, cyl, "Belt", belt, (0, 0, 0.6), (1, 0.85, 1), (0, 0, 0), "spine", {"radius": 0.222, "depth": 0.06}),
    ]
    for i, a in enumerate(range(0, 360, 45)):  # hair spikes around the crown
        r = math.radians(a)
        parts.append((hair, cone, f"Spike{i}", hair_c, (math.cos(r) * 0.2, math.sin(r) * 0.2 + 0.04, 1.47),
                      (1, 1, 1), (math.sin(r) * -35, math.cos(r) * 35, 0), "head", {"radius1": 0.09, "depth": 0.22, "vertices": 8}))
    bpy.ops.object.select_all(action="DESELECT")
    for coll, op, name, mat, loc, scale, rot, bone, kw in parts:
        obj = add(coll, op, name, mat, loc, scale, rot, **kw)
        if name.startswith(("Eye", "Blush")):
            obj["no_outline"] = True
        bpy.context.view_layer.update()
        parent_to_bone(obj, rig, bone)

    rig.animation_data_create()
    rest = {b: (0, None) for b in ("spine", "arm.L", "arm.R", "leg.L", "leg.R")}
    action(rig, "idle", [(1, {**rest, "hips": (0, 0.0)}), (13, {**rest, "hips": (0, 0.015), "arm.L": (0, None)}),
                         (25, {**rest, "hips": (0, 0.0)})])
    swing = lambda s: {"leg.L": (-28 * s, None), "leg.R": (28 * s, None), "arm.L": (24 * s, None),
                       "arm.R": (-24 * s, None), "spine": (0, None)}
    action(rig, "walk", [(1, {**swing(1), "hips": (0, 0.0)}), (7, {**swing(0), "hips": (0, 0.035)}),
                         (13, {**swing(-1), "hips": (0, 0.0)}), (19, {**swing(0), "hips": (0, 0.035)}),
                         (25, {**swing(1), "hips": (0, 0.0)})])
    action(rig, "attack", [(1, {**rest, "hips": (0, 0.0)}),
                           (6, {**rest, "arm.R": (150, None), "spine": (8, None), "hips": (0, 0.0)}),
                           (10, {**rest, "arm.R": (-75, None), "spine": (-12, None), "hips": (0, -0.03)}),
                           (14, {**rest, "arm.R": (-35, None), "spine": (-5, None), "hips": (0, -0.01)}),
                           (20, {**rest, "hips": (0, 0.0)})])
    rig.animation_data.action = None
    bpy.ops.wm.save_as_mainfile(filepath=out)
    print("saved", out)


if __name__ == "__main__":
    main()
