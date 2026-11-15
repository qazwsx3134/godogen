"""Add an editable 11-bone flying Boss rig to the saved mecha model.

Open boss_mecha.blend first. Saves a separate boss_animated.blend; it never
modifies the starting .blend. Rebuilding requires --overwrite when output exists.
"""
import math
import os
import sys
from pathlib import Path

import bpy
from mathutils import Vector

HERE=Path(r'D:\repo\godot\godogen\docs\86\enemy\boss\rebuild\meshy_refined\mecha_details\animated')
if '__file__' in globals() and Path(__file__).name=='build_rig.py':
    HERE=Path(__file__).resolve().parent
OUT=HERE/'boss_animated.blend'
if OUT.exists() and '--overwrite' not in sys.argv:
    raise RuntimeError('Animated source already exists; preserve it or pass --overwrite')
if Path(bpy.data.filepath).name!='boss_mecha.blend':
    raise RuntimeError('Open boss_mecha.blend as the source')
scene=bpy.context.scene
scene.render.fps=30
scene.render.fps_base=1.0
root=bpy.data.objects.get('Boss_40m')
if root is None:
    raise RuntimeError('Missing Boss_40m')


def in_boss(obj):
    node=obj
    while node is not None:
        if node==root:
            return True
        node=node.parent
    return False


def ancestors(obj):
    result=set()
    node=obj.parent
    while node is not None:
        result.add(node.name)
        node=node.parent
    return result


parts=[obj for obj in scene.objects if obj.type=='MESH' and in_boss(obj)]
if len(parts)!=607:
    raise RuntimeError(f'Expected 607 source meshes, found {len(parts)}; inspect source before rebuilding')
if any(obj.modifiers.get('Boss_Armature') for obj in parts):
    raise RuntimeError('Source already has Boss armature modifiers')
arm=bpy.data.armatures.new('Boss_Animated_Skeleton')
rig=bpy.data.objects.new('Boss_Animated_Rig',arm)
scene.collection.objects.link(rig)
rig.show_in_front=True
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
hull=arm.edit_bones.new('Hull')
hull.head=(0,0,4.7)
hull.tail=(0,0,5.7)
cannon=arm.edit_bones.new('Cannon')
cannon.head=(0,-.05,7.05)
cannon.tail=(0,-1.05,7.05)
cannon.parent=hull
rotor=arm.edit_bones.new('CoreRotor')
rotor.head=(0,-2.15,6.24)
rotor.tail=(0,-2.15,7.24)
rotor.parent=hull


def tail_center(side,t):
    return Vector((side*(1.30+.58*t),4.9+14.25*t,6.45+2.15*t))


for letter,side in (('L',-1),('R',1)):
    parent=hull
    for index in range(4):
        bone=arm.edit_bones.new(f'Tail_{letter}_{index+1}')
        bone.head=tail_center(side,index/4)
        bone.tail=tail_center(side,(index+1)/4)
        bone.parent=parent
        bone.use_connect=index>0
        parent=bone
bpy.ops.object.mode_set(mode='OBJECT')
bpy.context.view_layer.update()

# Rigid armor pieces follow their local segment. The long core and side rails
# blend between neighbouring joints so the tail bends without an abrupt kink.
counts={name:0 for name in arm.bones.keys()}
blended_vertices=0
for obj in parts:
    lineage=ancestors(obj)
    if 'Tail_Left_Module' in lineage or 'Tail_Right_Module' in lineage:
        letter='L' if 'Tail_Left_Module' in lineage else 'R'
        bone_names=[f'Tail_{letter}_{i}' for i in range(1,5)]
        groups=[obj.vertex_groups.new(name=name) for name in bone_names]
        smooth=obj.name.startswith(('Tail_Structural_Core_', 'Mecha_Tail_Side_Rail_'))
        if smooth:
            for vertex in obj.data.vertices:
                y=(obj.matrix_world@vertex.co).y
                u=max(0.0,min(3.0,((y-4.9)/14.25)*4.0-.5))
                idx=int(math.floor(u)); frac=u-idx
                groups[idx].add([vertex.index],1.0-frac,'REPLACE')
                if frac>1e-7 and idx<3:
                    groups[idx+1].add([vertex.index],frac,'REPLACE')
                    blended_vertices+=1
        else:
            y=sum((obj.matrix_world@v.co).y for v in obj.data.vertices)/len(obj.data.vertices)
            idx=max(0,min(3,int((y-4.9)/14.25*4)))
            groups[idx].add(list(range(len(obj.data.vertices))),1.0,'REPLACE')
        for group in groups:
            if any(g.group==group.index and g.weight>0 for v in obj.data.vertices for g in v.groups):
                counts[group.name]+=1
    else:
        moving_cannon=('Cannon_Module' in lineage and
                       not obj.name.startswith(('Cannon_Mount_Post','Cannon_Underside_Cradle')))
        moving_rotor=obj.name.startswith(('Meshy_Top_Turbine_Vane_','Meshy_Top_Turbine_Hub'))
        bone='Cannon' if moving_cannon else ('CoreRotor' if moving_rotor else 'Hull')
        group=obj.vertex_groups.new(name=bone)
        group.add(list(range(len(obj.data.vertices))),1.0,'REPLACE')
        counts[bone]+=1
    mod=obj.modifiers.new('Boss_Armature','ARMATURE')
    mod.object=rig
    mod.use_vertex_groups=True
print('BOSS_RIG_WEIGHTS',counts,'blended_vertices',blended_vertices)
if any(value==0 for value in counts.values()):
    raise RuntimeError('An animated bone has no geometry')


def rest_pose():
    for pose in rig.pose.bones:
        pose.rotation_mode='XYZ'
        pose.location=(0,0,0)
        pose.rotation_euler=(0,0,0)
        pose.scale=(1,1,1)


def make_action(name):
    action=bpy.data.actions.new(name)
    action.use_fake_user=True
    rig.animation_data_create()
    rig.animation_data.action=action
    return action


def key_all(frame):
    for pose in rig.pose.bones:
        pose.keyframe_insert(data_path='location',frame=frame)
        pose.keyframe_insert(data_path='rotation_euler',frame=frame)


def tail_wave(phase,amplitude):
    for letter,sign in (('L',-1),('R',1)):
        for i in range(4):
            offset=.45*i + (.16 if sign>0 else 0.0)
            # Subtract the initial value so all clips start and end at rest.
            value=math.sin(2*math.pi*phase-offset)+math.sin(offset)
            pose=rig.pose.bones[f'Tail_{letter}_{i+1}']
            pose.rotation_euler.z=math.radians(amplitude)*(0.70+.12*i)*value
            pose.rotation_euler.x=math.radians(amplitude*.24)*math.sin(2*math.pi*phase)


make_action('idle-loop')
for frame in range(0,91,5):
    scene.frame_set(frame)
    rest_pose()
    t=frame/90
    rig.pose.bones['Hull'].location.y=.20*(1-math.cos(2*math.pi*t))
    rig.pose.bones['CoreRotor'].rotation_euler.y=2*math.pi*t
    tail_wave(t,.8)
    key_all(frame)

make_action('fly-loop')
for frame in range(0,55,3):
    scene.frame_set(frame)
    rest_pose()
    t=frame/54
    rig.pose.bones['Hull'].location.y=.14*(1-math.cos(2*math.pi*t))
    rig.pose.bones['CoreRotor'].rotation_euler.y=2*math.pi*t
    tail_wave(t,1.8)
    key_all(frame)

make_action('fire')
for frame,recoil,body_lift in [(0,0,0),(6,-.10,.025),(9,-.18,.06),
                                (10,-.80,.10),(13,-.56,.08),(20,-.15,.03),
                                (28,0,0),(36,0,0)]:
    scene.frame_set(frame)
    rest_pose()
    t=frame/36
    rig.pose.bones['Hull'].location.y=body_lift
    # Cannon's local +Y points toward the nose, so negative Y recoils aft.
    rig.pose.bones['Cannon'].location.y=recoil
    rig.pose.bones['CoreRotor'].rotation_euler.y=2*math.pi*t
    tail_wave(t,.55)
    key_all(frame)

rig.animation_data.action=bpy.data.actions['idle-loop']
scene.frame_set(0)
rest_pose()
bpy.context.view_layer.update()
scene.frame_start=0
scene.frame_end=90
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=os.fspath(OUT))
print('BOSS_RIG_SAVED',OUT,'parts',len(parts),'bones',len(arm.bones),
      'actions',[(a.name,tuple(a.frame_range)) for a in bpy.data.actions if a.name in ('idle-loop','fly-loop','fire')])
