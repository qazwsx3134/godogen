"""Re-import the shipped GLB and render six views and representative motion frames.

Run with Blender 5.1: blender -b --python render_enemy.py -- melee|tank
"""
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

kind = sys.argv[sys.argv.index("--") + 1].lower()
if kind not in ("melee", "tank"):
    raise ValueError("Expected melee or tank")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), kind)
bpy.ops.wm.read_factory_settings(use_empty=True)
scn = bpy.context.scene
bpy.ops.import_scene.gltf(filepath=os.path.join(OUT, kind+".glb"), disable_bone_shape=True)
rig = next(o for o in scn.objects if o.type == "ARMATURE")
meshes = [o for o in scn.objects if o.type == "MESH"]
print("CHECK", kind, "BLENDER MESH OBJECTS",
      [(o.name, len(o.data.polygons), o.hide_render) for o in meshes], "BONES", len(rig.data.bones),
      "ACTIONS", [a.name for a in bpy.data.actions])

scn.render.engine = "BLENDER_EEVEE"
scn.render.resolution_x = scn.render.resolution_y = 640
scn.render.resolution_percentage = 100
scn.world = bpy.data.worlds.new("Backdrop")
scn.world.color = (0.52, 0.52, 0.52)
scn.view_settings.view_transform = "Standard"
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 3.4
sun.rotation_euler = (math.radians(34), math.radians(-16), math.radians(-28))
scn.collection.objects.link(sun)
fill = bpy.data.objects.new("Fill", bpy.data.lights.new("Fill", "SUN"))
fill.data.energy = 0.8
fill.rotation_euler = (math.radians(-45), math.radians(35), math.radians(140))
scn.collection.objects.link(fill)
cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
scn.collection.objects.link(cam)
scn.camera = cam
center = Vector((0, -0.85, 1.20))


def shot(name, direction, top=False):
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 7.8
    cam.location = center + direction.normalized()*13
    cam.rotation_euler = ((0, 0, math.pi) if top else
                          (center-cam.location).to_track_quat("-Z", "Y").to_euler())
    path = os.path.join(OUT, "_tmp_"+name+".png")
    scn.render.filepath = path
    bpy.ops.render.render(write_still=True)
    im = bpy.data.images.load(path, check_existing=False)
    pixels = np.array(im.pixels[:]).reshape(640, 640, 4)
    bpy.data.images.remove(im)
    os.remove(path)
    return pixels


def sheet(rows, name):
    pixels = np.vstack([np.hstack(row) for row in rows[::-1]])
    h, w = pixels.shape[:2]
    im = bpy.data.images.new(name, w, h)
    im.pixels = pixels.ravel()
    im.filepath_raw = os.path.join(OUT, name+".png")
    im.file_format = "PNG"
    im.save()
    bpy.data.images.remove(im)


rig.animation_data.action = None
scn.frame_set(0)
views = [shot("side", Vector((1, 0, 0))), shot("front", Vector((0, -1, 0))),
         shot("rear", Vector((0, 1, 0))), shot("top", Vector((0, 0, 1)), top=True),
         shot("front_34", Vector((1, -1.1, 0.75))), shot("rear_34", Vector((-1, 1.1, 0.65)))]
sheet([views[:3], views[3:]], "render_check")

rig.animation_data.action = bpy.data.actions["walk-loop"]
walk = []
for frame in (0, 6, 12, 18):
    scn.frame_set(frame)
    walk.append(shot("walk"+str(frame), Vector((1, -0.6, 0.35))))
rig.animation_data.action = bpy.data.actions["attack" if kind == "melee" else "fire"]
attack = []
for frame in ((0, 5, 9, 20) if kind == "melee" else (0, 2, 5, 12)):
    scn.frame_set(frame)
    attack.append(shot("action"+str(frame), Vector((1, -0.6, 0.35))))
sheet([walk, attack], "render_motion")
print("RENDER", kind, "done")
