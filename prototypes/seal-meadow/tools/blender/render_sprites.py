"""Renders a rigged character .blend into paper-doll sprite frames: every layer x animation x direction x frame.

    blender -b <character.blend> --factory-startup -P tools/blender/render_sprites.py -- <config.json> [--preview]

The camera never moves: an orthographic camera looks down `pitch_deg` like the game camera, the sun is fixed in
camera space (light always from the screen's upper left), and the character's root object turns to each direction.
So every layer, direction and frame shares one pixel grid: layers line up by construction.

Paper doll: a layer renders its own collection, with the layers listed in its `holdout` drawn as holdout
(they cut the layer where they stand in front of it but are not drawn). With the body as holdout, a sword behind
the body is cut away in every frame, so the game stacks layers body-first in one fixed order.

Config (paths relative to the config file):
{
  "name": "test_chibi",
  "out": "../render/test_chibi",          frames go to <out>/<layer>/<anim>/<direction>_<i>.png
  "root": "Rig",                           object turned per direction (the armature; meshes are its children)
  "front_rotation_deg": 0,                 root Z rotation at which the model faces the camera (-Y)
  "directions": 8,                         8: front, front_right, right, back_right, back; 4: front, right, back
  "cell_px": 512, "foot_px": 8, "meters_per_px": 0.0042, "pitch_deg": 40,
  "ground_margin_px": 48,                  room under the ground origin for toes that reach toward the camera
  "outline_m": 0.012, "outline_color": [0.17, 0.1, 0.07],   inverted-hull outline added at render time (0: none)
  "sun": true,                             add a sun from the upper left (off: use the .blend's lights)
  "layers": {"body": {"collection": "body"}, "weapon": {"collection": "weapon_sword", "holdout": ["body"]}},
  "anims": {"walk": {"action": "walk", "frames": [1, 7, 13, 19], "d": [9, 9, 9, 9], "loop": true}}
}
Writes <out>/render_index.json for tools/blender/pack_layers.py.
"""
import json
import math
import sys
from pathlib import Path

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

DIRECTION_ANGLES = {
    8: [("front", 0), ("front_right", 45), ("right", 90), ("back_right", 135), ("back", 180)],
    4: [("front", 0), ("right", 90), ("back", 180)],
}


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if not argv:
        raise SystemExit("usage: ... -P render_sprites.py -- <config.json> [--preview]")
    return Path(argv[0]).resolve(), "--preview" in argv


def set_engine(scene):
    for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            scene.render.engine = engine
            return
        except TypeError:
            continue
    raise SystemExit("no EEVEE engine in this Blender")


def setup_scene(cfg):
    scene = bpy.context.scene
    set_engine(scene)
    scene.render.resolution_x = scene.render.resolution_y = cfg["cell_px"]
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    return scene


def setup_camera(scene, cfg):
    data = bpy.data.cameras.new("SpriteCam")
    data.type = "ORTHO"
    data.ortho_scale = cfg["cell_px"] * cfg["meters_per_px"]
    data.clip_start = 0.1
    data.clip_end = 100.0
    cam = bpy.data.objects.new("SpriteCam", data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.rotation_euler = (math.radians(90 - cfg["pitch_deg"]), 0.0, 0.0)
    bpy.context.view_layer.update()
    forward = cam.matrix_world.to_quaternion() @ Vector((0, 0, -1))
    up = cam.matrix_world.to_quaternion() @ Vector((0, 1, 0))
    cam.location = Vector((0, 0, 0.7)) - forward * 20.0
    bpy.context.view_layer.update()
    # Slide the camera along its up axis until the ground origin lands on the ground row.
    # Seen from above, toes and a lunge reach below the ground origin on screen: leave room under it.
    ground_row = cfg["cell_px"] - cfg["foot_px"] - cfg["ground_margin_px"]
    want_v = 1.0 - ground_row / cfg["cell_px"]
    v = world_to_camera_view(scene, cam, Vector((0, 0, 0))).y
    cam.location += up * (v - want_v) * data.ortho_scale
    bpy.context.view_layer.update()
    return cam, ground_row


def setup_sun(scene, cam):
    data = bpy.data.lights.new("SpriteSun", "SUN")
    data.energy = 3.0
    sun = bpy.data.objects.new("SpriteSun", data)
    scene.collection.objects.link(sun)
    q = cam.matrix_world.to_quaternion()
    toward_light = (q @ Vector((-0.6, 0.7, 0.6))).normalized()  # screen upper-left, a little toward the camera
    sun.rotation_euler = Vector((0, 0, -1)).rotation_difference(-toward_light).to_euler()


def outline_material(color):
    mat = bpy.data.materials.new("SpriteOutline")
    mat.use_nodes = True
    mat.use_backface_culling = True
    nodes = mat.node_tree.nodes
    nodes.clear()
    emit = nodes.new("ShaderNodeEmission")
    emit.inputs["Color"].default_value = (*color, 1.0)
    out = nodes.new("ShaderNodeOutputMaterial")
    mat.node_tree.links.new(emit.outputs["Emission"], out.inputs["Surface"])
    return mat


def add_outlines(objects, thickness, color):
    mat = outline_material(color)
    for obj in objects:
        if obj.type != "MESH" or obj.get("no_outline"):
            continue
        obj.data.materials.append(mat)
        mod = obj.modifiers.new("SpriteOutline", "SOLIDIFY")
        mod.thickness = thickness
        mod.offset = 1.0
        mod.use_flip_normals = True
        mod.use_rim = False
        mod.material_offset = len(obj.data.materials) - 1


def collection_objects(name):
    coll = bpy.data.collections.get(name)
    if coll is None:
        raise SystemExit(f"collection '{name}' not found in the .blend")
    return [o for o in coll.all_objects if o.type in {"MESH", "CURVE", "SURFACE", "META", "FONT"}]


def assign_action(obj, action_name):
    action = bpy.data.actions.get(action_name)
    if action is None:
        raise SystemExit(f"action '{action_name}' not found in the .blend")
    ad = obj.animation_data or obj.animation_data_create()
    ad.action = action
    if hasattr(ad, "action_slot") and ad.action_slot is None and len(action.slots):
        ad.action_slot = action.slots[0]


def main():
    config_path, preview = parse_args()
    cfg = json.loads(config_path.read_text(encoding="utf-8"))
    cfg.setdefault("cell_px", 512)
    cfg.setdefault("foot_px", 8)
    cfg.setdefault("meters_per_px", 0.0042)
    cfg.setdefault("pitch_deg", 40)
    cfg.setdefault("ground_margin_px", 48)
    out = (config_path.parent / cfg["out"]).resolve()
    scene = setup_scene(cfg)
    cam, ground_row = setup_camera(scene, cfg)
    if cfg.get("sun", True):
        setup_sun(scene, cam)
    root = bpy.data.objects[cfg["root"]]
    base_rot = math.radians(cfg.get("front_rotation_deg", 0))
    directions = DIRECTION_ANGLES[cfg.get("directions", 8)]

    layer_objects = {n: collection_objects(l["collection"]) for n, l in cfg["layers"].items()}
    every = {o for objs in layer_objects.values() for o in objs}
    if cfg.get("outline_m", 0.012) > 0:
        add_outlines(every, cfg.get("outline_m", 0.012), cfg.get("outline_color", [0.17, 0.1, 0.07]))

    anims = cfg["anims"]
    if preview:  # one frame per layer and direction, to check style and alignment fast
        first = next(iter(anims))
        anims = {first: dict(anims[first], frames=anims[first]["frames"][:1], d=anims[first].get("d", [6])[:1])}

    index = {"name": cfg.get("name", config_path.stem), "cell_px": cfg["cell_px"], "foot_px": cfg["foot_px"],
             "meters_per_px": cfg["meters_per_px"], "ground_row": ground_row,
             "directions": cfg.get("directions", 8), "rows": [d for d, _ in directions],
             "layers": list(cfg["layers"]), "anims": {}}
    count = 0
    for layer_name, layer in cfg["layers"].items():
        held = {o for h in layer.get("holdout", []) for o in layer_objects[h]}  # holdout names other layers
        for obj in every | held:
            obj.hide_render = True
            obj.is_holdout = False
        for obj in layer_objects[layer_name]:
            obj.hide_render = False
        for obj in held - set(layer_objects[layer_name]):
            obj.hide_render = False
            obj.is_holdout = True
        for anim_name, anim in anims.items():
            assign_action(root, anim["action"])
            rows = []
            for dir_name, angle in directions:
                root.rotation_euler.z = base_rot + math.radians(angle)
                row = []
                for i, frame in enumerate(anim["frames"]):
                    scene.frame_set(frame)
                    rel = f"{layer_name}/{anim_name}/{dir_name}_{i}.png"
                    scene.render.filepath = str(out / rel)
                    bpy.ops.render.render(write_still=True)
                    row.append(rel)
                    count += 1
                rows.append(row)
            entry = index["anims"].setdefault(anim_name, {"d": anim.get("d", [6] * len(anim["frames"])),
                                                          "loop": anim.get("loop", True), "layers": {}})
            entry["layers"][layer_name] = rows
    out.mkdir(parents=True, exist_ok=True)
    (out / "render_index.json").write_text(json.dumps(index, indent=2), encoding="utf-8")
    print(f"rendered {count} frames into {out}")


if __name__ == "__main__":
    main()
