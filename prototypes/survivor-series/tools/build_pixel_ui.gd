extends SceneTree
## One-off UI pass (docs/pixel-ui-plan.md P3–P6): pixel-font theme with 9-slice frames from assets/ui/
## (tools/make_ui_frames.py), the new HUD (slots, elite bar, thin XP bar), the night-market boxes around menu,
## pause, results and shop, glass upgrade cards, and pixel damage numbers.
##   uv run --no-project --with pillow python tools/make_ui_frames.py
##   godot --headless --path . --import && godot --headless --path . -s tools/build_pixel_ui.gd
## Applied 2026-10-14. It refuses to run again (assets/ui/.applied); edit the theme and scenes directly.

const UI := "res://assets/ui/"
const TEXT := Color("fff4dc")
const SUB := Color("b9b0d6")
const GOLD := Color("ffd36b")
const INK := Color("120c1e")
const OLD_CREAM := Color(0.96862745, 0.9098039, 0.80784315, 1)
const OLD_TEAL := Color(0.44705883, 0.8784314, 0.7529412, 1)
const OLD_GREY := Color(0.56078434, 0.6509804, 0.6784314, 1)
const SCREENS := ["menu", "results", "pause", "upgrades", "upgrade_card", "shop", "shop_item"]
## World px per art px (2 screen px through the camera's 0.72 zoom).
const WORLD_PIXEL := 2.0 / 0.72

func _init() -> void:
	if FileAccess.file_exists(UI + ".applied"):
		push_error("pixel UI pass already applied; edit the theme and scenes directly")
		quit(1)
		return
	_theme()
	_slot("res://scenes/weapon_slot.tscn", 48, "WeaponSlot")
	_slot("res://scenes/passive_slot.tscn", 28, "PassiveSlot")
	_hud()
	for screen: String in SCREENS:
		_screen("res://scenes/%s.tscn" % screen)
	_damage_number()
	FileAccess.open(UI + ".applied", FileAccess.WRITE).store_string(Time.get_datetime_string_from_system())
	quit()

# --- theme -------------------------------------------------------------------------------------------------

func _frame(file: String, margin: Vector4, content: Vector4) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = load(UI + file + ".png")
	box.texture_margin_left = margin.x
	box.texture_margin_top = margin.y
	box.texture_margin_right = margin.z
	box.texture_margin_bottom = margin.w
	box.content_margin_left = content.x
	box.content_margin_top = content.y
	box.content_margin_right = content.z
	box.content_margin_bottom = content.w
	return box

func _theme() -> void:
	var theme := Theme.new()
	var font := FontVariation.new()
	font.base_font = load("res://assets/fonts/Cubic11.ttf")
	font.fallbacks = [load("res://assets/fonts/NotoSansTC.ttf")]
	theme.default_font = font
	theme.default_font_size = 22
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_shadow_color", "Label", INK)
	theme.set_constant("shadow_offset_x", "Label", 2)
	theme.set_constant("shadow_offset_y", "Label", 2)
	theme.set_constant("shadow_outline_size", "Label", 0)
	var edge := Vector4(8, 8, 8, 10)
	var pad := Vector4(16, 8, 16, 12)
	var pad_down := Vector4(16, 12, 16, 8)
	for state: Array in [["normal", "button", pad], ["hover", "button_hover", pad], ["pressed", "button_pressed", pad_down], ["disabled", "button_disabled", pad], ["hover_pressed", "button_pressed", pad_down]]:
		theme.set_stylebox(state[0], "Button", _frame(state[1], edge, state[2]))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for color: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		theme.set_color(color, "Button", TEXT)
	theme.set_color("font_disabled_color", "Button", SUB)
	# Gold call-to-action button.
	theme.set_type_variation("PrimaryButton", "Button")
	for state: Array in [["normal", "primary", pad], ["hover", "primary_hover", pad], ["pressed", "primary_pressed", pad_down], ["hover_pressed", "primary_pressed", pad_down]]:
		theme.set_stylebox(state[0], "PrimaryButton", _frame(state[1], edge, state[2]))
	for color: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		theme.set_color(color, "PrimaryButton", Color("3a210c"))
	# Glass card: the level-up choices, see-through over the fight.
	theme.set_type_variation("GlassCard", "Button")
	var glass := Vector4(6, 6, 6, 6)
	theme.set_stylebox("normal", "GlassCard", _frame("glass", glass, Vector4(14, 10, 14, 10)))
	for state: String in ["hover", "pressed", "hover_pressed"]:
		theme.set_stylebox(state, "GlassCard", _frame("glass_hover", glass, Vector4(18, 10, 10, 10)))
	theme.set_stylebox("focus", "GlassCard", StyleBoxEmpty.new())
	# Boxes: the night-market double frame, and the glass panel for level-ups.
	theme.set_stylebox("panel", "PanelContainer", _frame("box", Vector4(10, 10, 10, 10), Vector4(22, 20, 22, 22)))
	theme.set_type_variation("GlassPanel", "PanelContainer")
	theme.set_stylebox("panel", "GlassPanel", _frame("glass", glass, Vector4(18, 16, 18, 16)))
	theme.set_type_variation("Slot", "Panel")
	theme.set_stylebox("panel", "Slot", _frame("slot", Vector4(6, 6, 6, 6), Vector4(4, 4, 4, 4)))
	# Bars.
	theme.set_stylebox("background", "ProgressBar", _frame("bar_back", Vector4(4, 4, 4, 4), Vector4.ZERO))
	theme.set_stylebox("fill", "ProgressBar", _frame("bar_hp", Vector4(2, 2, 2, 2), Vector4.ZERO))
	theme.set_type_variation("XpBar", "ProgressBar")
	theme.set_stylebox("fill", "XpBar", _frame("bar_xp", Vector4.ZERO, Vector4.ZERO))
	theme.set_type_variation("EliteBar", "ProgressBar")
	theme.set_stylebox("fill", "EliteBar", _frame("bar_elite", Vector4(2, 2, 2, 2), Vector4.ZERO))
	theme.set_color("font_color", "CheckButton", TEXT)
	theme.set_color("font_hover_color", "CheckButton", TEXT)
	theme.set_color("font_pressed_color", "CheckButton", GOLD)
	theme.set_color("font_hover_pressed_color", "CheckButton", GOLD)
	assert(ResourceSaver.save(theme, "res://data/ui_theme.tres") == OK)

# --- helpers -----------------------------------------------------------------------------------------------

func _open(path: String) -> Node:
	return (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)

func _save(root: Node, path: String) -> void:
	var packed := PackedScene.new()
	assert(packed.pack(root) == OK)
	assert(ResourceSaver.save(packed, path) == OK)
	var nodes: int = _count(root)
	root.free()
	var check: Node = (load(path) as PackedScene).instantiate()
	assert(_count(check) == nodes, "%s lost nodes" % path)
	check.free()
	print("ui: ", path)

func _count(node: Node) -> int:
	var total: int = 1
	for child: Node in node.get_children():
		total += _count(child)
	return total

func _own(node: Node, root: Node) -> void:
	node.owner = root
	if node != root and not node.scene_file_path.is_empty():
		return
	for child: Node in node.get_children():
		_own(child, root)

func _add(parent: Node, child: Node, node_name: String, root: Node, unique: bool = false) -> Node:
	child.name = node_name
	parent.add_child(child)
	_own(child, root)
	child.unique_name_in_owner = unique
	return child

func _label(text: String, size: int, color: Color = TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	if color != TEXT:
		label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

## Font sizes snap to the pixel font's 11 px grid; tiny sizes (progress-bar percent hiding) stay.
static func pixel_size(size: int) -> int:
	if size <= 2:
		return size
	if size <= 14:
		return 11
	if size <= 23:
		return 22
	if size <= 38:
		return 33
	if size <= 49:
		return 44
	return 55

func _restyle(node: Node, root: Node) -> void:
	if node is Control and (node == root or node.owner == root):
		var control := node as Control
		if control.has_theme_font_size_override("font_size"):
			control.add_theme_font_size_override("font_size", pixel_size(control.get_theme_font_size("font_size")))
		for key: String in ["font_color"]:
			if control.has_theme_color_override(key):
				var color: Color = control.get_theme_color(key)
				if color.is_equal_approx(OLD_CREAM):
					control.remove_theme_color_override(key)
				elif color.is_equal_approx(OLD_TEAL):
					control.add_theme_color_override(key, GOLD)
				elif color.is_equal_approx(OLD_GREY):
					control.add_theme_color_override(key, SUB)
	for child: Node in node.get_children():
		_restyle(child, root)

## Puts `column` inside a new PanelContainer named `box_name` in its place.
func _wrap(column: Control, box_name: String, variation: String, root: Node) -> PanelContainer:
	var parent: Node = column.get_parent()
	var index: int = column.get_index()
	var box := PanelContainer.new()
	box.theme_type_variation = variation
	parent.add_child(box)
	parent.move_child(box, index)
	box.name = box_name
	box.owner = root
	column.reparent(box, false)
	_own(column, root)
	return box

# --- scenes ------------------------------------------------------------------------------------------------

func _slot(path: String, side: int, node_name: String) -> void:
	var root := Panel.new()
	root.name = node_name
	root.theme_type_variation = "Slot"
	root.custom_minimum_size = Vector2(side, side + (8 if side >= 40 else 0))
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_script(load("res://scripts/weapon_slot.gd"))
	var inset: int = 4 if side >= 40 else 3
	var icon: TextureRect = _add(root, TextureRect.new(), "Icon", root, true)
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = inset
	icon.offset_top = inset
	icon.offset_right = -inset
	icon.offset_bottom = -inset - (8 if side >= 40 else 0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = load("res://assets/pixel/icons/slipper_24.png")
	var short: Label = _add(root, _label("拖鞋" if side >= 40 else "拖", 22 if side >= 40 else 11), "Short", root, true)
	short.set_anchors_preset(Control.PRESET_FULL_RECT)
	short.offset_bottom = -(8 if side >= 40 else 0)
	short.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	short.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	short.visible = false
	var pips: HBoxContainer = _add(root, HBoxContainer.new(), "Pips", root, true)
	pips.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	pips.offset_top = -9
	pips.offset_bottom = -5
	pips.alignment = BoxContainer.ALIGNMENT_CENTER
	pips.add_theme_constant_override("separation", 2)
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pips.visible = side >= 40
	_save(root, path)

func _hud() -> void:
	var root := Control.new()
	root.name = "Hud"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = load("res://data/ui_theme.tres")
	root.set_script(load("res://scripts/hud.gd"))
	root.slot_scene = load("res://scenes/weapon_slot.tscn")
	root.passive_slot_scene = load("res://scenes/passive_slot.tscn")
	# Thin XP bar across the very top.
	var xp: ProgressBar = _add(root, ProgressBar.new(), "Experience", root, true)
	xp.theme_type_variation = "XpBar"
	xp.set_anchors_preset(Control.PRESET_TOP_WIDE)
	xp.offset_bottom = 10
	xp.show_percentage = false
	xp.max_value = 5
	xp.value = 2
	xp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top: MarginContainer = _add(root, MarginContainer.new(), "SafeTop", root)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: Array in [["margin_left", 16], ["margin_top", 18], ["margin_right", 16]]:
		top.add_theme_constant_override(side[0], side[1])
	var column: VBoxContainer = _add(top, VBoxContainer.new(), "Column", root)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	var row: HBoxContainer = _add(column, HBoxContainer.new(), "Row", root)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var level: Label = _add(row, _label("Lv.1", 22, GOLD), "Level", root, true)
	level.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level.size_flags_stretch_ratio = 1.0
	var time: Label = _add(row, _label("00:00", 33), "Time", root, true)
	time.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var right: HBoxContainer = _add(row, HBoxContainer.new(), "Right", root)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.alignment = BoxContainer.ALIGNMENT_END
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pause: Button = _add(right, Button.new(), "Pause", root, true)
	pause.text = "II"
	pause.custom_minimum_size = Vector2(60, 56)
	var stats: HBoxContainer = _add(column, HBoxContainer.new(), "Stats", root)
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 10)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(stats, _label("揍飛 0", 22, SUB), "Kills", root, true)
	_add(stats, _label("·", 22, SUB), "Dot", root)
	_add(stats, _label("金幣 0", 22, SUB), "Coins", root, true)
	var elite: ProgressBar = _add(column, ProgressBar.new(), "EliteBar", root, true)
	elite.theme_type_variation = "EliteBar"
	elite.custom_minimum_size = Vector2(300, 22)
	elite.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	elite.show_percentage = false
	elite.visible = false
	elite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var elite_name: Label = _add(elite, _label("精英", 11, Color("3a210c")), "EliteName", root)
	elite_name.set_anchors_preset(Control.PRESET_FULL_RECT)
	elite_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elite_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	elite_name.add_theme_constant_override("shadow_offset_x", 0)
	elite_name.add_theme_constant_override("shadow_offset_y", 0)
	var banner: Label = _add(root, _label("下班人潮來了！", 33, GOLD), "Banner", root, true)
	banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	banner.offset_top = 250
	banner.offset_bottom = 300
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_color_override("font_outline_color", INK)
	banner.add_theme_constant_override("outline_size", 8)
	banner.visible = false
	# Bottom: combo, weapon slots, passive slots, hint.
	var bottom: MarginContainer = _add(root, MarginContainer.new(), "SafeBottom", root)
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: Array in [["margin_left", 16], ["margin_bottom", 24], ["margin_right", 16]]:
		bottom.add_theme_constant_override(side[0], side[1])
	var stack: VBoxContainer = _add(bottom, VBoxContainer.new(), "Stack", root)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 6)
	var combo: Label = _add(stack, _label("", 33, GOLD), "Combo", root, true)
	combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for line: Array in [["Weapons", 6], ["Passives", 4]]:
		var slots: HBoxContainer = _add(stack, HBoxContainer.new(), line[0], root, true)
		slots.alignment = BoxContainer.ALIGNMENT_CENTER
		slots.add_theme_constant_override("separation", line[1])
		slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hint: Label = _add(stack, _label("按住拖曳移動 · 武器自動攻擊", 11, SUB), "Hint", root)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_save(root, "res://scenes/hud.tscn")

func _screen(path: String) -> void:
	var root: Node = _open(path)
	_restyle(root, root)
	var file: String = path.get_file().get_basename()
	match file:
		"menu", "results", "pause":
			_wrap(root.get_node("Center/Column"), "Box", "", root)
		"upgrades":
			_wrap(root.get_node("Center/Column"), "Glass", "GlassPanel", root)
			var shade: ColorRect = root.get_node("Shade")
			shade.color = Color(INK, 0.45)
		"shop":
			_wrap(root.get_node("Frame/Column"), "Box", "", root)
		"upgrade_card":
			root.theme_type_variation = "GlassCard"
			root.custom_minimum_size.y = 160
			var icon: TextureRect = root.get_node("Icon")
			icon.anchor_left = 0.0
			icon.anchor_right = 0.0
			icon.anchor_top = 0.5
			icon.anchor_bottom = 0.5
			icon.offset_left = 14
			icon.offset_right = 62
			icon.offset_top = -24
			icon.offset_bottom = 24
			icon.texture = load("res://assets/pixel/icons/slipper_24.png")
			var padding: MarginContainer = root.get_node("Padding")
			padding.add_theme_constant_override("margin_left", 74)
			padding.add_theme_constant_override("margin_right", 16)
			(root.get_node("%Description") as Control).custom_minimum_size.x = 320
			var stripe: ColorRect = root.get_node("Stripe")
			stripe.offset_left = 6
			stripe.offset_right = 10
			stripe.offset_top = 8
			stripe.offset_bottom = -8
	if file == "pause":
		var toggle := CheckButton.new()
		toggle.text = "震屏"
		toggle.button_pressed = true
		toggle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var column: Node = root.get_node("Center/Box/Column")
		_add(column, toggle, "ShakeToggle", root, true)
		column.move_child(toggle, root.get_node("%Resume").get_index())
	for button: String in {"menu": ["%Start"], "results": ["%Retry"], "pause": ["%Resume"]}.get(file, []):
		(root.get_node(button) as Button).theme_type_variation = "PrimaryButton"
	_save(root, path)

## Damage numbers: one font pixel per art pixel in world space.
func _damage_number() -> void:
	var root: Node2D = _open("res://scenes/damage_number.tscn")
	root.scale = Vector2.ONE * WORLD_PIXEL
	var text: Label = root.get_node("Text")
	text.add_theme_font_size_override("font_size", 11)
	text.add_theme_constant_override("outline_size", 3)
	text.add_theme_constant_override("shadow_offset_x", 0)
	text.add_theme_constant_override("shadow_offset_y", 0)
	text.offset_left = -24
	text.offset_right = 24
	text.offset_top = -8
	text.offset_bottom = 8
	_save(root, "res://scenes/damage_number.tscn")
