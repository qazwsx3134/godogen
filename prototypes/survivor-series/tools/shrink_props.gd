extends SceneTree
## One-off: map props drawn smaller (PROP_SCALE) at the same pixel density. Each prop's sprite moves to a pixel
## version re-shrunk from its original art; its roadblock footprint, light overlays and hit radius shrink with it,
## and the props inside the night-market clusters move closer together by the same factor.
##   godot --headless --path . -s tools/shrink_props.gd -- --plan     prints the pixelize.py commands to run
##   (run them), godot --headless --path . --import, then godot --headless --path . -s tools/shrink_props.gd
## Applied 2026-10-14 (assets/pixel/.props_shrunk); it refuses to run again. Edit the scenes directly.

const PROP_SCALE := 0.75
const PROPS := ["stall_fruit", "stall_snack", "lantern_post", "planter", "cone", "bollard", "parked_scooter", "fruit_crate"]
const CLUSTERS := ["market_row", "market_double", "roadblock"]
const MARK := "res://assets/pixel/.props_shrunk"

func _init() -> void:
	var plan: bool = "--plan" in OS.get_cmdline_user_args()
	if FileAccess.file_exists(MARK):
		push_error("props already shrunk; edit the scenes directly")
		quit(1)
		return
	for id: String in PROPS:
		var path := "res://scenes/props/%s.tscn" % id
		var root: Node2D = (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		var sprite: Sprite2D = root.get_node("Sprite")
		var old: Texture2D = sprite.texture
		var inner: int = old.get_height() - 2
		var height: int = roundi(inner * PROP_SCALE)
		var art: String = old.resource_path.replace("res://assets/pixel/", "assets/art/").get_basename()
		art = art.left(art.rfind("_")) + ".png"
		var out: String = old.resource_path.get_basename()
		out = out.left(out.rfind("_")) + "_%d.png" % height
		if plan:
			print("uv run --no-project --with pillow --with numpy python tools/pixelize.py --src %s --height %d --out %s" % [art, height, out.trim_prefix("res://")])
			root.free()
			continue
		var ratio: float = float(height) / inner
		sprite.texture = load(out)
		# Texture px -> inner art px (minus the 1 px outline pad), shrink, back.
		sprite.offset = (sprite.offset + Vector2.ONE) * ratio - Vector2.ONE
		var shape: CollisionShape2D = root.get_node("Block/Footprint")
		var box := (shape.shape as RectangleShape2D).duplicate() as RectangleShape2D
		box.size *= PROP_SCALE
		shape.shape = box
		shape.position *= PROP_SCALE
		for overlay: String in ["Glow", "Reflection"]:
			if root.has_node(overlay):
				var layer: Node2D = root.get_node(overlay)
				layer.position *= PROP_SCALE
				layer.scale *= PROP_SCALE
		root.hit_radius *= PROP_SCALE
		_save(root, path)
	if plan:
		quit()
		return
	for id: String in CLUSTERS:
		var path := "res://scenes/clusters/%s.tscn" % id
		var root: Node2D = (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		for prop: Node2D in root.get_children():
			prop.position *= PROP_SCALE
		_save(root, path)
	FileAccess.open(MARK, FileAccess.WRITE).store_string("PROP_SCALE %s %s" % [PROP_SCALE, Time.get_datetime_string_from_system()])
	quit()

func _save(root: Node, path: String) -> void:
	var nodes: int = _count(root)
	var packed := PackedScene.new()
	assert(packed.pack(root) == OK)
	assert(ResourceSaver.save(packed, path) == OK)
	root.free()
	var check: Node = (load(path) as PackedScene).instantiate()
	assert(_count(check) == nodes, "%s lost nodes" % path)
	check.free()
	print("shrunk: ", path)

func _count(node: Node) -> int:
	var total: int = 1
	for child: Node in node.get_children():
		total += _count(child)
	return total
