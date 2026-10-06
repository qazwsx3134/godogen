extends SceneTree
## Applied 2026-10-07. One-time, additive authoring migration; never run by the game.
const B = preload("res://addons/proto_kit/scene_builder.gd")
var theme: Theme
var failed: bool = false
func _initialize() -> void:
	build.call_deferred()
func save(node: Node, path: String, refs: Array = [], overwrite: bool = false) -> void:
	node.scene_file_path = ""
	var result: Dictionary = B.save_scene(node,path,{"overwrite":overwrite,"expected_refs":refs})
	failed = failed or not result.ok
func add(parent: Node, child: Node, node_name: String, unique: bool = false) -> Node:
	return B.add(parent,B.unique(child) if unique else child,node_name)
func text(parent: Node, node_name: String, content: String, font_size: int) -> Label:
	var node := Label.new()
	node.text = content
	node.add_theme_font_size_override("font_size",font_size)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add(parent,node,node_name,true)
	return node
func build() -> void:
	var main := B.instance("res://scenes/game.tscn")
	if main.get_meta("progression_scene_version",0) >= 1:
		main.free()
		print("skip: progression already authored; edit scenes directly")
		quit()
		return
	main.free()
	theme = load("res://data/ui_theme.tres")
	resources()
	card()
	panel()
	wave()
	flash()
	migrate_player()
	migrate_street()
	migrate_ui()
	if failed:
		quit(1)
		return
	main = B.instance("res://scenes/game.tscn")
	var panel_node := B.instance("res://scenes/upgrades.tscn") as Control
	panel_node.visible = false
	add(main.get_node("Interface"),panel_node,"UpgradePanel",true)
	main.set_meta("progression_scene_version",1)
	save(main,"res://scenes/game.tscn",["res://scenes/street.tscn","res://scenes/upgrades.tscn"],true)
	quit(1 if failed else 0)
func resources() -> void:
	DirAccess.make_dir_recursive_absolute("res://data/upgrades")
	var entries: Array = [
		["wave","衝擊波","每兩拳發射一道穿透衝擊波，揍到遠處的敵人。","新招式",1,"",0.75],
		["kick","回旋踢","每四拳追加回旋踢，掃開身邊一圈敵人。","新招式",1,"",0.7],
		["sweep","橫掃拳","每拳多打中一個前方敵人，最多同時三個。","攻擊模式",2,"",1.0],
		["power","拳力加重","拳擊與招式傷害增加 25%。","拳力",4,"",0.25],
		["speed","快拳連打","出拳速度增加 18%，移動也能連續揮拳。","攻速",4,"",0.18],
		["reach","長臂反擊","拳擊範圍增加 18，能先把靠近的敵人揍開。","範圍",4,"",18.0],
		["force","強力擊退","普通擊退增加 35%，汽車仍比行人更重。","擊退",3,"",0.35],
		["heavy","蓄力重拳","每第三拳打出 180% 傷害，拳頭更大、推力更強。","攻擊模式",1,"",1.8],
		["wave_power","巨浪衝擊","衝擊波更寬，額外增加相當於拳力 35% 的傷害。","招式強化",3,"wave",0.35],
		["kick_power","旋風踢擊","回旋踢範圍增加 22，傷害也隨層數提高。","招式強化",3,"kick",22.0]
	]
	var catalogue: Array[Resource] = []
	for entry: Array in entries:
		var path: String = "res://data/upgrades/%s.tres" % entry[0]
		if not FileAccess.file_exists(path):
			var item: Resource = load("res://scripts/upgrade_def.gd").new()
			item.id = StringName(entry[0])
			item.title = entry[1]
			item.description = entry[2]
			item.category = entry[3]
			item.max_stacks = entry[4]
			item.prerequisite = StringName(entry[5])
			item.value = entry[6]
			item.accent = Color("ffc56b") if entry[0] in ["kick","power","heavy","force"] else Color("72e0c0")
			failed = failed or ResourceSaver.save(item,path) != OK
		catalogue.append(load(path))
	if not FileAccess.file_exists("res://data/progression.tres"):
		var config: Resource = load("res://scripts/progression_def.gd").new()
		config.upgrades = catalogue
		failed = failed or ResourceSaver.save(config,"res://data/progression.tres") != OK
	for entry: Array in [["smoker",1],["bike",2],["car",3]]:
		var path: String = "res://data/%s.tres" % entry[0]
		var data: Resource = load(path)
		data.experience = entry[1]
		failed = failed or ResourceSaver.save(data,path) != OK
func card() -> void:
	var root_card := Button.new()
	root_card.name = "UpgradeCard"
	root_card.theme = theme
	root_card.custom_minimum_size = Vector2(420,118)
	root_card.set_script(load("res://scripts/upgrade_card.gd"))
	root_card.definition = load("res://data/upgrades/power.tres")
	var stripe := ColorRect.new()
	stripe.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	stripe.offset_right = 4
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stripe.color = Color("72e0c0")
	add(root_card,stripe,"Stripe",true)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left","right"]:
		margin.add_theme_constant_override("margin_"+side,20)
	for side: String in ["top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,12)
	add(root_card,margin,"Padding")
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation",5)
	add(margin,column,"Column")
	text(column,"Tag","拳力  ·  1 / 4",13).add_theme_color_override("font_color",Color("72e0c0"))
	text(column,"Title","拳力加重",24)
	var body := text(column,"Description","拳擊與招式傷害增加 25%。",17)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = 365
	save(root_card,"res://scenes/upgrade_card.tscn")
func panel() -> void:
	var root_panel := Control.new()
	root_panel.name = "UpgradePanel"
	root_panel.theme = theme
	root_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_panel.set_script(load("res://scripts/upgrade_panel.gd"))
	root_panel.card_scene = load("res://scenes/upgrade_card.tscn")
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.03,0.06,0.08,0.96)
	add(root_panel,shade,"Shade")
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add(root_panel,center,"Center")
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 420
	column.add_theme_constant_override("separation",16)
	add(center,column,"Column")
	text(column,"Level","LEVEL 2  /  揍飛成長",16).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text(column,"Title","升級！選一招",34).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var options := VBoxContainer.new()
	options.add_theme_constant_override("separation",12)
	add(column,options,"Options",true)
	for id: String in ["wave","kick","sweep"]:
		var item := B.instance("res://scenes/upgrade_card.tscn")
		item.definition = load("res://data/upgrades/%s.tres" % id)
		add(options,item,"Choice")
	text(column,"Note","戰鬥已暫停，選好再繼續揍。",16).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	save(root_panel,"res://scenes/upgrades.tscn",["res://scenes/upgrade_card.tscn"])
func line(parent: Node, node_name: String, points: Array, color: Color, width: float) -> void:
	var node := Line2D.new()
	node.points = PackedVector2Array(points)
	node.default_color = color
	node.width = width
	node.begin_cap_mode = Line2D.LINE_CAP_ROUND
	node.end_cap_mode = Line2D.LINE_CAP_ROUND
	add(parent,node,node_name,true)
func wave() -> void:
	var root_wave := Node2D.new()
	root_wave.name = "Shockwave"
	root_wave.set_script(load("res://scripts/wave.gd"))
	var visual := Node2D.new()
	visual.position.y = -20
	add(root_wave,visual,"Visual",true)
	line(visual,"Crest",[Vector2(-10,-26),Vector2(3,-14),Vector2(10,0),Vector2(3,14),Vector2(-10,26)],Color("72e0c0"),7)
	line(visual,"Trail",[Vector2(-48,-12),Vector2(-12,0),Vector2(-48,12)],Color(0.45,0.9,0.8,0.4),4)
	save(root_wave,"res://scenes/wave.tscn")
func flash() -> void:
	var root_flash := Node2D.new()
	root_flash.name = "AttackFlash"
	root_flash.set_script(load("res://scripts/attack_flash.gd"))
	var arc: Array = []
	var ring: Array = []
	for i: int in 21:
		var angle: float = lerpf(-PI/3,PI/3,i/20.0)
		arc.append(Vector2(cos(angle),sin(angle)) * 100)
	for i: int in 33:
		var angle: float = TAU * i/32.0
		ring.append(Vector2(cos(angle),sin(angle)) * 100)
	line(root_flash,"Arc",arc,Color(0.45,0.9,0.8,0.55),5)
	line(root_flash,"Ring",ring,Color("ffc56b"),8)
	root_flash.get_node("Ring").visible = false
	save(root_flash,"res://scenes/attack_flash.tscn")
func migrate_player() -> void:
	var player := B.instance("res://scenes/player.tscn")
	if not player.has_node("Motion"):
		var motion := Node2D.new()
		add(player,motion,"Motion",true)
		player.get_node("Visual").owner = null
		player.get_node("Visual").reparent(motion,false)
	save(player,"res://scenes/player.tscn",[],true)
func migrate_street() -> void:
	var street := B.instance("res://scenes/street.tscn")
	street.progression = load("res://data/progression.tres")
	street.wave_scene = load("res://scenes/wave.tscn")
	street.attack_flash_scene = load("res://scenes/attack_flash.tscn")
	if not street.has_node("Projectiles"):
		var holder := Node2D.new()
		holder.z_index = 4
		add(street,holder,"Projectiles",true)
	save(street,"res://scenes/street.tscn",["res://scenes/player.tscn","res://scenes/smoker.tscn","res://scenes/bike.tscn","res://scenes/car.tscn"],true)
func migrate_ui() -> void:
	var hud := B.instance("res://scenes/hud.tscn")
	var column := hud.get_node("SafeTop/Column")
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation",12)
	add(column,row,"Growth")
	text(row,"Level","Lv.1",16).add_theme_color_override("font_color",Color("72e0c0"))
	var xp := ProgressBar.new()
	xp.show_percentage = false
	xp.add_theme_font_size_override("font_size",1)
	for name: String in ["background","fill"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("ffc56b") if name == "fill" else Color("23313c")
		style.content_margin_top = 0
		style.content_margin_bottom = 0
		xp.add_theme_stylebox_override(name,style)
	xp.custom_minimum_size.y = 6
	xp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	xp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp.max_value = 5
	add(row,xp,"Experience",true)
	var toggle := column.get_node("ShakeToggle")
	toggle.owner = null
	toggle.reparent(row,false)
	var build_summary := text(column,"Build","基礎拳擊",13)
	build_summary.add_theme_color_override("font_color",Color("8fa6ad"))
	build_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	build_summary.max_lines_visible = 2
	var combo := text(hud,"Combo","",24)
	combo.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	combo.offset_top = -106
	combo.offset_bottom = -69
	combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo.add_theme_color_override("font_color",Color("ffc56b"))
	save(hud,"res://scenes/hud.tscn",[],true)
	var results := B.instance("res://scenes/results.tscn")
	var result_column := results.get_node("Center/Column")
	var summary := text(result_column,"BuildSummary","基礎拳擊",16)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.custom_minimum_size.x = 420
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_column.move_child(summary,3)
	save(results,"res://scenes/results.tscn",[],true)
	var menu := B.instance("res://scenes/menu.tscn")
	menu.get_node("Center/Column/Instructions").text = "拖曳移動，自動出拳\n揍飛升級，選招式越打越強"
	save(menu,"res://scenes/menu.tscn",[],true)
