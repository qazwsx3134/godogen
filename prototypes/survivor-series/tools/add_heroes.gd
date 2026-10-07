extends SceneTree
## One-time authoring migration for the two heroes, the night-market street and the smoke-eyed smoker (docs/art-direction.md).
## Run: godot --headless --path . --script res://tools/add_heroes.gd
## Applied 2026-10-07. Skips itself once player.tscn has BodyWoman; after that edit the scenes directly (re-running would erase hand edits).
const B = preload("res://addons/proto_kit/scene_builder.gd")
const INK := "13202d"
var failed: bool = false

func _initialize() -> void:
	build.call_deferred()

func poly(parent: Node, node_name: String, color: String, points: PackedVector2Array, at: Vector2 = Vector2.ZERO) -> Polygon2D:
	var shape := Polygon2D.new()
	shape.color = Color(color)
	shape.polygon = points
	shape.position = at
	B.add(parent, shape, node_name)
	return shape

func P(flat: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i: int in range(0, flat.size(), 2):
		points.append(Vector2(flat[i], flat[i + 1]))
	return points

func circle(radius: float, steps: int = 14) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i: int in steps:
		points.append(Vector2.RIGHT.rotated(TAU * i / steps) * radius)
	return points

func paint(root: Node, path: String, color: String, points: PackedVector2Array = PackedVector2Array()) -> void:
	var shape := root.get_node(path) as Polygon2D
	shape.color = Color(color)
	if not points.is_empty():
		shape.polygon = points

func save(node: Node, path: String, refs: Array = []) -> void:
	var result: Dictionary = B.save_scene(node, path, {"overwrite": true, "expected_refs": refs})
	failed = failed or not result.ok

func build() -> void:
	var hero := B.instance("res://scenes/player.tscn")
	if hero.has_node("%BodyWoman"):
		hero.free()
		print("skip: heroes already authored; edit the scenes directly")
		quit()
		return
	hero_scene(hero)
	smoker_scene()
	street_scene()
	menu_scene()
	quit(1 if failed else 0)

# --- Player: Body{Man,Woman} share the Fist; looks are placeholders until the pixel sprites arrive ---------

func hero_scene(hero: Node) -> void:
	var visual := hero.get_node("%Visual")
	var body := visual.get_node("Placeholder")
	var fist := body.get_node("Fist")
	body.remove_child(fist)
	visual.add_child(fist)  # kept in the same space: Placeholder sits at the origin
	body.name = "BodyMan"
	body.unique_name_in_owner = true
	# Man: big head, drooping shoulders, slicked-back black hair, navy suit and red tie, tired eyes, slight slouch.
	paint(body, "LegLeft", "1c2a55")
	paint(body, "LegRight", "1c2a55")
	paint(body, "ShoeLeft", "1b1b22")
	paint(body, "ShoeRight", "1b1b22")
	paint(body, "JacketOutline", INK, P([-26, -30, -12, -39, 12, -39, 24, -30, 22, -9, -23, -9]))
	paint(body, "Jacket", "26377a", P([-22, -29, -10, -36, 10, -36, 20, -29, 19, -12, -19, -12]))
	paint(body, "Hair", "0d0d14", P([-16, -51, -12, -65, 10, -66, 17, -52, 0, -58]))
	var head_outline := body.get_node("HeadOutline") as Polygon2D
	var face := body.get_node("Face") as Polygon2D
	head_outline.scale = Vector2(1.18, 1.12)
	face.scale = Vector2(1.18, 1.12)
	head_outline.position.y = -47
	face.position.y = -45
	(body.get_node("EyeLeft") as Polygon2D).polygon = P([0, 0, 4, 0, 4, 2, 0, 2])
	(body.get_node("EyeRight") as Polygon2D).polygon = P([0, 0, 4, 0, 4, 2, 0, 2])
	(body.get_node("EyeLeft") as Polygon2D).position = Vector2(-8, -47)
	(body.get_node("EyeRight") as Polygon2D).position = Vector2(5, -47)
	poly(body, "Shirt", "f2efe6", P([-4, -36, 5, -36, 0, -27]))
	poly(body, "Tie", "d9232d", P([-2.5, -34, 3, -34, 4.5, -21, 0.5, -15, -3.5, -21]))
	body.rotation = 0.06
	body.position = Vector2(-1, 1)
	# Woman: upright, wine hair, black short jacket over a light-blue top, white boots, sharp line eyes.
	var woman := body.duplicate() as Node2D
	woman.name = "BodyWoman"
	woman.rotation = 0.0
	woman.position = Vector2.ZERO
	woman.visible = false
	visual.add_child(woman)
	visual.move_child(woman, body.get_index() + 1)
	woman.get_node("Shirt").queue_free()
	woman.get_node("Tie").queue_free()
	paint(woman, "LegLeft", "4a2a24")
	paint(woman, "LegRight", "4a2a24")
	paint(woman, "ShoeLeft", "f4f5fb")
	paint(woman, "ShoeRight", "f4f5fb")
	paint(woman, "JacketOutline", INK, P([-21, -38, 19, -38, 22, -16, -19, -16]))
	paint(woman, "Jacket", "1a1a22", P([-18, -35, 16, -35, 19, -18, -16, -18]))
	paint(woman, "Hair", "8a1f3d", P([-17, -50, -12, -64, 11, -64, 17, -50, 0, -56]))
	poly(woman, "Top", "a8d4f0", P([-14, -19, 15, -19, 18, -10, -17, -10]))
	poly(woman, "HairLeft", "8a1f3d", P([-17, -52, -12, -52, -13, -33, -20, -30]))
	poly(woman, "HairRight", "8a1f3d", P([14, -52, 18, -50, 21, -30, 14, -34]))
	head_outline = woman.get_node("HeadOutline")
	face = woman.get_node("Face")
	head_outline.scale = Vector2.ONE
	face.scale = Vector2.ONE
	head_outline.position.y = -45
	face.position.y = -43
	var left_eye := woman.get_node("EyeLeft") as Polygon2D
	var right_eye := woman.get_node("EyeRight") as Polygon2D
	left_eye.position = Vector2(-9, -47)
	right_eye.position = Vector2(4, -47)
	left_eye.polygon = P([0, 1, 5, -1, 5, 1, 0, 3])
	right_eye.polygon = P([0, -1, 5, 1, 5, 3, 0, 1])
	left_eye.color = Color("8a1f3d")
	right_eye.color = Color("8a1f3d")
	B.unique(woman)
	save(hero, "res://scenes/player.tscn")

# --- Smoker: a smoke-black mass with glowing red eyes -------------------------------------------------------

func smoker_scene() -> void:
	var smoker := B.instance("res://scenes/smoker.tscn")
	var body := "Visual/Placeholder/"
	for part: String in ["LegLeft", "LegRight", "ShoeLeft", "ShoeRight", "JacketOutline", "HeadOutline", "Hair"]:
		paint(smoker, body + part, "0d0b12")
	paint(smoker, body + "Jacket", "2a2433")
	paint(smoker, body + "Face", "3a3345")
	for eye: String in ["EyeLeft", "EyeRight"]:
		paint(smoker, body + eye, "ff3b30", P([0, 0, 5, 0, 5, 4, 0, 4]))
	save(smoker, "res://scenes/smoker.tscn")

# --- Street: warm night-market palette, striped awnings and lanterns along the border -------------------------

func street_scene() -> void:
	var street := B.instance("res://scenes/street.tscn")
	var block := street.get_node("Block")
	var palette := {"Sidewalk": "5b4538", "Asphalt": "2e2527", "CrossStreet": "362b2d", "CenterDash": "b89a62", "CrossDash": "b89a62", "Crosswalk": "d1b98c", "Planter": "5e4436", "Shrub": "33702f", "Manhole": "130f12", "ParkingLine": "a68c62"}
	for child: Node in block.get_children():
		if not child is Polygon2D:
			continue
		for prefix: String in palette:
			if child.name.begins_with(prefix):
				(child as Polygon2D).color = Color(palette[prefix])
				break
	var market := Node2D.new()
	B.add(block, market, "NightMarket")
	var awnings := Node2D.new()
	B.add(market, awnings, "Awnings")
	for row: int in 2:
		var y: float = 0.0 if row == 0 else 1644.0
		for i: int in 25:
			poly(awnings, "Awning%d_%d" % [row + 1, i + 1], "d63a35" if i % 2 == 0 else "f3e9dc", P([0, 0, 48, 0, 48, 36, 0, 36]), Vector2(i * 48.0, y))
	var lanterns := Node2D.new()
	B.add(market, lanterns, "Lanterns")
	for row: int in 2:
		var y: float = 52.0 if row == 0 else 1628.0
		for i: int in 12:
			var at := Vector2(60.0 + i * 98.0, y)
			var glow := poly(lanterns, "Glow%d_%d" % [row + 1, i + 1], "ffb347", circle(17.0), at)
			glow.color.a = 0.28
			poly(lanterns, "Lantern%d_%d" % [row + 1, i + 1], "ff7a2e", circle(7.0), at)
	block.move_child(market, block.get_node("BackgroundArt").get_index())
	var heroes: Array[Resource] = [load("res://data/heroes/man.tres"), load("res://data/heroes/woman.tres")]
	street.heroes = heroes
	save(street, "res://scenes/street.tscn", ["res://scenes/player.tscn"])

# --- Menu: hero picker between the instructions and Start ---------------------------------------------------

func menu_scene() -> void:
	var menu := B.instance("res://scenes/menu.tscn")
	var column := menu.get_node("Center/Column")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	B.add(column, row, "HeroRow")
	for entry: Array in [["HeroMan", "男｜厭世西裝"], ["HeroWoman", "女｜冷酷外套"]]:
		var pick := Button.new()
		pick.toggle_mode = true
		pick.custom_minimum_size = Vector2(0, 52)
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.text = entry[1]
		B.add(row, B.unique(pick), entry[0])
	var note := Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.custom_minimum_size = Vector2(0, 44)
	note.add_theme_color_override("font_color", Color("ffc56b"))
	note.add_theme_font_size_override("font_size", 15)
	note.text = "平常很累，打起來很兇"
	B.add(column, B.unique(note), "HeroNote")
	column.move_child(row, column.get_node("Instructions").get_index() + 1)
	column.move_child(note, row.get_index() + 1)
	save(menu, "res://scenes/menu.tscn")
