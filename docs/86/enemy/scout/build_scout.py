# Scout enemy from scout.png (side / front / rear / top / bottom views). Low poly for crowds:
# ONE skinned mesh + armature (1 draw call), rigid weights (each part 100% on one bone), baked walk/idle loops.
# Run: blender.exe -b --factory-startup --python build_scout.py -- <out_dir(windows path)>
# Units: meters, 2.8 m tall (side view 322 px -> 0.0087 m/px). Nose (sensor tubes) to -Y = Godot +Z.
# Left side = +X. Legs L1..L4 / R1..R4 front to back.
import bpy, sys, os, math
from mathutils import Vector

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
from blender_kit import *  # noqa: E402,F403

OUT = sys.argv[sys.argv.index("--") + 1]
FPS = 30
WALK_FRAMES = 24   # 0.8 s per cycle
WALK_SPEED = 1.6   # m/s the walk cycle's feet travel at; AnimationPlayer speed_scale = move speed / this

scn = reset_scene()
scn.render.fps = FPS

# ---------------------------------------------------------------- materials
ARMOR = worn("Armor", (0.45, 0.58, 0.88, 1), chips=[((0.32, 0.4, 0.66, 1), 4, 0.62)],
             edge=(0.62, 0.74, 0.97, 1), grime=0.88, ao=0.45,
             gradient=((0.28, 0.4, 0.74, 1), (0.5, 0.64, 0.93, 1), 0.3, 2.6))
FRAME = worn("Frame", (0.22, 0.26, 0.36, 1), chips=[((0.34, 0.38, 0.48, 1), 9, 0.64)], edge=(0.42, 0.47, 0.58, 1))
BELLY = worn("Belly", (0.44, 0.46, 0.5, 1), chips=[((0.32, 0.33, 0.36, 1), 6, 0.62)])
SPINE = worn("Spine", (0.82, 0.85, 0.9, 1), edge=(1, 1, 1, 1))
LENS = flat_mat("Lens", (0.02, 0.02, 0.03, 1))
FINAL = {  # metallic, roughness, emission
    "Armor": (0.25, 0.32, None), "Frame": (0.5, 0.5, None), "Belly": (0.3, 0.6, None),
    "Spine": (0.6, 0.35, None), "Lens": (0.0, 0.15, None),
}

# ---------------------------------------------------------------- body (bone "Body")
body = []
crest_pts = bezier((0, -1.05, 1.42), (0, 0.35, 1.62), (0, 2.05, 2.8), 9)
crest_sizes = [(0.2, 0.3), (0.58, 0.75), (0.74, 1.0), (0.72, 1.02), (0.64, 0.92), (0.52, 0.74),
               (0.38, 0.52), (0.2, 0.28), (0, 0)]
body.append(tube("crest", crest_pts, crest_sizes, ARMOR, X, n=6, phase=0.5, smooth=True, sharp=50))
GZ = 1.47  # gun axis height
for s in (-1, 1):  # twin guns: angular receiver, rear dorsal fin, side groove, boxy muzzle shroud, tapered barrel
    x = s * 0.44
    g = lambda y, dz=0.0, dx=0.0: Vector((x + s * dx, y, GZ + dz))  # noqa: E731
    body += [
        tube(f"receiver{s}", [g(-0.38), g(-0.9), g(-1.5)], [(0.27, 0.32), (0.26, 0.3), (0.22, 0.27)], ARMOR, X, n=6),
        hull_pts([g(y, dz, dx) for y, dz in ((-0.42, 0.14), (-0.42, 0.26), (-0.62, 0.15), (-0.62, 0.3), (-0.9, 0.15))
                  for dx in (-0.05, 0.05)], f"fin{s}", ARMOR),
        box(f"groove{s}", (0.012, 0.95, 0.035), g(-0.95, -0.02, 0.13), FRAME),
        box(f"breech{s}", (0.24, 0.24, 0.26), g(-0.3), FRAME),
        hull_pts([g(y, dz, dx) for y in (-1.5, -1.72) for dz, dx in ((-0.2, 0.15), (-0.2, -0.15), (0.1, 0.15),
                                                                      (0.1, -0.15))]
                 + [g(y, 0.21, dx) for y in (-1.5, -1.6) for dx in (0.09, -0.09)],  # raked top-front edge
                 f"shroud{s}", ARMOR),
        hull_pts([g(y, dz, dx) for y, dz in ((-1.2, -0.12), (-1.2, -0.2), (-1.68, -0.2), (-1.68, -0.28))
                  for dx in (-0.1, 0.1)], f"lip{s}", ARMOR),
        cyl(f"muzzlering{s}", g(-1.72), g(-1.745), 0.11, FRAME, 8),
        cyl(f"bore{s}", g(-1.74), g(-1.75), 0.07, LENS, 8),
        cyl(f"barrel{s}", g(-1.74), g(-1.95), 0.06, SPINE, 8, r2=0.035),
        cyl(f"barrelbore{s}", g(-1.95), g(-1.955), 0.025, LENS, 6),
        hull_pts([(s * 0.18, -0.85, 0.95), (s * 0.36, -0.75, 0.68), (s * 0.34, -1.55, 0.6), (s * 0.24, -1.3, 0.9),
                  (s * 0.23, -0.85, 0.95), (s * 0.41, -0.75, 0.68), (s * 0.39, -1.55, 0.6), (s * 0.29, -1.3, 0.9)],
                 f"mandible{s}", ARMOR),
    ]
body += [
    hull_pts(mirror([(0.34, -0.7, 0.8), (0.34, -0.7, 1.35), (0.38, 0.2, 0.72), (0.38, 0.2, 1.45),
                     (0.3, 1.15, 0.8), (0.3, 1.15, 1.35), (0.12, -1.0, 0.75), (0.12, -1.0, 1.2)]), "core", FRAME),
    hull_pts(mirror([(0.32, -1.0, 1.2), (0.25, -1.15, 0.75), (0, -1.27, 0.42), (0, -1.22, 1.3), (0.3, -0.7, 0.6)]),
             "jaw", ARMOR),
    box("belly", (0.9, 1.9, 0.07), (0, 0.25, 0.61), BELLY),
    box("rear", (0.55, 0.4, 0.55), (0, 1.35, 1.05), FRAME),
]
for i in range(7):  # comb of spines under the back of the crest, pointing aft
    base = Vector((0, 1.12 + i * 0.05, 1.42 + i * 0.16))
    tip = base + Vector((0, 0.42 - i * 0.03, 0.06))
    body.append(hull_pts([base + Vector((sx, 0, sz)) for sx in (-0.17, 0.17) for sz in (-0.025, 0.025)] + [tip],
                         f"spine{i}", SPINE))

# ---------------------------------------------------------------- legs
LEGS = []  # (name, hip, knee, foot, out)
for side, sx in (("L", 1), ("R", -1)):
    for i, (hy, fy, fx) in enumerate(((-0.55, -2.35, 1.15), (-0.2, -0.4, 2.05), (0.25, 1.0, 2.05), (0.65, 2.15, 1.15))):
        hip = Vector((sx * 0.45, hy, 1.15))
        foot = Vector((sx * fx, fy, 0.0))
        out = Vector((foot.x - hip.x, foot.y - hip.y, 0)).normalized()
        knee = hip + out * 0.7 + Z * 0.25
        LEGS.append((f"{side}{i + 1}", hip, knee, foot, out))

parts = [weight_all(join(body, "body_part"), "Body")]
for name, hip, knee, foot, out in LEGS:
    hinge = out.cross(Z).normalized()
    body_bits = [box(f"{name}_hipbox", (0.22, 0.22, 0.24), hip, FRAME)]
    parts.append(weight_all(join(body_bits, f"{name}_hip"), "Body"))
    upper = [cyl(f"{name}_upper", hip, knee, 0.075, FRAME, 4),
             cyl(f"{name}_knee", knee - hinge * 0.12, knee + hinge * 0.12, 0.1, FRAME, 6)]
    parts.append(weight_all(join(upper, f"{name}_up"), f"{name}_Upper"))
    blade_pts = [knee + Z * 0.28 - out * 0.05, knee, knee + (foot - knee) * 0.45, foot + Z * 0.12]
    lower = [tube(f"{name}_blade", blade_pts, [(0.12, 0.08), (0.3, 0.2), (0.24, 0.16), (0.07, 0.06)], ARMOR, hinge),
             hull_pts([foot + hinge * u + out * v for u in (-0.07, 0.07) for v in (-0.15, 0.12)] +
                      [foot + Z * 0.12 + hinge * u + out * v for u in (-0.04, 0.04) for v in (-0.05, 0.05)],
                      f"{name}_foot", FRAME)]
    parts.append(weight_all(join(lower, f"{name}_low"), f"{name}_Lower"))
mesh = join(parts, "Scout")

# ---------------------------------------------------------------- UV + bake (rest pose, before the rig exists)
uv_atlas([mesh])
bake_single_material([mesh], OUT, "scout", FINAL, sizes=(1024, 512, 0))  # muzzles are dark, nothing glows
mesh.data.set_sharp_from_angle(angle=math.radians(40))  # keep the low-poly facets crisp, smooth the crest

# ---------------------------------------------------------------- armature
mesh.select_set(False)
arm_data = bpy.data.armatures.new("ScoutRig")
rig = bpy.data.objects.new("ScoutRig", arm_data)
scn.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")
root = arm_data.edit_bones.new("Body")
root.head, root.tail = (0, 0, 1.0), (0, 0, 1.4)
for name, hip, knee, foot, out in LEGS:  # bones point up (local Y = world up), local Z rolled to face outward
    up = arm_data.edit_bones.new(f"{name}_Upper")
    up.head, up.tail = hip, hip + Z * 0.25
    up.align_roll(out)
    up.parent = root
    low = arm_data.edit_bones.new(f"{name}_Lower")
    low.head, low.tail = knee, knee + Z * 0.25
    low.align_roll(out)
    low.parent = up
bpy.ops.object.mode_set(mode="OBJECT")
mesh.parent = rig
mod = mesh.modifiers.new("Armature", "ARMATURE")
mod.object = rig

# ---------------------------------------------------------------- animation
GROUP_A = {"L1", "R2", "L3", "R4"}  # alternating tetrapod: A swings while B pushes, then swap


def key_pose(frame, body_up, legs):
    scn.frame_set(frame)
    pb = rig.pose.bones["Body"]
    pb.location = (0, body_up, 0)  # bone local Y = world up
    pb.keyframe_insert("location", frame=frame)
    for name, (yaw, lift, bend) in legs.items():
        u = rig.pose.bones[f"{name}_Upper"]
        u.rotation_mode = "XYZ"
        u.rotation_euler = (lift, yaw, 0)
        u.keyframe_insert("rotation_euler", frame=frame)
        lo = rig.pose.bones[f"{name}_Lower"]
        lo.rotation_mode = "XYZ"
        lo.rotation_euler = (bend, 0, 0)
        lo.keyframe_insert("rotation_euler", frame=frame)


def new_action(name):
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    rig.animation_data_create()
    rig.animation_data.action = act
    return act


SWING, LIFT, BEND = 0.22, 0.32, 0.3
new_action("walk-loop")
for f in range(WALK_FRAMES + 1):
    legs = {}
    for name, hip, knee, foot, out in LEGS:
        fwd = 1.0 if Z.cross(out).y < 0 else -1.0  # +yaw moves this foot toward -Y (forward) when fwd = 1
        p = (f / WALK_FRAMES + (0.0 if name in GROUP_A else 0.5)) % 1.0
        if p < 0.5:  # swing: lift and carry the foot forward
            u = p / 0.5
            sweep = -1 + 2 * (3 * u * u - 2 * u * u * u)
            legs[name] = (fwd * SWING * sweep, -LIFT * math.sin(math.pi * u), BEND * math.sin(math.pi * u))
        else:        # stance: foot planted, body slides over it
            u = (p - 0.5) / 0.5
            legs[name] = (fwd * SWING * (1 - 2 * u), 0.0, 0.0)
    key_pose(f, 0.05 * math.sin(4 * math.pi * f / WALK_FRAMES), legs)

new_action("idle-loop")
for f in range(0, 61, 5):
    breathe = 0.035 * math.sin(2 * math.pi * f / 60)
    key_pose(f, breathe, {name: (0.0, 0.0, -breathe * 1.5) for name, *_ in LEGS})

rig.animation_data.action = None
scn.frame_set(0)

print(f"SCOUT tris={tri_count([mesh])} bones={len(arm_data.bones)}")
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "scout.blend"))
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "scout.glb"), export_format="GLB", export_yup=True,
                          export_skins=True, export_animations=True, export_animation_mode="ACTIONS",
                          export_force_sampling=True)
print("SCOUT done")
