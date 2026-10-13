extends SceneTree
## One-off scene builder (2026-10-14) for the user's nine-point feedback: hero HP bar with a drain trail,
## spring hand, thrown tofu, soft smoke, damage numbers, roadblock props and night-market clusters,
## one y-sorted world layer, bigger vehicles and grounded shadows. The saved scenes are the source from now on.
##   godot --headless --path prototypes/survivor-series -s tools/build_feedback_scenes.gd [-- --clusters-only]

const ART := "res://assets/art/"
const SHADOW := Color(0, 0, 0, 0.38)
## name, texture, feet anchor px, scale, footprint width as a fraction of the sprite, footprint depth px.
const PROPS := [
	["StallFruit", "stall-fruit.png", Vector2(78, 111), 1.8, 0.85, 48.0],
	["StallSnack", "stall-snack.png", Vector2(85, 111), 1.8, 0.85, 48.0],
	["LanternPost", "lantern_post.png", Vector2(24, 143), 1.2, 0.3, 14.0],
	["Planter", "planter.png", Vector2(32, 63), 1.0, 0.85, 30.0],
	["Cone", "cone.png", Vector2(12, 31), 1.0, 0.8, 14.0],
	["Bollard", "bollard.png", Vector2(10, 49), 1.0, 0.9, 12.0],
	["ParkedScooter", "parked_scooter.png", Vector2(45, 79), 1.1, 0.8, 26.0],
	["FruitCrate", "fruit_crate.png", Vector2(20, 31), 1.0, 0.9, 22.0],
]
var props: Dictionary = {}

func _init() -> void:
	var puff := _soft_puff()
	for spec: Array in PROPS:
		props[spec[0]] = _prop(spec)
	var clusters: Array[PackedScene] = [_market_row(), _market_double(), _roadblock()]
	# Rebuilds only the props and clusters; the other steps are not repeatable on already-built scenes.
	if "--clusters-only" in OS.get_cmdline_user_args():
		quit()
		return
	_player()
	_smoke(puff)
	_tofu()
	var cane := _cane()
	var item: Resource = load("res://data/items/cane.tres")
	item.projectile = cane
	assert(ResourceSaver.save(item) == OK)
	_vehicle("car", 0.8, Vector2(3.4, 2.4), Vector2(0, -28), -150.0)
	_vehicle("bike", 0.575, Vector2(1.6, 1.5), Vector2(0, 2), -100.0)
	for scene: String in ["smoker", "fatty"]:
		var root := _open("res://scenes/%s.tscn" % scene)
		(root.get_node("Shadow") as Polygon2D).color = SHADOW
		_save(root, "res://scenes/%s.tscn" % scene)
	_street(clusters, _damage_number())
	quit()

func _open(path: String) -> Node:
	return (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)

func _save(root: Node, path: String) -> PackedScene:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var packed := PackedScene.new()
	assert(packed.pack(root) == OK)
	assert(ResourceSaver.save(packed, path) == OK)
	root.free()
	return load(path)

## Owns `node` and its own children; an instanced sub-scene keeps its insides (owning them would save copies).
func _own(node: Node, root: Node) -> void:
	node.owner = root
	if node != root and not node.scene_file_path.is_empty():
		return
	for child: Node in node.get_children():
		_own(child, root)

func _add(parent: Node, child: Node, root: Node) -> Node:
	parent.add_child(child)
	_own(child, root)
	return child

func _count(node: Node) -> int:
	var total: int = 1
	for child: Node in node.get_children():
		total += _count(child)
	return total

## White disc with a soft edge; tinted and scaled for haze and smoke puffs.
func _soft_puff() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0.92))
	gradient.set_color(1, Color(0.6, 0.58, 0.66, 0))
	gradient.add_point(0.7, Color(0.93, 0.93, 0.95, 0.92))
	gradient.add_point(0.86, Color(0.6, 0.58, 0.66, 0.9))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 64
	texture.height = 64
	DirAccess.make_dir_recursive_absolute("res://assets/art/fx")
	assert(ResourceSaver.save(texture, ART + "fx/soft_puff.tres") == OK)
	return load(ART + "fx/soft_puff.tres")

## Prop: feet at the origin (y-sort point), the sprite above it, a StaticBody2D footprint that is a roadblock.
func _prop(spec: Array) -> PackedScene:
	var root := Node2D.new()
	root.name = spec[0]
	var texture: Texture2D = load(ART + "map/" + spec[1])
	var anchor: Vector2 = spec[2]
	var size: float = spec[3]
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = texture
	sprite.centered = false
	sprite.offset = -anchor
	sprite.scale = Vector2.ONE * size
	_add(root, sprite, root)
	var width: float = texture.get_width() * size
	var body := StaticBody2D.new()
	body.name = "Block"
	_add(root, body, root)
	var shape := CollisionShape2D.new()
	shape.name = "Footprint"
	var box := RectangleShape2D.new()
	box.size = Vector2(width * spec[4], spec[5])
	shape.shape = box
	shape.position = Vector2((texture.get_width() * 0.5 - anchor.x) * size, -spec[5] * 0.5 + 2.0)
	_add(body, shape, root)
	if spec[0] == "LanternPost":
		# Light pool centred on the base and a wet reflection toward the camera, both on the ground (under actors).
		for overlay: Array in [["Glow", "lantern_glow.png", Vector2(0, 11)], ["Reflection", "wet_reflection.png", Vector2(0, 106)]]:
			var layer := Sprite2D.new()
			layer.name = overlay[0]
			layer.texture = load(ART + "map/" + overlay[1])
			layer.position = overlay[2] * size
			layer.scale = Vector2.ONE * size
			layer.z_index = -9
			_add(root, layer, root)
	return _save(root, "res://scenes/props/%s.tscn" % String(spec[0]).to_snake_case())

func _cluster(node_name: String, placed: Array) -> PackedScene:
	var root := Node2D.new()
	root.name = node_name
	root.y_sort_enabled = true
	var counts: Dictionary = {}
	for entry: Array in placed:
		var prop := (props[entry[0]] as PackedScene).instantiate() as Node2D
		counts[entry[0]] = int(counts.get(entry[0], 0)) + 1
		prop.name = "%s%d" % [entry[0], counts[entry[0]]]
		prop.position = entry[1]
		if entry.size() > 2 and entry[2]:
			prop.scale.x = -1.0
		_add(root, prop, root)
	return _save(root, "res://scenes/clusters/%s.tscn" % node_name.to_snake_case())

## A row of stalls with lanterns at both ends and crates out front; gaps between stalls are alleys.
func _market_row() -> PackedScene:
	return _cluster("MarketRow", [
		["LanternPost", Vector2(-410, 10)], ["StallFruit", Vector2(-260, 0)], ["StallSnack", Vector2(0, 0)],
		["StallFruit", Vector2(260, 0), true], ["LanternPost", Vector2(400, 10)],
		["FruitCrate", Vector2(-150, 46)], ["FruitCrate", Vector2(120, 52)], ["Cone", Vector2(330, 70)]])

## Two rows facing an aisle, lanterns at the aisle mouths.
func _market_double() -> PackedScene:
	return _cluster("MarketDouble", [
		["StallSnack", Vector2(-140, -150)], ["StallFruit", Vector2(140, -150), true],
		["LanternPost", Vector2(-330, 0)], ["LanternPost", Vector2(330, 0)],
		["StallFruit", Vector2(-140, 160)], ["StallSnack", Vector2(140, 160), true],
		["FruitCrate", Vector2(-20, -110)], ["Planter", Vector2(0, 200)]])

## A street barricade: cones and bollards with a gap, parked scooters and a planter.
func _roadblock() -> PackedScene:
	return _cluster("Roadblock", [
		["Bollard", Vector2(-260, 0)], ["Cone", Vector2(-205, 4)], ["Cone", Vector2(-155, 0)], ["Cone", Vector2(-105, 4)],
		["Cone", Vector2(35, 4)], ["Cone", Vector2(85, 0)], ["Cone", Vector2(135, 4)], ["Bollard", Vector2(190, 0)],
		["ParkedScooter", Vector2(-170, 90)], ["ParkedScooter", Vector2(-60, 96)], ["ParkedScooter", Vector2(120, 90), true],
		["Planter", Vector2(290, -20)], ["LanternPost", Vector2(-330, -30)]])

func _player() -> void:
	var root := _open("res://scenes/player.tscn")
	(root.get_node("Shadow") as Polygon2D).color = SHADOW
	var bar: ProgressBar = root.get_node("HpBar")
	# Above the head (hero art is 90 px tall, feet at y = 8).
	bar.offset_top = -100.0
	bar.offset_bottom = -94.0
	bar.offset_left = -24.0
	bar.offset_right = 24.0
	var trail := bar.duplicate() as ProgressBar
	trail.name = "HpTrail"
	var fill := (bar.get_theme_stylebox("fill") as StyleBoxFlat).duplicate() as StyleBoxFlat
	fill.bg_color = Color("fff1c2")
	trail.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	root.add_child(trail)
	root.move_child(trail, bar.get_index())
	trail.owner = root
	trail.unique_name_in_owner = true
	_save(root, "res://scenes/player.tscn")

func _smoke(puff: Texture2D) -> void:
	var root := _open("res://scenes/smoke.tscn")
	for child: Node in root.get_children():
		root.remove_child(child)
		child.free()
	var haze := Sprite2D.new()
	haze.name = "Haze"
	haze.texture = puff
	haze.scale = Vector2(1.5, 0.6)
	haze.modulate = Color(0.45, 0.38, 0.55, 0.35)
	_add(root, haze, root)
	var puffs := Node2D.new()
	puffs.name = "Puffs"
	_add(root, puffs, root)
	puffs.unique_name_in_owner = true
	for spec: Array in [[Vector2(-22, -14), 0.62], [Vector2(18, -12), 0.7], [Vector2(-4, -26), 0.82], [Vector2(-18, -40), 0.55], [Vector2(14, -42), 0.6]]:
		var sprite := Sprite2D.new()
		sprite.name = "Puff%d" % (puffs.get_child_count() + 1)
		sprite.texture = puff
		sprite.position = spec[0]
		sprite.scale = Vector2.ONE * spec[1]
		sprite.modulate = Color(0.86, 0.85, 0.9, 0.85)
		_add(puffs, sprite, root)
	_save(root, "res://scenes/smoke.tscn")

## The pool and fumes appear only once the thrown tofu lands; the block is what flies.
func _tofu() -> void:
	var root := _open("res://scenes/tofu.tscn")
	var visual: Node2D = root.get_node("Visual")
	var landed := Node2D.new()
	landed.name = "Landed"
	visual.add_child(landed)
	visual.move_child(landed, 0)
	landed.owner = root
	for node_name: String in ["Pool", "PoolEdge", "Fume1", "Fume2", "Fume3"]:
		var node: Node = visual.get_node(node_name)
		node.reparent(landed)
		node.owner = root
	_save(root, "res://scenes/tofu.tscn")

func _cane() -> PackedScene:
	var root := Node2D.new()
	root.name = "SpringHand"
	root.set_script(load("res://scripts/projectile.gd"))
	root.set("mode", "spring")
	root.set("radius", 26.0)
	root.set("face_travel", false)
	var arm := Line2D.new()
	arm.name = "Arm"
	arm.width = 4.0
	arm.default_color = Color("ff8fb1")
	arm.joint_mode = Line2D.LINE_JOINT_ROUND
	_add(root, arm, root)
	arm.unique_name_in_owner = true
	var visual := Node2D.new()
	visual.name = "Visual"
	_add(root, visual, root)
	visual.unique_name_in_owner = true
	var hand := Sprite2D.new()
	hand.name = "Hand"
	hand.texture = load(ART + "icons/cane.png")
	hand.scale = Vector2.ONE * 0.42
	# The icon's hand points up-left; turn it to point along +x.
	hand.rotation = deg_to_rad(135.0)
	_add(visual, hand, root)
	return _save(root, "res://scenes/cane.tscn")

func _damage_number() -> PackedScene:
	var root := Node2D.new()
	root.name = "DamageNumber"
	root.set_script(load("res://scripts/damage_number.gd"))
	var label := Label.new()
	label.name = "Text"
	label.theme = load("res://data/ui_theme.tres")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.offset_left = -40.0
	label.offset_right = 40.0
	label.offset_top = -14.0
	label.offset_bottom = 14.0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color("1a1420"))
	label.add_theme_constant_override("outline_size", 5)
	label.text = "12"
	_add(root, label, root)
	label.unique_name_in_owner = true
	return _save(root, "res://scenes/damage_number.tscn")

func _vehicle(scene: String, art_scale: float, shadow_scale: Vector2, shadow_at: Vector2, bar_top: float) -> void:
	var root := _open("res://scenes/%s.tscn" % scene)
	var art: Sprite2D = root.get_node("Visual/Art")
	art.scale = Vector2.ONE * art_scale
	var shadow: Polygon2D = root.get_node("Shadow")
	shadow.color = SHADOW
	shadow.scale = shadow_scale
	shadow.position = shadow_at
	var bar: Control = root.get_node("HpBar")
	bar.offset_top = bar_top
	bar.offset_bottom = bar_top + 5.0
	_save(root, "res://scenes/%s.tscn" % scene)

## One y-sorted World holds props, enemies and the hero, so whoever stands lower on screen is drawn in front.
func _street(clusters: Array[PackedScene], number: PackedScene) -> void:
	var root := _open("res://scenes/street.tscn")
	var before: int = _count(root)
	var enemies: Node2D = root.get_node("Enemies")
	var world := Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	root.add_child(world)
	root.move_child(world, enemies.get_index())
	world.owner = root
	var map_props: Node2D = root.get_node("Map/Props")
	map_props.y_sort_enabled = true
	for node: Node2D in [map_props, enemies, root.get_node("Player")]:
		node.reparent(world)
		node.owner = root
	(root.get_node("World/Player") as Node2D).z_index = 0
	(root.get_node("Hazards") as Node2D).z_index = 2
	var numbers := Node2D.new()
	numbers.name = "Numbers"
	numbers.z_index = 9
	root.add_child(numbers)
	numbers.owner = root
	numbers.unique_name_in_owner = true
	var map: Node = root.get_node("Map")
	map.set("cluster_scenes", clusters)
	map.set("cluster_weights", PackedFloat32Array([3.0, 2.0, 2.0]))
	root.set("number_scene", number)
	root.set("magnet_radius", 110.0)
	var after: int = _count(root)
	print("street nodes %d -> %d" % [before, after])
	assert(after == before + 2)
	_save(root, "res://scenes/street.tscn")
