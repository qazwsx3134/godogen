extends SceneTree
## One-time authoring tool: builds every .tscn/.tres of the prototype with PackedScene.pack
## + ResourceSaver.save. After that the saved files are the source; edit them in the editor.
##
##   godot --headless --path . --script res://tools/build_scenes.gd            # only missing files
##   godot --headless --path . --script res://tools/build_scenes.gd -- --force  # overwrite (check git diff first!)
##
## Running the game or the tests never calls this.
##
## ui/hud.tscn, ui/joystick.tscn, ui/result_panel.tscn and ui/theme.tres were restyled afterwards by
## tools/restyle_hud.gd (concept-art HUD); the builders below still describe the old look, so do not
## --force those files. ui/ability_slot.tscn and pickups/coin.tscn only exist from that pass.

const HERO_LAYER: int = 2
const ENEMY_LAYER: int = 4
const WORLD_LAYER: int = 1

const INK: Color = Color(0.08, 0.08, 0.07)
const FLOOR: Color = Color(0.44, 0.52, 0.33)
const FLOOR_DARK: Color = Color(0.39, 0.47, 0.29)
const WALL: Color = Color(0.3, 0.27, 0.23)
const WALL_TOP: Color = Color(0.42, 0.38, 0.32)
const CANE: Color = Color(0.5, 0.25, 0.38)
const CANE_NODE: Color = Color(0.32, 0.14, 0.24)
const LEAF: Color = Color(0.45, 0.78, 0.3)

var _force: bool = false
var _failed: bool = false

func _initialize() -> void:
	_force = OS.get_cmdline_user_args().has("--force")
	_build.call_deferred()

func _build() -> void:
	_build_theme()
	_build_abilities()
	_save(_damage_number(), "res://effects/damage_number.tscn")
	_save(_explosion(), "res://effects/explosion.tscn")
	_save(_pickup("ExpGem", 0), "res://pickups/exp_gem.tscn")
	_save(_pickup("Heart", 1), "res://pickups/heart.tscn")
	_save(_sugarcane(), "res://player/sugarcane.tscn")
	_save(_hero(), "res://player/hero.tscn")
	_save(_bean("Pea", Color(0.35, 0.75, 0.25), _ellipse(11, 11)), "res://enemies/pea.tscn")
	_save(_bean("Corn", Color(0.98, 0.82, 0.2), PackedVector2Array([Vector2(-9, -11), Vector2(9, -11), Vector2(12, 0), Vector2(9, 11), Vector2(-9, 11), Vector2(-12, 0)])), "res://enemies/corn.tscn")
	_save(_bean("Carrot", Color(0.98, 0.5, 0.15), _rect(18, 18)), "res://enemies/carrot.tscn")
	_save(_bullet(), "res://enemies/bullet.tscn")
	_save(_rat(), "res://enemies/rat.tscn")
	_save(_tank("Tank", "res://enemies/tank.gd", {
		"display_name": "坦克", "max_hp": 320, "move_speed": 90.0, "contact_damage": 30, "exp_value": 5, "knockback": 20.0,
	}, Color(0.36, 0.46, 0.28), 1.3), "res://enemies/tank.tscn")
	_save(_plate(), "res://enemies/plate.tscn")
	_save(_tank("BossTank", "res://enemies/boss_tank.gd", {
		"display_name": "巨型坦克", "max_hp": 4200, "move_speed": 70.0, "contact_damage": 50, "crush_damage": 180,
		"exp_value": 40, "is_boss": true, "heart_drop_chance": 1.0, "spawn_delay": 1.0, "knockback": 0.0,
		"dash_speed": 1050.0, "dash_range": 900.0, "windup_time": 0.9, "recover_time": 1.2,
		"rat_scene": load("res://enemies/rat.tscn"),
	}, Color(0.55, 0.16, 0.13), 2.3), "res://enemies/boss_tank.tscn")
	_save(_chiang(), "res://enemies/chiang_boss.tscn")
	_save(_crate(), "res://arena/crate.tscn")
	_save(_barrier(), "res://arena/barrier.tscn")
	_save(_door(), "res://arena/door.tscn")
	_save(_arena_temple(), "res://arena/arena_temple.tscn")
	_save(_arena_square(), "res://arena/arena_square.tscn")
	_save(_arena_memorial(), "res://arena/arena_memorial.tscn")
	_build_rooms()
	_save(_ability_card(), "res://ui/ability_card.tscn")
	_save(_joystick(), "res://ui/joystick.tscn")
	_save(_hud(), "res://ui/hud.tscn")
	_save(_choice_panel(), "res://ui/choice_panel.tscn")
	_save(_result_panel(), "res://ui/result_panel.tscn")
	_save(_main(), "res://main.tscn")
	print("BUILD FAILED" if _failed else "BUILD OK")
	quit(1 if _failed else 0)

# --- saving ------------------------------------------------------------------

func _save(root: Node, path: String) -> void:
	if FileAccess.file_exists(path) and not _force:
		print("skip (exists): ", path)
		root.free()
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	_own(root, root)
	var expected: int = _count(root)
	var packed := PackedScene.new()
	var error: Error = packed.pack(root)
	if error == OK:
		error = ResourceSaver.save(packed, path)
	if error != OK:
		push_error("cannot save %s: %s" % [path, error_string(error)])
		_failed = true
		root.free()
		return
	var reloaded: PackedScene = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var check: Node = reloaded.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	var actual: int = _count(check)
	if actual != expected:
		push_error("%s: %d nodes before pack, %d after reload" % [path, expected, actual])
		_failed = true
	else:
		print("saved: %s (%d nodes)" % [path, actual])
	check.free()
	root.free()

## Owner on every authored node; sub-scene instances get an owner on their root only.
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

func _instance(path: String) -> Node:
	var packed: PackedScene = load(path) as PackedScene
	return packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)

func _unique(node: Node) -> Node:
	node.set_meta(&"_unique", true)
	return node

func _add(parent: Node, child: Node, node_name: String = "") -> Node:
	if not node_name.is_empty():
		child.name = node_name
	parent.add_child(child)
	return child

# --- shapes ------------------------------------------------------------------

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

func _circle_shape(radius: float) -> CollisionShape2D:
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	return shape

func _rect_shape(node_name: String, size: Vector2, at: Vector2) -> CollisionShape2D:
	var shape := CollisionShape2D.new()
	shape.name = node_name
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = at
	return shape

func _flat(color: Color, radius: int = 12, border: Color = Color(0, 0, 0, 0), border_width: int = 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	if border_width > 0:
		box.border_color = border
		box.set_border_width_all(border_width)
	return box

func _bar(node_name: String, fill: Color, size: Vector2, at: Vector2) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.name = node_name
	bar.show_percentage = false
	bar.position = at
	bar.size = size
	bar.custom_minimum_size = Vector2(0, size.y)
	bar.max_value = 100
	bar.value = 100
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override(&"background", _flat(Color(0.05, 0.05, 0.05, 0.75), 6))
	bar.add_theme_stylebox_override(&"fill", _flat(fill, 6))
	return bar

func _label(node_name: String, text: String, font_size: int, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _full_rect(control: Control) -> Control:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return control

# --- theme and data ----------------------------------------------------------

func _build_theme() -> void:
	var path: String = "res://ui/theme.tres"
	if FileAccess.file_exists(path) and not _force:
		print("skip (exists): ", path)
		return
	var font := FontVariation.new()
	font.base_font = load("res://ui/fonts/NotoSansTC.ttf") as Font
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 700}
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 36
	theme.set_color(&"font_outline_color", &"Label", Color(0, 0, 0, 0.85))
	theme.set_constant(&"outline_size", &"Label", 8)
	theme.set_font_size(&"font_size", &"Button", 40)
	theme.set_color(&"font_color", &"Button", Color(1, 0.97, 0.88))
	theme.set_stylebox(&"normal", &"Button", _flat(Color(0.2, 0.25, 0.17, 0.95), 22, Color(0.95, 0.85, 0.55), 4))
	theme.set_stylebox(&"hover", &"Button", _flat(Color(0.27, 0.33, 0.22, 0.95), 22, Color(1, 0.92, 0.6), 4))
	theme.set_stylebox(&"pressed", &"Button", _flat(Color(0.15, 0.19, 0.12, 0.95), 22, Color(1, 0.92, 0.6), 4))
	theme.set_stylebox(&"focus", &"Button", StyleBoxEmpty.new())
	if ResourceSaver.save(theme, path) == OK:
		print("saved: ", path)
	else:
		_fail("cannot save theme")

func _fail(message: String) -> void:
	push_error(message)
	_failed = true

func _build_abilities() -> void:
	var AbilityDef: GDScript = load("res://data/ability_def.gd") as GDScript
	var rows: Array = [
		["front", "正面甘蔗 +1", "正前方多丟一根\n每根傷害 −25%", Color(0.95, 0.75, 0.3), 3, false],
		["multishot", "連續投擲", "每次攻擊多丟一輪\n傷害 −15%", Color(1.0, 0.55, 0.3), 3, false],
		["diagonal", "斜向甘蔗", "往左右斜前方各丟一根", Color(0.6, 0.8, 1.0), 1, false],
		["side", "側向甘蔗", "往左右兩側各丟一根", Color(0.5, 0.7, 0.95), 1, false],
		["rear", "後方甘蔗", "往背後丟一根", Color(0.55, 0.6, 0.9), 1, false],
		["pierce", "穿透", "甘蔗穿過坦克\n每穿一台傷害 −33%", Color(0.85, 0.5, 0.95), 1, false],
		["ricochet", "彈射", "打中後彈向附近坦克\n最多 3 次", Color(0.95, 0.45, 0.75), 1, false],
		["wall_bounce", "牆壁反彈", "碰到牆會反彈 2 次", Color(0.72, 0.72, 0.72), 1, false],
		["attack_boost", "攻擊強化", "攻擊力 +20%", Color(1.0, 0.4, 0.35), 5, false],
		["attack_speed", "攻速強化", "丟擲速度 +20%", Color(1.0, 0.85, 0.35), 5, false],
		["crit", "暴擊強化", "暴擊率 +10%\n暴擊造成 2 倍傷害", Color(1.0, 0.95, 0.5), 4, false],
		["fire", "火焰甘蔗", "命中後燃燒 2 秒", Color(1.0, 0.45, 0.15), 1, false],
		["freeze", "冰凍甘蔗", "命中後減速 1.5 秒", Color(0.5, 0.85, 1.0), 1, false],
		["hp_boost", "生命強化", "生命上限 +120", Color(0.4, 0.85, 0.45), 5, false],
		["heal", "急救", "回復 40% 生命", Color(0.9, 0.35, 0.45), 99, true],
	]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/abilities"))
	for row: Array in rows:
		var path: String = "res://data/abilities/%s.tres" % row[0]
		if FileAccess.file_exists(path) and not _force:
			continue
		var def: Resource = AbilityDef.new()
		def.id = StringName(row[0])
		def.title = row[1]
		def.description = row[2]
		def.color = row[3]
		def.max_stacks = row[4]
		def.needs_missing_hp = row[5]
		if ResourceSaver.save(def, path) != OK:
			_fail("cannot save " + path)
	print("abilities: %d" % rows.size())

func _ability_paths() -> Array[String]:
	var paths: Array[String] = []
	for id: String in ["front", "multishot", "diagonal", "side", "rear", "pierce", "ricochet", "wall_bounce",
			"attack_boost", "attack_speed", "crit", "fire", "freeze", "hp_boost", "heal"]:
		paths.append("res://data/abilities/%s.tres" % id)
	return paths

# --- small scenes ------------------------------------------------------------

func _damage_number() -> Node:
	var root := Node2D.new()
	root.name = "DamageNumber"
	root.set_script(load("res://effects/damage_number.gd"))
	var label: Label = _label("Label", "123", 44)
	label.position = Vector2(-120, -30)
	label.size = Vector2(240, 60)
	_add(root, _unique(label))
	return root

func _explosion() -> Node:
	var root := Node2D.new()
	root.name = "Explosion"
	root.set_script(load("res://effects/explosion.gd"))
	var flash: Node2D = _unique(Node2D.new())
	_add(root, flash, "Flash")
	flash.add_child(_poly("Outer", _ellipse(80, 80), Color(1.0, 0.55, 0.15, 0.85)))
	flash.add_child(_poly("Inner", _ellipse(50, 50), Color(1.0, 0.95, 0.6, 0.95)))
	var sparks := CPUParticles2D.new()
	sparks.emitting = false
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = 18
	sparks.lifetime = 0.55
	sparks.direction = Vector2.UP
	sparks.spread = 180.0
	sparks.gravity = Vector2.ZERO
	sparks.initial_velocity_min = 180.0
	sparks.initial_velocity_max = 420.0
	sparks.damping_min = 300.0
	sparks.damping_max = 500.0
	sparks.scale_amount_min = 6.0
	sparks.scale_amount_max = 12.0
	sparks.color = Color(1.0, 0.75, 0.3)
	_add(root, _unique(sparks), "Sparks")
	return root

func _pickup(node_name: String, kind: int) -> Node:
	var root := Node2D.new()
	root.name = node_name
	root.set_script(load("res://pickups/pickup.gd"))
	root.set("kind", kind)
	var visual: Node2D = _unique(Node2D.new())
	_add(root, visual, "Visual")
	if kind == 0:
		visual.add_child(_poly("Gem", PackedVector2Array([Vector2(0, -16), Vector2(11, 0), Vector2(0, 16), Vector2(-11, 0)]), Color(0.35, 0.8, 1.0)))
		visual.add_child(_poly("Shine", PackedVector2Array([Vector2(0, -12), Vector2(5, -2), Vector2(0, 2), Vector2(-5, -2)]), Color(0.85, 0.97, 1.0)))
	else:
		var heart := PackedVector2Array()
		for i: int in 32:
			var t: float = TAU * i / 32.0
			heart.append(Vector2(16.0 * pow(sin(t), 3), -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))) * 1.3)
		visual.add_child(_poly("Heart", heart, Color(0.95, 0.25, 0.35)))
	return root

func _cane_visual(length: float, thickness: float) -> Node2D:
	var cane := Node2D.new()
	cane.add_child(_poly("Stalk", _rect(length, thickness), CANE))
	var joints: int = 3
	for i: int in joints:
		var x: float = -length * 0.5 + length * (i + 1) / (joints + 1)
		cane.add_child(_poly("Joint%d" % (i + 1), _rect(4, thickness + 3, x), CANE_NODE))
	var tip: float = length * 0.5
	cane.add_child(_poly("LeafA", PackedVector2Array([Vector2(tip - 4, -2), Vector2(tip + 22, -14), Vector2(tip + 6, 2)]), LEAF))
	cane.add_child(_poly("LeafB", PackedVector2Array([Vector2(tip - 4, 2), Vector2(tip + 20, 13), Vector2(tip + 6, -1)]), LEAF.darkened(0.15)))
	return cane

func _sugarcane() -> Node:
	var root := Area2D.new()
	root.name = "Sugarcane"
	root.set_script(load("res://player/sugarcane.gd"))
	root.collision_layer = 0
	root.collision_mask = ENEMY_LAYER
	var visual: Node2D = _cane_visual(76, 12)
	_add(root, _unique(visual), "Visual")
	_add(root, _circle_shape(18))
	return root

func _hero() -> Node:
	var root := CharacterBody2D.new()
	root.name = "Hero"
	root.set_script(load("res://player/hero.gd"))
	root.collision_layer = HERO_LAYER
	root.collision_mask = WORLD_LAYER | ENEMY_LAYER
	root.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	root.add_to_group(&"hero", true)
	root.add_child(_poly("Shadow", _ellipse(34, 13), Color(0, 0, 0, 0.28), Vector2(0, 26)))
	var body: Node2D = _unique(Node2D.new())
	_add(root, body, "Body")
	body.add_child(_poly("Torso", _ellipse(26, 24), Color(0.2, 0.46, 0.78), Vector2(0, 4)))
	body.add_child(_poly("Belt", _rect(44, 7, 0, 12), Color(0.35, 0.22, 0.12)))
	body.add_child(_poly("Head", _ellipse(18, 18), Color(0.96, 0.8, 0.62), Vector2(0, -26)))
	body.add_child(_poly("Hair", PackedVector2Array([Vector2(-19, -28), Vector2(-17, -40), Vector2(-8, -46),
		Vector2(6, -46), Vector2(16, -41), Vector2(20, -30), Vector2(12, -34), Vector2(2, -31), Vector2(-9, -34)]), Color(0.16, 0.11, 0.08)))
	body.add_child(_poly("EyeLeft", _ellipse(2.5, 3), INK, Vector2(-6, -24)))
	body.add_child(_poly("EyeRight", _ellipse(2.5, 3), INK, Vector2(6, -24)))
	var held: Node2D = _unique(_cane_visual(64, 10))
	held.position = Vector2(20, -2)
	held.rotation = -0.35
	_add(body, held, "HeldCane")
	var hand := Marker2D.new()
	hand.position = Vector2(0, -10)
	_add(root, _unique(hand), "Hand")
	_add(root, _circle_shape(28))
	_add(root, _unique(_bar("HpBar", Color(0.35, 0.85, 0.35), Vector2(100, 14), Vector2(-50, -86))))
	var hp_label: Label = _label("HpLabel", "600", 26)
	hp_label.position = Vector2(-60, -122)
	hp_label.size = Vector2(120, 36)
	_add(root, _unique(hp_label))
	return root

func _bean(node_name: String, color: Color, shape: PackedVector2Array) -> Node:
	var root := Area2D.new()
	root.name = node_name
	root.set_script(load("res://enemies/bean.gd"))
	root.collision_layer = 0
	root.collision_mask = HERO_LAYER
	root.add_child(_poly("Glow", _ellipse(19, 19), Color(color, 0.35)))
	root.add_child(_poly("Bean", shape, color))
	root.add_child(_poly("Shine", _ellipse(4, 3), Color(1, 1, 1, 0.7), Vector2(-4, -5)))
	_add(root, _circle_shape(12))
	return root

## Shared enemy root: shadow, collision, contact area, HP bar. `body` holds the looks.
func _enemy_root(node_name: String, script_path: String, props: Dictionary, radius: float, shadow: Vector2) -> Array:
	var root := CharacterBody2D.new()
	root.name = node_name
	root.set_script(load(script_path))
	for key: String in props:
		root.set(key, props[key])
		if root.get(key) != props[key]:
			_fail("%s.%s did not take the value (typed array?)" % [node_name, key])
	root.collision_layer = ENEMY_LAYER
	root.collision_mask = WORLD_LAYER | HERO_LAYER | ENEMY_LAYER
	root.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	root.add_child(_poly("Shadow", _ellipse(shadow.x, shadow.y), Color(0, 0, 0, 0.28), Vector2(0, radius * 0.45)))
	var body: Node2D = _unique(Node2D.new())
	_add(root, body, "Body")
	_add(root, _circle_shape(radius))
	var contact := Area2D.new()
	contact.collision_layer = 0
	contact.collision_mask = HERO_LAYER
	_add(root, _unique(contact), "ContactArea")
	_add(contact, _circle_shape(radius + 14.0))
	_add(root, _unique(_bar("HpBar", Color(0.9, 0.25, 0.2), Vector2(90, 12), Vector2(-45, -radius - 34))))
	return [root, body]

func _bullet() -> Node:
	var root := Area2D.new()
	root.name = "Bullet"
	root.set_script(load("res://enemies/bean.gd"))
	root.set("spin", 0.0)
	root.collision_layer = 0
	root.collision_mask = HERO_LAYER
	root.add_child(_poly("Glow", _ellipse(26, 17), Color(1.0, 0.3, 0.1, 0.45)))
	root.add_child(_poly("Outline", _rect(26, 16, -1), Color(0.15, 0.08, 0.05)))
	root.add_child(_poly("Casing", _rect(20, 11, -3), Color(1.0, 0.82, 0.3)))
	root.add_child(_poly("Tip", PackedVector2Array([Vector2(7, -6), Vector2(14, -4), Vector2(17, 0), Vector2(14, 4), Vector2(7, 6)]), Color(1.0, 0.95, 0.7)))
	_add(root, _circle_shape(10))
	return root

## Final boss, front view: bald head, moustache, military coat with medals,
## and a pistol arm (%GunArm) that turns toward the hero.
func _chiang() -> Node:
	var parts: Array = _enemy_root("ChiangBoss", "res://enemies/chiang_boss.gd", {
		"display_name": "蔣介石", "max_hp": 4500, "move_speed": 150.0, "contact_damage": 60, "exp_value": 40,
		"is_boss": true, "heart_drop_chance": 1.0, "spawn_delay": 1.0, "knockback": 0.0, "body_faces_motion": false,
		"bullet_scene": load("res://enemies/bullet.tscn"),
	}, 56.0, Vector2(62, 18))
	var root: Node2D = parts[0]
	var body: Node2D = parts[1]
	var khaki := Color(0.6, 0.55, 0.38)
	var skin := Color(0.94, 0.8, 0.64)
	body.add_child(_poly("LegLeft", _rect(20, 40, -16, 62), khaki.darkened(0.25)))
	body.add_child(_poly("LegRight", _rect(20, 40, 16, 62), khaki.darkened(0.25)))
	body.add_child(_poly("BootLeft", _rect(24, 12, -16, 84), INK))
	body.add_child(_poly("BootRight", _rect(24, 12, 16, 84), INK))
	body.add_child(_poly("ArmLeft", _rect(18, 60, -50, 18), khaki.darkened(0.1)))
	body.add_child(_poly("Coat", PackedVector2Array([Vector2(-42, -22), Vector2(42, -22), Vector2(48, 50), Vector2(-48, 50)]), khaki))
	body.add_child(_poly("Collar", PackedVector2Array([Vector2(-18, -24), Vector2(18, -24), Vector2(10, -8), Vector2(0, 2), Vector2(-10, -8)]), khaki.darkened(0.2)))
	body.add_child(_poly("Belt", _rect(92, 9, 0, 30), Color(0.35, 0.22, 0.12)))
	body.add_child(_poly("Buckle", _rect(12, 11, 0, 30), Color(0.85, 0.7, 0.3)))
	for i: int in 3:
		body.add_child(_poly("Button%d" % (i + 1), _ellipse(3, 3), Color(0.85, 0.7, 0.3), Vector2(0, 2 + i * 12)))
	var ribbons: Array[Color] = [Color(0.8, 0.15, 0.15), Color(0.2, 0.35, 0.75), Color(0.85, 0.7, 0.3)]
	for i: int in ribbons.size():
		body.add_child(_poly("Medal%d" % (i + 1), _rect(9, 6, -30 + i * 10, -6), ribbons[i]))
	body.add_child(_poly("Neck", _rect(16, 10, 0, -26), skin.darkened(0.08)))
	body.add_child(_poly("EarLeft", _ellipse(6, 9), skin.darkened(0.05), Vector2(-27, -58)))
	body.add_child(_poly("EarRight", _ellipse(6, 9), skin.darkened(0.05), Vector2(27, -58)))
	body.add_child(_poly("Head", _ellipse(27, 32), skin, Vector2(0, -60)))
	body.add_child(_poly("Shine", _ellipse(10, 6), Color(1, 1, 1, 0.35), Vector2(-8, -82)))
	body.add_child(_poly("BrowLeft", _rect(12, 3, -10, -66), Color(0.25, 0.2, 0.18)))
	body.add_child(_poly("BrowRight", _rect(12, 3, 10, -66), Color(0.25, 0.2, 0.18)))
	body.add_child(_poly("EyeLeft", _ellipse(3, 3), INK, Vector2(-10, -58)))
	body.add_child(_poly("EyeRight", _ellipse(3, 3), INK, Vector2(10, -58)))
	body.add_child(_poly("Moustache", PackedVector2Array([Vector2(-11, -44), Vector2(11, -44), Vector2(8, -40), Vector2(-8, -40)]), Color(0.2, 0.17, 0.15)))
	body.add_child(_poly("Mouth", _rect(10, 2, 0, -36), Color(0.5, 0.3, 0.28)))
	var arm: Node2D = _unique(Node2D.new())
	arm.position = Vector2(46, -10)
	arm.rotation = PI * 0.5
	_add(root, arm, "GunArm")
	arm.add_child(_poly("Sleeve", _rect(44, 18, 20), khaki.darkened(0.1)))
	arm.add_child(_poly("Hand", _ellipse(9, 9), skin, Vector2(44, 0)))
	arm.add_child(_poly("Pistol", PackedVector2Array([Vector2(44, -6), Vector2(72, -6), Vector2(72, 2), Vector2(52, 2), Vector2(50, 10), Vector2(44, 10)]), Color(0.2, 0.2, 0.22)))
	var muzzle := Marker2D.new()
	muzzle.position = Vector2(76, -2)
	_add(arm, _unique(muzzle), "Muzzle")
	return root

## Rat facing +x (the body turns toward where it runs).
func _rat() -> Node:
	var parts: Array = _enemy_root("Rat", "res://enemies/rat.gd", {
		"display_name": "老鼠", "max_hp": 90, "move_speed": 210.0, "contact_damage": 45, "exp_value": 2, "knockback": 90.0,
	}, 24.0, Vector2(34, 12))
	var body: Node2D = parts[1]
	var fur := Color(0.56, 0.54, 0.53)
	var pink := Color(0.95, 0.62, 0.66)
	var tail: Node2D = _unique(Node2D.new())
	tail.position = Vector2(-28, 0)
	_add(body, tail, "Tail")
	tail.add_child(_poly("TailShape", PackedVector2Array([Vector2(0, -3), Vector2(-22, -6), Vector2(-40, 2), Vector2(-42, 5), Vector2(-22, -1), Vector2(0, 3)]), pink))
	body.add_child(_poly("Torso", _ellipse(30, 19), fur))
	body.add_child(_poly("Belly", _ellipse(18, 11), fur.lightened(0.18), Vector2(-4, 0)))
	body.add_child(_poly("EarLeft", _ellipse(9, 9), pink, Vector2(18, -15)))
	body.add_child(_poly("EarRight", _ellipse(9, 9), pink, Vector2(18, 15)))
	body.add_child(_poly("Head", _ellipse(17, 14), fur.darkened(0.05), Vector2(26, 0)))
	body.add_child(_poly("Nose", _ellipse(5, 5), pink, Vector2(43, 0)))
	body.add_child(_poly("EyeLeft", _ellipse(3.5, 3.5), INK, Vector2(31, -6)))
	body.add_child(_poly("EyeRight", _ellipse(3.5, 3.5), INK, Vector2(31, 6)))
	return parts[0]

## Tank facing +x with a dozer blade on the front: it attacks by running people over.
func _tank(node_name: String, script_path: String, props: Dictionary, color: Color, size: float) -> Node:
	var w: float = 84.0 * size
	var h: float = 58.0 * size
	var parts: Array = _enemy_root(node_name, script_path, props, 34.0 * size, Vector2(w * 0.62, h * 0.55))
	var root: Node2D = parts[0]
	var body: Node2D = parts[1]
	body.rotation = PI * 0.5   # face down, toward where the hero enters
	body.add_child(_poly("TrackLeft", _rect(w + 12 * size, 16 * size, 0, -h * 0.5), Color(0.18, 0.18, 0.17)))
	body.add_child(_poly("TrackRight", _rect(w + 12 * size, 16 * size, 0, h * 0.5), Color(0.18, 0.18, 0.17)))
	for i: int in 5:
		var x: float = -w * 0.5 + w * (i + 0.5) / 5.0
		body.add_child(_poly("TreadL%d" % (i + 1), _rect(4 * size, 16 * size, x, -h * 0.5), Color(0.3, 0.3, 0.28)))
		body.add_child(_poly("TreadR%d" % (i + 1), _rect(4 * size, 16 * size, x, h * 0.5), Color(0.3, 0.3, 0.28)))
	body.add_child(_poly("Hull", _rect(w, h), color))
	body.add_child(_poly("Plate", _rect(w * 0.5, h * 0.55, -w * 0.12), color.lightened(0.12)))
	body.add_child(_poly("Blade", PackedVector2Array([
		Vector2(w * 0.5 + 4 * size, -h * 0.5 - 12 * size), Vector2(w * 0.5 + 16 * size, -h * 0.5 - 12 * size),
		Vector2(w * 0.5 + 22 * size, 0), Vector2(w * 0.5 + 16 * size, h * 0.5 + 12 * size),
		Vector2(w * 0.5 + 4 * size, h * 0.5 + 12 * size)]), Color(0.62, 0.62, 0.6)))
	body.add_child(_poly("Turret", _ellipse(22 * size, 20 * size, 10), color.lightened(0.18)))
	body.add_child(_poly("Barrel", _rect(34 * size, 10 * size, 30 * size), color.darkened(0.45)))
	body.add_child(_poly("Hatch", _ellipse(8 * size, 8 * size), color.darkened(0.3), Vector2(-5 * size, 0)))
	var line := Line2D.new()
	line.width = h + 30 * size
	line.default_color = Color(1.0, 0.1, 0.05, 0.3)
	line.points = PackedVector2Array([Vector2.ZERO, Vector2(0, 600)])
	line.visible = false
	line.z_index = -1
	_add(root, _unique(line), "DashLine")
	return root

## Plate monster: a dinner plate with a face and a few beans still on it.
func _plate() -> Node:
	var beans: Array[PackedScene] = [load("res://enemies/pea.tscn"), load("res://enemies/corn.tscn"), load("res://enemies/carrot.tscn")]
	var parts: Array = _enemy_root("Plate", "res://enemies/plate.gd", {
		"display_name": "餐盤怪", "max_hp": 200, "move_speed": 120.0, "contact_damage": 30, "exp_value": 4,
		"body_faces_motion": false, "knockback": 40.0,
		"bean_scenes": beans,
	}, 42.0, Vector2(48, 16))
	var root: Node2D = parts[0]
	var body: Node2D = parts[1]
	root.add_child(_poly("LegLeft", _rect(8, 22, -18, 44), Color(0.35, 0.35, 0.38)))
	root.add_child(_poly("LegRight", _rect(8, 22, 18, 44), Color(0.35, 0.35, 0.38)))
	root.move_child(root.get_node("LegLeft"), 1)
	root.move_child(root.get_node("LegRight"), 1)
	body.add_child(_poly("Rim", _ellipse(48, 48, 32), Color(0.96, 0.96, 0.93)))
	var ring := Line2D.new()
	ring.name = "BlueRing"
	ring.points = _ellipse(40, 40, 32)
	ring.closed = true
	ring.width = 5.0
	ring.default_color = Color(0.3, 0.5, 0.85)
	body.add_child(ring)
	body.add_child(_poly("Well", _ellipse(33, 33, 28), Color(0.9, 0.9, 0.87)))
	body.add_child(_poly("Pea", _ellipse(5, 5), Color(0.35, 0.75, 0.25), Vector2(-16, 16)))
	body.add_child(_poly("Corn", _rect(8, 7, 0, 20), Color(0.98, 0.82, 0.2)))
	body.add_child(_poly("Carrot", _rect(7, 7, 15, 15), Color(0.98, 0.5, 0.15)))
	body.add_child(_poly("EyeLeft", _ellipse(6, 7), INK, Vector2(-13, -6)))
	body.add_child(_poly("EyeRight", _ellipse(6, 7), INK, Vector2(13, -6)))
	body.add_child(_poly("BrowLeft", PackedVector2Array([Vector2(-22, -18), Vector2(-6, -13), Vector2(-7, -10), Vector2(-22, -15)]), INK))
	body.add_child(_poly("BrowRight", PackedVector2Array([Vector2(22, -18), Vector2(6, -13), Vector2(7, -10), Vector2(22, -15)]), INK))
	body.add_child(_poly("Mouth", _rect(14, 4, 0, 6), INK))
	var muzzle := Marker2D.new()
	muzzle.position = Vector2(0, 0)
	_add(root, _unique(muzzle), "Muzzle")
	return root

func _crate() -> Node:
	var root := StaticBody2D.new()
	root.name = "Crate"
	root.collision_layer = WORLD_LAYER
	root.collision_mask = 0
	root.add_child(_poly("Shadow", _rect(96, 96, 6, 8), Color(0, 0, 0, 0.25)))
	root.add_child(_poly("Box", _rect(92, 92), Color(0.6, 0.42, 0.22)))
	root.add_child(_poly("Inset", _rect(72, 72), Color(0.68, 0.5, 0.28)))
	root.add_child(_poly("SlatA", PackedVector2Array([Vector2(-36, -30), Vector2(-30, -36), Vector2(36, 30), Vector2(30, 36)]), Color(0.5, 0.34, 0.17)))
	root.add_child(_poly("SlatB", PackedVector2Array([Vector2(30, -36), Vector2(36, -30), Vector2(-30, 36), Vector2(-36, 30)]), Color(0.5, 0.34, 0.17)))
	_add(root, _rect_shape("CollisionShape2D", Vector2(92, 92), Vector2.ZERO))
	return root

func _barrier() -> Node:
	var root := StaticBody2D.new()
	root.name = "Barrier"
	root.collision_layer = WORLD_LAYER
	root.collision_mask = 0
	root.add_child(_poly("Shadow", _rect(244, 64, 6, 8), Color(0, 0, 0, 0.25)))
	root.add_child(_poly("Block", _rect(240, 60), Color(0.56, 0.56, 0.54)))
	root.add_child(_poly("Top", _rect(228, 18, 0, -14), Color(0.68, 0.68, 0.65)))
	for i: int in 3:
		root.add_child(_poly("Stripe%d" % (i + 1), _rect(28, 60, -70 + i * 70), Color(0.85, 0.7, 0.2)))
	_add(root, _rect_shape("CollisionShape2D", Vector2(240, 60), Vector2.ZERO))
	return root

func _door() -> Node:
	var root := Area2D.new()
	root.name = "Door"
	root.set_script(load("res://arena/door.gd"))
	root.collision_layer = 0
	root.collision_mask = HERO_LAYER
	root.add_child(_poly("Opening", _rect(180, 60, 0, -30), Color(0.1, 0.09, 0.08)))
	var glow: Polygon2D = _poly("Glow", _rect(170, 70, 0, -25), Color(1.0, 0.9, 0.45, 0.8))
	_add(root, _unique(glow))
	var bars: Node2D = _unique(Node2D.new())
	_add(root, bars, "Bars")
	for i: int in 5:
		bars.add_child(_poly("Bar%d" % (i + 1), _rect(10, 64, -64 + i * 32, -30), Color(0.85, 0.2, 0.15)))
	root.add_child(_poly("PostLeft", _rect(20, 80, -100, -30), WALL_TOP))
	root.add_child(_poly("PostRight", _rect(20, 80, 100, -30), WALL_TOP))
	_add(root, _rect_shape("CollisionShape2D", Vector2(170, 60), Vector2(0, 10)))
	return root

## Shared arena: floor with a paving grid, collision walls, the facade above the top wall
## (drawn up into the HUD band), a Decor node and the door. Theme functions fill in the looks.
func _arena_base(node_name: String, floor_color: Color, grid_color: Color, grid: float, wall: Color, trim: Color) -> Node2D:
	var root := Node2D.new()
	root.name = node_name
	root.add_child(_poly("Floor", _rect(960, 1500, 540, 1010), floor_color))
	var paving := Node2D.new()
	_add(root, paving, "Paving")
	var x: float = 60.0 + grid
	var n: int = 1
	while x < 1020.0:
		paving.add_child(_poly("V%d" % n, _rect(3, 1500, x, 1010), grid_color))
		x += grid
		n += 1
	var y: float = 260.0 + grid
	n = 1
	while y < 1760.0:
		paving.add_child(_poly("H%d" % n, _rect(960, 3, 540, y), grid_color))
		y += grid
		n += 1
	# Facades are drawn for y 88–260 and squeezed into 150–260 so they stay below the HUD row.
	var facade := Node2D.new()
	facade.position = Vector2(0, 93.7)
	facade.scale = Vector2(1, 0.64)
	_add(root, facade, "Facade")
	var walls := StaticBody2D.new()
	walls.collision_layer = WORLD_LAYER
	walls.collision_mask = 0
	_add(root, walls, "Walls")
	var pieces: Dictionary = {
		"Top": Rect2(0, 190, 1080, 70), "Bottom": Rect2(0, 1760, 1080, 70),
		"Left": Rect2(0, 190, 60, 1640), "Right": Rect2(1020, 190, 60, 1640),
	}
	for key: String in pieces:
		var rect: Rect2 = pieces[key]
		walls.add_child(_poly("Wall" + key, _rect(rect.size.x, rect.size.y, rect.get_center().x, rect.get_center().y), wall))
		walls.add_child(_rect_shape(key + "Shape", rect.size, rect.get_center()))
	walls.add_child(_poly("TrimTop", _rect(960, 10, 540, 255), trim))
	walls.add_child(_poly("TrimLeft", _rect(8, 1500, 56, 1010), trim))
	walls.add_child(_poly("TrimRight", _rect(8, 1500, 1024, 1010), trim))
	walls.add_child(_poly("TrimBottom", _rect(960, 8, 540, 1764), trim))
	root.move_child(walls, facade.get_index())   # facade draws over the top wall
	_add(root, Node2D.new(), "Decor")
	var door: Node2D = _instance("res://arena/door.tscn") as Node2D
	door.position = Vector2(540, 262)
	_add(root, _unique(door), "Door")
	return root

## Tiled roof band from y0 to y1 with alternating tile stripes and a ridge on top.
func _roof(parent: Node, y0: float, y1: float, tile: Color, ridge: Color, x0: float = 0.0, x1: float = 1080.0) -> void:
	parent.add_child(_poly("Roof", PackedVector2Array([Vector2(x0 + 30, y0), Vector2(x1 - 30, y0), Vector2(x1, y1), Vector2(x0, y1)]), tile))
	var stripe: float = x0 + 40.0
	var i: int = 1
	while stripe < x1 - 30.0:
		parent.add_child(_poly("Tile%d" % i, _rect(6, y1 - y0 - 6, stripe, (y0 + y1) * 0.5 + 3), tile.darkened(0.2)))
		stripe += 28.0
		i += 1
	parent.add_child(_poly("Ridge", _rect(x1 - x0 - 40, 10, (x0 + x1) * 0.5, y0 + 3), ridge))

## 宮廟: grey stone courtyard, red walls with gold trim, glazed roof gate, red pillars,
## lanterns and an incense burner.
func _arena_temple() -> Node:
	var root: Node2D = _arena_base("ArenaTemple", Color(0.6, 0.56, 0.52), Color(0.52, 0.48, 0.44), 120.0,
		Color(0.62, 0.14, 0.12), Color(0.86, 0.68, 0.26))
	var facade: Node = root.get_node("Facade")
	facade.add_child(_poly("GateWall", _rect(1080, 90, 540, 215), Color(0.66, 0.15, 0.12)))
	_roof(facade, 105, 172, Color(0.92, 0.58, 0.16), Color(0.2, 0.52, 0.36))
	facade.add_child(_poly("EaveLeft", PackedVector2Array([Vector2(0, 172), Vector2(-10, 140), Vector2(40, 172)]), Color(0.2, 0.52, 0.36)))
	facade.add_child(_poly("EaveRight", PackedVector2Array([Vector2(1080, 172), Vector2(1090, 140), Vector2(1040, 172)]), Color(0.2, 0.52, 0.36)))
	facade.add_child(_poly("Plaque", _rect(220, 44, 540, 210), Color(0.12, 0.1, 0.1)))
	facade.add_child(_poly("PlaqueGold", _rect(206, 32, 540, 210), Color(0.86, 0.68, 0.26)))
	var decor: Node = root.get_node("Decor")
	var pillars: Array[Vector2] = [Vector2(110, 520), Vector2(970, 520), Vector2(110, 960), Vector2(970, 960), Vector2(110, 1400), Vector2(970, 1400)]
	for i: int in pillars.size():
		decor.add_child(_poly("PillarShadow%d" % (i + 1), _ellipse(30, 30), Color(0, 0, 0, 0.2), pillars[i] + Vector2(5, 7)))
		decor.add_child(_poly("Pillar%d" % (i + 1), _ellipse(26, 26), Color(0.72, 0.13, 0.1), pillars[i]))
		decor.add_child(_poly("PillarRing%d" % (i + 1), _ellipse(14, 14), Color(0.86, 0.68, 0.26), pillars[i]))
	for i: int in 2:
		var at: Vector2 = Vector2(390 + i * 300, 320)
		decor.add_child(_poly("Lantern%d" % (i + 1), _ellipse(24, 30), Color(0.9, 0.15, 0.12), at))
		decor.add_child(_poly("LanternBand%d" % (i + 1), _rect(30, 5, at.x, at.y), Color(0.95, 0.8, 0.3)))
	var burner: Vector2 = Vector2(180, 1680)
	decor.add_child(_poly("BurnerShadow", _ellipse(58, 34), Color(0, 0, 0, 0.2), burner + Vector2(5, 7)))
	decor.add_child(_poly("Burner", _ellipse(52, 30), Color(0.45, 0.33, 0.18), burner))
	decor.add_child(_poly("BurnerAsh", _ellipse(38, 20), Color(0.3, 0.26, 0.22), burner + Vector2(0, -3)))
	for i: int in 3:
		decor.add_child(_poly("Smoke%d" % (i + 1), _ellipse(16 + i * 6, 12 + i * 5), Color(0.9, 0.9, 0.9, 0.35 - i * 0.08), burner + Vector2(-10 + i * 12, -35 - i * 34)))
	return root

## 天安門廣場: large grey paving, a red gate with a yellow roof and five arches,
## lamp posts along the sides and a flag pole at the bottom.
func _arena_square() -> Node:
	var root: Node2D = _arena_base("ArenaSquare", Color(0.72, 0.72, 0.7), Color(0.63, 0.63, 0.61), 160.0,
		Color(0.5, 0.5, 0.49), Color(0.92, 0.92, 0.9))
	var facade: Node = root.get_node("Facade")
	facade.add_child(_poly("GateWall", _rect(1080, 110, 540, 205), Color(0.7, 0.16, 0.12)))
	_roof(facade, 88, 150, Color(0.96, 0.76, 0.22), Color(0.85, 0.6, 0.15), 120, 960)
	facade.add_child(_poly("Beam", _rect(840, 12, 540, 156), Color(0.2, 0.4, 0.45)))
	for i: int in 5:
		var arch_x: float = 540.0 + (i - 2) * 150.0
		var arch_w: float = 70.0 if i == 2 else 54.0
		facade.add_child(_poly("Arch%d" % (i + 1), _rect(arch_w, 58, arch_x, 231), Color(0.14, 0.08, 0.07)))
		facade.add_child(_poly("ArchTop%d" % (i + 1), _ellipse(arch_w * 0.5, 16), Color(0.14, 0.08, 0.07), Vector2(arch_x, 202)))
	facade.add_child(_poly("Balustrade", _rect(1080, 8, 540, 250), Color(0.95, 0.95, 0.93)))
	var decor: Node = root.get_node("Decor")
	for i: int in 4:
		for side: int in 2:
			var at: Vector2 = Vector2(115 if side == 0 else 965, 460 + i * 380)
			var tag: String = "%d%s" % [i + 1, "L" if side == 0 else "R"]
			decor.add_child(_poly("LampGlow" + tag, _ellipse(34, 34), Color(1, 0.95, 0.75, 0.25), at))
			decor.add_child(_poly("Lamp" + tag, _ellipse(14, 14), Color(0.25, 0.25, 0.27), at))
			decor.add_child(_poly("LampBulb" + tag, _ellipse(8, 8), Color(1, 0.96, 0.8), at))
	var pole: Vector2 = Vector2(880, 1700)
	decor.add_child(_poly("PoleBase", _ellipse(26, 16), Color(0.85, 0.85, 0.83), pole + Vector2(0, 5)))
	decor.add_child(_poly("Pole", _ellipse(7, 7), Color(0.4, 0.4, 0.42), pole))
	decor.add_child(_poly("Flag", PackedVector2Array([pole + Vector2(6, -60), pole + Vector2(86, -52), pole + Vector2(80, -10), pole + Vector2(6, -16)]), Color(0.85, 0.12, 0.1)))
	return root

## 中正紀念堂: white marble plaza, white walls with blue tile tops, the white hall with a
## blue octagonal roof above, cypress trees and lamps along the sides.
func _arena_memorial() -> Node:
	var blue := Color(0.16, 0.3, 0.66)
	var root: Node2D = _arena_base("ArenaMemorial", Color(0.88, 0.87, 0.84), Color(0.76, 0.79, 0.84), 120.0,
		Color(0.93, 0.93, 0.91), blue)
	var facade: Node = root.get_node("Facade")
	facade.add_child(_poly("HallBase", _rect(560, 90, 540, 215), Color(0.97, 0.97, 0.95)))
	for i: int in 5:
		facade.add_child(_poly("Step%d" % (i + 1), _rect(300 - i * 20, 4, 540, 255 - i * 9), Color(0.82, 0.82, 0.8)))
	facade.add_child(_poly("HallDoor", _rect(80, 50, 540, 210), blue.darkened(0.3)))
	facade.add_child(_poly("RoofLower", PackedVector2Array([Vector2(230, 170), Vector2(850, 170), Vector2(790, 130), Vector2(290, 130)]), blue))
	facade.add_child(_poly("RoofUpper", PackedVector2Array([Vector2(330, 130), Vector2(750, 130), Vector2(680, 88), Vector2(400, 88)]), blue.lightened(0.08)))
	facade.add_child(_poly("Finial", _ellipse(14, 12), Color(0.9, 0.75, 0.3), Vector2(540, 84)))
	facade.add_child(_poly("WallLeft", _rect(260, 60, 130, 230), Color(0.95, 0.95, 0.93)))
	facade.add_child(_poly("WallRight", _rect(260, 60, 950, 230), Color(0.95, 0.95, 0.93)))
	facade.add_child(_poly("TileLeft", _rect(260, 14, 130, 196), blue))
	facade.add_child(_poly("TileRight", _rect(260, 14, 950, 196), blue))
	var decor: Node = root.get_node("Decor")
	for i: int in 4:
		for side: int in 2:
			var at: Vector2 = Vector2(118 if side == 0 else 962, 470 + i * 360)
			var tag: String = "%d%s" % [i + 1, "L" if side == 0 else "R"]
			decor.add_child(_poly("TreeShadow" + tag, _ellipse(40, 40), Color(0, 0, 0, 0.18), at + Vector2(6, 8)))
			decor.add_child(_poly("Tree" + tag, _ellipse(36, 36, 12), Color(0.2, 0.45, 0.28), at))
			decor.add_child(_poly("TreeTop" + tag, _ellipse(20, 20, 10), Color(0.28, 0.56, 0.34), at + Vector2(-6, -6)))
	decor.add_child(_poly("Path", _rect(160, 1480, 540, 1010), Color(0.93, 0.92, 0.9, 0.6)))
	decor.move_child(decor.get_node("Path"), 0)
	return root

# --- rooms -------------------------------------------------------------------

## [tank scene, x, y, property overrides]
## [enemy scene, x, y, property overrides]. Rats come first; tanks from room 2, plates from room 3.
func _build_rooms() -> void:
	var rat: String = "res://enemies/rat.tscn"
	var tank: String = "res://enemies/tank.tscn"
	var plate: String = "res://enemies/plate.tscn"
	var boss: String = "res://enemies/boss_tank.tscn"
	var crate: String = "res://arena/crate.tscn"
	var barrier: String = "res://arena/barrier.tscn"
	var layouts: Array[Dictionary] = [
		{"enemies": [[rat, 300, 520], [rat, 780, 520], [rat, 540, 420], [rat, 420, 680], [rat, 660, 680]],
			"obstacles": [[crate, 250, 1120], [crate, 830, 1120]]},
		{"enemies": [[rat, 250, 560], [rat, 830, 560], [rat, 400, 700], [rat, 680, 700], [tank, 540, 420]],
			"obstacles": [[crate, 540, 900], [crate, 200, 1150]]},
		{"enemies": [[plate, 260, 440], [plate, 820, 440], [rat, 420, 700], [rat, 660, 700], [rat, 540, 600]],
			"obstacles": [[barrier, 540, 820], [crate, 250, 1100], [crate, 830, 1100]], "hp_scale": 1.05},
		{"enemies": [[tank, 280, 460], [tank, 800, 460], [plate, 540, 400], [rat, 400, 720], [rat, 680, 720], [rat, 540, 800]],
			"obstacles": [[crate, 300, 1020], [crate, 780, 1020]], "hp_scale": 1.1},
		{"enemies": [[boss, 540, 560, {"display_name": "重型坦克", "max_hp": 1800, "exp_value": 20, "summon_count": 2, "scale": Vector2(0.8, 0.8)}]],
			"obstacles": [], "boss": true},
		{"enemies": [[plate, 240, 420], [plate, 840, 420], [plate, 540, 360], [rat, 380, 700], [rat, 700, 700], [rat, 540, 780]],
			"obstacles": [[barrier, 300, 900], [barrier, 780, 900]], "hp_scale": 1.15},
		{"enemies": [[tank, 240, 460], [tank, 840, 460], [tank, 540, 380], [rat, 360, 760], [rat, 720, 760], [rat, 540, 700]],
			"obstacles": [[crate, 200, 1000], [crate, 880, 1000], [crate, 540, 1150]], "hp_scale": 1.2},
		{"enemies": [[plate, 240, 400], [plate, 840, 400], [plate, 540, 330], [tank, 330, 640], [tank, 750, 640]],
			"obstacles": [[barrier, 540, 820], [crate, 250, 1080], [crate, 830, 1080]], "hp_scale": 1.3},
		{"enemies": [[tank, 250, 520], [tank, 830, 520], [plate, 380, 360], [plate, 700, 360], [rat, 300, 760],
			[rat, 780, 760], [rat, 450, 820], [rat, 630, 820]],
			"obstacles": [[crate, 300, 1050], [crate, 780, 1050]], "hp_scale": 1.4},
		{"enemies": [["res://enemies/chiang_boss.tscn", 540, 520]], "obstacles": [[crate, 260, 1150], [crate, 820, 1150]], "boss": true},
	]
	for i: int in layouts.size():
		var area: Array = ["res://arena/arena_temple.tscn", "宮廟"] if i < 3 else (
			["res://arena/arena_square.tscn", "天安門廣場"] if i < 7 else ["res://arena/arena_memorial.tscn", "中正紀念堂"])
		layouts[i]["arena"] = area[0]
		layouts[i]["area_name"] = area[1]
		_save(_room(i + 1, layouts[i]), "res://rooms/room_%02d.tscn" % (i + 1))

func _room(number: int, layout: Dictionary) -> Node:
	var root := Node2D.new()
	root.name = "Room%02d" % number
	root.set_script(load("res://rooms/room.gd"))
	root.set("boss_room", layout.get("boss", false))
	root.set("hp_scale", layout.get("hp_scale", 1.0))
	root.set("area_name", layout["area_name"])
	_add(root, _unique(_instance(layout["arena"])), "Arena")
	var obstacles := Node2D.new()
	_add(root, obstacles, "Obstacles")
	for row: Array in layout["obstacles"]:
		var obstacle: Node2D = _instance(row[0]) as Node2D
		obstacle.position = Vector2(row[1], row[2])
		obstacles.add_child(obstacle)
	var enemies: Node2D = _unique(Node2D.new())
	_add(root, enemies, "Enemies")
	for row: Array in layout["enemies"]:
		var enemy: Node2D = _instance(row[0]) as Node2D
		enemy.position = Vector2(row[1], row[2])
		if row.size() > 3:
			var overrides: Dictionary = row[3]
			for key: String in overrides:
				enemy.set(key, overrides[key])
		enemies.add_child(enemy)
	var start := Marker2D.new()
	start.position = Vector2(540, 1640)
	_add(root, _unique(start), "PlayerStart")
	return root

# --- UI ----------------------------------------------------------------------

func _ability_card() -> Node:
	var card := Button.new()
	card.name = "AbilityCard"
	card.set_script(load("res://ui/ability_card.gd"))
	card.custom_minimum_size = Vector2(900, 210)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	_add(card, _full_rect(margin), "Margin")
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 28)
	_add(margin, row, "Row")
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(110, 110)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.color = Color(0.85, 0.5, 0.95)
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(row, _unique(swatch), "Swatch")
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(row, texts, "Texts")
	_add(texts, _unique(_label("Title", "穿透", 44, HORIZONTAL_ALIGNMENT_LEFT)))
	var description: Label = _label("Description", "甘蔗穿過坦克\n每穿一台傷害 −33%", 28, HORIZONTAL_ALIGNMENT_LEFT)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_color_override(&"font_color", Color(0.9, 0.9, 0.82))
	_add(texts, _unique(description))
	_add(row, _unique(_label("Stack", "1 / 3", 28)))
	return card

func _joystick() -> Node:
	var root := Control.new()
	root.name = "Joystick"
	root.set_script(load("res://ui/joystick.gd"))
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_full_rect(root)
	var base := Panel.new()
	base.size = Vector2(260, 260)
	base.position = Vector2(410, 1300)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.add_theme_stylebox_override(&"panel", _flat(Color(1, 1, 1, 0.14), 130, Color(1, 1, 1, 0.45), 5))
	_add(root, _unique(base), "Base")
	var knob := Panel.new()
	knob.size = Vector2(120, 120)
	knob.position = Vector2(70, 70)
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	knob.add_theme_stylebox_override(&"panel", _flat(Color(1, 1, 1, 0.55), 60))
	_add(base, _unique(knob), "Knob")
	var hint: Label = _label("Hint", "按住拖曳移動・放開就自動丟甘蔗", 28)
	hint.modulate = Color(1, 1, 1, 0.55)
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_top = -80
	hint.offset_bottom = -30
	hint.offset_left = -400
	hint.offset_right = 400
	_add(root, hint)
	return root

func _hud() -> Node:
	var root := Control.new()
	root.name = "Hud"
	root.set_script(load("res://ui/hud.gd"))
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	_full_rect(root)
	var joystick: Control = _instance("res://ui/joystick.tscn") as Control
	_add(root, _unique(joystick), "Joystick")
	joystick.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	joystick.offset_top = 300

	var top := MarginContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 190
	for side: String in ["left", "right"]:
		top.add_theme_constant_override("margin_" + side, 40)
	top.add_theme_constant_override(&"margin_top", 60)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(root, top, "TopBar")
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(top, column, "Column")
	var info := HBoxContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_theme_constant_override(&"separation", 20)
	_add(column, info, "InfoRow")
	_add(info, _unique(_label("RoomLabel", "第 1 / 10 間", 38, HORIZONTAL_ALIGNMENT_LEFT)))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(info, spacer, "Spacer")
	_add(info, _unique(_label("LevelLabel", "Lv 1", 38)))
	var pause := Button.new()
	pause.text = "暫停"
	pause.custom_minimum_size = Vector2(130, 64)
	pause.add_theme_font_size_override(&"font_size", 30)
	_add(info, _unique(pause), "PauseButton")
	var exp_bar: ProgressBar = _bar("ExpBar", Color(0.35, 0.8, 1.0), Vector2(0, 20), Vector2.ZERO)
	exp_bar.value = 0
	_add(column, _unique(exp_bar))
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override(&"h_separation", 8)
	chips.add_theme_constant_override(&"v_separation", 8)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(column, _unique(chips), "AbilityChips")

	var boss := VBoxContainer.new()
	boss.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	boss.offset_top = 196
	boss.offset_bottom = 262
	boss.offset_left = 120
	boss.offset_right = -120
	boss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss.add_theme_constant_override(&"separation", 2)
	_add(root, _unique(boss), "BossPanel")
	_add(boss, _unique(_label("BossName", "巨砲坦克王", 28)))
	_add(boss, _unique(_bar("BossBar", Color(0.9, 0.2, 0.15), Vector2(0, 22), Vector2.ZERO)))

	var banner: Label = _label("Banner", "門開了！往上走", 72)
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	banner.offset_left = -500
	banner.offset_right = 500
	banner.offset_top = -260
	banner.offset_bottom = -140
	_add(root, _unique(banner))

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.visible = false
	_add(root, _unique(_full_rect(overlay)), "PauseOverlay")
	var center := CenterContainer.new()
	_add(overlay, _full_rect(center), "Center")
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 40)
	_add(center, box, "Box")
	_add(box, _label("PausedTitle", "暫停中", 80))
	var resume := Button.new()
	resume.text = "繼續"
	resume.custom_minimum_size = Vector2(420, 120)
	_add(box, _unique(resume), "ResumeButton")

	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(root, _unique(_full_rect(fade)), "Fade")
	return root

func _panel_frame(root_name: String, script_path: String) -> Array:
	var root := Control.new()
	root.name = root_name
	root.set_script(load(script_path))
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	_full_rect(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.68)
	_add(root, _full_rect(dim), "Dim")
	var center := CenterContainer.new()
	_add(root, _full_rect(center), "Center")
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(920, 0)
	box.add_theme_constant_override(&"separation", 26)
	_add(center, box, "Box")
	return [root, box]

func _choice_panel() -> Node:
	var parts: Array = _panel_frame("ChoicePanel", "res://ui/choice_panel.gd")
	var root: Control = parts[0]
	var box: VBoxContainer = parts[1]
	root.set("card_scene", load("res://ui/ability_card.tscn"))
	var title: Label = _label("Title", "升級！", 88)
	title.add_theme_color_override(&"font_color", Color(1.0, 0.9, 0.45))
	_add(box, _unique(title))
	_add(box, _unique(_label("Subtitle", "選擇一項能力", 36)))
	var cards := VBoxContainer.new()
	cards.add_theme_constant_override(&"separation", 22)
	_add(box, _unique(cards), "Cards")
	for i: int in 3:
		_add(cards, _instance("res://ui/ability_card.tscn"), "PreviewCard%d" % (i + 1))
	return root

func _result_panel() -> Node:
	var parts: Array = _panel_frame("ResultPanel", "res://ui/result_panel.gd")
	var root: Control = parts[0]
	var box: VBoxContainer = parts[1]
	box.add_theme_constant_override(&"separation", 50)
	_add(box, _unique(_label("Title", "第一章 完成！", 88)))
	var summary: Label = _label("Summary", "Lv 8｜擊倒 42 隻敵人｜拿到 7 個能力", 40)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add(box, _unique(summary))
	var restart := Button.new()
	restart.text = "再來一次"
	restart.custom_minimum_size = Vector2(480, 130)
	restart.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_add(box, _unique(restart), "RestartButton")
	return root

# --- main --------------------------------------------------------------------

func _main() -> Node:
	var root := Node2D.new()
	root.name = "Main"
	root.set_script(load("res://main.gd"))
	var rooms: Array[PackedScene] = []
	for i: int in 10:
		rooms.append(load("res://rooms/room_%02d.tscn" % (i + 1)) as PackedScene)
	root.set("rooms", rooms)
	var abilities: Array[Resource] = []
	for path: String in _ability_paths():
		abilities.append(load(path))
	root.set("abilities", abilities)
	root.set("sugarcane_scene", load("res://player/sugarcane.tscn"))
	root.set("exp_gem_scene", load("res://pickups/exp_gem.tscn"))
	root.set("heart_scene", load("res://pickups/heart.tscn"))
	root.set("damage_number_scene", load("res://effects/damage_number.tscn"))
	root.set("explosion_scene", load("res://effects/explosion.tscn"))

	var camera := Camera2D.new()
	camera.position = Vector2(540, 960)
	_add(root, _unique(camera), "Camera")
	var holder := Node2D.new()
	_add(root, _unique(holder), "RoomHolder")
	_add(holder, _instance("res://rooms/room_01.tscn"), "PreviewRoom")
	_add(root, _unique(Node2D.new()), "Pickups")
	var hero: Node2D = _instance("res://player/hero.tscn") as Node2D
	hero.position = Vector2(540, 1640)
	_add(root, _unique(hero), "Hero")
	_add(root, _unique(Node2D.new()), "Shots")
	_add(root, _unique(Node2D.new()), "EnemyShots")
	_add(root, _unique(Node2D.new()), "Effects")
	var layer := CanvasLayer.new()
	layer.layer = 10
	_add(root, layer, "UiLayer")
	_add(layer, _unique(_instance("res://ui/hud.tscn")), "Hud")
	# Hidden in the main scene so the editor shows the room; open them in their own scenes.
	var choice: Control = _instance("res://ui/choice_panel.tscn") as Control
	choice.visible = false
	_add(layer, _unique(choice), "ChoicePanel")
	var result: Control = _instance("res://ui/result_panel.tscn") as Control
	result.visible = false
	_add(layer, _unique(result), "ResultPanel")
	var time_control := Node.new()
	time_control.set_script(load("res://game/time_control.gd"))
	time_control.process_mode = Node.PROCESS_MODE_ALWAYS
	_add(root, _unique(time_control), "TimeControl")
	var sfx := Node.new()
	sfx.set_script(load("res://game/sfx.gd"))
	sfx.process_mode = Node.PROCESS_MODE_ALWAYS
	_add(root, _unique(sfx), "Sfx")
	return root
