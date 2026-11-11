import bpy, sys, os, math
from mathutils import Vector
OUT = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True); scn = bpy.context.scene
bpy.ops.import_scene.gltf(filepath=os.path.join(OUT, "walker.glb"))
scn.render.engine = "BLENDER_EEVEE"; scn.render.resolution_x, scn.render.resolution_y = 1600, 1100
scn.world = bpy.data.worlds.new("w"); scn.world.color = (0.6, 0.6, 0.6); scn.view_settings.view_transform = "Standard"
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); sun.data.energy = 3.5
sun.rotation_euler = (math.radians(40), 0, math.radians(-30)); scn.collection.objects.link(sun)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); scn.collection.objects.link(cam); scn.camera = cam
c = Vector((0, -0.3, 1.5)); cam.data.lens = 40
cam.location = c + Vector((1.0, -1.15, 0.55)).normalized() * 8.2
cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
scn.render.filepath = os.path.join(OUT, "render_closeup.png"); bpy.ops.render.render(write_still=True)
