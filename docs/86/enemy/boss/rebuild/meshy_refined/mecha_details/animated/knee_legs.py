"""Turn the Boss's straight ring legs into two-segment insect legs with a knee.

Open boss_animated.blend. Each of the 62 Leg_Primary rods is replaced by an upper
segment (hip -> raised knee) and a blade-like lower segment (knee -> foot), rigidly
skinned to its own <name>_Upper / <name>_Lower bones under Hull, like the scout.
The 32 short Leg_Secondary struts (they never reached the ground) are removed.
Adds a metachronal 'walk-loop' (waves run front to back, sides in antiphase) and keys
the new bones at rest in idle-loop / fly-loop / fire. Saves boss_animated.blend in
place (git is the backup); refuses to run twice.

blender --background boss_animated.blend --python-exit-code 1 --python knee_legs.py
"""
import math
import os
import sys
from pathlib import Path

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, os.fspath(HERE.parents[5]))
from blender_kit import cyl, tube, hull_pts  # noqa: E402

Z = Vector((0, 0, 1))
# Crouched, splayed jackknife legs after docs/86/enemy/boss/boss-fight.png: flat angular
# plates, knee low and far out, pointed tips planted wide around the hull.
FOOT_OUT = 3.0      # feet moved this much further out than the source rods
KNEE_OUT = 0.62     # knee position along the hip->foot horizontal reach
KNEE_UP = 0.9       # knee height above the hip (m)
PLATE = 4.0         # plate width relative to the source rod radius (thin along the hinge)
FOOT_Z = 1.2        # feet sit 1.2 m up in model space; Godot lowers the Model so the belly hangs ~0.8 m off the ground
LEG_EVERY = 3       # keep every third ring position: fewer, heavier legs
THICK = 2.2         # leg radius relative to the source rod
FPS = 30
WALK_FRAMES = 48    # 1.6 s cycle: slow, heavy
WAVES = 1.0         # one leg wave along each side
SWING_DUTY = 0.3    # fraction of the cycle a foot is in the air
HULL_BOB = 0.18     # hull dips this far (m) as legs plant, twice per cycle
SWING, LIFT, BEND = 0.2, 0.42, 0.5

if Path(bpy.data.filepath).name != 'boss_animated.blend':
    raise RuntimeError('Open boss_animated.blend first')
scene = bpy.context.scene
rig = bpy.data.objects['Boss_Animated_Rig']
if 'Leg_L00_Upper' in rig.data.bones:
    raise RuntimeError('Knee legs already built; restore boss_animated.blend from git to rebuild')
module = bpy.data.objects['Leg_And_Spine_Module']
mat_upper = bpy.data.materials['V2_Blue_Steel']
mat_lower = bpy.data.materials['V2_Bright_Metal']

rods = sorted((o for o in scene.objects if o.type == 'MESH' and o.name.startswith('Leg_Primary')), key=lambda o: o.name)
struts = [o for o in scene.objects if o.type == 'MESH' and o.name.startswith('Leg_Secondary')]
if len(rods) != 62 or len(struts) != 32:
    raise RuntimeError(f'Expected 62 rods and 32 struts, found {len(rods)}/{len(struts)}')

legs = []  # (name, hip, knee, foot, out, radius)
counters = {'L': 0, 'R': 0}
seen = {'L': 0, 'R': 0}
for rod in rods:
    rod_side = 'L' if '_-1_' in rod.name else 'R'  # Leg_Primary_-1_NN = left (-X), names run nose to tail
    seen[rod_side] += 1
    if (seen[rod_side] - 1) % LEG_EVERY:
        continue
    vs = [rod.matrix_world @ v.co for v in rod.data.vertices]
    zmin, zmax = min(v.z for v in vs), max(v.z for v in vs)
    top = [v for v in vs if v.z > zmax - 0.2]
    hip = sum(top, Vector()) / len(top)
    bottom = [v for v in vs if v.z < zmin + 0.2]
    foot = sum(bottom, Vector()) / len(bottom)
    foot.z = FOOT_Z
    radius = max(0.06, max((v - hip).length for v in top)) * THICK
    out = Vector((foot.x - hip.x, foot.y - hip.y, 0)).normalized()
    foot += out * FOOT_OUT
    reach = Vector((foot.x - hip.x, foot.y - hip.y, 0))
    knee = hip + out * (reach.length * KNEE_OUT) + Z * KNEE_UP
    side = 'L' if hip.x < 0 else 'R'
    legs.append((f'Leg_{side}{counters[side]:02d}', hip, knee, foot, out, radius))
    counters[side] += 1
for obj in rods + struts:
    bpy.data.objects.remove(obj, do_unlink=True)


def attach(obj, bone):
    world = obj.matrix_world.copy()
    obj.parent = module
    obj.matrix_world = world
    group = obj.vertex_groups.new(name=bone)
    group.add(list(range(len(obj.data.vertices))), 1.0, 'REPLACE')
    mod = obj.modifiers.new('Boss_Armature', 'ARMATURE')
    mod.object = rig
    mod.use_vertex_groups = True


def join(objs, name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    objs[0].name = objs[0].data.name = name
    return objs[0]


for name, hip, knee, foot, out, r in legs:
    hinge = out.cross(Z).normalized()
    upper = join([tube(f'{name}_thigh', [hip, (hip + knee) * 0.5, knee],
                       [(r * 1.1, r * PLATE * 0.8), (r * 1.2, r * PLATE), (r * 1.0, r * PLATE * 0.75)], mat_upper, hinge),
                  cyl(f'{name}_knee', knee - hinge * r * 1.4, knee + hinge * r * 1.4, r * 1.6, mat_lower, 6)],
                 f'{name}_Upper_Mesh')
    attach(upper, f'{name}_Upper')
    blade = [knee + (knee - hip).normalized() * r * 2.0, knee, knee + (foot - knee) * 0.35, foot]
    lower = join([tube(f'{name}_blade', blade,
                       [(r * 0.9, r * PLATE * 0.5), (r * 1.1, r * PLATE * 1.15), (r * 0.9, r * PLATE * 0.85), (0, 0)],
                       mat_upper, hinge),
                  cyl(f'{name}_shin_rib', knee, knee + (foot - knee) * 0.7, r * 0.45, mat_lower, 4)],
                 f'{name}_Lower_Mesh')
    attach(lower, f'{name}_Lower')

# ---------------------------------------------------------------- bones (local Y = world up, Z rolled outward)
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
hull = rig.data.edit_bones['Hull']
for name, hip, knee, foot, out, r in legs:
    up = rig.data.edit_bones.new(f'{name}_Upper')
    up.head, up.tail = hip, hip + Z * 0.4
    up.align_roll(out)
    up.parent = hull
    low = rig.data.edit_bones.new(f'{name}_Lower')
    low.head, low.tail = knee, knee + Z * 0.4
    low.align_roll(out)
    low.parent = up
bpy.ops.object.mode_set(mode='OBJECT')


def key_legs(frame, poses):
    for name, (yaw, lift, bend) in poses.items():
        u = rig.pose.bones[f'{name}_Upper']
        u.rotation_mode = 'XYZ'
        u.rotation_euler = (lift, yaw, 0)
        u.keyframe_insert('rotation_euler', frame=frame)
        lo = rig.pose.bones[f'{name}_Lower']
        lo.rotation_mode = 'XYZ'
        lo.rotation_euler = (bend, 0, 0)
        lo.keyframe_insert('rotation_euler', frame=frame)


rest = {name: (0.0, 0.0, 0.0) for name, *_ in legs}
for action_name in ('idle-loop', 'fly-loop', 'fire'):
    action = bpy.data.actions[action_name]
    rig.animation_data.action = action
    start, end = (int(v) for v in action.frame_range)
    for frame in (start, end):
        scene.frame_set(frame)
        key_legs(frame, rest)

walk = bpy.data.actions.new('walk-loop')
walk.use_fake_user = True
rig.animation_data.action = walk
side_count = {'L': counters['L'], 'R': counters['R']}
stance_travel = []
for frame in range(0, WALK_FRAMES + 1, 2):
    scene.frame_set(frame)
    poses = {}
    for name, hip, knee, foot, out, r in legs:
        side, index = name[4], int(name[5:7])
        fwd = 1.0 if Z.cross(out).y < 0 else -1.0  # +yaw carries this foot toward the nose (-Y)
        p = (frame / WALK_FRAMES + WAVES * index / side_count[side] + (0.5 if side == 'R' else 0.0)) % 1.0
        if p < SWING_DUTY:
            u = p / SWING_DUTY
            sweep = -1 + 2 * (3 * u * u - 2 * u * u * u)
            poses[name] = (fwd * SWING * sweep, -LIFT * math.sin(math.pi * u), BEND * math.sin(math.pi * u))
        else:
            u = (p - SWING_DUTY) / (1 - SWING_DUTY)
            poses[name] = (fwd * SWING * (1 - 2 * u), 0.0, 0.0)
    key_legs(frame, poses)
    hull = rig.pose.bones['Hull']
    hull.location = (0, -HULL_BOB * abs(math.sin(2 * math.pi * frame / WALK_FRAMES)), 0)  # bone local Y = up
    hull.keyframe_insert('location', frame=frame)
for name, hip, knee, foot, out, r in legs:
    reach = Vector((foot.x - hip.x, foot.y - hip.y, 0)).length
    stance_travel.append(2 * SWING * reach * abs(out.x))
walk_speed = sum(stance_travel) / len(stance_travel) / ((1 - SWING_DUTY) * WALK_FRAMES / FPS)

rig.animation_data.action = bpy.data.actions['idle-loop']
scene.frame_set(0)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_mainfile()
parts = [o for o in scene.objects if o.type == 'MESH' and o.parent is not None and o.name != 'Boss_Animated_Runtime']
print('KNEE_LEGS_SAVED legs', len(legs), 'bones', len(rig.data.bones), 'walk_speed_m_s', round(walk_speed, 3))
