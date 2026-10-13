extends SceneTree
## One-off (2026-10-14): points every item without an icon at its pixel icon (assets/pixel/icons/<id>_24.png from
## tools/slice_icon_sheet.py; the fillers reuse rice and coin), and swaps the last vector shapes for pixel sprites:
## the hero's fist, the umbrella, the flying tofu tray and the passing rider. Old shapes stay, hidden.
##   godot --headless --path . -s tools/wire_icons.gd
## Refuses to run twice (player.tscn has Fist/Art). Edit the resources and scenes directly afterwards.

## World px per art px.
const WP := 2.0 / 0.72
const REUSE := {"rice": "rice_24", "change": "coin_24"}

func _init() -> void:
	var player: Node = _open("res://scenes/player.tscn")
	if player.has_node("Motion/Visual/Fist/Art"):
		push_error("already applied; edit the scenes directly")
		player.free()
		quit(1)
		return
	for file: String in DirAccess.get_files_at("res://data/items/"):
		if not file.ends_with(".tres"):
			continue
		var item: Resource = load("res://data/items/" + file)
		if item.icon != null:
			continue
		var name: String = REUSE.get(String(item.id), "%s_24" % item.id)
		var path := "res://assets/pixel/icons/%s.png" % name
		if not ResourceLoader.exists(path):
			print("no icon yet: ", item.id)
			continue
		item.icon = load(path)
		assert(ResourceSaver.save(item) == OK)
		print("icon: ", item.id)
	# The generated fist and rider face left; the scenes face right.
	_sprite(player, "Motion/Visual/Fist", "res://assets/pixel/fx/fist.png", Vector2(20, -29)).flip_h = true
	_sprite(player, "Motion/Umbrella", "res://assets/pixel/fx/umbrella.png", Vector2(-20, -20))
	_save(player, "res://scenes/player.tscn")
	var tofu: Node = _open("res://scenes/tofu.tscn")
	for shape: String in ["Visual/Block", "Visual/BlockOutline"]:
		tofu.get_node(shape).visible = false
	var tray := Sprite2D.new()
	tray.name = "Tray"
	tray.texture = load("res://assets/pixel/fx/tofu.png")
	tray.scale = Vector2.ONE * WP
	tray.position = Vector2(0, -10)
	tofu.get_node("Visual").add_child(tray)
	tray.owner = tofu
	_save(tofu, "res://scenes/tofu.tscn")
	var rider: Node = _open("res://scenes/rider.tscn")
	_sprite(rider, "Visual", "res://assets/pixel/fx/rider.png", Vector2(0, -16)).flip_h = true
	rider.face_travel = false
	rider.upright = true
	_save(rider, "res://scenes/rider.tscn")
	quit()

## Hides the vector children of `holder` and adds a pixel sprite named Art centred on `at` (holder-local).
func _sprite(root: Node, holder: String, texture: String, at: Vector2) -> Sprite2D:
	var parent: Node = root.get_node(holder)
	for child: Node in parent.get_children():
		if child is Polygon2D or child is Line2D:
			child.visible = false
	var art := Sprite2D.new()
	art.name = "Art"
	art.texture = load(texture)
	art.scale = Vector2.ONE * WP
	art.position = at
	parent.add_child(art)
	art.owner = root
	return art

func _open(path: String) -> Node:
	return (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)

func _save(root: Node, path: String) -> void:
	var nodes: int = _count(root)
	var packed := PackedScene.new()
	assert(packed.pack(root) == OK)
	assert(ResourceSaver.save(packed, path) == OK)
	root.free()
	var check: Node = (load(path) as PackedScene).instantiate()
	assert(_count(check) == nodes, "%s lost nodes" % path)
	check.free()
	print("art: ", path)

func _count(node: Node) -> int:
	var total: int = 1
	for child: Node in node.get_children():
		total += _count(child)
	return total
