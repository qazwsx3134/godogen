extends SceneTree
## One-off scene builder (2026-10-13): approved art for heroes, fatty, vehicles, pickups and level-up cards.
## Geometric placeholders stay in the scenes, hidden. The saved scenes are the source from now on.
##   godot --headless --path prototypes/survivor-series -s tools/build_art_scenes.gd

const ART := "res://assets/art/"
## Art is exported at twice the game size and shown at 0.5, feet at this y (the shadow's centre).
const FEET := 8.0

func _init() -> void:
	_player()
	_enemy("fatty", ["enemies/fatty.png"], -96.0)
	_enemy("bike", _dirs("motorcycle"), -90.0)
	_enemy("car", _dirs("car"), -100.0)
	_pickup()
	_card()
	for pair: Array in [["cane", "cane"], ["firecracker", "firecracker"], ["incense", "incense"], ["lantern", "lantern"], ["pearl", "pearl"], ["slipper", "slipper"]]:
		var item: Resource = load("res://data/items/%s.tres" % pair[0])
		item.icon = load(ART + "icons/%s.png" % pair[1])
		assert(ResourceSaver.save(item) == OK)
	quit()

## S, SE, E, NE, N: the order enemy.gd expects.
func _dirs(vehicle: String) -> Array:
	return ["s", "se", "e", "ne", "n"].map(func(d: String) -> String: return "vehicles/%s-%s.png" % [vehicle, d])

func _open(path: String) -> Node:
	return (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)

func _save(root: Node, path: String) -> void:
	var packed := PackedScene.new()
	assert(packed.pack(root) == OK)
	assert(ResourceSaver.save(packed, path) == OK)
	root.free()

## Feet-anchored sprite: the texture's bottom edge sits on FEET whichever direction texture is shown.
func _feet(sprite: Sprite2D, texture: Texture2D) -> void:
	sprite.texture = texture
	sprite.visible = true
	sprite.scale = Vector2(0.5, 0.5)
	sprite.position = Vector2(0, FEET)
	sprite.centered = true
	sprite.offset = Vector2(0, -texture.get_height() * 0.5)

func _player() -> void:
	var root := _open("res://scenes/player.tscn")
	for pair: Array in [["BodyMan", "man"], ["BodyWoman", "woman"]]:
		var body: Node2D = root.get_node("Motion/Visual/" + pair[0])
		for child: Node in body.get_children():
			child.visible = false
		# The body node carries a small placeholder tilt; the art stands straight.
		body.rotation = 0.0
		body.position = Vector2.ZERO
		var art := Sprite2D.new()
		art.name = "Art"
		body.add_child(art)
		art.owner = root
		_feet(art, load(ART + "heroes/%s.png" % pair[1]))
	_save(root, "res://scenes/player.tscn")

func _enemy(scene: String, textures: Array, bar_top: float) -> void:
	var root := _open("res://scenes/%s.tscn" % scene)
	_feet(root.get_node("Visual/Art"), load(ART + textures[1 if textures.size() >= 5 else 0]))
	root.get_node("Visual/Placeholder").visible = false
	if textures.size() >= 5:
		var list: Array[Texture2D] = []
		for path: String in textures:
			list.append(load(ART + path))
		root.direction_textures = list
	var bar: Control = root.get_node("HpBar")
	bar.offset_top = bar_top
	bar.offset_bottom = bar_top + 5.0
	_save(root, "res://scenes/%s.tscn" % scene)

func _pickup() -> void:
	var root := _open("res://scenes/pickup.tscn")
	# look node, icon, height in game px
	for spec: Array in [["Gem", "gem", 18.0], ["GemMid", "gem", 24.0], ["GemBig", "gem", 32.0], ["Coin", "coin", 20.0],
			["Food", "rice", 30.0], ["Magnet", "vacuum", 30.0], ["Chest", "chest", 36.0]]:
		var look: Node2D = root.get_node("Looks/" + spec[0])
		for child: Node in look.get_children():
			child.visible = false
		var art := Sprite2D.new()
		art.name = "Art"
		art.texture = load(ART + "icons/%s.png" % spec[1])
		art.scale = Vector2.ONE * spec[2] / 128.0
		look.add_child(art)
		art.owner = root
	_save(root, "res://scenes/pickup.tscn")

func _card() -> void:
	var root := _open("res://scenes/upgrade_card.tscn")
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	icon.offset_left = -76.0
	icon.offset_top = 8.0
	icon.offset_right = -16.0
	icon.offset_bottom = 68.0
	root.add_child(icon)
	icon.owner = root
	icon.unique_name_in_owner = true
	icon.texture = load(ART + "icons/slipper.png")
	_save(root, "res://scenes/upgrade_card.tscn")
