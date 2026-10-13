extends SceneTree
## Builds the game's scenes and theme once. After this the .tscn files are the source: edit them in the editor.
## Positions that follow art size (background strips, sprite offsets) are read from the textures, so after new
## art lands this can be re-run with --overwrite *before* anyone edits the scenes by hand (check git diff first).
##   godot --headless --path . --script res://tools/build_scenes.gd [-- --overwrite]

const SceneBuilder = preload("res://addons/proto_kit/scene_builder.gd")
const GROUND_Y := 318.0
const FONT := preload("res://assets/fonts/Cubic11.ttf")

var overwrite := false
var theme: Theme


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	overwrite = "--overwrite" in OS.get_cmdline_user_args()
	theme = _theme()
	var ok := true
	for job in [_titan, _rock, _warning, _player, _beast, _levi, _hud, _screens, _main]:
		var r: Dictionary = job.call()
		print("%s ok=%s nodes=%d %s" % [job.get_method(), r.ok, r.nodes, r.error])
		ok = ok and r.ok
	quit(0 if ok else 1)


func _save(root: Node, path: String, refs: Array = []) -> Dictionary:
	return SceneBuilder.save_scene(root, path, {"overwrite": overwrite, "expected_refs": refs})


func _tex(path: String) -> Texture2D:
	return load(path) as Texture2D


func _sprite(path: String, frames: int, feet := true) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _tex(path)
	s.hframes = frames
	if feet:
		s.offset = Vector2(0.0, -s.texture.get_height() / 2.0)
	return s


func _u(parent: Node, child: Node, node_name: String) -> Node:
	return SceneBuilder.add(parent, SceneBuilder.unique(child), node_name)


# ------------------------------------------------------------- theme

func _box(bg: Color, border: Color, width := 2, pad := 6) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(width)
	b.set_content_margin_all(pad)
	b.content_margin_left = pad + 6
	b.content_margin_right = pad + 6
	return b


func _theme() -> Theme:
	var th := Theme.new()
	th.default_font = FONT
	th.default_font_size = 11
	th.set_color(&"font_color", &"Label", Color("#f4ead2"))
	th.set_color(&"font_outline_color", &"Label", Color("#140e0c"))
	th.set_constant(&"outline_size", &"Label", 4)
	th.set_stylebox(&"normal", &"Button", _box(Color("#24402e"), Color("#c9b98a")))
	th.set_stylebox(&"hover", &"Button", _box(Color("#2f5a3d"), Color("#f2e3b0")))
	th.set_stylebox(&"pressed", &"Button", _box(Color("#18301f"), Color("#f2e3b0")))
	th.set_stylebox(&"focus", &"Button", _box(Color(0, 0, 0, 0), Color("#ffd86a"), 2))
	th.set_color(&"font_color", &"Button", Color("#f4ead2"))
	th.set_color(&"font_hover_color", &"Button", Color("#ffffff"))
	th.set_color(&"font_focus_color", &"Button", Color("#ffffff"))
	th.set_color(&"font_outline_color", &"Button", Color("#140e0c"))
	th.set_constant(&"outline_size", &"Button", 3)
	th.set_font_size(&"font_size", &"Button", 11)
	th.set_stylebox(&"panel", &"PanelContainer", _box(Color(0.08, 0.1, 0.09, 0.92), Color("#c9b98a"), 2, 10))
	var bar_bg := _box(Color(0.06, 0.06, 0.08, 0.85), Color("#c9b98a"), 1, 0)
	var bar_fill := _box(Color("#e0a63a"), Color("#e0a63a"), 0, 0)
	th.set_stylebox(&"background", &"ProgressBar", bar_bg)
	th.set_stylebox(&"fill", &"ProgressBar", bar_fill)
	ResourceSaver.save(th, "res://assets/ui/theme.tres")
	return load("res://assets/ui/theme.tres")


func _label(text: String, size := 11, color := Color("#f4ead2")) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if size != 11:
		l.add_theme_font_size_override(&"font_size", size)
	if color != Color("#f4ead2"):
		l.add_theme_color_override(&"font_color", color)
	return l


func _rect(c: Control, pos: Vector2, size: Vector2) -> Control:
	c.position = pos
	c.size = size
	return c


## Pin a control to a screen edge so it follows wide phones (the viewport stretches past 640 px in width).
## h_anchor/v_anchor: 0 = left/top, 0.5 = centre, 1 = right/bottom; pos is the offset of the top-left from that anchor.
func _pin(c: Control, h_anchor: float, v_anchor: float, pos: Vector2, size: Vector2) -> Control:
	c.anchor_left = h_anchor
	c.anchor_right = h_anchor
	c.anchor_top = v_anchor
	c.anchor_bottom = v_anchor
	c.offset_left = pos.x
	c.offset_top = pos.y
	c.offset_right = pos.x + size.x
	c.offset_bottom = pos.y + size.y
	return c


func _full(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE if not c is BaseButton else c.mouse_filter
	return c


func _centered(l: Label, y: float, h := 20.0) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_TOP_WIDE)
	l.offset_top = y
	l.offset_bottom = y + h
	return l


# ------------------------------------------------------------- actors

func _titan() -> Dictionary:
	var root := Node2D.new()
	root.name = "Titan"
	root.set_script(load("res://scripts/titan.gd"))
	_u(root, _sprite("res://assets/sprites/titan_tall.png", 4), "Sprite")
	return _save(root, "res://scenes/titan.tscn")


func _rock() -> Dictionary:
	var root := Node2D.new()
	root.name = "Rock"
	root.set_script(load("res://scripts/rock.gd"))
	var s := _sprite("res://assets/sprites/rocks.png", 4, false)
	_u(root, s, "Sprite")
	return _save(root, "res://scenes/rock.tscn")


func _warning() -> Dictionary:
	var root := _sprite("res://assets/ui/emblem.png", 4, false)
	root.name = "Warning"
	root.frame = 3
	root.z_index = 6
	return _save(root, "res://scenes/warning.tscn")


func _player() -> Dictionary:
	var root := Node2D.new()
	root.name = "Player"
	root.set_script(load("res://scripts/player.gd"))
	var body: Node2D = _u(root, Node2D.new(), "Body")
	_u(body, _sprite("res://assets/sprites/erwin_gallop.png", 6), "Gallop")
	var action: Sprite2D = _u(body, _sprite("res://assets/sprites/erwin_actions.png", 3), "Action")
	action.visible = false
	return _save(root, "res://scenes/player.tscn")


func _beast() -> Dictionary:
	var root := Node2D.new()
	root.name = "Beast"
	root.set_script(load("res://scripts/beast.gd"))
	var body_tex := _tex("res://assets/sprites/beast_body.png")
	var h := body_tex.get_height()
	var pivot: Node2D = _u(root, Node2D.new(), "ArmPivot")
	pivot.position = Vector2(4.0, -h * 0.6)
	var arm := Sprite2D.new()
	arm.texture = _tex("res://assets/sprites/beast_arm.png")
	arm.centered = false
	arm.offset = Vector2(-arm.texture.get_width(), -arm.texture.get_height() / 2.0)
	_u(pivot, arm, "Arm")
	_u(root, _sprite("res://assets/sprites/beast_body.png", 3), "Body")
	var face: Marker2D = _u(root, Marker2D.new(), "Face")
	face.position = Vector2(-30.0, -h * 0.82)
	var hand: Marker2D = _u(root, Marker2D.new(), "HandRock")
	hand.position = Vector2(20.0, -h * 0.98)
	return _save(root, "res://scenes/beast.tscn")


func _levi() -> Dictionary:
	var root := Node2D.new()
	root.name = "Levi"
	var s := _sprite("res://assets/sprites/levi.png", 5)
	SceneBuilder.add(root, s, "Sprite")
	return _save(root, "res://scenes/levi.tscn")


# ------------------------------------------------------------- UI

func _hud() -> Dictionary:
	var root := CanvasLayer.new()
	root.name = "Hud"
	root.layer = 5
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.set_script(load("res://scripts/hud.gd"))
	var emblem := _tex("res://assets/ui/emblem.png")
	var full := AtlasTexture.new()
	full.atlas = emblem
	full.region = Rect2(0, 0, emblem.get_width() / 4.0, emblem.get_height())
	var empty := AtlasTexture.new()
	empty.atlas = emblem
	empty.region = Rect2(emblem.get_width() / 4.0, 0, emblem.get_width() / 4.0, emblem.get_height())
	root.set(&"heart_full", full)
	root.set(&"heart_empty", empty)
	var ui := _full(Control.new())
	ui.theme = theme
	SceneBuilder.add(root, ui, "UI")
	var flash: ColorRect = _u(ui, _full(ColorRect.new()), "Flash")
	flash.color = Color(1, 0, 0, 0)
	var top: Control = _u(ui, _full(Control.new()), "Top")
	var hearts: HBoxContainer = _u(top, _rect(HBoxContainer.new(), Vector2(10, 6), Vector2(90, 26)), "Hearts")
	hearts.add_theme_constant_override(&"separation", 3)
	for i in 3:
		var heart := TextureRect.new()
		heart.texture = full
		heart.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		heart.custom_minimum_size = Vector2(26, 26)
		SceneBuilder.add(hearts, heart, "Heart%d" % (i + 1))
	var progress: Panel = _u(top, _pin(Panel.new(), 0.5, 0.0, Vector2(-120, 12), Vector2(220, 7)), "Progress")
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress.add_theme_stylebox_override(&"panel", _box(Color(0.06, 0.06, 0.08, 0.85), Color("#c9b98a"), 1, 0))
	var fill: ColorRect = _u(progress, _rect(ColorRect.new(), Vector2(1, 1), Vector2(0, 5)), "Fill")
	fill.color = Color("#e0a63a")
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var goal := _label("獸之巨人", 11, Color("#ffcf8a"))
	SceneBuilder.add(top, _pin(goal, 0.5, 0.0, Vector2(106, 6), Vector2(70, 18)), "GoalLabel")
	var marker := TextureRect.new()
	var head := AtlasTexture.new()
	head.atlas = _tex("res://assets/sprites/erwin_gallop.png")
	head.region = Rect2(0, 0, head.atlas.get_width() / 6.0, head.atlas.get_height())
	marker.texture = head
	marker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	marker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_u(top, _pin(marker, 0.5, 0.0, Vector2(-132, 0), Vector2(26, 22)), "Marker")
	var score := _label("000000  討伐 0")
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_u(top, _pin(score, 1.0, 0.0, Vector2(-200, 26), Vector2(190, 16)), "Score")
	var combo := _label("", 11, Color("#ffd86a"))
	combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_u(top, _pin(combo, 1.0, 0.0, Vector2(-200, 42), Vector2(190, 16)), "Combo")
	_u(ui, _centered(_label("", 11), 66.0), "Hint")
	_u(ui, _centered(_label("", 33, Color("#ffe2a0")), 104.0, 40.0), "Banner")
	_u(ui, _centered(_label("", 11), 148.0), "BannerSub")
	var pads: Control = _u(ui, _full(Control.new()), "TouchPads")
	for side in [["跳躍", 0.0, Vector2(10, -80), "JumpPad"], ["斬擊", 1.0, Vector2(-102, -80), "SlashPad"]]:
		var pad := PanelContainer.new()
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pad.modulate = Color(1, 1, 1, 0.4)
		_pin(pad, side[1], 1.0, side[2], Vector2(92, 70))
		var l := _label(side[0], 22)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		SceneBuilder.add(pad, l, "Label")
		_u(pads, pad, side[3])
	var pause: Button = _u(ui, _pin(Button.new(), 1.0, 0.0, Vector2(-36, 4), Vector2(30, 22)), "PauseButton")
	pause.text = "II"
	pause.focus_mode = Control.FOCUS_NONE
	return _save(root, "res://scenes/hud.tscn")


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(150, 34)
	return b


func _panel_box(parent: Control, node_name: String, y: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.offset_top = y
	SceneBuilder.add(parent, panel, node_name)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override(&"separation", 8)
	SceneBuilder.add(panel, box, "Box")
	return box


func _screens() -> Dictionary:
	var root := CanvasLayer.new()
	root.name = "Screens"
	root.layer = 10
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.set_script(load("res://scripts/screens.gd"))
	var ui := _full(Control.new())
	ui.theme = theme
	SceneBuilder.add(root, ui, "UI")

	# title
	var title: Control = _u(ui, _full(Control.new()), "Title")
	var art := _full(TextureRect.new())
	art.texture = _tex("res://assets/ui/title_art.png")
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	SceneBuilder.add(title, art, "Art")
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.03, 0.05, 0.62)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	shade.offset_top = -96
	SceneBuilder.add(title, shade, "Shade")
	var start: Button = _u(title, _full(Button.new()), "StartButton")
	start.flat = true
	start.mouse_filter = Control.MOUSE_FILTER_STOP
	start.focus_mode = Control.FOCUS_NONE
	SceneBuilder.add(title, _centered(_label("艾爾文衝鋒", 44, Color("#ffe6a8")), 22.0, 50.0), "TitleLabel")
	SceneBuilder.add(title, _centered(_label("ERWIN'S CHARGE ・ 10.14 團長生日紀念", 11, Color("#f4ead2")), 74.0), "SubLabel")
	_u(title, _centered(_label("點擊畫面　出擊！", 22, Color("#ffffff")), 270.0, 26.0), "PressLabel")
	_u(title, _centered(_label("點左半邊：跳躍　　點右半邊：斬擊・彈反", 11, Color("#d8ccb0")), 300.0), "Controls")
	SceneBuilder.add(title, _centered(_label("巨人靠近時斬擊　看到 ! 就準備彈反巨石　撐到獸之巨人出現", 11, Color("#d8ccb0")), 318.0), "Tips")
	_u(title, _centered(_label("", 11, Color("#ffd86a")), 336.0), "Best")
	var rotate := _centered(_label("把手機橫過來玩，畫面更大！", 11, Color("#ffffff")), 96.0)
	rotate.visible = false
	_u(title, rotate, "RotateHint")

	# pause
	var pause: Control = _u(ui, _full(Control.new()), "Pause")
	var dim := _full(ColorRect.new())
	dim.color = Color(0, 0, 0, 0.55)
	SceneBuilder.add(pause, dim, "Dim")
	var pbox := _panel_box(pause, "Panel", 92.0)
	var plabel := _label("暫停", 22)
	plabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	SceneBuilder.add(pbox, plabel, "PauseLabel")
	_u(pbox, _button("繼續"), "ResumeButton")
	_u(pbox, _button("聲音：開"), "MuteButton")
	_u(pbox, _button("重新開始"), "RestartButton")

	# game over
	var over: Control = _u(ui, _full(Control.new()), "GameOver")
	var odim := _full(ColorRect.new())
	odim.color = Color(0.12, 0.0, 0.0, 0.62)
	SceneBuilder.add(over, odim, "Dim")
	SceneBuilder.add(over, _centered(_label("獻出心臟！", 44, Color("#ff6a5a")), 60.0, 50.0), "OverTitle")
	SceneBuilder.add(over, _centered(_label("團長倒下了……但調查兵團永不放棄", 11), 112.0), "OverSub")
	var stats := _centered(_label("", 11), 150.0, 40.0)
	_u(over, stats, "OverStats")
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 12)
	row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	row.offset_top = 214
	row.offset_bottom = 244
	SceneBuilder.add(over, row, "Buttons")
	_u(row, _button("重新出擊"), "RetryButton")
	_u(row, _button("從獸之巨人重來"), "BossRetryButton")

	# ending
	var ending: Control = _u(ui, _full(Control.new()), "Ending")
	var eart := _full(TextureRect.new())
	eart.texture = _tex("res://assets/ui/ending_art.png")
	eart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	eart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	SceneBuilder.add(ending, eart, "Art")
	var band := ColorRect.new()
	band.color = Color(0.05, 0.03, 0.04, 0.5)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.set_anchors_preset(Control.PRESET_TOP_WIDE)
	band.offset_bottom = 84
	SceneBuilder.add(ending, band, "Band")
	var confetti := Node2D.new()
	confetti.set_script(load("res://addons/proto_kit/pixel_vfx.gd"))
	confetti.set(&"pixel", 1.0)
	_u(ending, confetti, "Confetti")
	_u(ending, _centered(_label("HAPPY BIRTHDAY", 33, Color("#ffe2a0")), 8.0, 40.0), "EndingTitle")
	SceneBuilder.add(ending, _centered(_label("艾爾文團長，生日快樂！　10.14", 22, Color("#ffffff")), 48.0, 28.0), "EndingSub")
	var estats_bg := ColorRect.new()
	estats_bg.color = Color(0.05, 0.03, 0.04, 0.62)
	estats_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	estats_bg.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	estats_bg.offset_top = -78
	SceneBuilder.add(ending, estats_bg, "StatsBand")
	_u(ending, _centered(_label("", 11), 286.0, 32.0), "EndingStats")
	var again := _button("再衝一次")
	again.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	again.grow_horizontal = Control.GROW_DIRECTION_BOTH
	again.offset_top = -38
	again.offset_bottom = -10
	again.offset_left = -60
	again.offset_right = 60
	_u(ending, again, "AgainButton")

	var fade: ColorRect = _u(ui, _full(ColorRect.new()), "Fade")
	fade.color = Color(0, 0, 0, 0)
	return _save(root, "res://scenes/screens.tscn")


# ------------------------------------------------------------- main

func _layer(parent: Node, node_name: String, tex_path: String, bottom: float) -> Parallax2D:
	var layer := Parallax2D.new()
	var tex := _tex(tex_path)
	layer.repeat_size = Vector2(tex.get_width(), 0)
	layer.repeat_times = int(ceil(960.0 / tex.get_width())) + 2
	layer.ignore_camera_scroll = true
	_u(parent, layer, node_name)
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.position = Vector2(0, bottom - tex.get_height())
	SceneBuilder.add(layer, s, "Sprite")
	return layer


func _main() -> Dictionary:
	var root := Node2D.new()
	root.name = "Main"
	root.set_script(load("res://scripts/main.gd"))
	root.set(&"run_track", load("res://assets/audio/bgm_run.wav"))
	root.set(&"boss_track", load("res://assets/audio/bgm_boss.wav"))
	root.set(&"end_track", load("res://assets/audio/bgm_end.wav"))
	var sfx := Node.new()
	sfx.set_script(load("res://scripts/sfx.gd"))
	_u(root, sfx, "Sfx")
	var music := Node.new()
	music.set_script(load("res://addons/proto_kit/music.gd"))
	music.process_mode = Node.PROCESS_MODE_ALWAYS
	_u(root, music, "Music")
	for i in 2:
		SceneBuilder.add(music, AudioStreamPlayer.new(), "Player%d" % (i + 1))
	var tc := Node.new()
	tc.set_script(load("res://addons/proto_kit/time_control.gd"))
	tc.process_mode = Node.PROCESS_MODE_ALWAYS
	_u(root, tc, "TimeControl")

	_layer(root, "Sky", "res://assets/bg/sky.png", 360.0)
	_layer(root, "Far", "res://assets/bg/far.png", GROUND_Y + 8.0)
	var far_beast := _sprite("res://assets/sprites/beast_body.png", 3)
	far_beast.position = Vector2(560, GROUND_Y - 62.0)
	far_beast.scale = Vector2(0.32, 0.32)
	far_beast.self_modulate = Color(0.36, 0.33, 0.46)
	far_beast.visible = false
	_u(root, far_beast, "BeastFar")
	_layer(root, "Mid", "res://assets/bg/mid.png", GROUND_Y + 6.0)
	_layer(root, "Ruins", "res://assets/bg/ruins.png", GROUND_Y + 4.0)
	var gate := Sprite2D.new()
	gate.texture = _tex("res://assets/bg/wall_gate.png")
	gate.centered = false
	gate.position = Vector2(-40.0, GROUND_Y + 6.0 - gate.texture.get_height())
	_u(root, gate, "WallGate")
	_layer(root, "Ground", "res://assets/bg/ground.png", GROUND_Y - 8.0 + _tex("res://assets/bg/ground.png").get_height())

	var world := Node2D.new()
	SceneBuilder.add(root, world, "World")
	var beast := SceneBuilder.instance("res://scenes/beast.tscn")
	beast.position = Vector2(520, GROUND_Y)
	beast.visible = false
	_u(world, beast, "Beast")
	_u(world, Node2D.new(), "Obstacles")
	var player := SceneBuilder.instance("res://scenes/player.tscn")
	player.position = Vector2(120, GROUND_Y)
	_u(world, player, "Player")
	var levi := SceneBuilder.instance("res://scenes/levi.tscn")
	levi.visible = false
	_u(world, levi, "Levi")

	var fx := Node2D.new()
	fx.set_script(load("res://addons/proto_kit/pixel_vfx.gd"))
	fx.set(&"pixel", 1.0)
	fx.set(&"font", FONT)
	fx.z_index = 5
	_u(root, fx, "Fx")
	var cam := Camera2D.new()
	cam.position = Vector2(320, 180)
	cam.ignore_rotation = false
	_u(root, cam, "Camera")
	_u(root, SceneBuilder.instance("res://scenes/hud.tscn"), "Hud")
	_u(root, SceneBuilder.instance("res://scenes/screens.tscn"), "Screens")
	return _save(root, "res://scenes/main.tscn", ["res://scenes/player.tscn", "res://scenes/beast.tscn",
			"res://scenes/levi.tscn", "res://scenes/hud.tscn", "res://scenes/screens.tscn"])
