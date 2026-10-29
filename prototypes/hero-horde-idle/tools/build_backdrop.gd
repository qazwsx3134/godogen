extends SceneTree
## Applied 2026-10-29: the march strip's layered backdrop (docs/bg-layer-prompts.md; textures from
## tools/pack_backdrop.py) as scenes/components/march_backdrop.tscn, instanced as MarchBackdrop in each page in place
## of the landscape cut from the reference image (DistantLandscape, LowerLandscape*, LowerPatch*, Ground). Each
## scrolling layer carries `parallax_depth` metadata that march_arena.gd bind_scenery() reads. The backdrop scene is
## skipped once it exists (edit it in the editor); a page that already has MarchBackdrop is left alone.
##   godot --headless --path prototypes/hero-horde-idle --script res://tools/build_backdrop.gd

const SceneBuilder = preload("res://addons/proto_kit/scene_builder.gd")
const BACKDROP := "res://scenes/components/march_backdrop.tscn"
const DIR := "res://assets/backdrop/"
const PAGES := ["overview", "train", "backpack", "heroes", "adventure", "store"]
## name, texture, top, bottom (page layout px), parallax depth (-1 = does not scroll)
const LAYERS := [
	["Sky", "sky", 100, 525, -1.0],
	["Far", "far", 268, 368, 0.12],
	["Mid", "mid", 322, 472, 0.35],
	["Props", "props", 306, 476, 0.65],
	["Ground", "ground", 466, 526, 1.0],
]


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var ok := _backdrop()
	for page: String in PAGES:
		ok = _swap("res://scenes/pages/%s.tscn" % page) and ok
	quit(0 if ok else 1)


func _backdrop() -> bool:
	var root := Control.new()
	root.name = "MarchBackdrop"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.offset_right = 941.0
	root.offset_bottom = 526.0
	for layer: Array in LAYERS:
		var rect := TextureRect.new()
		rect.texture = load(DIR + layer[1] + ".png")
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_TILE
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.offset_top = layer[2]
		rect.offset_right = 941.0
		rect.offset_bottom = layer[3]
		if layer[4] >= 0.0:
			rect.set_meta(&"parallax_depth", layer[4])
		SceneBuilder.add(root, rect, layer[0])
	return SceneBuilder.save_scene(root, BACKDROP).ok


func _swap(path: String) -> bool:
	var opened: Dictionary = SceneBuilder.open_scene(path)
	var root: Node = opened.root
	if root.get_node_or_null(^"MarchBackdrop") != null:
		root.free()
		return true
	var at: int = root.get_node(^"DistantLandscape").get_index()
	for node: Node in root.get_children():
		var n: String = node.name
		if n == "DistantLandscape" or n == "Ground" or n.begins_with("LowerLandscape") or n.begins_with("LowerPatch"):
			root.remove_child(node)
			node.free()
	SceneBuilder.put(root, SceneBuilder.instance(BACKDROP), "MarchBackdrop", at)
	var refs: Array = opened.refs.duplicate()
	refs.append(BACKDROP)
	return SceneBuilder.save_scene(root, path, {"overwrite": true, "expected_refs": refs}).ok
