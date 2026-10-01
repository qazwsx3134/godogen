extends SceneTree
## One-off authoring tool for the concept-art arena pass (.claude/tasks/sugarcane-art/arena-brief.md).
## Rebuilds arena/door.tscn and the four obstacle scenes, creates arena/arena_{temple,square,memorial,hall}.tscn
## (a painted Background plus invisible Walls that follow what is drawn), re-lays-out rooms/room_01..10.tscn
## (arena, obstacles, enemy and start positions, y-sort) and edits main.tscn and effects/aoe_circle.tscn.
##
##   godot --headless --path . --script res://tools/apply_arena_art.gd
##
## It has been applied. From here on the saved .tscn files are the source: edit them in the editor.
## Running it again is refused (arena_hall.tscn exists), because a second pass would overwrite hand edits;
## `-- --force` runs it anyway and rewrites everything listed above.
##
## All coordinates are world pixels (the world is 1080x1920 and each background covers it exactly).
## A wall is a rectangle the hero cannot enter; together they trace what the background draws as a
## railing, garden, building or tree. `walk` bounds the open floor (enemies and the hero start inside it).
## A door sits at the painted exit: `at` is the middle of its threshold, `scale` fits the visuals to the
## painted doorway.

const ARENAS: Dictionary = {
	"temple": {
		"name": "ArenaTemple", "bg": "res://assets/bg_temple.png", "scene": "res://arena/arena_temple.tscn",
		"walk": Rect2(80, 287, 925, 1420),
		"door": {"at": Vector2(540, 250), "scale": Vector2(1.0, 1.05)},
		"walls": [
			["TopLeft", Rect2(-100, -100, 540, 387)],
			["TopRight", Rect2(640, -100, 540, 387)],
			["GateDoors", Rect2(440, -100, 200, 325)],
			["LionLeft", Rect2(305, 280, 70, 32)],
			["LionRight", Rect2(705, 280, 70, 32)],
			["Left", Rect2(-100, 280, 180, 1570)],
			["Right", Rect2(1005, 280, 175, 1570)],
			["CenserLeft", Rect2(78, 545, 32, 95)],
			["CenserRight", Rect2(970, 545, 35, 95)],
			["BottomLeft", Rect2(-100, 1707, 527, 300)],
			["BottomRight", Rect2(660, 1707, 520, 300)],
			["BottomEnd", Rect2(380, 1850, 340, 200)],
		],
	},
	"square": {
		"name": "ArenaSquare", "bg": "res://assets/bg_square.png", "scene": "res://arena/arena_square.tscn",
		"walk": Rect2(68, 235, 942, 1573),
		"door": {"at": Vector2(543, 238), "scale": Vector2(0.4, 0.42)},
		"walls": [
			["TopLeft", Rect2(-100, -100, 562, 400)],
			["TopRight", Rect2(618, -100, 562, 400)],
			["GateBase", Rect2(462, -100, 156, 335)],
			["PlanterLeft", Rect2(200, 300, 55, 107)],
			["PlanterRight", Rect2(827, 300, 55, 107)],
			["Left", Rect2(-100, 300, 168, 1520)],
			["Right", Rect2(1010, 300, 170, 1520)],
			["LampLeft", Rect2(66, 1068, 44, 175)],
			["LampRight", Rect2(972, 1068, 40, 175)],
			["FenceLeft", Rect2(-100, 1493, 533, 102)],
			["FenceRight", Rect2(653, 1493, 527, 102)],
			["Bottom", Rect2(-100, 1808, 1280, 300)],
		],
	},
	"memorial": {
		"name": "ArenaMemorial", "bg": "res://assets/bg_memorial.png", "scene": "res://arena/arena_memorial.tscn",
		"walk": Rect2(66, 535, 954, 1295),
		"door": {"at": Vector2(541, 540), "scale": Vector2(0.45, 0.5)},
		"walls": [
			["Top", Rect2(-100, -100, 1280, 635)],
			["GardenLeftUpper", Rect2(-100, 535, 475, 210)],
			["GardenLeftLower", Rect2(-100, 745, 405, 100)],
			["GardenRightUpper", Rect2(705, 535, 475, 210)],
			["GardenRightLower", Rect2(765, 745, 415, 100)],
			["StairRailLeft", Rect2(465, 520, 22, 225)],
			["StairRailRight", Rect2(598, 520, 19, 225)],
			["Left", Rect2(-100, 845, 166, 540)],
			["Right", Rect2(1018, 845, 162, 540)],
			["BannerLeft", Rect2(-100, 1385, 280, 135)],
			["BannerRight", Rect2(900, 1385, 280, 135)],
			["BedLeft", Rect2(-100, 1520, 400, 185)],
			["BedRight", Rect2(780, 1520, 400, 185)],
			["TreeBottomLeft", Rect2(300, 1655, 125, 55)],
			["TreeBottomRight", Rect2(655, 1655, 128, 55)],
			["GardenBottomLeft", Rect2(-100, 1705, 537, 300)],
			["GardenBottomRight", Rect2(645, 1705, 535, 300)],
			["PathEnd", Rect2(437, 1830, 208, 170)],
		],
	},
	"hall": {
		"name": "ArenaHall", "bg": "res://assets/bg_hall.png", "scene": "res://arena/arena_hall.tscn",
		"walk": Rect2(100, 255, 880, 1605),
		"door": {"at": Vector2(543, 150), "scale": Vector2(1.3, 1.0)},
		"walls": [
			["TopLeft", Rect2(-100, -100, 525, 355)],
			["TopRight", Rect2(655, -100, 525, 355)],
			["StairTop", Rect2(425, -100, 230, 140)],
			["BrazierLeft", Rect2(270, 250, 78, 92)],
			["BrazierRight", Rect2(733, 250, 78, 92)],
			["BannerLeft", Rect2(45, 250, 140, 53)],
			["BannerRight", Rect2(900, 250, 135, 53)],
			["Left", Rect2(-100, 250, 145, 1460)],
			["Right", Rect2(1040, 250, 140, 1460)],
			["LowLeft", Rect2(-100, 1700, 200, 400)],
			["LowRight", Rect2(980, 1700, 200, 400)],
			["Bottom", Rect2(-100, 1860, 1280, 200)],
			["BrazierBottomLeft", Rect2(115, 1795, 90, 125)],
			["BrazierBottomRight", Rect2(883, 1795, 85, 125)],
		],
	},
}

## `base` is the collision footprint (the lower part of the picture only: the picture's top half is height
## the hero can walk behind), centred on the node origin; `lift` is how far below the origin the picture ends.
const OBSTACLES: Dictionary = {
	"crate": {"scene": "res://arena/crate.tscn", "name": "Crate", "texture": "res://assets/crate.png",
		"base": Vector2(62, 30), "lift": 17.0},
	"sandbags": {"scene": "res://arena/barrier.tscn", "name": "Barrier", "texture": "res://assets/sandbags.png",
		"base": Vector2(236, 32), "lift": 16.0},
	"hedgehog": {"scene": "res://arena/hedgehog.tscn", "name": "Hedgehog", "texture": "res://assets/hedgehog.png",
		"base": Vector2(70, 30), "lift": 15.0},
	"stone_block": {"scene": "res://arena/stone_block.tscn", "name": "StoneBlock", "texture": "res://assets/stone_block.png",
		"base": Vector2(80, 32), "lift": 17.0},
}

## Per room: which arena, where the hero starts, the obstacles, and (only where the old positions fall in
## a wall or garden) new positions for the enemies in the order they are listed in the room scene.
## Keep the middle column (x 470-610) free: the autoplay bot walks to the door in a straight line.
const ROOMS: Array[Dictionary] = [
	{"arena": "temple", "start": Vector2(540, 1640),
		"obstacles": [["crate", Vector2(250, 1120)], ["stone_block", Vector2(830, 1120)]]},
	{"arena": "temple", "start": Vector2(540, 1640),
		"obstacles": [["stone_block", Vector2(300, 900)], ["crate", Vector2(200, 1150)], ["crate", Vector2(860, 1150)]]},
	{"arena": "temple", "start": Vector2(540, 1640),
		"obstacles": [["stone_block", Vector2(320, 820)], ["crate", Vector2(250, 1100)], ["crate", Vector2(830, 1100)]]},
	{"arena": "square", "start": Vector2(540, 1400),
		"obstacles": [["sandbags", Vector2(300, 1020)], ["hedgehog", Vector2(790, 1040)], ["crate", Vector2(780, 1250)]]},
	{"arena": "square", "start": Vector2(540, 1400),
		"obstacles": [["hedgehog", Vector2(220, 1000)], ["hedgehog", Vector2(860, 1000)]]},
	{"arena": "square", "start": Vector2(540, 1400),
		"enemies": [Vector2(260, 490), Vector2(820, 490), Vector2(540, 380), Vector2(380, 700), Vector2(700, 700), Vector2(540, 780)],
		"obstacles": [["sandbags", Vector2(300, 900)], ["sandbags", Vector2(780, 900)], ["crate", Vector2(250, 1200)]]},
	{"arena": "square", "start": Vector2(540, 1400),
		"enemies": [Vector2(260, 490), Vector2(820, 490), Vector2(540, 380), Vector2(360, 760), Vector2(720, 760), Vector2(540, 700)],
		"obstacles": [["hedgehog", Vector2(210, 1000)], ["hedgehog", Vector2(870, 1000)], ["crate", Vector2(300, 1250)]]},
	{"arena": "memorial", "start": Vector2(540, 1640),
		"enemies": [Vector2(260, 930), Vector2(820, 930), Vector2(540, 890), Vector2(330, 1110), Vector2(750, 1110)],
		"obstacles": [["crate", Vector2(230, 1250)], ["stone_block", Vector2(850, 1250)]]},
	{"arena": "memorial", "start": Vector2(540, 1640),
		"enemies": [Vector2(250, 960), Vector2(830, 960), Vector2(380, 890), Vector2(700, 890),
			Vector2(300, 1180), Vector2(780, 1180), Vector2(450, 1230), Vector2(630, 1230)],
		"obstacles": [["crate", Vector2(230, 1330)], ["stone_block", Vector2(850, 1330)]]},
	{"arena": "hall", "start": Vector2(540, 1640),
		"obstacles": [["stone_block", Vector2(250, 1000)], ["stone_block", Vector2(830, 1000)],
			["crate", Vector2(150, 1380)], ["crate", Vector2(930, 1380)]]},
]

var _failed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var force: bool = OS.get_cmdline_user_args().has("--force")
	if FileAccess.file_exists("res://arena/arena_hall.tscn") and not force:
		print("already applied (arena/arena_hall.tscn exists): nothing to do")
		quit(0)
		return
	_save(_door(), "res://arena/door.tscn", ["Bars", "Glow"])
	for kind: String in OBSTACLES:
		var spec: Dictionary = OBSTACLES[kind]
		_save(_obstacle(spec), spec["scene"], ["Sprite"])
	for key: String in ARENAS:
		_save(_arena(ARENAS[key]), ARENAS[key]["scene"], ["Background", "Door"])
	for index: int in ROOMS.size():
		_layout_room(index)
	_edit_main()
	_edit_aoe_circle()
	print("ARENA ART FAILED" if _failed else "ARENA ART OK")
	quit(1 if _failed else 0)

# --- saving ------------------------------------------------------------------

func _fail(message: String) -> void:
	push_error(message)
	_failed = true

func _save(root: Node, path: String, required: Array) -> void:
	_own(root, root)
	var expected: int = _count(root)
	var packed := PackedScene.new()
	var error: Error = packed.pack(root)
	if error == OK:
		error = ResourceSaver.save(packed, path)
	root.free()
	if error != OK:
		_fail("cannot save %s: %s" % [path, error_string(error)])
		return
	var reloaded: PackedScene = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var check: Node = reloaded.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	var actual: int = _count(check)
	if actual != expected:
		_fail("%s: %d nodes before pack, %d after reload" % [path, expected, actual])
	for node_name: String in required:
		if check.get_node_or_null("%" + node_name) == null:
			_fail("%s: missing %%%s after reload" % [path, node_name])
	print("saved: %s (%d nodes)" % [path, actual])
	check.free()

## Owner on every authored node (a node without one is silently dropped by pack()); sub-scene
## instances get an owner on their root only. The owner is set before the unique-name flag.
func _own(node: Node, owner: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner
		if child.has_meta(&"_unique"):
			child.remove_meta(&"_unique")
			child.unique_name_in_owner = true
		if child.scene_file_path.is_empty():
			_own(child, owner)

func _count(node: Node) -> int:
	var total: int = 1
	for child: Node in node.get_children():
		total += _count(child)
	return total

func _edit(path: String) -> Node:
	return (ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)

func _instance(path: String) -> Node:
	return (ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)

func _unique(node: Node) -> Node:
	node.set_meta(&"_unique", true)
	return node

func _add(parent: Node, child: Node, node_name: String = "") -> Node:
	if not node_name.is_empty():
		child.name = node_name
	parent.add_child(child)
	return child

# --- small builders ----------------------------------------------------------

func _poly(node_name: String, points: PackedVector2Array, color: Color, at: Vector2 = Vector2.ZERO) -> Polygon2D:
	var polygon := Polygon2D.new()
	polygon.name = node_name
	polygon.polygon = points
	polygon.color = color
	polygon.position = at
	return polygon

func _rect(w: float, h: float, cx: float = 0.0, cy: float = 0.0) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(cx - w * 0.5, cy - h * 0.5), Vector2(cx + w * 0.5, cy - h * 0.5),
		Vector2(cx + w * 0.5, cy + h * 0.5), Vector2(cx - w * 0.5, cy + h * 0.5),
	])

func _ellipse(rx: float, ry: float, sides: int = 24) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i: int in sides:
		var angle: float = TAU * i / sides
		points.append(Vector2(cos(angle) * rx, sin(angle) * ry))
	return points

func _rect_shape(node_name: String, size: Vector2, at: Vector2) -> CollisionShape2D:
	var shape := CollisionShape2D.new()
	shape.name = node_name
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = at
	return shape

# --- door and obstacles ------------------------------------------------------

## The doorway is 160 wide and 120 tall above the origin (the middle of the threshold); an arena instance
## scales it to fit the painted door. Closed: dark-red bars over the doorway. Open (door.gd): a golden
## light column and a glowing floor.
func _door() -> Node:
	var root := Area2D.new()
	root.name = "Door"
	root.collision_layer = 0
	root.collision_mask = 2
	root.set_script(load("res://arena/door.gd"))
	var bars: Node2D = _unique(Node2D.new())
	_add(root, bars, "Bars")
	bars.add_child(_poly("Backing", _rect(160, 120, 0, -60), Color(0.12, 0.02, 0.03, 0.5)))
	for i: int in 7:
		bars.add_child(_poly("Bar%d" % (i + 1), _rect(8, 116, -60 + i * 20, -60), Color(0.82, 0.14, 0.1, 1.0)))
	bars.add_child(_poly("RailTop", _rect(164, 9, 0, -114), Color(0.55, 0.08, 0.07, 1.0)))
	bars.add_child(_poly("RailMiddle", _rect(164, 7, 0, -60), Color(0.55, 0.08, 0.07, 1.0)))
	bars.add_child(_poly("RailBottom", _rect(164, 9, 0, -5), Color(0.55, 0.08, 0.07, 1.0)))
	bars.add_child(_poly("Lock", _ellipse(10, 10, 14), Color(0.96, 0.8, 0.3, 1.0), Vector2(0, -60)))
	var glow: Node2D = _unique(Node2D.new())
	glow.visible = false
	_add(root, glow, "Glow")
	var halo: Polygon2D = _poly("Halo", _ellipse(104, 26), Color(1.0, 0.9, 0.45, 0.6), Vector2(0, 4))
	glow.add_child(halo)
	var column: Polygon2D = _poly("Column", PackedVector2Array([Vector2(-78, 0), Vector2(78, 0), Vector2(46, -200), Vector2(-46, -200)]), Color.WHITE)
	column.vertex_colors = PackedColorArray([Color(1.0, 0.88, 0.4, 0.85), Color(1.0, 0.88, 0.4, 0.85),
		Color(1.0, 0.85, 0.3, 0.0), Color(1.0, 0.85, 0.3, 0.0)])
	glow.add_child(column)
	var core: Polygon2D = _poly("Core", PackedVector2Array([Vector2(-30, 0), Vector2(30, 0), Vector2(14, -160), Vector2(-14, -160)]), Color.WHITE)
	core.vertex_colors = PackedColorArray([Color(1.0, 0.98, 0.8, 0.95), Color(1.0, 0.98, 0.8, 0.95),
		Color(1.0, 0.95, 0.6, 0.0), Color(1.0, 0.95, 0.6, 0.0)])
	glow.add_child(core)
	_add(root, _rect_shape("CollisionShape2D", Vector2(170, 60), Vector2(0, 10)))
	return root

func _obstacle(spec: Dictionary) -> Node:
	var base: Vector2 = spec["base"]
	var texture: Texture2D = load(spec["texture"]) as Texture2D
	var root := StaticBody2D.new()
	root.name = spec["name"]
	root.collision_mask = 0
	root.add_child(_poly("Shadow", _ellipse(base.x * 0.6, base.y * 0.55), Color(0, 0, 0, 0.28), Vector2(0, 6)))
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = texture
	sprite.position = Vector2(0, float(spec["lift"]) - texture.get_height() * 0.5)
	root.add_child(_unique(sprite))
	_add(root, _rect_shape("CollisionShape2D", base, Vector2.ZERO))
	return root

# --- arenas ------------------------------------------------------------------

func _arena(spec: Dictionary) -> Node:
	var root := Node2D.new()
	root.name = spec["name"]
	root.set_script(load("res://arena/arena.gd"))
	root.z_index = -2
	root.set("walk_area", spec["walk"])
	var background := Sprite2D.new()
	background.texture = load(spec["bg"]) as Texture2D
	background.centered = false
	_add(root, _unique(background), "Background")
	var walls := StaticBody2D.new()
	walls.collision_mask = 0
	_add(root, walls, "Walls")
	for wall: Array in spec["walls"]:
		var rect: Rect2 = wall[1]
		walls.add_child(_rect_shape(wall[0], rect.size, rect.get_center()))
	var door: Node2D = _instance("res://arena/door.tscn") as Node2D
	var door_spec: Dictionary = spec["door"]
	door.position = door_spec["at"]
	door.scale = door_spec["scale"]
	_add(root, _unique(door), "Door")
	return root

# --- rooms, main, effects ----------------------------------------------------

func _layout_room(index: int) -> void:
	var path: String = "res://rooms/room_%02d.tscn" % (index + 1)
	var spec: Dictionary = ROOMS[index]
	var room: Node = _edit(path)
	room.set("y_sort_enabled", true)
	var old: Node = room.get_node("%Arena")
	var slot: int = old.get_index()
	room.remove_child(old)
	old.free()
	var arena: Node = _instance(ARENAS[spec["arena"]]["scene"])
	arena.name = "Arena"
	room.add_child(arena)
	room.move_child(arena, slot)
	arena.owner = room
	arena.unique_name_in_owner = true

	var obstacles: Node = room.get_node("Obstacles")
	obstacles.set("y_sort_enabled", true)
	for child: Node in obstacles.get_children():
		obstacles.remove_child(child)
		child.free()
	var counts: Dictionary = {}
	for entry: Array in spec["obstacles"]:
		var kind: String = entry[0]
		var info: Dictionary = OBSTACLES[kind]
		counts[kind] = int(counts.get(kind, 0)) + 1
		var obstacle: Node2D = _instance(info["scene"]) as Node2D
		obstacle.name = "%s%d" % [info["name"], counts[kind]]
		obstacle.position = entry[1]
		obstacles.add_child(obstacle)
		obstacle.owner = room

	var enemies: Node = room.get_node("%Enemies")
	enemies.set("y_sort_enabled", true)
	var kids: Array[Node] = enemies.get_children()
	if spec.has("enemies"):
		var spots: Array = spec["enemies"]
		if spots.size() != kids.size():
			_fail("%s: %d enemy positions for %d enemies" % [path, spots.size(), kids.size()])
		else:
			for i: int in kids.size():
				(kids[i] as Node2D).position = spots[i]
	var named: Dictionary = {}
	for kid: Node in kids:
		var type_name: String = kid.scene_file_path.get_file().get_basename().to_pascal_case()
		named[type_name] = int(named.get(type_name, 0)) + 1
		kid.name = type_name if kids.size() == 1 else "%s%d" % [type_name, named[type_name]]
	(room.get_node("%PlayerStart") as Node2D).position = spec["start"]
	_save(room, path, ["Arena", "Enemies", "PlayerStart"])

## y-sort lets the hero, enemies, pickups and obstacles overlap by depth; the shot containers draw above them
## (a bullet leaves the muzzle in front of the shooter) and Effects always on top. main.tscn is patched as text:
## re-packing it would also rewrite the HUD panels' anchor overrides.
func _edit_main() -> void:
	var path: String = "res://main.tscn"
	var text: String = FileAccess.get_file_as_string(path)
	var before: int = _count_nodes(path)
	for patch: Array in [["Main", "y_sort_enabled = true"], ["RoomHolder", "y_sort_enabled = true"],
			["Pickups", "y_sort_enabled = true"], ["Shots", "z_index = 1"], ["EnemyShots", "z_index = 1"],
			["Effects", "z_index = 2"]]:
		text = _patch_node(text, patch[0], patch[1])
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	var main: Node = _instance(path)
	var after: int = _count(main)
	if after != before:
		_fail("%s: %d nodes before the patch, %d after" % [path, before, after])
	if not (main.y_sort_enabled and main.get_node("%RoomHolder").y_sort_enabled and main.get_node("%Pickups").y_sort_enabled
			and main.get_node("%Shots").z_index == 1 and main.get_node("%EnemyShots").z_index == 1 and main.get_node("%Effects").z_index == 2):
		_fail("%s: y-sort or z_index patch did not load" % path)
	print("patched: %s (%d nodes)" % [path, after])
	main.free()

func _count_nodes(path: String) -> int:
	var scene: Node = _instance(path)
	var total: int = _count(scene)
	scene.free()
	return total

## Adds `line` to the block of node `node_name` (right after its header and unique-name line) unless it is there.
func _patch_node(text: String, node_name: String, line: String) -> String:
	var header: RegExMatch = RegEx.create_from_string("\\[node name=\"%s\" [^\\]]*\\]\\n(?:unique_name_in_owner = true\\n)?" % node_name).search(text)
	if header == null:
		_fail("main.tscn: no node %s to patch" % node_name)
		return text
	var next_block: int = text.find("\n[", header.get_end())
	if text.substr(header.get_end(), next_block - header.get_end() if next_block >= 0 else -1).contains(line):
		return text
	return text.insert(header.get_end(), line + "\n")

## The red circles lie on the floor: above the arena (-2), below the characters. They sit in EnemyShots
## (z 1), so the layer is absolute; a relative -1 would land on the characters' layer.
func _edit_aoe_circle() -> void:
	var circle: Node = _edit("res://effects/aoe_circle.tscn")
	circle.set("z_index", -1)
	circle.set("z_as_relative", false)
	_save(circle, "res://effects/aoe_circle.tscn", ["Fill", "Ring", "Grow"])
