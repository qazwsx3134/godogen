extends RefCounted
## Shared palette and Control styling for the three selectable presentation styles.

const DEFAULT_ID: String = "cinema"
const PREFERENCE_PATH: String = "user://ui_preferences.cfg"
const LABELS: Dictionary = {
	"cinema": "月下映畫",
	"ledger": "萬事屋委託簿",
	"manga": "吐槽分鏡",
}

const PALETTES: Dictionary = {
	"cinema": {
		"canvas": Color("#0b0d18"),
		"panel": Color("#0d1722"),
		"panel_soft": Color(0.035, 0.065, 0.095, 0.94),
		"surface": Color("#15232f"),
		"surface_hover": Color("#203541"),
		"text": Color("#f4f1e9"),
		"muted": Color("#c1cccf"),
		"accent": Color("#a9d0cf"),
		"accent_ink": Color("#13262b"),
		"thought": Color("#a9c8f3"),
		"danger": Color("#ffb2a1"),
		"disabled": Color("#84939b"),
		"disabled_surface": Color("#26333b"),
		"rule": Color("#77999b"),
		"focus": Color("#d4efeb"),
		"name_bg": Color("#547f82"),
		"name_ink": Color("#f5f4ec"),
		"floating_bg": Color("#15232f"),
		"floating_ink": Color("#f4f1e9"),
		"quick_text": Color("#d4ddda"),
		"quick_bg": Color(0.04, 0.075, 0.105, 0.2),
		"quick_active": Color("#a9d0cf"),
		"quick_active_ink": Color("#13262b"),
		"scene_outline": Color(0.015, 0.025, 0.04, 0.96),
		"text_outline": Color(0.015, 0.025, 0.04, 0.92),
		"button_radius": 5,
		"panel_radius": 8,
		"button_border": 1,
		"panel_border": 1,
		"focus_border": 3,
	},
	"ledger": {
		"canvas": Color("#e3dac8"),
		"panel": Color("#f2e8d2"),
		"panel_soft": Color("#eee3cc"),
		"surface": Color("#e7dbc3"),
		"surface_hover": Color("#f8efde"),
		"text": Color("#382f28"),
		"muted": Color("#6d5c47"),
		"accent": Color("#a94432"),
		"accent_ink": Color("#fff7e8"),
		"thought": Color("#66533f"),
		"danger": Color("#8f2d22"),
		"disabled": Color("#766f64"),
		"disabled_surface": Color("#d9cfbc"),
		"rule": Color("#a99773"),
		"focus": Color("#842e23"),
		"name_bg": Color("#a94432"),
		"name_ink": Color("#fff7e8"),
		"floating_bg": Color("#a94432"),
		"floating_ink": Color("#fff7e8"),
		"quick_text": Color("#665642"),
		"quick_bg": Color(0.53, 0.4, 0.25, 0.0),
		"quick_active": Color("#a94432"),
		"quick_active_ink": Color("#fff7e8"),
		"scene_outline": Color(0.12, 0.075, 0.045, 0.96),
		"text_outline": Color("#f2e8d2"),
		"button_radius": 2,
		"panel_radius": 2,
		"button_border": 1,
		"panel_border": 1,
		"focus_border": 3,
	},
	"manga": {
		"canvas": Color("#222320"),
		"panel": Color("#f5f3e9"),
		"panel_soft": Color("#f0eee4"),
		"surface": Color("#fbfaf4"),
		"surface_hover": Color("#fff2a9"),
		"text": Color("#242522"),
		"muted": Color("#555650"),
		"accent": Color("#b83424"),
		"accent_ink": Color("#fff9eb"),
		"thought": Color("#444641"),
		"danger": Color("#a3291d"),
		"disabled": Color("#62635d"),
		"disabled_surface": Color("#d9d8d0"),
		"rule": Color("#242522"),
		"focus": Color("#d8a900"),
		"name_bg": Color("#ffdc41"),
		"name_ink": Color("#242522"),
		"floating_bg": Color("#ffdc41"),
		"floating_ink": Color("#242522"),
		"quick_text": Color("#41433e"),
		"quick_bg": Color(0.96, 0.95, 0.9, 0.22),
		"quick_active": Color("#ffdc41"),
		"quick_active_ink": Color("#242522"),
		"scene_outline": Color(0.06, 0.06, 0.055, 0.96),
		"text_outline": Color("#f5f3e9"),
		"button_radius": 0,
		"panel_radius": 0,
		"button_border": 2,
		"panel_border": 2,
		"focus_border": 4,
	},
}


static func style_ids() -> Array[String]:
	return ["cinema", "ledger", "manga"]


static func normalize_id(style_id: String) -> String:
	return style_id if PALETTES.has(style_id) else DEFAULT_ID


static func style_label(style_id: String) -> String:
	return str(LABELS.get(normalize_id(style_id), LABELS[DEFAULT_ID]))


static func palette(style_id: String) -> Dictionary:
	return PALETTES[normalize_id(style_id)] as Dictionary


static func load_preference(path: String = PREFERENCE_PATH) -> String:
	var config: ConfigFile = ConfigFile.new()
	if config.load(path) != OK:
		return DEFAULT_ID
	return normalize_id(str(config.get_value("ui", "style", DEFAULT_ID)))


static func save_preference(style_id: String, path: String = PREFERENCE_PATH) -> Error:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("ui", "style", normalize_id(style_id))
	return config.save(path)


static func apply_button(button: Button, style_id: String, role: String = "standard", active: bool = false) -> void:
	var normalized: String = normalize_id(style_id)
	button.set_meta("ui_style_role", role)
	button.set_meta("ui_style_active", active)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_stylebox_override("normal", button_style(normalized, role, "normal", active))
	button.add_theme_stylebox_override("hover", button_style(normalized, role, "hover", active))
	button.add_theme_stylebox_override("pressed", button_style(normalized, role, "pressed", active))
	button.add_theme_stylebox_override("hover_pressed", button_style(normalized, role, "pressed", active))
	button.add_theme_stylebox_override("focus", button_style(normalized, role, "focus", active))
	button.add_theme_stylebox_override("disabled", button_style(normalized, role, "disabled", active))
	var p: Dictionary = palette(normalized)
	var regular_ink: Color = _button_ink(p, role, active, "normal")
	button.add_theme_color_override("font_color", regular_ink)
	button.add_theme_color_override("font_hover_color", _button_ink(p, role, active, "hover"))
	button.add_theme_color_override("font_pressed_color", _button_ink(p, role, active, "pressed"))
	button.add_theme_color_override("font_focus_color", regular_ink)
	button.add_theme_color_override("font_disabled_color", p["disabled"] as Color)


static func button_style(style_id: String, role: String, state: String, active: bool = false) -> StyleBoxFlat:
	var p: Dictionary = palette(style_id)
	var is_primary: bool = role in ["primary", "boke_primary", "danger_action"]
	var is_selector: bool = role == "selector"
	var normal_bg: Color = p["surface"] as Color
	var normal_border: Color = p["rule"] as Color
	var hover_bg: Color = p["surface_hover"] as Color
	var hover_border: Color = p["accent"] as Color
	var pressed_bg: Color = p["accent"] as Color
	var pressed_border: Color = p["focus"] as Color
	var border_width: int = int(p["button_border"])
	var radius: int = int(p["button_radius"])
	var margins: Vector4 = Vector4(24.0, 12.0, 24.0, 12.0)

	if role == "quickbar":
		normal_bg = p["quick_active"] as Color if active else p["quick_bg"] as Color
		normal_border = p["accent"] as Color if active else Color(0, 0, 0, 0)
		hover_bg = p["surface_hover"] as Color if not active else (p["quick_active"] as Color).lightened(0.08)
		hover_border = p["rule"] as Color if not active else p["focus"] as Color
		pressed_bg = p["accent"] as Color
		pressed_border = p["focus"] as Color
		border_width = 0 if not active else maxi(1, int(p["button_border"]))
		radius = 0 if style_id == "cinema" else radius
		margins = Vector4(8.0, 8.0, 8.0, 8.0)
	elif role == "subtle":
		normal_bg = Color(0, 0, 0, 0)
		normal_border = p["rule"] as Color
		hover_bg = p["surface_hover"] as Color
		hover_border = p["accent"] as Color
		margins = Vector4(16.0, 8.0, 16.0, 8.0)
	elif is_primary:
		normal_bg = p["accent"] as Color
		normal_border = p["focus"] as Color
		hover_bg = (p["accent"] as Color).lightened(0.1)
		hover_border = p["focus"] as Color
		pressed_bg = (p["accent"] as Color).darkened(0.12)
		pressed_border = p["focus"] as Color
		border_width = maxi(1, int(p["button_border"]))
	elif is_selector and active:
		normal_bg = p["accent"] as Color
		normal_border = p["focus"] as Color
		hover_bg = (p["accent"] as Color).lightened(0.1)
		hover_border = p["focus"] as Color
		pressed_bg = (p["accent"] as Color).darkened(0.1)
		pressed_border = p["focus"] as Color
		border_width = maxi(2, int(p["button_border"]))
	elif role == "slot_card_empty":
		normal_bg = p["panel_soft"] as Color
		normal_border = p["rule"] as Color
		hover_bg = p["surface_hover"] as Color
		hover_border = p["accent"] as Color
	elif role == "slot_card_invalid":
		normal_bg = p["surface"] as Color
		normal_border = p["danger"] as Color
		hover_bg = p["surface_hover"] as Color
		hover_border = p["danger"] as Color
		pressed_bg = p["danger"] as Color
		pressed_border = p["focus"] as Color

	var result: StyleBoxFlat = StyleBoxFlat.new()
	var fill: Color = normal_bg
	var border: Color = normal_border
	var state_width: int = border_width
	match state:
		"hover":
			fill = hover_bg
			border = hover_border
		"pressed":
			fill = pressed_bg
			border = pressed_border
		"focus":
			fill = normal_bg
			border = p["focus"] as Color
			state_width = int(p["focus_border"])
		"disabled":
			fill = p["disabled_surface"] as Color
			border = p["disabled"] as Color
			state_width = maxi(1, int(p["button_border"]))
	if role in ["quickbar", "subtle"] and state in ["normal", "disabled"] and not active:
		state_width = 0 if role == "quickbar" else state_width
	result.bg_color = fill
	# Focus is drawn over the current button state; only add its ring.
	result.draw_center = state != "focus"
	result.border_color = border
	result.set_border_width_all(state_width)
	result.set_corner_radius_all(radius)
	result.content_margin_left = margins.x
	result.content_margin_top = margins.y
	result.content_margin_right = margins.z
	result.content_margin_bottom = margins.w
	if style_id == "manga" and role not in ["quickbar", "subtle"]:
		result.shadow_color = Color(0.08, 0.08, 0.07, 0.22)
		result.shadow_size = 2 if state != "disabled" else 0
		result.shadow_offset = Vector2(2.0, 2.0)
	return result


static func panel_style(style_id: String, role: String) -> StyleBoxFlat:
	var p: Dictionary = palette(style_id)
	var result: StyleBoxFlat = StyleBoxFlat.new()
	var background: Color = p["panel"] as Color
	var border: Color = p["rule"] as Color
	var border_width: int = int(p["panel_border"])
	var radius: int = int(p["panel_radius"])
	var margins: Vector4 = Vector4(20.0, 14.0, 20.0, 14.0)
	match role:
		"dialogue":
			background = p["panel_soft"] as Color
			border = p["accent"] as Color
			border_width = 0
			result.border_width_top = maxi(1, int(p["panel_border"]))
			radius = 0
			margins = Vector4(48.0, 24.0, 48.0, 24.0)
		"name", "name_thought":
			background = p["name_bg"] as Color
			border = p["accent"] as Color
			border_width = 1 if style_id != "manga" else 2
			radius = 0 if style_id == "manga" else int(p["button_radius"])
			margins = Vector4(10.0, 2.0, 10.0, 2.0)
		"hud":
			background = p["panel_soft"] as Color
			border = p["rule"] as Color
			border_width = maxi(1, int(p["panel_border"]))
		"menu", "log", "slots", "confirmation", "toast", "title_selector":
			background = p["panel"] as Color
			border = p["rule"] as Color
			border_width = maxi(1, int(p["panel_border"]))
			margins = Vector4(24.0, 18.0, 24.0, 18.0)
	if style_id == "manga" and role not in ["dialogue", "name", "name_thought"]:
		result.shadow_color = Color(0.05, 0.05, 0.04, 0.3)
		result.shadow_size = 5
		result.shadow_offset = Vector2(5.0, 5.0)
	result.bg_color = background
	result.border_color = border
	result.set_border_width_all(border_width)
	if style_id == "ledger" and role in ["menu", "log", "slots", "confirmation", "title_selector"]:
		result.border_width_left = maxi(3, border_width)
		result.border_color = p["accent"] as Color
	if role == "dialogue":
		result.border_width_top = maxi(1, int(p["panel_border"]))
		if style_id == "ledger":
			result.border_width_left = 6
		elif style_id == "manga":
			result.border_width_top = 5
	result.set_corner_radius_all(radius)
	result.content_margin_left = margins.x
	result.content_margin_top = margins.y
	result.content_margin_right = margins.z
	result.content_margin_bottom = margins.w
	return result


static func label_color(style_id: String, role: String) -> Color:
	var p: Dictionary = palette(style_id)
	match role:
		"scene_overlay", "title_overlay":
			return Color("#fffdf5")
		"accent":
			return p["accent"] as Color
		"thought":
			return p["thought"] as Color
		"muted":
			return p["muted"] as Color
		"quickbar":
			return p["quick_text"] as Color
		"speaker":
			return p["name_ink"] as Color
		"danger":
			return p["danger"] as Color
		"disabled":
			return p["disabled"] as Color
		_:
			return p["text"] as Color


static func apply_label(label: Label, style_id: String, role: String = "body") -> void:
	var p: Dictionary = palette(style_id)
	label.set_meta("ui_style_role", role)
	label.add_theme_color_override("font_color", label_color(style_id, role))
	if role in ["scene_overlay", "title_overlay"]:
		label.add_theme_color_override("font_outline_color", p["scene_outline"] as Color)
		label.add_theme_constant_override("outline_size", 5 if role == "title_overlay" else 4)
	else:
		label.add_theme_color_override("font_outline_color", p["text_outline"] as Color)
		label.add_theme_constant_override("outline_size", 2)
	if role == "toast":
		label.add_theme_stylebox_override("normal", panel_style(style_id, "toast"))


static func apply_panel(panel: Panel, style_id: String, role: String = "menu") -> void:
	panel.set_meta("ui_style_role", role)
	panel.add_theme_stylebox_override("panel", panel_style(style_id, role))


static func contrast_ratio(foreground: Color, background: Color) -> float:
	var first: float = _relative_luminance(foreground)
	var second: float = _relative_luminance(background)
	var brighter: float = maxf(first, second)
	var darker: float = minf(first, second)
	return (brighter + 0.05) / (darker + 0.05)


static func _button_ink(p: Dictionary, role: String, active: bool, state: String) -> Color:
	if state == "disabled":
		return p["disabled"] as Color
	if role == "quickbar":
		return p["quick_active_ink"] as Color if active else p["quick_text"] as Color
	if role in ["primary", "boke_primary", "danger_action"]:
		return p["accent_ink"] as Color
	if role == "selector" and active:
		return p["accent_ink"] as Color
	return p["text"] as Color


static func _relative_luminance(color: Color) -> float:
	var red: float = _linear_component(color.r)
	var green: float = _linear_component(color.g)
	var blue: float = _linear_component(color.b)
	return 0.2126 * red + 0.7152 * green + 0.0722 * blue


static func _linear_component(value: float) -> float:
	return value / 12.92 if value <= 0.04045 else pow((value + 0.055) / 1.055, 2.4)
