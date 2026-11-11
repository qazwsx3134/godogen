# Re-import scout.glb and render (1) side / front / top / 3-4 views and (2) a 4-frame strip of the walk cycle.
# Run like build_scout.py. Writes render_check.png and render_walk.png next to the glb.
import bpy, sys, os, math
import numpy as np
from mathutils import Vector

OUT = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
scn = bpy.context.scene
bpy.ops.import_scene.gltf(filepath=os.path.join(OUT, "scout.glb"))
rig = next(o for o in scn.objects if o.type == "ARMATURE")
meshes = [o for o in scn.objects if o.type == "MESH"]
print("ACTIONS", [a.name for a in bpy.data.actions])
print("MESHES", len(meshes), "BONES", len(rig.data.bones))

scn.render.engine = "BLENDER_EEVEE"
scn.render.resolution_x = scn.render.resolution_y = 640
scn.world = bpy.data.worlds.new("w"); scn.world.color = (0.55, 0.55, 0.55)
scn.view_settings.view_transform = "Standard"
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 3.5; sun.rotation_euler = (math.radians(40), 0, math.radians(-30))
scn.collection.objects.link(sun)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); scn.collection.objects.link(cam)
scn.camera = cam
c = Vector((0, 0, 1.3))

def shot(name, d, ortho, rot=None):
    cam.data.type = "ORTHO" if ortho else "PERSP"
    cam.data.ortho_scale = 6.4
    cam.data.lens = 35
    cam.location = c + d.normalized() * (12 if ortho else 9)
    cam.rotation_euler = rot if rot else (c - cam.location).to_track_quat("-Z", "Y").to_euler()
    path = os.path.join(OUT, f"_tmp_{name}.png")
    scn.render.filepath = path
    bpy.ops.render.render(write_still=True)
    im = bpy.data.images.load(path)
    px = np.array(im.pixels[:]).reshape(640, 640, 4)
    bpy.data.images.remove(im)
    os.remove(path)
    return px

def save(tiles_rows, name):
    rows = [np.hstack(r) for r in tiles_rows]
    sheet = np.vstack(rows[::-1])  # image pixels are bottom-up
    h, w = sheet.shape[:2]
    img = bpy.data.images.new(name, w, h)
    img.pixels = sheet.ravel()
    img.filepath_raw = os.path.join(OUT, name + ".png"); img.file_format = "PNG"; img.save()

rig.animation_data.action = None
scn.frame_set(0)
views = [shot("side", Vector((1, 0, 0)), True), shot("front", Vector((0, -1, 0)), True),
         shot("top", Vector((0, 0, 1)), True, (0, 0, math.pi)), shot("persp", Vector((1.0, -1.1, 0.6)), False)]
save([views[:2], views[2:]], "render_check")

rig.animation_data.action = bpy.data.actions["walk-loop"]
strip = []
for f in (0, 6, 12, 18):
    scn.frame_set(f)
    strip.append(shot(f"w{f}", Vector((1.0, -0.4, 0.35)), False))
save([strip], "render_walk")
print("RENDER done")
