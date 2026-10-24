extends SceneTree
## One-time maker of scenes/ui/tutorial_overlay.tscn (the first-time guide). After it exists the scene is the source:
## this refuses to overwrite it unless run with `-- --force` (check `git diff` first).
##   godot --headless --path . --script res://tools/make_tutorial_scenes.gd [-- --force]

const Builder = preload("res://addons/proto_kit/scene_builder.gd")
const PATH := "res://scenes/ui/tutorial_overlay.tscn"


func _init() -> void:
	var force: bool = "--force" in OS.get_cmdline_user_args()
	if ResourceLoader.exists(PATH) and not force:
		push_error("%s exists; pass -- --force to rebuild it" % PATH)
		quit(1)
		return
	var font := FontVariation.new()
	font.base_font = load("res://assets/fonts/NotoSerifTC.ttf")
	font.variation_opentype = {2003265652: 500.0}
	var theme := Theme.new()
	theme.default_font = font

	var root := Control.new()
	root.name = "TutorialOverlay"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP  # nothing under the guide takes a tap
	root.theme = theme
	root.set_script(load("res://scripts/tutorial_overlay.gd"))
	for shade_name: String in ["ShadeTop", "ShadeBottom", "ShadeLeft", "ShadeRight"]:
		var shade := ColorRect.new()
		shade.name = shade_name
		shade.unique_name_in_owner = true
		shade.color = Color(0.03, 0.05, 0.09, 0.66)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(shade)
	var focus := Panel.new()
	focus.name = "Focus"
	focus.unique_name_in_owner = true
	focus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = Color("#d9e2ea")  # deep-blue/silver frame, like the reading buttons
	ring.set_border_width_all(6)
	ring.set_corner_radius_all(14)
	ring.shadow_color = Color("#203e5e")
	ring.shadow_size = 6
	focus.add_theme_stylebox_override("panel", ring)
	root.add_child(focus)
	var arrow := Label.new()
	arrow.name = "Arrow"
	arrow.unique_name_in_owner = true
	arrow.text = "▼"
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.add_theme_font_size_override("font_size", 64)
	arrow.add_theme_color_override("font_color", Color("#f8f3e9"))
	arrow.add_theme_color_override("font_outline_color", Color("#203e5e"))
	arrow.add_theme_constant_override("outline_size", 10)
	root.add_child(arrow)

	var card := PanelContainer.new()
	card.name = "Card"
	card.unique_name_in_owner = true
	card.set_meta("ui_style_role", "menu")  # the washi paper (ui_styles PAPER_ROLES)
	card.anchor_right = 1.0
	card.offset_left = 48.0
	card.offset_right = -48.0
	card.offset_top = 1100.0
	root.add_child(card)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	card.add_child(margin)
	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.add_theme_constant_override("separation", 20)
	margin.add_child(rows)
	var title := _label("Title", "裝傻與吐槽", 44, "accent")
	rows.add_child(title)
	var body := _label("Body", "對方的話分成好幾句。\n用 < > 切換，找出哪一句在裝傻。", 36, "body")
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(body)
	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.add_theme_constant_override("separation", 20)
	rows.add_child(buttons)
	var step := _label("Step", "1／3", 30, "muted")
	step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	step.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	buttons.add_child(step)
	buttons.add_child(_button("Skip", "略過", "standard"))
	buttons.add_child(_button("Next", "下一步 ›", "primary"))

	var result: Dictionary = Builder.save_scene(root, PATH, {"overwrite": force})
	print("tutorial overlay: ", result)
	quit(0 if result.ok else 1)


func _label(node_name: String, text: String, font_size: int, role: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.unique_name_in_owner = true
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.set_meta("ui_style_role", role)
	return label


func _button(node_name: String, text: String, role: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.unique_name_in_owner = true
	button.text = text
	button.custom_minimum_size = Vector2(220, 104)  # well over 48 CSS px on a 390-wide phone
	button.add_theme_font_size_override("font_size", 34)
	button.set_meta("ui_style_role", role)
	return button
