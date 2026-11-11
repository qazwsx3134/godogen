"""Build the low-poly melee and tank enemies from their three-view references.

Blender 5.1: blender -b --factory-startup --python build_enemy.py -- melee|tank
Outputs are written next to the reference image. The scout's shared geometry,
atlas and rigid-skinning helpers are reused; no scout files are modified.
"""
import math
import os
import sys
import json
import struct

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.append(os.path.dirname(HERE))
from blender_kit import *  # noqa: E402,F403

kind = sys.argv[sys.argv.index("--") + 1].lower()
if kind not in ("melee", "tank"):
    raise ValueError("Expected melee or tank")
OUT = os.path.join(HERE, kind)
os.makedirs(OUT, exist_ok=True)
scn = reset_scene()
scn.render.fps = 30
bpy.context.preferences.filepaths.save_version = 0  # rebuilding does not leave .blend1 backups

# Reference palette: pale cool armor, deep-blue plates and dark mechanical joints.
# All source materials are baked into a single atlas and a single exported material.
ARMOR = worn("Armor", (0.62, 0.72, 0.87, 1),
             chips=[((0.46, 0.55, 0.72, 1), 5, 0.67)], edge=(0.88, 0.94, 1, 1),
             grime=0.94, ao=0.6,
             gradient=((0.43, 0.54, 0.72, 1), (0.72, 0.8, 0.93, 1), 0.25, 2.8))
BLUE = worn("Blue", (0.15, 0.23, 0.41, 1),
            chips=[((0.23, 0.32, 0.5, 1), 6, 0.68)], edge=(0.38, 0.5, 0.7, 1),
            grime=0.93, ao=0.65)
FRAME = worn("Frame", (0.12, 0.16, 0.23, 1), edge=(0.35, 0.4, 0.49, 1), grime=0.9)
STEEL = worn("Steel", (0.38, 0.46, 0.57, 1), edge=(0.68, 0.75, 0.86, 1), grime=0.92)
LENS = flat_mat("Lens", (0.015, 0.025, 0.04, 1))
CYAN = flat_mat("Cyan", (0.05, 0.48, 0.68, 1))
FINAL = {"Armor": (0.25, 0.38, None), "Blue": (0.35, 0.38, None),
         "Frame": (0.5, 0.48, None), "Steel": (0.6, 0.34, None),
         "Lens": (0.05, 0.18, None), "Cyan": (0.2, 0.35, None)}


def prism(name, points, mat):
    return hull_pts(points, name, mat)


def slab(name, points, thickness, mat):
    """Convex plate between a pair of offset polygon outlines."""
    off = Vector(thickness) * 0.5
    return prism(name, [Vector(p) + off * side for p in points for side in (-1, 1)], mat)


body = []
# In Blender the nose points -Y and +Z is up. GLB/Godot sees the nose as +Z.
body.append(prism("core", mirror([
    (0.38, -1.55, 0.75), (0.58, -1.10, 1.35), (0.67, -0.50, 1.50),
    (0.68, 0.85, 1.36), (0.48, 1.55, 1.15), (0.34, 1.62, 0.72),
    (0.52, -0.55, 0.60), (0.50, 0.85, 0.58), (0.0, -1.73, 0.85)
]), FRAME))
body.append(prism("ventral_keel", mirror([
    (0.0, -1.72, 0.83), (0.38, -1.32, 0.93), (0.48, -0.65, 0.60),
    (0.34, 0.95, 0.59), (0.0, 1.40, 0.63), (0.0, -1.28, 0.34)
]), BLUE))
body.append(prism("forward_beak", mirror([
    (0.0, -1.78, 0.77), (0.36, -1.42, 1.13), (0.46, -0.95, 1.44),
    (0.0, -1.02, 1.56), (0.0, -1.35, 0.45)
]), ARMOR))
body.append(slab("center_ridge", [(0, -1.78, 0.82), (0, -1.25, 1.50),
                                 (0, 0.90, 1.61), (0, 1.65, 1.45),
                                 (0, 0.55, 1.45)], (0.13, 0, 0), BLUE))
for s in (-1, 1):
    # Layered swept upper carapace and forward cheek plates, readable from above.
    body.append(prism(f"wing_{s}", [(s*x, y, z) for x, y, z in [
        (0.22, -1.18, 1.46), (0.69, -0.96, 1.35), (1.02, 0.55, 1.30),
        (0.48, 1.87, 1.57), (0.24, 1.35, 1.62), (0.16, -0.65, 1.62),
        (0.32, -0.75, 1.26), (0.75, 0.50, 1.18), (0.42, 1.55, 1.35)
    ]], ARMOR))
    body.append(slab(f"wing_inset_{s}", [(s*0.27, -1.14, 1.50), (s*0.74, -0.72, 1.42),
                                          (s*0.91, 0.48, 1.38), (s*0.37, 1.55, 1.62),
                                          (s*0.21, 0.64, 1.67)], (0, 0, 0.035), BLUE))
    body.append(prism(f"cheek_{s}", [(s*x, y, z) for x, y, z in [
        (0.12, -1.67, 0.93), (0.50, -1.40, 1.15), (0.68, -0.68, 1.12),
        (0.56, -0.72, 0.70), (0.22, -1.38, 0.58), (0.12, -1.60, 0.75)
    ]], ARMOR))
    body.append(slab(f"sensor_{s}", [(s*0.18, -1.695, 1.00), (s*0.41, -1.50, 1.14),
                                      (s*0.40, -1.49, 1.05), (s*0.20, -1.65, 0.92)],
                     (0, -0.018, 0), CYAN))
    body.append(box(f"side_spar_{s}", (0.14, 1.9, 0.18), (s*0.66, 0.18, 0.91), STEEL))

# Compact rear vent; a few deep separated slats communicate the reference without
# modeling the dozens of tiny fasteners in the concept image.
body.append(box("rear_housing", (0.68, 0.28, 0.64), (0, 1.48, 1.03), BLUE))
for i in range(4):
    body.append(box(f"rear_vent_{i}", (0.48, 0.04, 0.055), (0, 1.64, 0.84+i*0.12), FRAME))

parts = []
weapon_parts = []  # (objects, rigid bone)
extra_bones = []  # (name, head, parent)

if kind == "melee":
    # Elevated rectangular sensor/pod and paired supports.
    for y in (-0.55, 0.62):
        for s in (-1, 1):
            body.append(cyl(f"pod_strut_{s}_{y}", (s*0.29, y, 1.53),
                            (s*0.38, y+0.08, 2.20), 0.065, STEEL, 5))
    pod_pts = [Vector((0, -0.95, 2.48)), Vector((0, -0.78, 2.49)),
               Vector((0, 0.95, 2.49)), Vector((0, 1.16, 2.45))]
    body.append(tube("sensor_pod", pod_pts, [(0.54, 0.46), (0.70, 0.62),
                                               (0.70, 0.62), (0.55, 0.46)],
                     BLUE, X, n=8, phase=0.5))
    body.append(cyl("pod_front", (0, -0.96, 2.48), (0, -1.01, 2.48), 0.265, ARMOR, 8))
    body.append(box("pod_highlight", (0.035, 1.75, 0.035), (0.33, 0.05, 2.51), STEEL))
    body.append(box("pod_highlight_m", (0.035, 1.75, 0.035), (-0.33, 0.05, 2.51), STEEL))
    # A shorter comb than the tank's large radiator, behind the pod.
    for i in range(5):
        y = 1.00 + i*0.14
        body.append(slab(f"melee_rib_{i}", [(0, y, 1.48), (0, y+0.21, 1.48),
                                            (0, y+0.27, 1.87)], (0.045, 0, 0), FRAME))
    for s, side in ((1, "L"), (-1, "R")):
        pivot = Vector((s*1.14, -1.18, 1.05))
        body.append(cyl(f"blade_mount_{side}", (s*0.61, -0.90, 1.12), pivot,
                        0.12, FRAME, 6))
        extra_bones.append((f"{side}_Blade", pivot, "Body"))
        p0 = pivot
        p1 = Vector((s*1.55, -1.82, 1.35))
        p2 = Vector((s*2.05, -2.55, 2.05))
        p3 = Vector((s*2.62, -3.20, 2.75))
        blade = [cyl(f"blade_joint_{side}", pivot + Vector((0, 0, -0.09)),
                     pivot + Vector((0, 0, 0.09)), 0.16, FRAME, 8),
                 tube(f"blade_base_{side}", [p0, p1, p2, p3],
                      [(0.15, 0.16), (0.32, 0.12), (0.23, 0.075), (0.01, 0.012)],
                      BLUE, X, n=4),
                 tube(f"blade_edge_{side}", [p1 + Vector((s*0.10, -0.04, 0.04)),
                                               p2 + Vector((s*0.075, -0.04, 0.04)), p3],
                      [(0.10, 0.025), (0.07, 0.02), (0.005, 0.005)], ARMOR, X, n=4)]
        weapon_parts.append((blade, f"{side}_Blade"))
else:
    # Turret, long single cannon and the aft cooling fins of the heavy gunner.
    pivot = Vector((0, -0.10, 1.53))
    extra_bones.append(("Turret", pivot, "Body"))
    extra_bones.append(("Cannon", Vector((0, -1.17, 1.72)), "Turret"))
    turret = [cyl("turret_ring", (0, 0.05, 1.52), (0, 0.05, 1.68), 0.54, FRAME, 10),
              prism("turret_armor", mirror([(0.22, -1.13, 1.58), (0.43, -0.73, 1.62),
                                             (0.51, 0.36, 1.63), (0.36, 0.76, 1.65),
                                             (0.24, 0.55, 1.92), (0.25, -0.65, 1.93),
                                             (0, -1.2, 1.67)]), BLUE)]
    for s in (-1, 1):
        turret.append(prism(f"turret_wing_{s}", [(s*x, y, z) for x, y, z in [
            (0.28, -0.80, 1.72), (0.89, -0.56, 1.54), (0.99, 0.50, 1.55),
            (0.42, 1.10, 1.83), (0.28, 0.55, 1.97), (0.32, -0.55, 1.95)
        ]], ARMOR))
    weapon_parts.append((turret, "Turret"))
    gun = [tube("cannon_breech", [Vector((0, -0.75, 1.73)), Vector((0, -1.3, 1.73)),
                                   Vector((0, -1.9, 1.73))],
                [(0.48, 0.36), (0.44, 0.32), (0.25, 0.23)], ARMOR, X, n=6),
           tube("long_cannon", [Vector((0, -1.78, 1.73)), Vector((0, -4.18, 1.73))],
                [(0.20, 0.20), (0.15, 0.15)], ARMOR, X, n=6),
           cyl("muzzle_ring", (0, -4.18, 1.73), (0, -4.28, 1.73), 0.11, FRAME, 8),
           cyl("muzzle_bore", (0, -4.28, 1.73), (0, -4.29, 1.73), 0.075, LENS, 8),
           box("barrel_stripe", (0.025, 2.15, 0.018), (0, -2.95, 1.825), BLUE)]
    weapon_parts.append((gun, "Cannon"))
    for i in range(9):
        y = 0.22 + i*0.155
        body.append(slab(f"radiator_fin_{i}", [(0, y, 1.45), (0, y+0.38, 1.46),
                                                (0, y+0.52, 2.04)], (0.06, 0, 0), BLUE))
    body.append(slab("dorsal_fin", [(0, -0.12, 1.85), (0, 0.64, 2.54),
                                     (0, 0.20, 1.87)], (0.10, 0, 0), ARMOR))

parts.append(weight_all(join(body, "BodyParts"), "Body"))
for items, bone in weapon_parts:
    parts.append(weight_all(join(items, bone + "Parts"), bone))

# Eight legs share the scout bone names and its alternating-tetrapod gait.
legs = []
for side, s in (("L", 1), ("R", -1)):
    for i, (hy, fy, fx) in enumerate(((-0.76, -2.18, 1.55), (-0.28, -0.65, 2.15),
                                      (0.34, 0.84, 2.18), (0.91, 2.05, 1.70))):
        hip = Vector((s*0.63, hy, 1.13))
        foot = Vector((s*fx, fy, 0.0))
        out = Vector((foot.x-hip.x, foot.y-hip.y, 0)).normalized()
        knee = hip + out*0.71 + Z*0.22
        name = f"{side}{i+1}"
        legs.append((name, hip, knee, foot, out))
        hinge = out.cross(Z).normalized()
        parts.append(weight_all(box(name+"_hip", (0.24, 0.25, 0.24), hip, FRAME), "Body"))
        upper = [cyl(name+"_upper", hip, knee, 0.105, FRAME, 5),
                 cyl(name+"_joint", knee-hinge*0.13, knee+hinge*0.13, 0.12, STEEL, 6),
                 tube(name+"_upper_armor", [hip+Z*0.06, knee+Z*0.08],
                      [(0.19, 0.17), (0.24, 0.17)], ARMOR, hinge, n=4)]
        parts.append(weight_all(join(upper, name+"_UpperParts"), name+"_Upper"))
        lower = [tube(name+"_shin", [knee+Z*0.25, knee, knee+(foot-knee)*0.55, foot+Z*0.1],
                      [(0.13, 0.08), (0.31, 0.19), (0.24, 0.14), (0.07, 0.06)], ARMOR, hinge),
                 prism(name+"_foot", [foot+hinge*u+out*v+Z*h for u,v,h in
                     ((-0.12,-0.17,0), (0.12,-0.17,0), (-0.12,0.16,0), (0.12,0.16,0),
                      (-0.06,-0.04,0.12), (0.06,-0.04,0.12), (-0.06,0.08,0.12), (0.06,0.08,0.12))], FRAME)]
        parts.append(weight_all(join(lower, name+"_LowerParts"), name+"_Lower"))

mesh = join(parts, kind.capitalize())
# Triangulate deliberately before export so there are no implicit n-gon conversions.
bpy.context.view_layer.objects.active = mesh
for o in bpy.context.selected_objects:
    o.select_set(False)
mesh.select_set(True)
tri = mesh.modifiers.new("FinalTriangulation", "TRIANGULATE")
bpy.ops.object.modifier_apply(modifier=tri.name)
uv_atlas([mesh])
bake_single_material([mesh], OUT, kind, FINAL, sizes=(1024, 512, 0))
mesh.data.set_sharp_from_angle(angle=math.radians(40))

mesh.select_set(False)
arm_data = bpy.data.armatures.new(kind.capitalize()+"Rig")
rig = bpy.data.objects.new(kind.capitalize()+"Rig", arm_data)
scn.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")
root = arm_data.edit_bones.new("Body")
root.head, root.tail = (0, 0, 1.0), (0, 0, 1.4)
for name, hip, knee, foot, out in legs:
    upper = arm_data.edit_bones.new(name+"_Upper")
    upper.head, upper.tail = hip, hip+Z*0.25
    upper.align_roll(out)
    upper.parent = root
    lower = arm_data.edit_bones.new(name+"_Lower")
    lower.head, lower.tail = knee, knee+Z*0.25
    lower.align_roll(out)
    lower.parent = upper
for name, head, parent in extra_bones:
    bone = arm_data.edit_bones.new(name)
    bone.head, bone.tail = head, head+Z*0.25
    bone.parent = arm_data.edit_bones[parent]
bpy.ops.object.mode_set(mode="OBJECT")
mesh.parent = rig
mod = mesh.modifiers.new("Armature", "ARMATURE")
mod.object = rig


def action(name):
    a = bpy.data.actions.new(name)
    a.use_fake_user = True
    rig.animation_data_create()
    rig.animation_data.action = a
    return a


def rest_pose():
    for bone in rig.pose.bones:
        bone.rotation_mode = "XYZ"
        bone.location = (0, 0, 0)
        bone.rotation_euler = (0, 0, 0)


def key_all(frame):
    for bone in rig.pose.bones:
        bone.keyframe_insert("location", frame=frame)
        bone.keyframe_insert("rotation_euler", frame=frame)


GROUP_A = {"L1", "R2", "L3", "R4"}
action("walk-loop")
for frame in range(25):
    scn.frame_set(frame)
    rest_pose()
    for name, hip, knee, foot, out in legs:
        forward = 1.0 if Z.cross(out).y < 0 else -1.0
        phase = (frame/24 + (0 if name in GROUP_A else 0.5)) % 1
        if phase < 0.5:
            u = phase/0.5
            sweep = -1+2*(3*u*u-2*u*u*u)
            yaw, lift, bend = forward*0.22*sweep, -0.32*math.sin(math.pi*u), 0.3*math.sin(math.pi*u)
        else:
            u = (phase-0.5)/0.5
            yaw, lift, bend = forward*0.22*(1-2*u), 0, 0
        rig.pose.bones[name+"_Upper"].rotation_euler = (lift, yaw, 0)
        rig.pose.bones[name+"_Lower"].rotation_euler = (bend, 0, 0)
    key_all(frame)

action("idle-loop")
for frame in range(0, 61, 5):
    scn.frame_set(frame)
    rest_pose()
    # Stay above the ground plane; a centered sine would push all feet through it.
    rig.pose.bones["Body"].location.y = 0.008*(1-math.cos(2*math.pi*frame/60))
    key_all(frame)

if kind == "melee":
    action("attack")
    for frame, swing in ((0, 0), (5, -0.30), (9, 0.48), (14, 0.24), (20, 0)):
        scn.frame_set(frame)
        rest_pose()
        rig.pose.bones["L_Blade"].rotation_euler.y = swing
        rig.pose.bones["R_Blade"].rotation_euler.y = -swing
        key_all(frame)
else:
    action("fire")
    for frame, recoil in ((0, 0), (2, 0.23), (5, 0.14), (12, 0)):
        scn.frame_set(frame)
        rest_pose()
        # Unrolled Blender bone local Z points toward +Y, the rear of the vehicle.
        rig.pose.bones["Cannon"].location.z = recoil
        key_all(frame)

rig.animation_data.action = None
rest_pose()
scn.frame_set(0)
print(f"{kind.upper()} tris={tri_count([mesh])} bones={len(arm_data.bones)} "
      f"verts={len(mesh.data.vertices)} materials={len(mesh.data.materials)}")
# Embed the two baked images in the artist source as well as the GLB, so the
# .blend can be opened after the directory is moved to another computer.
for suffix in ("albedo", "orm"):
    bpy.data.images[f"{kind}_{suffix}"].pack()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, kind+".blend"))
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, kind+".glb"), export_format="GLB", export_yup=True,
                          export_skins=True, export_animations=True, export_animation_mode="ACTIONS",
                          export_force_sampling=True)

# The Blender exporter emits translation, rotation and scale channels for every
# bone in every action. All scales, leg translations and body rotations are
# constant here. Remove those channels to reduce animation work per instance.
# Keep the leg rotations and weapon channels in *every* action, including the
# constant reset values, so an interrupted walk or attack returns to rest.
glb_path = os.path.join(OUT, kind+".glb")
with open(glb_path, "rb") as f:
    raw = f.read()
magic, version, total = struct.unpack_from("<4sII", raw)
json_size, json_type = struct.unpack_from("<II", raw, 12)
if (magic, version, total, json_type) != (b"glTF", 2, len(raw), 0x4E4F534A):
    raise ValueError("Unexpected GLB container")
doc = json.loads(raw[20:20+json_size])
for anim in doc["animations"]:
    kept = []
    for channel in anim["channels"]:
        target = channel["target"]
        bone = doc["nodes"][target["node"]].get("name", "")
        path = target["path"]
        keep = (bone == "Body" and path == "translation")
        keep |= (bone.endswith(("_Upper", "_Lower")) and path == "rotation")
        keep |= (kind == "melee" and bone in ("L_Blade", "R_Blade") and path == "rotation")
        keep |= (kind == "tank" and bone == "Cannon" and path == "translation")
        if keep:
            kept.append(channel)
    print("ANIMATION CHANNELS", anim["name"], len(anim["channels"]), "->", len(kept))
    anim["channels"] = kept
    # Prune orphan sampler records; buffer data remains intact and aligned.
    used = sorted({ch["sampler"] for ch in kept})
    remap = {old: new for new, old in enumerate(used)}
    anim["samplers"] = [anim["samplers"][i] for i in used]
    for channel in kept:
        channel["sampler"] = remap[channel["sampler"]]
encoded = json.dumps(doc, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
encoded += b" "*((-len(encoded)) % 4)
remaining_chunks = raw[20+json_size:]
with open(glb_path, "wb") as f:
    f.write(struct.pack("<4sII", b"glTF", 2, 20+len(encoded)+len(remaining_chunks)))
    f.write(struct.pack("<II", len(encoded), 0x4E4F534A))
    f.write(encoded)
    f.write(remaining_chunks)
print(kind.upper()+" done")
