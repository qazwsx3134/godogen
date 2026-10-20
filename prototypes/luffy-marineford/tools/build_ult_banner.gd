extends SceneTree
## Applied 2026-10-20. One-time authoring tool; do not rerun over edited scenes.
## Refuses to overwrite ult_banner.tscn. Saves the HUD with an actual subscene
## instance, checking node counts/owners and preserving existing card instances.
## godot --headless --path prototypes/luffy-marineford --script res://tools/build_ult_banner.gd
const Builder = preload("res://addons/proto_kit/scene_builder.gd")
const BANNER_PATH := "res://scenes/ult_banner.tscn"


func _initialize() -> void:
	_build.call_deferred()


func _node(parent: Node, node: Control, node_name: String, unique: bool = false) -> Control:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.focus_mode = Control.FOCUS_NONE
	Builder.add(parent, Builder.unique(node) if unique else node, node_name)
	return node


func _fill(node: Control) -> void:
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _label(parent: Node, node_name: String, text: String, font_size: int, color: Color, unique: bool = false) -> Label:
	var label := _node(parent, Label.new(), node_name, unique) as Label
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 0)
	return label


func _build() -> void:
	if FileAccess.file_exists(BANNER_PATH):
		push_error("ult_banner.tscn already authored; edit it directly, do not regenerate")
		quit(1)
		return
	var root := Control.new()
	root.name = "UltBanner"
	root.set_script(load("res://scripts/ult_banner.gd"))
	root.theme = load("res://ui/theme.tres")
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	_fill(root)
	var flash := _node(root, ColorRect.new(), "BannerFlash", true) as ColorRect
	_fill(flash)
	flash.color = Color.WHITE
	flash.modulate.a = 0.0
	var motion := _node(root, Control.new(), "Motion", true)
	_fill(motion)
	var safe_frame := _node(motion, MarginContainer.new(), "SafeFrame", true)
	_fill(safe_frame)
	var canvas := _node(safe_frame, Control.new(), "Canvas")
	var band := _node(canvas, Panel.new(), "Band", true) as Panel
	band.anchor_left = -0.16
	band.anchor_right = 1.16
	band.anchor_top = 0.5
	band.anchor_bottom = 0.5
	band.offset_top = -88
	band.offset_bottom = 88
	band.rotation_degrees = -10.0
	band.pivot_offset = Vector2(844.8, 88)
	var ink := StyleBoxFlat.new()
	ink.bg_color = Color("142338")
	ink.border_color = Color("f0e9d9")
	ink.border_width_top = 2
	ink.border_width_bottom = 2
	ink.shadow_color = Color(0.02, 0.04, 0.09, 0.5)
	ink.shadow_size = 12
	band.add_theme_stylebox_override("panel", ink)
	var accent := _node(band, ColorRect.new(), "Accent", true) as ColorRect
	accent.anchor_right = 1.0
	accent.offset_top = 5
	accent.offset_bottom = 11
	accent.color = Color("ffd16b")
	var echo := _node(band, ColorRect.new(), "LowerRule") as ColorRect
	echo.anchor_right = 1
	echo.anchor_top = 1
	echo.anchor_bottom = 1
	echo.offset_top = -12
	echo.offset_bottom = -9
	echo.color = Color("596b80")
	# A handful of editable slashes, not a shader or an image generation batch.
	var stripes := _node(band, HBoxContainer.new(), "Stripes") as HBoxContainer
	stripes.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	stripes.offset_left = -280
	stripes.offset_right = -40
	stripes.add_theme_constant_override("separation", 18)
	for i in 6:
		var slash := _node(stripes, ColorRect.new(), "Slash%d" % i) as ColorRect
		slash.custom_minimum_size.x = 14
		slash.rotation_degrees = 18
		slash.color = Color(0.65, 0.77, 0.9, 0.12)
	var safe := _node(band, MarginContainer.new(), "SafeContent", true) as MarginContainer
	_fill(safe)
	safe.add_theme_constant_override("margin_left", 229)
	safe.add_theme_constant_override("margin_right", 229)
	safe.add_theme_constant_override("margin_top", 18)
	safe.add_theme_constant_override("margin_bottom", 18)
	var ratio := _node(safe, AspectRatioContainer.new(), "ContentWidth") as AspectRatioContainer
	ratio.ratio = 5.1
	ratio.stretch_mode = AspectRatioContainer.STRETCH_FIT
	var row := _node(ratio, HBoxContainer.new(), "ContentRow") as HBoxContainer
	row.add_theme_constant_override("separation", 28)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var portrait_frame := _node(row, PanelContainer.new(), "PortraitFrame") as PanelContainer
	portrait_frame.custom_minimum_size = Vector2(120, 120)
	portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var portrait_style := StyleBoxFlat.new()
	portrait_style.bg_color = Color("253b52")
	portrait_style.border_color = Color("fff6dd")
	portrait_style.set_border_width_all(3)
	portrait_style.set_corner_radius_all(18)
	portrait_style.content_margin_left = 6
	portrait_style.content_margin_right = 6
	portrait_style.content_margin_top = 6
	portrait_style.content_margin_bottom = 6
	portrait_frame.add_theme_stylebox_override("panel", portrait_style)
	var portrait_stack := _node(portrait_frame, Control.new(), "PortraitStack")
	portrait_stack.custom_minimum_size = Vector2(108, 108)
	var portrait_accent := _node(portrait_stack, ColorRect.new(), "PortraitAccent", true) as ColorRect
	_fill(portrait_accent)
	portrait_accent.color = Color(1, 1, 1, 0.12)
	var portrait := _node(portrait_stack, TextureRect.new(), "Portrait", true) as TextureRect
	_fill(portrait)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var initials := _label(portrait_stack, "Initials", "LF", 40, Color("fff6dd"), true)
	_fill(initials)
	initials.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initials.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var words := _node(row, VBoxContainer.new(), "Words") as VBoxContainer
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 1)
	_label(words, "Eyebrow", "ULTIMATE / 必殺", 14, Color("ffd16b"), true)
	var title := _label(words, "Title", "霸王色霸氣", 48, Color("fff6dd"), true)
	title.clip_text = true
	title.max_lines_visible = 1
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var subtitle := _label(words, "Subtitle", "蒙奇・D・魯夫", 20, Color("adbdcf"), true)
	subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var saved: Dictionary = Builder.save_scene(root, BANNER_PATH)
	if not saved.ok:
		quit(1)
		return
	var hud := Builder.instance("res://scenes/hud.tscn")
	var hud_root := hud.get_node("Root")
	var banner := Builder.instance(BANNER_PATH)
	banner.name = "UltBanner"
	Builder.unique(banner)
	hud_root.add_child(banner)
	# Child order: Flash, UltBanner, LevelUp (the modal stays above announcements).
	hud_root.move_child(banner, hud_root.get_node("LevelUp").get_index())
	var result: Dictionary = Builder.save_scene(hud, "res://scenes/hud.tscn", {"overwrite": true,
		"expected_refs": [BANNER_PATH, "res://scenes/upgrade_card.tscn"]})
	print(result)
	quit(0 if result.ok else 1)
