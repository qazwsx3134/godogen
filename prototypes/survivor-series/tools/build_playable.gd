extends SceneTree
## One-time authoring: skips existing files. Never called by gameplay or tests.
const B = preload("res://addons/proto_kit/scene_builder.gd")
const INK := Color("13202d")
const GOLD := Color("ffc56b")
const TEAL := Color("72e0c0")
var failed: bool = false
var theme: Theme

func _initialize() -> void:
	build.call_deferred()

func build() -> void:
	theme = Theme.new()
	theme.default_font = load("res://assets/fonts/NotoSansTC.ttf")
	if theme.default_font == null:
		push_error("Import the project before authoring scenes: UI font is not loaded")
		quit(1)
		return
	theme.default_font_size = 20
	for style_name: String in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("263e4d") if style_name == "normal" else Color("39596a")
		style.set_corner_radius_all(14)
		style.set_border_width_all(2)
		style.border_color = TEAL if style_name == "focus" else Color("60737a")
		style.content_margin_top = 14
		style.content_margin_bottom = 14
		theme.set_stylebox(style_name, "Button", style)
	theme.set_color("font_color", "Label", Color("f7e8ce"))
	theme.set_color("font_color", "Button", Color("f7e8ce"))
	if not FileAccess.file_exists("res://data/ui_theme.tres"):
		ResourceSaver.save(theme, "res://data/ui_theme.tres")
	theme = load("res://data/ui_theme.tres")
	actor("player")
	for kind: String in ["smoker", "bike", "car"]:
		actor(kind)
	smoke()
	impact()
	joystick()
	menu_screen()
	hud_screen()
	result_screen()
	pause_screen()
	street()
	game()
	quit(1 if failed else 0)

func save(root_node: Node, path: String, refs: Array = []) -> void:
	var result: Dictionary = B.save_scene(root_node, path, {"expected_refs": refs})
	if not result.ok:
		failed = true

func add(parent: Node, child: Node, node_name: String, unique: bool = false) -> Node:
	return B.add(parent, B.unique(child) if unique else child, node_name)

func poly(parent: Node, node_name: String, points: Array, color: Color, at: Vector2 = Vector2.ZERO) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array(points)
	p.color = color
	p.position = at
	add(parent, p, node_name)
	return p

func rect(parent: Node, node_name: String, at: Vector2, dimensions: Vector2, color: Color) -> Polygon2D:
	return poly(parent, node_name, [Vector2.ZERO, Vector2(dimensions.x, 0), dimensions, Vector2(0, dimensions.y)], color, at)

func oval(parent: Node, node_name: String, at: Vector2, radius: Vector2, color: Color) -> Polygon2D:
	var points: Array = []
	for i: int in 24:
		points.append(Vector2(cos(i * TAU / 24.0), sin(i * TAU / 24.0)) * radius)
	return poly(parent, node_name, points, color, at)

func actor(kind: String) -> void:
	var root_actor: Node2D = CharacterBody2D.new() if kind == "player" else Node2D.new()
	root_actor.name = kind.capitalize()
	root_actor.set_script(load("res://scripts/player.gd" if kind == "player" else "res://scripts/enemy.gd"))
	var shadow := oval(root_actor, "Shadow", Vector2(0, 6), Vector2(22, 9) if kind in ["player", "smoker"] else Vector2(35, 14), Color(0.0, 0.0, 0.0, 0.3))
	B.unique(shadow)
	var visual := Node2D.new()
	add(root_actor, visual, "Visual", true)
	var placeholder := Node2D.new()
	add(visual, placeholder, "Placeholder")
	if kind in ["player", "smoker"]:
		var coat: Color = TEAL if kind == "player" else Color("c08ed0")
		rect(placeholder, "LegLeft", Vector2(-13, -14), Vector2(10, 19), INK)
		rect(placeholder, "LegRight", Vector2(3, -14), Vector2(10, 19), INK)
		oval(placeholder, "ShoeLeft", Vector2(-9, 5), Vector2(9, 5), GOLD)
		oval(placeholder, "ShoeRight", Vector2(10, 5), Vector2(9, 5), GOLD)
		poly(placeholder, "JacketOutline", [Vector2(-23,-38), Vector2(18,-38), Vector2(23,-9), Vector2(-20,-9)], INK)
		poly(placeholder, "Jacket", [Vector2(-19,-35), Vector2(15,-35), Vector2(19,-12), Vector2(-16,-12)], coat)
		oval(placeholder, "HeadOutline", Vector2(0,-45), Vector2(17,18), INK)
		oval(placeholder, "Face", Vector2(0,-43), Vector2(13,14), Color("f7cfa0"))
		poly(placeholder, "Hair", [Vector2(-14,-50), Vector2(-10,-61), Vector2(9,-60), Vector2(15,-51), Vector2(0,-55)], INK)
		rect(placeholder, "EyeLeft", Vector2(-7,-47), Vector2(3,3), INK)
		rect(placeholder, "EyeRight", Vector2(5,-47), Vector2(3,3), INK)
		var fist := Node2D.new()
		add(placeholder, fist, "Fist", kind == "player")
		oval(fist, "KnuckleOutline", Vector2(20,-29), Vector2(13,11), INK)
		oval(fist, "Knuckle", Vector2(20,-29), Vector2(9,7), Color("f7cfa0"))
		if kind == "smoker":
			rect(fist, "Cigarette", Vector2(27,-35), Vector2(13,4), Color("eeeecc"))
			rect(fist, "Ember", Vector2(39,-35), Vector2(3,4), Color("ff7855"))
	elif kind == "bike":
		oval(placeholder, "WheelFront", Vector2(16,2), Vector2(12,16), INK)
		oval(placeholder, "WheelBack", Vector2(-18,-14), Vector2(11,15), INK)
		poly(placeholder, "Scooter", [Vector2(-26,-31), Vector2(8,-36), Vector2(31,-7), Vector2(16,5), Vector2(-15,-10)], Color("ff7855"))
		rect(placeholder, "Seat", Vector2(-17,-33), Vector2(24,10), INK)
		oval(placeholder, "Rider", Vector2(-5,-34), Vector2(14,20), Color("344458"))
		oval(placeholder, "Helmet", Vector2(-5,-55), Vector2(16,15), Color("f8e5bb"))
		rect(placeholder, "Visor", Vector2(-14,-56), Vector2(19,6), INK)
		rect(placeholder, "Headlight", Vector2(14,-13), Vector2(12,7), GOLD)
	else:
		for at: Vector2 in [Vector2(-37,-6), Vector2(31,-6), Vector2(-37,-39), Vector2(31,-39)]:
			rect(placeholder, "Wheel", at, Vector2(12,23), INK)
		poly(placeholder, "CarOutline", [Vector2(-43,-47),Vector2(22,-60),Vector2(48,-7),Vector2(37,22),Vector2(-26,24),Vector2(-45,4)], INK)
		poly(placeholder, "Body", [Vector2(-39,-44),Vector2(20,-55),Vector2(44,-5),Vector2(34,18),Vector2(-24,20),Vector2(-40,2)], Color("eab153"))
		poly(placeholder, "Windshield", [Vector2(-24,-31),Vector2(12,-37),Vector2(25,-13),Vector2(-17,-8)], Color("496b80"))
		oval(placeholder, "Driver", Vector2(4,-22), Vector2(7,8), Color("f7cfa0"))
		rect(placeholder, "Bumper", Vector2(-26,11), Vector2(59,6), Color("efe2b6"))
		rect(placeholder, "LightLeft", Vector2(-28,3), Vector2(13,5), Color("fff0b0"))
		rect(placeholder, "LightRight", Vector2(21,0), Vector2(13,5), Color("fff0b0"))
	var image := Sprite2D.new()
	image.position = Vector2(0,-25)
	image.scale = Vector2.ONE * (0.14 if kind == "car" else 0.1)
	image.visible = false
	add(visual, image, "Art")
	if kind == "player":
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 14
		shape.shape = circle
		add(root_actor, shape, "Collision")
	else:
		var data: Resource = load("res://scripts/enemy_def.gd").new()
		data.kind = kind
		if kind == "bike":
			data.max_hp = 102.0
			data.speed = 70.0
			data.radius = 24.0
			data.weight = 2.0
		elif kind == "car":
			data.max_hp = 170.0
			data.speed = 30.0
			data.radius = 40.0
			data.weight = 6.0
		var data_path: String = "res://data/%s.tres" % kind
		if not FileAccess.file_exists(data_path):
			ResourceSaver.save(data, data_path)
		root_actor.definition = load(data_path)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.add_theme_font_size_override("font_size",1)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fill := StyleBoxFlat.new()
		fill.bg_color = GOLD
		fill.content_margin_top = 0
		fill.content_margin_bottom = 0
		bar.add_theme_stylebox_override("fill", fill)
		var background := StyleBoxFlat.new()
		background.bg_color = INK
		background.content_margin_top = 0
		background.content_margin_bottom = 0
		bar.add_theme_stylebox_override("background", background)
		bar.position = Vector2(-22,-80)
		bar.size = Vector2(44,5)
		add(root_actor, bar, "HpBar", true)
		var warn := Node2D.new()
		add(root_actor, warn, "Warning", true)
		for entry: Array in [["WarningLane",36.0,Color(1,0.35,0.2,0.16)],["WarningLine",3.0,Color(1,0.55,0.2,0.8)]]:
			var line := Line2D.new()
			line.points = PackedVector2Array([Vector2.ZERO,Vector2(0,150)])
			line.width = entry[1]
			line.default_color = entry[2]
			add(warn, line, entry[0], true)
		warn.visible = false
	save(root_actor,"res://scenes/%s.tscn" % kind)

func smoke() -> void:
	var cloud := Node2D.new()
	cloud.name = "Smoke"
	cloud.set_script(load("res://scripts/smoke.gd"))
	oval(cloud,"DangerZone",Vector2.ZERO,Vector2(44,32),Color(0.55,0.4,0.75,0.25))
	for i: int in 5:
		oval(cloud,"Puff",Vector2((i-2)*13,-12-(i%2)*14),Vector2(22,17),Color(0.65,0.6,0.72,0.45))
	save(cloud,"res://scenes/smoke.tscn")

func impact() -> void:
	var fx := Node2D.new()
	fx.name = "Impact"
	fx.set_script(load("res://scripts/impact.gd"))
	var burst := Node2D.new()
	add(fx,burst,"Burst",true)
	var points: Array = []
	for i: int in 16:
		points.append(Vector2(cos(i*TAU/16),sin(i*TAU/16)) * (28.0 if i%2==0 else 11.0))
	poly(burst,"Star",points,GOLD)
	var streak := Line2D.new()
	streak.points = PackedVector2Array([Vector2(-120,0),Vector2(22,0)])
	streak.width = 8
	streak.default_color = Color(1,0.88,0.6,0.7)
	add(fx,streak,"Streak",true)
	var caption := Label.new()
	caption.theme = theme
	caption.text = "飛出去！"
	caption.position = Vector2(-32,-58)
	caption.add_theme_font_size_override("font_size",22)
	caption.add_theme_color_override("font_outline_color",INK)
	caption.add_theme_constant_override("outline_size",6)
	add(fx,caption,"Caption",true)
	save(fx,"res://scenes/impact.tscn")

func joystick() -> void:
	var stick := Control.new()
	stick.name = "Stick"
	stick.set_script(load("res://addons/proto_kit/floating_stick.gd"))
	stick.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stick.offset_top = 170
	stick.offset_bottom = -56
	stick.radius = 74.0
	stick.knob_travel = 30.0
	for entry: Array in [["Base",Vector2(110,110),Color(0.3,0.9,0.75,0.16)],["Knob",Vector2(44,44),Color(0.5,1,0.85,0.6)]]:
		var panel := Panel.new()
		panel.size = entry[1]
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = entry[2]
		style.set_corner_radius_all(60)
		style.set_border_width_all(2)
		style.border_color = TEAL
		panel.add_theme_stylebox_override("panel",style)
		add(stick if entry[0]=="Base" else stick.get_node("Base"),panel,entry[0],true)
	stick.get_node("Base/Knob").position = Vector2(33,33)
	save(stick,"res://scenes/joystick.tscn")

func screen(node_name: String) -> Control:
	var root_control := Control.new()
	root_control.name = node_name
	root_control.theme = theme
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return root_control

func centered_column(root_control: Control) -> VBoxContainer:
	var shade := ColorRect.new()
	shade.color = Color(0.035,0.075,0.1,0.96)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add(root_control,shade,"Shade")
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add(root_control,center,"Center")
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 420
	column.add_theme_constant_override("separation",22)
	add(center,column,"Column")
	return column

func label(parent: Node, node_name: String, content: String, font_size: int, color: Color = Color("f7e8ce")) -> Label:
	var item := Label.new()
	item.text = content
	item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item.add_theme_font_size_override("font_size",font_size)
	item.add_theme_color_override("font_color",color)
	add(parent,item,node_name,true)
	return item

func button(parent: Node, node_name: String, content: String) -> void:
	var item := Button.new()
	item.text = content
	item.custom_minimum_size = Vector2(60,56)
	add(parent,item,node_name,true)

func menu_screen() -> void:
	var root_control := screen("Menu")
	var column := centered_column(root_control)
	label(column,"Edition","STREET  /  IMPACT LAB",15,TEAL)
	label(column,"Title","行人反擊",52)
	label(column,"Subtitle","把不講理的傢伙，揍出畫面。",20,GOLD)
	label(column,"Instructions","拖曳螢幕移動，靠近敵人自動揮拳\n躲煙霧、閃機車，挑戰 90 秒",18)
	button(column,"Start","開始測試  →")
	label(column,"Note","本測試場不會死亡，受擊會記次",15,Color("8fa6ad"))
	save(root_control,"res://scenes/menu.tscn")

func hud_screen() -> void:
	var root_control := screen("Hud")
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	margin.add_theme_constant_override("margin_top",42)
	margin.add_theme_constant_override("margin_left",26)
	margin.add_theme_constant_override("margin_right",26)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add(root_control,margin,"SafeTop")
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation",8)
	add(margin,column,"Column")
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation",18)
	add(column,row,"Stats")
	label(row,"Time","90 秒",24,GOLD)
	label(row,"Kills","揍飛  0",18)
	label(row,"Hits","受擊  0",18)
	var filler := Control.new()
	filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add(row,filler,"Spacer")
	button(row,"Pause","Ⅱ")
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = 5
	bar.show_percentage = false
	bar.value = 90
	bar.max_value = 90
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = TEAL
	bar.add_theme_stylebox_override("fill",fill)
	add(column,bar,"TimeBar",true)
	var toggle := CheckButton.new()
	toggle.text = "震屏"
	toggle.size_flags_horizontal = Control.SIZE_SHRINK_END
	toggle.button_pressed = true
	toggle.add_theme_font_size_override("font_size",14)
	add(column,toggle,"ShakeToggle",true)
	var hint := Label.new()
	hint.text = "按住拖曳移動  ·  靠近自動揮拳"
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -54
	hint.offset_bottom = -24
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size",16)
	hint.add_theme_color_override("font_color",Color("8fa6ad"))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add(root_control,hint,"Hint")
	save(root_control,"res://scenes/hud.tscn")

func result_screen() -> void:
	var root_control := screen("Results")
	var column := centered_column(root_control)
	label(column,"Edition","90 秒  /  測試完成",16,TEAL)
	label(column,"Title","打得夠爽嗎？",38)
	label(column,"ResultStats","揍飛 0 個敵人\n受擊 0 次\n出拳 0 次",24,GOLD)
	button(column,"Retry","再揍一次  →")
	button(column,"Home","回到入口")
	save(root_control,"res://scenes/results.tscn")

func pause_screen() -> void:
	var root_control := screen("PausePanel")
	var column := centered_column(root_control)
	label(column,"Title","休息一下",38)
	label(column,"Note","已暫停，時間與敵人都會等你。",18)
	button(column,"Resume","繼續揮拳  →")
	save(root_control,"res://scenes/pause.tscn")

func street() -> void:
	var arena := Node2D.new()
	arena.name = "Street"
	arena.process_mode = Node.PROCESS_MODE_PAUSABLE
	arena.set_script(load("res://scripts/street.gd"))
	var scenes: Array[PackedScene] = []
	for kind: String in ["smoker","bike","car"]:
		scenes.append(load("res://scenes/%s.tscn" % kind))
	arena.enemy_scenes = scenes
	arena.smoke_scene = load("res://scenes/smoke.tscn")
	arena.impact_scene = load("res://scenes/impact.tscn")
	var back := Node2D.new()
	back.z_index = -10
	add(arena,back,"Block")
	rect(back,"Sidewalk",Vector2(15,146),Vector2(510,702),Color("57646a"))
	rect(back,"Asphalt",Vector2(38,169),Vector2(464,650),Color("263641"))
	for y: int in range(210,810,54):
		rect(back,"CenterDash",Vector2(266,y),Vector2(8,22),Color("647370"))
	for x: int in range(64,468,48):
		rect(back,"Crosswalk",Vector2(x,766),Vector2(28,26),Color("94a19a"))
	for y: int in [205,355,505,655]:
		for x: int in [8,509]:
			rect(back,"Planter",Vector2(x,y),Vector2(23,42),INK)
			oval(back,"Shrub",Vector2(x+11,y+15),Vector2(15,22),Color("46685c"))
	var background := Sprite2D.new()
	background.position = Vector2(270,480)
	background.visible = false
	add(back,background,"BackgroundArt")
	add(arena,Node2D.new(),"Hazards",true)
	var enemies := Node2D.new()
	enemies.y_sort_enabled = true
	add(arena,enemies,"Enemies",true)
	for i: int in 3:
		var example := B.instance("res://scenes/%s.tscn" % ["smoker","bike","car"][i]) as Node2D
		example.position = [Vector2(210,570),Vector2(110,290),Vector2(420,350)][i]
		add(enemies,example,"PreviewEnemy")
	var player := B.instance("res://scenes/player.tscn") as CharacterBody2D
	player.position = Vector2(270,650)
	player.z_index = 1
	add(arena,player,"Player",true)
	var effects := Node2D.new()
	effects.z_index = 8
	add(arena,effects,"Effects",true)
	var camera := Camera2D.new()
	camera.position = Vector2(270,480)
	camera.ignore_rotation = false
	add(arena,camera,"Camera",true)
	save(arena,"res://scenes/street.tscn",["res://scenes/player.tscn","res://scenes/smoker.tscn","res://scenes/bike.tscn","res://scenes/car.tscn"])

func game() -> void:
	var main := Node.new()
	main.name = "StreetImpact"
	main.process_mode = Node.PROCESS_MODE_ALWAYS
	main.set_script(load("res://scripts/game.gd"))
	var street_instance := B.instance("res://scenes/street.tscn") as Node2D
	street_instance.visible = false
	add(main,street_instance,"Street",true)
	var services := Node.new()
	add(main,services,"Services")
	var time_control := Node.new()
	time_control.set_script(load("res://addons/proto_kit/time_control.gd"))
	add(services,time_control,"TimeControl",true)
	var sfx := Node.new()
	sfx.set_script(load("res://scripts/sfx.gd"))
	add(services,sfx,"Sfx",true)
	var music := Node.new()
	music.set_script(load("res://addons/proto_kit/music.gd"))
	add(services,music,"Music")
	add(music,AudioStreamPlayer.new(),"VoiceA")
	add(music,AudioStreamPlayer.new(),"VoiceB")
	var layer := CanvasLayer.new()
	add(main,layer,"Interface")
	var refs: Array = ["res://scenes/street.tscn"]
	for entry: Array in [["joystick","Stick"],["hud","Hud"],["menu","Menu"],["results","Results"],["pause","PausePanel"]]:
		var path: String = "res://scenes/%s.tscn" % entry[0]
		var screen_instance := B.instance(path) as Control
		screen_instance.visible = entry[1] == "Menu"
		add(layer,screen_instance,entry[1],true)
		refs.append(path)
	save(main,"res://scenes/game.tscn",refs)
