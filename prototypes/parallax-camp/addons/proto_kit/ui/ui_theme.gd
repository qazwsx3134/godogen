extends RefCounted
## Texture-free themes from ui_styles.json; title/caption labels use matching type variations.
## `const UiTheme = preload("res://addons/proto_kit/ui/ui_theme.gd")`
## System fonts use the catalog family when installed, with CJK system fallbacks otherwise.

const TOKEN_PATH: String = "res://addons/proto_kit/ui/ui_styles.json"


static func tokens() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(TOKEN_PATH)) as Dictionary


static func ids() -> Array:
	return tokens().keys()


static func _box(data: Dictionary, fill: String, edge: String = "border") -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(data[fill])
	box.border_color = Color(data[edge])
	box.set_border_width_all(int(data.border_width))
	box.set_corner_radius_all(int(data.corner_radius))
	box.content_margin_left = float(data.spacing.row)
	box.content_margin_right = float(data.spacing.row)
	box.content_margin_top = float(data.spacing.row)
	box.content_margin_bottom = float(data.spacing.row)
	return box


static func build(style_id: String) -> Theme:
	var catalog: Dictionary = tokens()
	if not catalog.has(style_id):
		push_error("Unknown UI style: " + style_id)
		return null
	var data: Dictionary = catalog[style_id]
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray([data.font, "Noto Sans CJK TC", "Microsoft JhengHei", "WenQuanYi Zen Hei"])
	font.font_weight = int(data.font_weight)
	theme.default_font = font
	theme.default_font_size = int(data.font_sizes.body)
	for type: String in ["Label", "Button", "ProgressBar", "TabContainer", "TabBar"]:
		theme.set_color("font_color", type, Color(data.text))
		theme.set_font_size("font_size", type, int(data.font_sizes.body))
	for variation: String in ["TitleLabel", "CaptionLabel"]:
		theme.set_type_variation(variation, "Label")
	theme.set_font_size("font_size", "TitleLabel", int(data.font_sizes.title))
	theme.set_font_size("font_size", "CaptionLabel", int(data.font_sizes.caption))
	theme.set_color("font_color", "CaptionLabel", Color(data.text_dim))
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var fill: String = "panel"
		if state == "hover" or state == "focus":
			fill = "panel_alt"
		elif state == "pressed":
			fill = "select"
		theme.set_stylebox(state, "Button", _box(data, fill, "accent" if state == "focus" else "border"))
		theme.set_color("font_" + state + "_color", "Button", Color(data.text_dim if state == "disabled" else data.text))
	theme.set_type_variation("RoundButton", "Button")
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var rounded: StyleBoxFlat = theme.get_stylebox(state, "Button").duplicate() as StyleBoxFlat
		rounded.set_corner_radius_all(32)
		theme.set_stylebox(state, "RoundButton", rounded)
	for type: String in ["Panel", "PanelContainer"]:
		theme.set_stylebox("panel", type, _box(data, "panel"))
	theme.set_stylebox("background", "ProgressBar", _box(data, "panel_alt"))
	theme.set_stylebox("fill", "ProgressBar", _box(data, "accent", "accent"))
	theme.set_stylebox("panel", "TabContainer", _box(data, "panel"))
	for type: String in ["TabContainer", "TabBar"]:
		for state: String in ["tab_selected", "tab_unselected", "tab_hovered", "tab_disabled", "tab_focus"]:
			theme.set_stylebox(state, type, _box(data, "select" if state == "tab_selected" else "panel_alt"))
		for state: String in ["font_selected_color", "font_unselected_color", "font_hovered_color", "font_disabled_color"]:
			theme.set_color(state, type, Color(data.text_dim if state == "font_disabled_color" else data.text))
	for type: String in ["VBoxContainer", "HBoxContainer", "GridContainer"]:
		theme.set_constant("separation", type, int(data.spacing.row))
	theme.set_constant("h_separation", "GridContainer", int(data.spacing.row))
	theme.set_constant("v_separation", "GridContainer", int(data.spacing.row))
	theme.set_type_variation("SectionVBox", "VBoxContainer")
	theme.set_constant("separation", "SectionVBox", int(data.spacing.section))
	return theme
