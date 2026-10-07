extends SceneTree
## One-time, additive authoring migration for the 10-minute horde version (docs/horde-spec.md); never run by the game.
## Run: godot --headless --path . --script res://tools/add_horde.gd
## Applied 2026-10-07. Skips itself once game.tscn carries horde_scene_version; after that, edit the scenes and resources directly.
## (The first run stopped inside migrate_street; that one function was re-run once by hand. Do not repeat it: street.tscn is hand-editable now.)
const B = preload("res://addons/proto_kit/scene_builder.gd")
const Item = preload("res://scripts/item_def.gd")
var theme: Theme
var failed: bool = false

func _initialize() -> void:
	build.call_deferred()

func save(node: Node, path: String, refs: Array = [], overwrite: bool = false) -> void:
	node.scene_file_path = ""
	var result: Dictionary = B.save_scene(node, path, {"overwrite": overwrite, "expected_refs": refs})
	failed = failed or not result.ok

func save_res(resource: Resource, path: String) -> void:
	failed = failed or ResourceSaver.save(resource, path) != OK

func add(parent: Node, child: Node, node_name: String, unique: bool = false) -> Node:
	return B.add(parent, B.unique(child) if unique else child, node_name)

func poly(parent: Node, node_name: String, color: String, points: PackedVector2Array, at: Vector2 = Vector2.ZERO) -> Polygon2D:
	var shape := Polygon2D.new()
	shape.color = Color(color)
	shape.polygon = points
	shape.position = at
	add(parent, shape, node_name)
	return shape

func rect(w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)])

func ellipse(rx: float, ry: float, sides: int = 20) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i: int in sides:
		points.append(Vector2(cos(TAU * i / sides) * rx, sin(TAU * i / sides) * ry))
	return points

func text(parent: Node, node_name: String, content: String, font_size: int, unique: bool = true) -> Label:
	var node := Label.new()
	node.text = content
	node.add_theme_font_size_override("font_size", font_size)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add(parent, node, node_name, unique)
	return node

func build() -> void:
	var main := B.instance("res://scenes/game.tscn")
	if main.get_meta("horde_scene_version", 0) >= 1:
		main.free()
		print("skip: horde version already authored; edit scenes directly")
		quit()
		return
	main.free()
	theme = load("res://data/ui_theme.tres")
	projectiles()
	effects()
	enemies()
	items()
	timeline()
	meta_catalogue()
	shop_scenes()
	migrate_cards()
	migrate_player()
	migrate_street()
	migrate_ui()
	if failed:
		quit(1)
		return
	main = B.instance("res://scenes/game.tscn")
	main.session_duration = 600.0
	var meta := Node.new()
	meta.set_script(load("res://scripts/meta.gd"))
	meta.catalogue = load("res://data/meta.tres")
	add(main.get_node("Services"), meta, "Meta", true)
	var shop := B.instance("res://scenes/shop.tscn") as Control
	shop.visible = false
	add(main.get_node("Interface"), shop, "Shop", true)
	main.set_meta("horde_scene_version", 1)
	save(main, "res://scenes/game.tscn", ["res://scenes/street.tscn", "res://scenes/upgrades.tscn", "res://scenes/shop.tscn"], true)
	quit(1 if failed else 0)

# --- Projectiles -----------------------------------------------------------------------------------

func projectile_root(node_name: String, radius: float, spin: float = 0.0, face: bool = true) -> Node2D:
	var root := Node2D.new()
	root.name = node_name
	root.set_script(load("res://scripts/projectile.gd"))
	root.radius = radius
	root.spin = spin
	root.face_travel = face
	var visual := Node2D.new()
	visual.position = Vector2(0, -18)
	add(root, visual, "Visual", true)
	return root

func projectiles() -> void:
	var wave := B.instance("res://scenes/wave.tscn")
	wave.set_script(load("res://scripts/projectile.gd"))
	wave.radius = 18.0
	save(wave, "res://scenes/wave.tscn", [], true)

	var slipper := projectile_root("Slipper", 16.0, 14.0, false)
	var v: Node2D = slipper.get_node("Visual")
	poly(v, "Sole", "1b2a33", ellipse(17, 9))
	poly(v, "SoleTop", "f2f2ea", ellipse(15, 7.5))
	poly(v, "Strap", "2f6fd6", PackedVector2Array([Vector2(-4, -8), Vector2(5, -8), Vector2(5, 8), Vector2(-4, 8)]))
	save(slipper, "res://scenes/slipper.tscn")

	var pearl := projectile_root("Pearl", 9.0)
	v = pearl.get_node("Visual")
	poly(v, "Outline", "120c08", ellipse(8, 8, 14))
	poly(v, "Ball", "4a2c1a", ellipse(6.5, 6.5, 14))
	poly(v, "Shine", "b88a63", ellipse(2, 2, 8), Vector2(-2, -2))
	save(pearl, "res://scenes/pearl.tscn")

	var cracker := projectile_root("Firecracker", 10.0, 9.0, false)
	v = cracker.get_node("Visual")
	poly(v, "Outline", "1b1010", rect(12, 22), Vector2(-6, -11))
	poly(v, "Tube", "e0322b", rect(9, 19), Vector2(-4.5, -9.5))
	poly(v, "Band", "ffd36b", rect(9, 3), Vector2(-4.5, -2))
	poly(v, "Spark", "fff2a8", ellipse(3, 3, 8), Vector2(0, -14))
	save(cracker, "res://scenes/firecracker.tscn")

	var incense := projectile_root("Incense", 13.0, 0.0, false)
	v = incense.get_node("Visual")
	poly(v, "Stick", "8a5a2b", rect(4, 30), Vector2(-2, -15))
	poly(v, "Glow", "ff9a3c", ellipse(6, 6, 10), Vector2(0, -16))
	poly(v, "Tip", "ff3b1f", ellipse(3, 3, 8), Vector2(0, -16))
	poly(v, "Wisp", "e8e0d0", PackedVector2Array([Vector2(-2, -20), Vector2(3, -28), Vector2(-1, -36), Vector2(-4, -34), Vector2(0, -28), Vector2(-5, -21)]))
	save(incense, "res://scenes/incense.tscn")

	var lantern := projectile_root("Lantern", 10.0, 0.0, false)
	v = lantern.get_node("Visual")
	poly(v, "Outline", "3a1d0c", PackedVector2Array([Vector2(-14, -20), Vector2(14, -20), Vector2(11, 14), Vector2(-11, 14)]))
	poly(v, "Paper", "ffe2a3", PackedVector2Array([Vector2(-12, -18), Vector2(12, -18), Vector2(9, 12), Vector2(-9, 12)]))
	poly(v, "Flame", "ff7a2f", ellipse(5, 7, 10), Vector2(0, 5))
	poly(v, "Wish", "d6452c", rect(6, 14), Vector2(-3, -12))
	save(lantern, "res://scenes/lantern.tscn")

func effects() -> void:
	var root := Node2D.new()
	root.name = "Blast"
	root.set_script(load("res://scripts/blast.gd"))
	poly(root, "Fill", "ffb34759", ellipse(100, 70, 28)).unique_name_in_owner = true
	var ring := Line2D.new()
	ring.points = ellipse(100, 70, 28)
	ring.closed = true
	ring.width = 6.0
	ring.default_color = Color("ffb347")
	add(root, ring, "Ring", true)
	var caption := text(root, "Caption", "噗～", 26)
	caption.position = Vector2(-50, -60)
	caption.size = Vector2(100, 34)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_color_override("font_color", Color("f7e8ce"))
	caption.add_theme_color_override("font_outline_color", Color("10161c"))
	caption.add_theme_constant_override("outline_size", 6)
	save(root, "res://scenes/blast.tscn")

	var drop := Node2D.new()
	drop.name = "Pickup"
	drop.set_script(load("res://scripts/pickup.gd"))
	var looks := Node2D.new()
	looks.position = Vector2(0, -6)
	add(drop, looks, "Looks", true)
	for entry: Array in [["Gem", "5aa9ff", 6.0], ["GemMid", "6bd66b", 8.0], ["GemBig", "ff5a4f", 12.0]]:
		var gem := Node2D.new()
		add(looks, gem, entry[0])
		var r: float = entry[2]
		poly(gem, "Outline", "0d1820", PackedVector2Array([Vector2(0, -r - 2), Vector2(r * 0.8 + 2, 0), Vector2(0, r + 2), Vector2(-r * 0.8 - 2, 0)]))
		poly(gem, "Body", entry[1], PackedVector2Array([Vector2(0, -r), Vector2(r * 0.8, 0), Vector2(0, r), Vector2(-r * 0.8, 0)]))
	var coin := Node2D.new()
	add(looks, coin, "Coin")
	poly(coin, "Outline", "5a3b00", ellipse(9, 9, 16))
	poly(coin, "Face", "ffd36b", ellipse(7, 7, 16))
	var food := Node2D.new()
	add(looks, food, "Food")
	poly(food, "Bowl", "e8e0d0", PackedVector2Array([Vector2(-13, -2), Vector2(13, -2), Vector2(9, 9), Vector2(-9, 9)]))
	poly(food, "Rice", "fffaf0", ellipse(12, 5, 14), Vector2(0, -3))
	poly(food, "Pork", "7a3d18", ellipse(8, 3.5, 12), Vector2(0, -5))
	var magnet := Node2D.new()
	add(looks, magnet, "Magnet")
	poly(magnet, "Body", "8fa6ad", rect(18, 14), Vector2(-9, -7))
	poly(magnet, "Nozzle", "4a5a62", rect(16, 4), Vector2(-20, 2))
	var chest := Node2D.new()
	add(looks, chest, "Chest")
	poly(chest, "Box", "c0392b", rect(26, 18), Vector2(-13, -9))
	poly(chest, "Lid", "e0322b", rect(28, 6), Vector2(-14, -12))
	poly(chest, "Band", "ffd36b", rect(4, 24), Vector2(-2, -12))
	save(drop, "res://scenes/pickup.tscn")

# --- Enemies and data ------------------------------------------------------------------------------

func enemies() -> void:
	for entry: Array in [["smoker", 26.0, 46.0, 1, 5.0, false], ["bike", 40.0, -1.0, 2, 7.0, true], ["car", 150.0, 32.0, 4, 12.0, true]]:
		var path: String = "res://data/%s.tres" % entry[0]
		var data: Resource = load(path)
		data.max_hp = entry[1]
		if entry[2] > 0.0:
			data.speed = entry[2]
		data.experience = entry[3]
		data.contact_damage = entry[4]
		data.turns = entry[5]
		if entry[0] == "smoker":
			data.hazard_interval = 4.0
		save_res(data, path)
	var fat: Resource = load("res://scripts/enemy_def.gd").new()
	fat.kind = "fatty"
	fat.max_hp = 220.0
	fat.speed = 30.0
	fat.radius = 30.0
	fat.weight = 4.0
	fat.experience = 5
	fat.contact_damage = 10.0
	fat.aura_radius = 80.0
	fat.aura_slow = 0.45
	fat.burst_radius = 120.0
	fat.burst_damage = 80.0
	save_res(fat, "res://data/fatty.tres")
	var root := B.instance("res://scenes/smoker.tscn")
	root.name = "Fatty"
	root.definition = load("res://data/fatty.tres")
	var placeholder: Node2D = root.get_node("Visual/Placeholder")
	placeholder.scale = Vector2(1.45, 1.2)
	placeholder.get_node("Fist/Cigarette").free()
	placeholder.get_node("Fist/Ember").free()
	placeholder.get_node("Jacket").color = Color("8a9a3a")
	placeholder.get_node("Hair").color = Color("3a2a1a")
	poly(placeholder, "Belly", "f0d2a8", ellipse(11, 9, 16), Vector2(0, -26))
	var shadow: Polygon2D = root.get_node("Shadow")
	shadow.scale = Vector2(1.5, 1.3)
	var aura := Node2D.new()
	aura.z_index = -1
	add(root, aura, "Stink", true)
	root.move_child(aura, 0)
	var cloud := poly(aura, "Cloud", "9bd65a2e", ellipse(80, 56, 28))
	cloud.position = Vector2(0, -4)
	for i: int in 3:
		poly(aura, "Wisp%d" % (i + 1), "9bd65a99", PackedVector2Array([Vector2(0, 0), Vector2(5, -8), Vector2(1, -16), Vector2(-3, -14), Vector2(1, -8), Vector2(-4, -1)]), Vector2(-28 + i * 28, -70 - (i % 2) * 8))
	root.get_node("HpBar").offset_top = -96.0
	root.get_node("HpBar").offset_bottom = -91.0
	save(root, "res://scenes/fatty.tscn")

func item(entry: Dictionary) -> Resource:
	var path: String = "res://data/items/%s.tres" % entry.id
	if FileAccess.file_exists(path):
		return load(path)
	var resource: Resource = Item.new()
	for key: String in entry:
		var value: Variant = entry[key]
		if key == "id" or key == "unlock" or key == "kind" or key == "variant" or key == "stat" or key == "evolve_passive" or key == "evolve_into" or key == "replaces":
			value = StringName(value)
		elif key == "accent":
			value = Color(value)
		elif key == "projectile":
			value = load("res://scenes/%s.tscn" % value)
		elif key == "level_notes":
			value = PackedStringArray(value)
		elif key == "amount_levels":
			value = PackedInt32Array(value)
		resource.set(key, value)
	save_res(resource, path)
	return load(path)

func passive(id: String, title: String, line: String, stat: String, per_level: float, accent: String, unlock: String = "") -> Dictionary:
	return {"id": id, "title": title, "description": line, "level_notes": [line, line, line, line], "slot": "passive", "accent": accent, "max_level": 5, "stat": stat, "per_level": per_level, "unlock": unlock}

func items() -> void:
	DirAccess.make_dir_recursive_absolute("res://data/items")
	var entries: Array[Dictionary] = [
		{"id": "punch", "title": "拳頭", "description": "自動揍最近的敵人。", "level_notes": ["傷害 +5，出拳更快", "多打中一個前方敵人", "傷害 +5，範圍變大", "每第三拳是 180% 重拳", "多打中一個前方敵人", "傷害 +5，出拳更快", "傷害 +5，範圍變大"], "max_level": 8, "accent": "f7e8ce", "kind": "punch", "damage": 22.0, "damage_per_level": 5.0, "cooldown": 0.42, "cooldown_per_level": 0.04, "amount": 1, "amount_levels": [3, 6], "area": 1.0, "area_per_level": 0.04, "special_level": 5, "evolve_passive": "sacha", "evolve_into": "iron_palm"},
		{"id": "wave", "title": "衝擊波", "description": "朝敵人射出穿透的衝擊波。", "level_notes": ["傷害 +5，冷卻縮短", "多一道衝擊波", "傷害 +5，波更寬", "多一道衝擊波", ], "accent": "72e0c0", "kind": "wave", "projectile": "wave", "damage": 16.0, "damage_per_level": 5.0, "cooldown": 1.3, "cooldown_per_level": 0.06, "amount": 1, "amount_levels": [3, 5], "area": 1.0, "area_per_level": 0.08, "speed": 440.0, "duration": 0.9, "pierce": -1, "knockback": 0.8},
		{"id": "kick", "title": "回旋踢", "description": "每隔一段時間踢開身邊一圈敵人。", "level_notes": ["傷害 +6，範圍變大", "冷卻縮短", "傷害 +6，範圍變大", "冷卻縮短，範圍變大"], "accent": "ffc56b", "kind": "kick", "damage": 20.0, "damage_per_level": 6.0, "cooldown": 2.2, "cooldown_per_level": 0.08, "area": 1.0, "area_per_level": 0.1, "knockback": 1.6},
		{"id": "slipper", "title": "藍白拖", "description": "丟出藍白拖，飛出去還會飛回來。", "level_notes": ["多丟一隻", "傷害 +4，冷卻縮短", "多丟一隻", "傷害 +4，拖鞋變大"], "accent": "5aa9ff", "kind": "slipper", "projectile": "slipper", "damage": 14.0, "damage_per_level": 4.0, "cooldown": 1.6, "cooldown_per_level": 0.05, "amount": 1, "amount_levels": [2, 4], "area": 1.0, "area_per_level": 0.05, "speed": 420.0, "duration": 1.6, "evolve_passive": "massage", "evolve_into": "homing_slipper"},
		{"id": "pearl", "title": "珍珠奶茶", "description": "射出珍珠，撞到街區邊緣會反彈。", "level_notes": ["多射一顆", "多射一顆", "傷害 +3，冷卻縮短", "多射一顆"], "accent": "c58b52", "kind": "pearl", "projectile": "pearl", "damage": 10.0, "damage_per_level": 3.0, "cooldown": 1.1, "cooldown_per_level": 0.05, "amount": 1, "amount_levels": [2, 3, 5], "speed": 380.0, "duration": 2.0, "pierce": 2, "knockback": 0.6, "evolve_passive": "energy", "evolve_into": "pearl_storm"},
		{"id": "firecracker", "title": "鞭炮", "description": "丟進敵人堆裡炸開。", "level_notes": ["多丟一串", "傷害 +6，爆炸變大", "多丟一串", "傷害 +6，冷卻縮短"], "accent": "ff5a4f", "kind": "firecracker", "projectile": "firecracker", "damage": 18.0, "damage_per_level": 6.0, "cooldown": 2.0, "cooldown_per_level": 0.06, "amount": 1, "amount_levels": [2, 4], "area": 1.0, "area_per_level": 0.1, "duration": 0.45, "knockback": 1.4, "evolve_passive": "megaphone", "evolve_into": "beehive"},
		{"id": "incense", "title": "三炷香", "description": "三支香繞著身體轉，燙到就痛。", "level_notes": ["傷害 +3，轉更大圈", "多一支香", "傷害 +3，持續更久", "多一支香"], "accent": "ffb347", "kind": "incense", "projectile": "incense", "damage": 9.0, "damage_per_level": 3.0, "cooldown": 4.5, "cooldown_per_level": 0.05, "amount": 3, "amount_levels": [3, 5], "area": 1.0, "area_per_level": 0.06, "speed": 360.0, "duration": 3.0, "knockback": 0.8, "evolve_passive": "amulet", "evolve_into": "mazu"},
		{"id": "lantern", "title": "天燈", "description": "從天上往畫面內的敵人砸火。", "level_notes": ["多一盞", "多一盞，傷害 +7", "多一盞", "多一盞，火更大"], "accent": "ffd36b", "unlock": "survive_5", "kind": "lantern", "projectile": "lantern", "damage": 24.0, "damage_per_level": 7.0, "cooldown": 2.4, "cooldown_per_level": 0.06, "amount": 1, "amount_levels": [2, 3, 4, 5], "area": 1.0, "area_per_level": 0.06, "duration": 0.4, "knockback": 1.2, "evolve_passive": "points", "evolve_into": "pingxi"},
		{"id": "cane", "title": "愛的小手", "description": "左右橫掃一長條，打一大片。", "level_notes": ["兩邊一起打", "傷害 +5，打更遠", "冷卻縮短", "傷害 +5，打更遠"], "accent": "ff8fb1", "unlock": "kills_300", "kind": "cane", "damage": 16.0, "damage_per_level": 5.0, "cooldown": 1.4, "cooldown_per_level": 0.05, "amount": 1, "amount_levels": [2], "area": 1.0, "area_per_level": 0.08, "knockback": 1.2, "evolve_passive": "chicken", "evolve_into": "duster"},
		{"id": "iron_palm", "title": "鐵沙掌", "description": "沙茶醬加持：前方大範圍，每拳都是重拳。", "slot": "evolution", "max_level": 1, "accent": "ffd36b", "kind": "punch", "variant": "palm", "replaces": "punch", "damage": 70.0, "cooldown": 0.32, "amount": 8, "area": 1.5, "knockback": 2.0},
		{"id": "homing_slipper", "title": "媽媽的追蹤拖鞋", "description": "不管跑多遠，拖鞋都會追上。", "slot": "evolution", "max_level": 1, "accent": "ffd36b", "kind": "slipper", "variant": "homing", "replaces": "slipper", "projectile": "slipper", "damage": 30.0, "cooldown": 0.9, "amount": 4, "area": 1.2, "speed": 460.0, "duration": 2.5, "knockback": 1.4},
		{"id": "pearl_storm", "title": "珍珠暴雨", "description": "珍珠像下雨一樣連射。", "slot": "evolution", "max_level": 1, "accent": "ffd36b", "kind": "pearl", "replaces": "pearl", "projectile": "pearl", "damage": 22.0, "cooldown": 0.25, "amount": 3, "area": 1.2, "speed": 460.0, "duration": 2.0, "pierce": 5, "knockback": 0.8},
		{"id": "beehive", "title": "鹽水蜂炮", "description": "四面八方射出蜂炮，碰到就炸。", "slot": "evolution", "max_level": 1, "accent": "ffd36b", "kind": "firecracker", "variant": "rocket", "replaces": "firecracker", "projectile": "firecracker", "damage": 40.0, "cooldown": 1.5, "amount": 14, "area": 1.3, "speed": 380.0, "duration": 1.2, "knockback": 1.6},
		{"id": "mazu", "title": "媽祖遶境", "description": "香陣常駐不散，繞得更大圈。", "slot": "evolution", "max_level": 1, "accent": "ffd36b", "kind": "incense", "variant": "permanent", "replaces": "incense", "projectile": "incense", "damage": 26.0, "cooldown": 1.0, "amount": 6, "area": 1.6, "speed": 420.0, "knockback": 1.2},
		{"id": "pingxi", "title": "平溪天燈祭", "description": "滿天天燈一起落下。", "slot": "evolution", "max_level": 1, "accent": "ffd36b", "kind": "lantern", "replaces": "lantern", "projectile": "lantern", "damage": 50.0, "cooldown": 1.4, "amount": 8, "area": 1.6, "duration": 0.4, "knockback": 1.5},
		{"id": "duster", "title": "雞毛撢子", "description": "兩邊同時揮，又寬又痛。", "slot": "evolution", "max_level": 1, "accent": "ffd36b", "kind": "cane", "variant": "both", "replaces": "cane", "damage": 48.0, "cooldown": 1.0, "amount": 2, "area": 1.8, "knockback": 1.6},
		passive("sacha", "沙茶醬", "所有武器傷害 +10%。", "might", 0.1, "ffb347"),
		passive("chicken", "雞排", "血量上限 +20%。", "max_hp", 0.2, "ffc56b"),
		passive("energy", "提神飲料", "冷卻時間 −8%。", "cooldown", 0.08, "72e0c0"),
		passive("points", "集點卡", "撿東西的範圍 +35%。", "magnet", 0.35, "5aa9ff"),
		passive("amulet", "平安符", "每次受傷少扣 1。", "armor", 1.0, "ff5a4f"),
		passive("megaphone", "大聲公", "攻擊範圍 +10%。", "area", 0.1, "ffd36b"),
		passive("massage", "腳底按摩", "移動速度 +8%。", "speed", 0.08, "6bd66b"),
		passive("hongbao", "紅包", "經驗 +8%。", "growth", 0.08, "e0322b", "total_2000"),
	]
	var catalogue: Array[Resource] = []
	for entry: Dictionary in entries:
		catalogue.append(item(entry))
	var fillers: Array[Resource] = [
		item({"id": "rice", "title": "滷肉飯", "description": "回復 30 血量。", "slot": "filler", "accent": "c58b52", "stat": "heal", "per_level": 30.0}),
		item({"id": "change", "title": "零錢", "description": "多帶 20 金幣回家。", "slot": "filler", "accent": "ffd36b", "stat": "coins", "per_level": 4.0}),
	]
	var config: Resource = load("res://data/progression.tres")
	config.set_script(load("res://scripts/progression_def.gd"))
	config.items = catalogue
	config.fillers = fillers
	save_res(config, "res://data/progression.tres")

func timeline() -> void:
	var schedule: Resource = load("res://scripts/spawn_schedule.gd").new()
	var rows: Array = [
		[0, 1.0, 2, [1, 0, 0, 0], 1.0, 30, 0, -1],
		[60, 0.9, 3, [1, 0.25, 0, 0], 1.1, 45, 0, -1],
		[120, 0.9, 3, [1, 0.3, 0.15, 0], 1.2, 55, 14, -1],
		[180, 0.8, 4, [1, 0.3, 0.15, 0.2], 1.4, 70, 0, -1],
		[240, 0.8, 4, [1, 0.35, 0.2, 0.25], 1.7, 80, 0, 3],
		[300, 0.7, 5, [1, 0.3, 0.2, 0.3], 2.0, 90, 24, -1],
		[360, 0.7, 5, [1, 0.45, 0.25, 0.3], 2.4, 100, 0, 2],
		[420, 0.65, 6, [1, 0.35, 0.3, 0.4], 2.9, 110, 0, -1],
		[480, 0.6, 6, [1, 0.4, 0.3, 0.4], 3.4, 120, 30, 3],
		[540, 0.45, 8, [1, 0.4, 0.35, 0.5], 4.0, 140, 36, 2],
	]
	var phases: Array[Resource] = []
	for row: Array in rows:
		var phase: Resource = load("res://scripts/spawn_phase.gd").new()
		phase.start = row[0]
		phase.interval = row[1]
		phase.batch = row[2]
		phase.weights = PackedFloat32Array(row[3])
		phase.hp_scale = row[4]
		phase.max_alive = row[5]
		phase.ring = row[6]
		phase.elite = row[7]
		phases.append(phase)
	schedule.phases = phases
	save_res(schedule, "res://data/spawn_schedule.tres")

func meta_catalogue() -> void:
	var catalogue: Resource = load("res://scripts/meta_def.gd").new()
	var shop: Array[Resource] = []
	for row: Array in [
		["might", "力量訓練", "所有武器傷害 +5%。", "might", 0.05, 5, 100, 1.5],
		["vitality", "健康檢查", "血量上限 +10%。", "max_hp", 0.1, 3, 120, 1.6],
		["recovery", "早睡早起", "每秒回復 0.2 血。", "recovery", 0.2, 3, 150, 1.6],
		["helmet", "安全帽", "每次受傷少扣 1。", "armor", 1.0, 2, 200, 2.0],
		["drink", "手搖飲集點", "冷卻時間 −2.5%。", "cooldown", 0.025, 2, 300, 2.0],
		["voice", "大嗓門", "攻擊範圍 +5%。", "area", 0.05, 2, 250, 1.8],
		["jog", "晨跑習慣", "移動速度 +5%。", "speed", 0.05, 2, 150, 1.8],
		["bargain", "撿便宜", "撿東西的範圍 +25%。", "magnet", 0.25, 2, 100, 1.8],
		["cram", "補習班", "經驗 +5%。", "growth", 0.05, 3, 200, 1.6],
		["piggy", "存錢筒", "金幣 +10%。", "greed", 0.1, 3, 150, 1.6],
		["revival", "再來一碗", "每局可以復活一次。", "revival", 1.0, 1, 800, 1.0],
	]:
		var entry: Resource = load("res://scripts/shop_item_def.gd").new()
		entry.id = StringName(row[0])
		entry.title = row[1]
		entry.description = row[2]
		entry.stat = StringName(row[3])
		entry.per_level = row[4]
		entry.max_level = row[5]
		entry.base_cost = row[6]
		entry.cost_growth = row[7]
		shop.append(entry)
	var goals: Array[Resource] = []
	for row: Array in [
		["survive_5", "撐過五分鐘", "單局撐過 05:00", "best_time", 300.0, "天燈"],
		["kills_300", "揍飛高手", "單局揍飛 300", "best_kills", 300.0, "愛的小手"],
		["total_2000", "街頭傳說", "累計揍飛 2000", "total_kills", 2000.0, "紅包"],
	]:
		var goal: Resource = load("res://scripts/achievement_def.gd").new()
		goal.id = StringName(row[0])
		goal.title = row[1]
		goal.description = row[2]
		goal.stat = row[3]
		goal.threshold = row[4]
		goal.reward = row[5]
		goals.append(goal)
	catalogue.shop = shop
	catalogue.achievements = goals
	save_res(catalogue, "res://data/meta.tres")

# --- UI --------------------------------------------------------------------------------------------

func shop_scenes() -> void:
	var card := Button.new()
	card.name = "ShopItem"
	card.theme = theme
	card.custom_minimum_size = Vector2(420, 84)
	card.set_script(load("res://scripts/shop_item.gd"))
	card.definition = load("res://data/meta.tres").shop[0]
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	for side: String in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add(card, margin, "Padding")
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add(margin, row, "Row")
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add(row, column, "Column")
	text(column, "Title", "力量訓練", 20)
	text(column, "Description", "所有武器傷害 +5%。", 14).add_theme_color_override("font_color", Color("8fa6ad"))
	var side := VBoxContainer.new()
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add(row, side, "Side")
	text(side, "Level", "Lv.0 / 5", 14).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var cost := text(side, "Cost", "100 金幣", 18)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost.add_theme_color_override("font_color", Color("ffc56b"))
	save(card, "res://scenes/shop_item.tscn")

	var root := Control.new()
	root.name = "Shop"
	root.theme = theme
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.set_script(load("res://scripts/shop.gd"))
	root.item_scene = load("res://scenes/shop_item.tscn")
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.035, 0.075, 0.1, 0.98)
	add(root, shade, "Shade")
	var frame := MarginContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("margin_left", 60)
	frame.add_theme_constant_override("margin_right", 60)
	frame.add_theme_constant_override("margin_top", 56)
	frame.add_theme_constant_override("margin_bottom", 36)
	add(root, frame, "Frame")
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	add(frame, body, "Column")
	var title := text(body, "Title", "街頭補給站", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var wallet := text(body, "Wallet", "金幣  0", 20)
	wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wallet.add_theme_color_override("font_color", Color("ffc56b"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add(body, scroll, "Scroll")
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	add(scroll, list, "List")
	var items_box := VBoxContainer.new()
	items_box.add_theme_constant_override("separation", 8)
	add(list, items_box, "Items", true)
	for i: int in 2:
		add(items_box, B.instance("res://scenes/shop_item.tscn"), "Preview%d" % (i + 1))
	var goals_title := text(list, "GoalsTitle", "解鎖目標", 20, false)
	goals_title.add_theme_color_override("font_color", Color("72e0c0"))
	var goals := text(list, "Goals", "【未解鎖】撐過五分鐘：單局撐過 05:00 → 天燈", 15)
	goals.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goals.custom_minimum_size.x = 400
	var back := Button.new()
	back.text = "回到街上  →"
	back.custom_minimum_size = Vector2(0, 56)
	add(body, back, "Back", true)
	save(root, "res://scenes/shop.tscn", ["res://scenes/shop_item.tscn"])

func migrate_cards() -> void:
	var card := B.instance("res://scenes/upgrade_card.tscn")
	card.definition = load("res://data/items/slipper.tres")
	card.get_node("Padding/Column/Tag").text = "新武器"
	card.get_node("Padding/Column/Title").text = "藍白拖"
	card.get_node("Padding/Column/Description").text = "丟出藍白拖，飛出去還會飛回來。"
	save(card, "res://scenes/upgrade_card.tscn", [], true)
	var panel := B.instance("res://scenes/upgrades.tscn")
	var ids: Array = ["slipper", "pearl", "firecracker"]
	for i: int in 3:
		panel.get_node("Center/Column/Options").get_child(i).definition = load("res://data/items/%s.tres" % ids[i])
	panel.get_node("Center/Column/Level").text = "LEVEL 2"
	save(panel, "res://scenes/upgrades.tscn", ["res://scenes/upgrade_card.tscn"], true)

func bar_style(color: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color)
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

func migrate_player() -> void:
	var hero := B.instance("res://scenes/player.tscn")
	var bar := ProgressBar.new()
	bar.offset_left = -22
	bar.offset_right = 22
	bar.offset_top = 14
	bar.offset_bottom = 19
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_font_size_override("font_size", 1)
	bar.add_theme_stylebox_override("background", bar_style("13202d"))
	bar.add_theme_stylebox_override("fill", bar_style("ff5a4f"))
	bar.max_value = 100
	bar.value = 100
	add(hero, bar, "HpBar", true)
	save(hero, "res://scenes/player.tscn", [], true)

func migrate_street() -> void:
	var street := B.instance("res://scenes/street.tscn")
	street.bounds = Rect2(48, 48, 1104, 1584)
	var kinds: Array[PackedScene] = [load("res://scenes/smoker.tscn"), load("res://scenes/bike.tscn"), load("res://scenes/car.tscn"), load("res://scenes/fatty.tscn")]
	street.enemy_scenes = kinds
	street.blast_scene = load("res://scenes/blast.tscn")
	street.pickup_scene = load("res://scenes/pickup.tscn")
	street.schedule = load("res://data/spawn_schedule.tres")
	street.progression = load("res://data/progression.tres")
	var block: Node2D = street.get_node("Block")
	var art: Sprite2D = block.get_node("BackgroundArt")
	for child: Node in block.get_children():
		if child != art:
			block.remove_child(child)
			child.free()
	art.position = Vector2(600, 840)
	poly(block, "Sidewalk", "576469", rect(1200, 1680))
	poly(block, "Asphalt", "26363f", rect(1128, 1608), Vector2(36, 36))
	poly(block, "CrossStreet", "2c3d47", rect(1128, 150), Vector2(36, 765))
	for i: int in 26:
		var y: float = 70.0 + i * 62.0
		if y > 730.0 and y < 950.0:
			continue
		poly(block, "CenterDash%d" % (i + 1), "647370", rect(8, 24), Vector2(596, y))
	for i: int in 17:
		var x: float = 70.0 + i * 66.0
		if x > 520.0 and x < 680.0:
			continue
		poly(block, "CrossDash%d" % (i + 1), "647370", rect(26, 8), Vector2(x, 836))
	for side: int in 2:
		for i: int in 6:
			var y: float = 742.0 if side == 0 else 930.0
			poly(block, "Crosswalk%d" % (side * 6 + i + 1), "8fa6ad", rect(18, 14), Vector2(520 + i * 28, y))
	for i: int in 7:
		for side: int in 2:
			var at := Vector2(4 if side == 0 else 1172, 120 + i * 230)
			poly(block, "Planter%d" % (i * 2 + side + 1), "2f3a3e", rect(24, 54), at)
			poly(block, "Shrub%d" % (i * 2 + side + 1), "3c6e5a", ellipse(14, 22, 14), at + Vector2(12, 27))
	for i: int in 5:
		var at := Vector2(200 + (i % 3) * 380, 300 + i * 270)
		poly(block, "Manhole%d" % (i + 1), "1c2a31", ellipse(18, 12, 16), at)
	for i: int in 8:
		poly(block, "ParkingLine%d" % (i + 1), "5d6d6b", rect(4, 60), Vector2(100 + i * 70, 1520))
	block.move_child(art, block.get_child_count() - 1)
	var pickups := Node2D.new()
	add(street, pickups, "Pickups", true)
	street.move_child(pickups, street.get_node("Enemies").get_index())
	var arsenal := Node.new()
	arsenal.set_script(load("res://scripts/arsenal.gd"))
	arsenal.flash_scene = load("res://scenes/attack_flash.tscn")
	add(street, arsenal, "Arsenal", true)
	var hero: Node2D = street.get_node("Player")
	hero.position = Vector2(600, 840)
	var enemies: Node2D = street.get_node("Enemies")
	enemies.get_node("PreviewEnemy").position = Vector2(600, 690)
	enemies.get_node("PreviewEnemy2").position = Vector2(380, 600)
	enemies.get_node("PreviewEnemy3").position = Vector2(830, 620)
	add(enemies, B.instance("res://scenes/fatty.tscn"), "PreviewEnemy4").position = Vector2(800, 1000)
	var camera: Camera2D = street.get_node("Camera")
	camera.position = Vector2(600, 840)
	camera.limit_left = 0
	camera.limit_top = -190
	camera.limit_right = 1200
	camera.limit_bottom = 1750
	save(street, "res://scenes/street.tscn", ["res://scenes/player.tscn", "res://scenes/smoker.tscn", "res://scenes/bike.tscn", "res://scenes/car.tscn", "res://scenes/fatty.tscn"], true)

func migrate_ui() -> void:
	var hud := B.instance("res://scenes/hud.tscn")
	var coins: Label = hud.get_node("SafeTop/Column/Stats/Hits")
	coins.name = "Coins"
	coins.text = "金幣  0"
	hud.get_node("SafeTop/Column/Stats/Time").text = "00:00"
	hud.get_node("SafeTop/Column/Build").text = "拳頭 1"
	save(hud, "res://scenes/hud.tscn", [], true)

	var menu := B.instance("res://scenes/menu.tscn")
	var column: Node = menu.get_node("Center/Column")
	column.get_node("Edition").text = "STREET  /  SURVIVOR"
	column.get_node("Instructions").text = "拖曳移動，武器自動攻擊\n撐過十分鐘，越打越強"
	column.get_node("Start").text = "開始  →"
	column.get_node("Note").text = "金幣可以買永久強化；達成目標解鎖新武器"
	var shop := Button.new()
	shop.text = "街頭補給站"
	shop.custom_minimum_size = Vector2(0, 50)
	add(column, shop, "OpenShop", true)
	column.move_child(shop, column.get_node("Start").get_index() + 1)
	var wallet := text(column, "Wallet", "金幣  0  ·  最佳 00:00", 17)
	wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wallet.add_theme_color_override("font_color", Color("ffc56b"))
	column.move_child(wallet, shop.get_index() + 1)
	save(menu, "res://scenes/menu.tscn", [], true)

	var results := B.instance("res://scenes/results.tscn")
	var list: Node = results.get_node("Center/Column")
	var unlocks := text(list, "Unlocks", "", 20)
	unlocks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	unlocks.add_theme_color_override("font_color", Color("ffd36b"))
	list.move_child(unlocks, list.get_node("BuildSummary").get_index() + 1)
	save(results, "res://scenes/results.tscn", [], true)
