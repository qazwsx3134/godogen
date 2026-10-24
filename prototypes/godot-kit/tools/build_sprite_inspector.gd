extends SceneTree
## Authoring tool: saves addons/proto_kit/sprite_inspector.tscn (the sprite animation test page). The saved scene is
## the editable source; re-running skips it unless `-- --force` (check `git diff` first).
##   timeout 120 godot --headless --path prototypes/godot-kit --script res://tools/build_sprite_inspector.gd [-- --force]

const B = preload("res://addons/proto_kit/scene_builder.gd")


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var root := Control.new()
	root.name = "SpriteInspector"
	root.set_script(load("res://addons/proto_kit/sprite_inspector.gd"))
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := _add(root, ColorRect.new(), "Background") as ColorRect
	bg.color = Color(0.11, 0.12, 0.14)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := _add(root, MarginContainer.new(), "Margin") as MarginContainer
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	var cols := _add(margin, HBoxContainer.new(), "Columns") as HBoxContainer
	cols.add_theme_constant_override("separation", 10)

	# Left: sources, animations, directions, playback settings.
	var left := _vbox(cols, "Left", 6)
	left.custom_minimum_size = Vector2(300, 0)
	_label(left, "SheetTitle", "Sheet")
	var sheets := _add(left, ItemList.new(), "SheetList", true) as ItemList
	sheets.custom_minimum_size = Vector2(0, 160)
	_label(left, "AnimTitle", "動畫")
	var anims := _add(left, ItemList.new(), "AnimList", true) as ItemList
	anims.custom_minimum_size = Vector2(0, 150)
	_label(left, "DirTitle", "方向（↑↓）")
	_add(left, GridContainer.new(), "Directions", true)
	_label(left, "SpeedTitle", "速度（[ ]）")
	_add(left, OptionButton.new(), "Speed", true)
	_label(left, "ZoomTitle", "倍率（Z）：所有幀同一倍率")
	_add(left, OptionButton.new(), "Zoom", true)
	var onion := _add(left, CheckBox.new(), "OnionCheck", true) as CheckBox
	onion.text = "洋蔥皮：疊上一格（O）"
	var overlays := _add(left, CheckBox.new(), "OverlayCheck", true) as CheckBox
	overlays.text = "格線、腳底線、外框（G）"
	overlays.button_pressed = true
	var nearest := _add(left, CheckBox.new(), "NearestCheck", true) as CheckBox
	nearest.text = "像素取樣（nearest）"

	# Middle: the frame, transport, the frame strip, the readout.
	var mid := _vbox(cols, "Middle", 6)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var view := _add(mid, Control.new(), "FrameView", true) as Control
	view.set_script(load("res://addons/proto_kit/sprite_inspector_frame.gd"))
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.clip_contents = true
	var transport := _add(mid, HBoxContainer.new(), "Transport") as HBoxContainer
	transport.alignment = BoxContainer.ALIGNMENT_CENTER
	for spec: Array in [["PrevButton", "◀ 上一格"], ["PlayButton", "暫停"], ["NextButton", "下一格 ▶"]]:
		var b := _add(transport, Button.new(), spec[0], true) as Button
		b.text = spec[1]
		b.custom_minimum_size = Vector2(120, 40)
		b.focus_mode = Control.FOCUS_NONE
	var scroll := _add(mid, ScrollContainer.new(), "StripScroll") as ScrollContainer
	scroll.custom_minimum_size = Vector2(0, 170)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var strip := _add(scroll, HBoxContainer.new(), "FrameStrip", true) as HBoxContainer
	strip.add_theme_constant_override("separation", 6)
	var info := _add(mid, Label.new(), "Info", true) as Label
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(0, 66)
	info.text = "選一個 sheet"

	# Right: atlas with grid, problems.
	var right := _vbox(cols, "Right", 6)
	right.custom_minimum_size = Vector2(440, 0)
	_label(right, "AtlasTitle", "圖集（藍框：目前動畫的格，橘框：現在這格，點格子跳過去）")
	var atlas := _add(right, Control.new(), "AtlasView", true) as Control
	atlas.set_script(load("res://addons/proto_kit/sprite_inspector_atlas.gd"))
	atlas.custom_minimum_size = Vector2(0, 320)
	atlas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_label(right, "IssueTitle", "檢查結果（點一列跳到該格）")
	var issues := _add(right, ItemList.new(), "Issues", true) as ItemList
	issues.custom_minimum_size = Vector2(0, 220)
	issues.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var result: Dictionary = B.save_scene(root, "res://addons/proto_kit/sprite_inspector.tscn",
		{"overwrite": "--force" in OS.get_cmdline_user_args()})
	print("sprite_inspector: ", "skipped (exists)" if result.get("skipped", false) else ("ok" if result.ok else result.error))
	quit(0 if result.ok else 1)


func _add(parent: Node, child: Node, node_name: String, unique: bool = false) -> Node:
	if unique:
		B.unique(child)
	return B.add(parent, child, node_name)


func _vbox(parent: Node, node_name: String, gap: int) -> VBoxContainer:
	var v := _add(parent, VBoxContainer.new(), node_name) as VBoxContainer
	v.add_theme_constant_override("separation", gap)
	return v


func _label(parent: Node, node_name: String, text: String) -> Label:
	var l := _add(parent, Label.new(), node_name) as Label
	l.text = text
	return l
