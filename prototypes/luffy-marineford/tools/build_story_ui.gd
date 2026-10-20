extends SceneTree
## Authors scenes/toast_item.tscn and scenes/story_ui.tscn (dialogue box, subtitle, toasts, act title, letterbox,
## skip button). One-time tool: existing scenes are skipped, edit them in the editor.
##   godot --headless --path prototypes/luffy-marineford --script res://tools/build_story_ui.gd

const Builder = preload("res://addons/proto_kit/scene_builder.gd")
const TOAST_PATH := "res://scenes/toast_item.tscn"
const STORY_PATH := "res://scenes/story_ui.tscn"
const INK := Color("142338")
const CREAM := Color("fff6dd")
const GOLD := Color("ffd16b")


func _initialize() -> void:
	_build.call_deferred()


func _add(parent: Node, node: Control, node_name: String, unique: bool = false) -> Control:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.focus_mode = Control.FOCUS_NONE
	Builder.add(parent, Builder.unique(node) if unique else node, node_name)
	return node


func _label(parent: Node, node_name: String, text: String, font_size: int, color: Color, unique: bool = false) -> Label:
	var label := _add(parent, Label.new(), node_name, unique) as Label
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _style(bg: Color, border: Color, width: int, radius: int, margin: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin
	s.content_margin_bottom = margin
	return s


func _portrait_frame(parent: Node, prefix: String, side: int) -> void:
	var frame := _add(parent, PanelContainer.new(), prefix + "Frame") as PanelContainer
	frame.custom_minimum_size = Vector2(side, side)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.add_theme_stylebox_override("panel", _style(Color("253b52"), CREAM, 2, 10, 3))
	var stack := _add(frame, Control.new(), prefix + "Stack")
	var tex := _add(stack, TextureRect.new(), prefix, true) as TextureRect
	tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var initials := _label(stack, prefix.replace("Portrait", "Initials"), "魯", int(side * 0.4), CREAM, true)
	initials.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	initials.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initials.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _build_toast() -> bool:
	var root := Control.new()
	root.name = "ToastItem"
	root.set_script(load("res://scripts/toast_item.gd"))
	root.custom_minimum_size = Vector2(380, 72)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var motion := _add(root, Control.new(), "Motion", true)
	motion.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var band := _add(motion, PanelContainer.new(), "Band") as PanelContainer
	band.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := _style(Color(INK, 0.93), CREAM, 0, 0, 8)
	style.border_width_right = 3
	style.border_width_bottom = 2
	style.content_margin_left = 16
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_right = 14
	band.add_theme_stylebox_override("panel", style)
	var row := _add(band, HBoxContainer.new(), "Row") as HBoxContainer
	row.add_theme_constant_override("separation", 12)
	_portrait_frame(row, "ToastPortrait", 56)
	var words := _add(row, VBoxContainer.new(), "Words") as VBoxContainer
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", -2)
	_label(words, "ToastSpeaker", "白鬍子", 18, GOLD, true)
	_label(words, "ToastText", "參戰！", 28, CREAM, true)
	var accent := _add(motion, ColorRect.new(), "ToastAccent", true) as ColorRect
	accent.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	accent.offset_right = 7
	accent.color = GOLD
	var result: Dictionary = Builder.save_scene(root, TOAST_PATH)
	print("toast_item: ", result)
	return result.ok


func _build_story() -> bool:
	var root := CanvasLayer.new()
	root.name = "StoryUi"
	root.layer = 2
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.set_script(load("res://scripts/story_ui.gd"))
	root.set(&"toast_scene", load(TOAST_PATH))
	var ui := _add(root, Control.new(), "Root")
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.theme = load("res://ui/theme.tres")

	var top := _add(ui, ColorRect.new(), "LetterboxTop", true) as ColorRect
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 56
	top.color = Color.BLACK
	var bottom := _add(ui, ColorRect.new(), "LetterboxBottom", true) as ColorRect
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -56
	bottom.pivot_offset = Vector2(0, 56)
	bottom.color = Color.BLACK

	var subtitle := _add(ui, PanelContainer.new(), "Subtitle", true) as PanelContainer
	subtitle.anchor_left = 0.5
	subtitle.anchor_right = 0.5
	subtitle.anchor_top = 1.0
	subtitle.anchor_bottom = 1.0
	subtitle.offset_left = -330
	subtitle.offset_right = 330
	subtitle.offset_top = -170
	subtitle.offset_bottom = -112
	subtitle.grow_horizontal = Control.GROW_DIRECTION_BOTH
	subtitle.grow_vertical = Control.GROW_DIRECTION_BEGIN
	subtitle.add_theme_stylebox_override("panel", _style(Color(0.02, 0.04, 0.08, 0.6), Color.TRANSPARENT, 0, 12, 10))
	var line := _add(subtitle, HBoxContainer.new(), "Line") as HBoxContainer
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_theme_constant_override("separation", 10)
	_label(line, "SubtitleSpeaker", "魯夫", 22, GOLD, true)
	var said := _label(line, "SubtitleText", "因為我是弟弟啊！", 26, CREAM, true)
	said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	said.custom_minimum_size.x = 200

	var toasts := _add(ui, VBoxContainer.new(), "Toasts", true) as VBoxContainer
	toasts.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	toasts.offset_top = 118
	toasts.offset_right = 380
	toasts.offset_bottom = 400
	toasts.add_theme_constant_override("separation", 8)
	var sample := Builder.instance(TOAST_PATH)
	Builder.add(toasts, sample, "SampleToast")

	var catcher := _add(ui, Control.new(), "Catcher", true)
	catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP

	var box := _add(ui, PanelContainer.new(), "DialogueBox", true) as PanelContainer
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	box.offset_left = 24
	box.offset_right = -24
	box.offset_top = -184
	box.offset_bottom = -20
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.add_theme_stylebox_override("panel", _style(Color(INK, 0.95), CREAM, 2, 14, 14))
	var row := _add(box, HBoxContainer.new(), "Row") as HBoxContainer
	row.add_theme_constant_override("separation", 18)
	_portrait_frame(row, "Portrait", 136)
	var words := _add(row, VBoxContainer.new(), "Words") as VBoxContainer
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 4)
	_label(words, "Speaker", "魯夫", 24, GOLD, true)
	var text := _label(words, "Text", "艾斯——！我來救你了！", 28, CREAM, true)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var next := _label(words, "NextMark", "▼", 20, GOLD, true)
	next.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var title := _add(ui, Control.new(), "ActTitle", true)
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var black := _add(title, ColorRect.new(), "Black") as ColorRect
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.color = Color(0.02, 0.03, 0.06)
	var center := _add(title, VBoxContainer.new(), "Center") as VBoxContainer
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 6)
	var number := _label(center, "TitleNumber", "第四幕", 30, GOLD, true)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var name_label := _label(center, "TitleName", "處刑台", 76, CREAM, true)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var rule := _add(center, ColorRect.new(), "Rule") as ColorRect
	rule.custom_minimum_size = Vector2(220, 3)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rule.color = GOLD

	var skip := _add(ui, Button.new(), "Skip", true) as Button
	skip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	skip.offset_left = -150
	skip.offset_top = 8
	skip.offset_right = -16
	skip.offset_bottom = 48
	skip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	skip.text = "跳過 ▶▶"
	skip.mouse_filter = Control.MOUSE_FILTER_STOP
	skip.add_theme_font_size_override("font_size", 20)
	var result: Dictionary = Builder.save_scene(root, STORY_PATH, {"expected_refs": [TOAST_PATH]})
	print("story_ui: ", result)
	return result.ok


func _build() -> void:
	quit(0 if _build_toast() and _build_story() else 1)
