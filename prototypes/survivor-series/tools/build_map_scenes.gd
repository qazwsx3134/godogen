extends SceneTree
## One-off scene builder (2026-10-12): prop item scenes, the endless map in street.tscn, gangster art on the smoker.
## The saved scenes are the source from now on; do not rerun over hand edits without checking the diff.
##   godot --headless --path prototypes/survivor-series -s tools/build_map_scenes.gd

const ART := "res://assets/art/map/"
## name, texture, feet anchor in px (from art_src/map/godot's exported demo scene).
const PROPS := [
	["StallFruit", "stall-fruit.png", Vector2(78, 111)],
	["StallSnack", "stall-snack.png", Vector2(85, 111)],
	["LanternPost", "lantern_post.png", Vector2(24, 143)],
	["Planter", "planter.png", Vector2(32, 63)],
	["Cone", "cone.png", Vector2(12, 31)],
	["Bollard", "bollard.png", Vector2(10, 49)],
	["ParkedScooter", "parked_scooter.png", Vector2(45, 79)],
	["FruitCrate", "fruit_crate.png", Vector2(20, 31)],
]

func _init() -> void:
	var scenes: Array[PackedScene] = []
	for spec: Array in PROPS:
		scenes.append(_prop(spec[0], spec[1], spec[2]))
	_street(scenes)
	_smoker()
	quit()

func _save(root: Node, path: String) -> PackedScene:
	var packed := PackedScene.new()
	assert(packed.pack(root) == OK)
	assert(ResourceSaver.save(packed, path) == OK)
	root.free()
	return load(path)

func _prop(node_name: String, file: String, anchor: Vector2) -> PackedScene:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.texture = load(ART + file)
	sprite.centered = false
	sprite.offset = -anchor
	if node_name == "LanternPost":
		# Light pool centred on the base; the wet reflection runs from the base toward the camera.
		for overlay: Array in [["Glow", "lantern_glow.png", Vector2(0, 11)], ["Reflection", "wet_reflection.png", Vector2(0, 106)]]:
			var layer := Sprite2D.new()
			layer.name = overlay[0]
			layer.texture = load(ART + overlay[1])
			layer.position = overlay[2]
			layer.show_behind_parent = true
			sprite.add_child(layer)
			layer.owner = sprite
	return _save(sprite, "res://scenes/props/%s.tscn" % node_name.to_snake_case())

func _street(prop_scenes: Array[PackedScene]) -> void:
	var root: Node = (load("res://scenes/street.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	var before: int = _count(root)
	var block: Node = root.get_node("Block")
	var removed: int = _count(block)
	root.remove_child(block)
	block.free()
	var map := Node2D.new()
	map.name = "Map"
	map.z_index = -10
	map.set_script(load("res://scripts/map.gd"))
	map.set("prop_scenes", prop_scenes)
	root.add_child(map)
	root.move_child(map, 0)
	map.owner = root
	map.unique_name_in_owner = true
	var ground := Sprite2D.new()
	ground.name = "Ground"
	ground.texture = load(ART + "pavement.png")
	ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ground.region_enabled = true
	# 4096 covers a wide desktop view plus one tile of snapping; a multiple of 512 keeps the tiles aligned.
	ground.region_rect = Rect2(0, 0, 4096, 4096)
	var props := Node2D.new()
	props.name = "Props"
	for child: Node2D in [ground, props]:
		map.add_child(child)
		child.owner = root
		child.unique_name_in_owner = true
	var camera: Camera2D = root.get_node("Camera")
	camera.limit_left = -10000000
	camera.limit_top = -10000000
	camera.limit_right = 10000000
	camera.limit_bottom = 10000000
	var after: int = _count(root)
	print("street nodes: %d -> %d (removed %d, added 3)" % [before, after, removed])
	assert(after == before - removed + 3)
	_save(root, "res://scenes/street.tscn")

func _smoker() -> void:
	var root: Node = (load("res://scenes/smoker.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	var art: Sprite2D = root.get_node("Visual/Art")
	art.texture = load("res://assets/art/enemies/gangster.png")
	art.visible = true
	# 160 px source at 0.5 = 80 px tall, feet on the shadow.
	art.scale = Vector2(0.5, 0.5)
	art.position = Vector2(0, -32)
	root.get_node("Visual/Placeholder").visible = false
	var bar: Control = root.get_node("HpBar")
	bar.offset_top = -82.0
	bar.offset_bottom = -77.0
	_save(root, "res://scenes/smoker.tscn")

func _count(node: Node) -> int:
	var total: int = 1
	for child: Node in node.get_children():
		total += _count(child)
	return total
