extends SceneTree
## One-off scene builder. Saved scenes are the source of truth afterwards: this only writes scenes that do not exist
## yet, so edits made in the editor survive. To rebuild one on purpose, check its diff first, then
##   godot --headless --path . --script res://tools/build_scenes.gd -- --force=title,result

const INK := Color(0.16, 0.15, 0.24)
const CREAM := Color(0.98, 0.93, 0.84)

var _force: PackedStringArray = []


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--force="):
			_force = a.trim_prefix("--force=").split(",")
	_save("actor", _actor)
	_save("skewer", _skewer)
	_save("stage", _stage)
	_save("hud", _hud)
	_save("three_eat", _three_eat)
	_save("toss_game", _toss_game)
	_save("title", _title)
	_save("story", _story)
	_save("result", _result)
	_save("calibrate", _calibrate)
	_save("main", _main)
	quit()


func _save(name: String, build: Callable) -> void:
	var path := "res://scenes/%s.tscn" % name
	if ResourceLoader.exists(path) and not name in _force:
		print("keep  ", path)
		return
	var root: Node = build.call()
	_own(root, root)
	var count := _count(root)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, path)
	var back := (load(path) as PackedScene).instantiate() if err == OK else null
	if err != OK or back == null or _count(back) != count:
		push_error("could not save %s (err %d)" % [path, err])
	else:
		print("wrote ", path, " (", count, " nodes)")
	root.free()
	if back:
		back.free()


## Every descendant belongs to root, except the insides of instanced sub-scenes (they stay theirs).
func _own(node: Node, root: Node) -> void:
	for c in node.get_children():
		c.owner = root
		if c.scene_file_path.is_empty():
			_own(c, root)


func _count(node: Node) -> int:
	var n := 1
	for c in node.get_children():
		n += _count(c)
	return n


func _add(parent: Node, child: Node, name: String, unique := false) -> Node:
	child.name = name
	parent.add_child(child)
	if unique:
		child.unique_name_in_owner = true
	return child


func _rect(parent: Node, name: String, pos: Vector2, size: Vector2, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = pos
	r.size = size
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return _add(parent, r, name)


func _label(parent: Node, name: String, text: String, size: int, unique := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return _add(parent, l, name, unique)


func _button(parent: Node, name: String, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(150, 44)
	b.add_theme_font_size_override("font_size", 20)
	return _add(parent, b, name, true)


## A full-screen Control with a cream background and a centred column; returns [root, column].
func _screen(name: String, script: String, separation := 10) -> Array:
	var root := Control.new()
	root.name = name
	root.set_script(load(script))
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.color = CREAM
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(root, bg, "Background")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(root, center, "Center")
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", separation)
	_add(center, column, "Column")
	return [root, column]


func _actor() -> Node:
	var root := Node2D.new()
	root.name = "Actor"
	root.set_script(load("res://scripts/actor.gd"))
	_rect(root, "Body", Vector2(-40, -140), Vector2(80, 140), Color(0.3, 0.4, 0.7))
	_rect(root, "Head", Vector2(-30, -196), Vector2(60, 58), Color(0.98, 0.86, 0.74))
	var name_label := _label(root, "NameLabel", "角色", 16)
	name_label.position = Vector2(-50, 4)
	name_label.size = Vector2(100, 24)
	var hand := Marker2D.new()
	hand.position = Vector2(46, -100)
	_add(root, hand, "Hand")
	var mouth := Marker2D.new()
	mouth.position = Vector2(-18, -158)
	_add(root, mouth, "Mouth")
	var sweat := _rect(root, "Sweat", Vector2(32, -200), Vector2(6, 12), Color(0.45, 0.75, 1.0))
	sweat.visible = false
	return root


func _skewer() -> Node:
	var root := Node2D.new()
	root.name = "Skewer"
	root.set_script(load("res://scripts/skewer.gd"))
	return root


func _stage() -> Node:
	var root := Node2D.new()
	root.name = "Stage"
	root.set_script(load("res://scripts/stage.gd"))
	_rect(root, "Background", Vector2(-320, -60), Vector2(1280, 480), Color(0.96, 0.86, 0.7))
	var crowd := Node2D.new()
	crowd.set_script(load("res://scripts/crowd.gd"))
	crowd.position = Vector2(320, 236)
	crowd.width = 1100.0
	_add(root, crowd, "Crowd", true)
	var curtain := _rect(root, "Curtain", Vector2(-320, -60), Vector2(1280, 100), Color(0.74, 0.2, 0.25))
	curtain.unique_name_in_owner = true
	var lanterns := Node2D.new()
	lanterns.set_script(load("res://scripts/lanterns.gd"))
	lanterns.position = Vector2(320, 40)
	lanterns.width = 1100.0
	lanterns.count = 11
	_add(root, lanterns, "Lanterns", true)
	var banner := _label(root, "Banner", "丸子大胃王大賽", 22)
	banner.add_theme_color_override("font_color", CREAM)
	banner.position = Vector2(170, 4)
	banner.size = Vector2(300, 32)
	var speed := Node2D.new()
	speed.set_script(load("res://scripts/speed_lines.gd"))
	speed.position = Vector2(507, 150)
	speed.visible = false
	_add(root, speed, "SpeedLines", true)
	_rect(root, "BackTable", Vector2(150, 236), Vector2(170, 10), Color(0.45, 0.28, 0.18))
	var actor := load("res://scenes/actor.tscn") as PackedScene
	for c in [["RivalA", "對手", Vector2(180, 238), Color(0.42, 0.38, 0.55), 0.5],
			["RivalB", "對手", Vector2(240, 238), Color(0.42, 0.38, 0.55), 0.5],
			["Referee", "裁判", Vector2(400, 250), Color(0.18, 0.18, 0.2), 0.62]]:
		var a := actor.instantiate()
		a.position = c[2]
		a.scale = Vector2(c[4], c[4])
		_add(root, a, c[0], true)
		a.display_name = c[1]
		a.body_color = c[3]
	var plates := Node2D.new()
	plates.set_script(load("res://scripts/plate_stack.gd"))
	plates.position = Vector2(210, 236)
	_add(root, plates, "RivalPlates", true)
	_rect(root, "Table", Vector2(-320, 282), Vector2(1280, 140), Color(0.55, 0.36, 0.22))
	return root


func _hud() -> Node:
	var root := CanvasLayer.new()
	root.name = "HUD"
	root.set_script(load("res://scripts/hud.gd"))
	var judge := _label(root, "JudgeLabel", "", 34, true)
	judge.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	judge.offset_left = -160
	judge.offset_right = 160
	judge.offset_top = 48
	judge.offset_bottom = 96
	var call := _label(root, "CallLabel", "", 28, true)
	call.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	call.offset_left = -160
	call.offset_right = 160
	call.offset_top = 96
	call.offset_bottom = 136
	call.add_theme_color_override("font_color", Color(0.8, 0.12, 0.15))
	var round_label := _label(root, "RoundLabel", "", 13, true)
	round_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	round_label.offset_left = 10
	round_label.offset_top = 8
	round_label.offset_right = 200
	round_label.offset_bottom = 28
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	round_label.add_theme_color_override("font_color", CREAM)
	var score := _label(root, "Scoreboard", "", 13, true)
	score.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	score.offset_left = -250
	score.offset_top = 8
	score.offset_right = -10
	score.offset_bottom = 28
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score.add_theme_color_override("font_color", CREAM)
	var hint := _label(root, "Hint", "", 14, true)
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_left = -310
	hint.offset_right = 310
	hint.offset_top = -30
	hint.offset_bottom = -8
	hint.add_theme_color_override("font_color", CREAM)
	return root


## A round scene: the shared stage and HUD, the three of them at the front table, the skewer pile and sounds.
func _round(name: String, script: String, chart: String, hint: String) -> Node:
	var root := Node2D.new()
	root.name = name
	root.set_script(load(script))
	root.chart_path = chart
	var conductor := Node.new()
	conductor.set_script(load("res://scripts/conductor.gd"))
	_add(root, conductor, "Conductor", true)
	var camera := Camera2D.new()
	camera.position = Vector2(320, 180)
	_add(root, camera, "Camera", true)
	_add(root, (load("res://scenes/stage.tscn") as PackedScene).instantiate(), "Stage", true)
	var actor := load("res://scenes/actor.tscn") as PackedScene
	for c in [["Gintoki", "銀時", Vector2(110, 290), Color(0.86, 0.89, 0.96), 1.0],
			["Shinpachi", "新八", Vector2(300, 300), Color(0.55, 0.7, 0.92), 0.8],
			["Kagura", "神樂", Vector2(525, 290), Color(0.88, 0.24, 0.3), 0.95]]:
		var a := actor.instantiate()
		a.position = c[2]
		a.scale = Vector2(c[4], c[4])
		_add(root, a, c[0], true)
		a.display_name = c[1]
		a.body_color = c[3]
	var pile := Node2D.new()
	pile.set_script(load("res://scripts/plate_stack.gd"))
	pile.sticks = true
	pile.position = Vector2(588, 300)
	_add(root, pile, "SkewerPile", true)
	_add(root, Node2D.new(), "Skewers", true)
	var hud := (load("res://scenes/hud.tscn") as PackedScene).instantiate()
	_add(root, hud, "HUD", true)
	hud.hint_text = hint
	for s in [["Chomp", "chomp"], ["Miss", "miss"], ["Whiff", "whiff"]]:
		var p := AudioStreamPlayer.new()
		p.stream = load("res://assets/sfx/%s.wav" % s[1])
		_add(root, p, s[0], true)
	return root


func _three_eat() -> Node:
	var root := _round("ThreeEat", "res://scripts/three_eat.gd", "res://data/songs/eat3.json",
		"紅豆→左（銀時）　醬油→中（新八）　三色→右（神樂）：落下那拍點那一側")
	var window := _rect(root, "HatchWindow", Vector2(290, 44), Vector2(60, 26), Color(0.25, 0.15, 0.1))
	root.move_child(window, root.get_node("Stage").get_index() + 1)
	var hatch := Marker2D.new()
	hatch.position = Vector2(320, 62)
	_add(root, hatch, "Hatch", true)
	return root


func _toss_game() -> Node:
	return _round("TossGame", "res://scripts/toss_game.gd", "res://data/songs/toss2.json",
		"聽到「咚」之後的第二拍點畫面；高音快拋是下一拍")


func _title() -> Node:
	var parts := _screen("Title", "res://scripts/title.gd", 12)
	var col: VBoxContainer = parts[1]
	_label(col, "GameTitle", "丸子大胃王", 46)
	_label(col, "Subtitle", "～神樂生日快樂 11.3～", 22)
	_button(col, "Start", "開始")
	_button(col, "Calibrate", "延遲校準")
	_label(col, "CalibInfo", "目前延遲校準：0 ms", 14, true)
	var credit := _label(parts[0], "Credit", "銀魂同人・非商業｜美術與音樂為暫用", 12)
	credit.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	credit.offset_left = -330
	credit.offset_top = -26
	credit.offset_right = -10
	credit.offset_bottom = -6
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return parts[0]


func _story() -> Node:
	var root := Control.new()
	root.name = "Story"
	root.set_script(load("res://scripts/story.gd"))
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.96, 0.86, 0.7)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(root, bg, "Background")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(root, panel, "Box")
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 24
	panel.offset_right = -24
	panel.offset_top = -132
	panel.offset_bottom = -18
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(panel, col, "Column")
	var speaker := _label(col, "Speaker", "", 18, true)
	speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	speaker.add_theme_color_override("font_color", CREAM)
	var line := _label(col, "Line", "", 22, true)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_theme_color_override("font_color", CREAM)
	var hint := _label(root, "Hint", "點一下繼續 ▶", 14)
	hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	hint.offset_left = -160
	hint.offset_top = 10
	hint.offset_right = -12
	hint.offset_bottom = 32
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return root


func _result() -> Node:
	var parts := _screen("Result", "res://scripts/result.gd", 8)
	var col: VBoxContainer = parts[1]
	_label(col, "LevelTitle", "關卡", 20, true)
	_label(col, "Rank", "大胃王", 48, true)
	_label(col, "Score", "0 分", 24, true)
	_label(col, "Counts", "完美 0　不錯 0　勉強 0　漏掉 0", 16, true)
	var comment := _label(col, "Comment", "", 18, true)
	comment.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	comment.custom_minimum_size = Vector2(520, 0)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	_add(col, row, "Buttons")
	_button(row, "Next", "下一回合")
	_button(row, "Retry", "重來這回合")
	_button(row, "Back", "回標題")
	return parts[0]


func _calibrate() -> Node:
	var parts := _screen("Calibrate", "res://scripts/calibrate.gd", 14)
	var root: Control = parts[0]
	var conductor := Node.new()
	conductor.set_script(load("res://scripts/conductor.gd"))
	_add(root, conductor, "Conductor", true)
	var col: VBoxContainer = parts[1]
	_label(col, "Instruction", "跟著牛鈴的拍子點畫面（至少 8 次）", 20)
	var dot := ColorRect.new()
	dot.color = Color(0.88, 0.24, 0.3)
	dot.custom_minimum_size = Vector2(48, 48)
	dot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(col, dot, "Dot", true)
	_label(col, "Info", "", 16, true)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	_add(col, row, "Buttons")
	_button(row, "Apply", "套用")
	_button(row, "Retry", "重測")
	_button(row, "Back", "返回")
	return root


func _main() -> Node:
	var root := Node.new()
	root.name = "Main"
	root.set_script(load("res://scripts/main.gd"))
	_add(root, Node.new(), "Screen", true)
	return root
