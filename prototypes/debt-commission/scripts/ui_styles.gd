extends RefCounted
## Control styling for the skin in play (skin.gd registers each skin's look under its id). The base
## look is 銀魂和紙: washi panels (`panel_paper`), navy-and-silver framed buttons, and the in-play
## pieces (round HUD, clue tag, folded search bar, toast, QTE prompt) on the skin's `hud` resources.
## A skin with `"look": "flat"` gets plain StyleBoxes from its palette instead.

const DEFAULT_ID: String = "gintama"

## Full panels (log, save slots, chapters, case file, confirmations) on the skin's panel paper.
const PAPER_ROLES: Array[String] = ["menu", "log", "slots", "confirmation"]
## The base skin's look, used until skin.gd registers it (scenes opened in the editor, tools).
const BASE_LOOK: Dictionary = {
	"look": "washi",
	"panel_paper": "res://assets/ui/gintama_panel_paper.png",
	"plaque": "res://assets/ui/gintama_heading_plaque.png",
	"hud": {"panel": "res://assets/ui/gintama_hud/hud_panel.tres", "clue_chip": "res://assets/ui/gintama_hud/clue_chip.tres",
		"toast": "res://assets/ui/gintama_hud/toast.tres", "font": "res://assets/ui/gintama_hud/serif.tres"},
}

## Registered looks by skin id: {look, palette (merged over the base), panel_paper, plaque, hud}.
static var _looks: Dictionary = {}

const PALETTES: Dictionary = {
	"gintama": {
		"canvas": Color("#e8dfcf"),
		"panel": Color("#f4eddf"),
		"panel_soft": Color("#f7f2e8"),
		"surface": Color("#f5efe3"),
		"surface_hover": Color("#e6edf1"),
		"text": Color("#203047"),
		"muted": Color("#536174"),
		"accent": Color("#203e5e"),
		"accent_ink": Color("#f8f3e9"),
		"thought": Color("#3a5f7e"),
		"danger": Color("#963e4b"),
		"disabled": Color("#77766f"),
		"disabled_surface": Color("#ddd8ce"),
		"rule": Color("#385673"),
		"focus": Color("#183650"),
		"name_bg": Color("#203e5e"),
		"name_ink": Color("#f8f3e9"),
		"floating_bg": Color("#203e5e"),
		"floating_ink": Color("#f8f3e9"),
		"quick_text": Color("#32485d"),
		"quick_bg": Color(0.84, 0.89, 0.92, 0.18),
		"quick_active": Color("#d7e4eb"),
		"quick_active_ink": Color("#203047"),
		"scene_outline": Color(0.09, 0.16, 0.23, 0.72),
		"text_outline": Color("#f7f2e8"),
		"button_radius": 5,
		"panel_radius": 6,
		"button_border": 1,
		"panel_border": 2,
		"focus_border": 3,
	},
}


## Takes a skin's look (from skin.gd): its palette keys (CSS hex) over the base palette.
static func register_look(id: String, skin: Dictionary) -> void:
	var colors: Dictionary = (PALETTES[DEFAULT_ID] as Dictionary).duplicate()
	var own: Dictionary = skin.get("palette", {}) as Dictionary
	for key: String in own.keys():
		colors[key] = Color(str(own[key])) if own[key] is String else own[key]
	_looks[id] = {"look": str(skin.get("look", "washi")), "palette": colors,
		"panel_paper": str(skin.get("panel_paper", "")), "plaque": str(skin.get("plaque", "")),
		"hud": (skin.get("hud", {}) as Dictionary).duplicate()}


static func style_ids() -> Array[String]:
	var ids: Array[String] = [DEFAULT_ID]
	for id: String in _looks.keys():
		if not ids.has(id):
			ids.append(id)
	return ids


static func normalize_id(style_id: String) -> String:
	return style_id if _looks.has(style_id) else DEFAULT_ID


static func palette(style_id: String) -> Dictionary:
	return _look(style_id)["palette"] as Dictionary


## True for the washi family of looks (paper panels, framed buttons); false for "flat".
static func washi(style_id: String) -> bool:
	return str(_look(style_id)["look"]) == "washi"


## A HUD resource of the skin (panel, clue_chip, toast: StyleBox; font: Font), null when it has none.
static func hud_resource(style_id: String, key: String) -> Resource:
	var path: String = str((_look(style_id)["hud"] as Dictionary).get(key, ""))
	return load(path) if not path.is_empty() and ResourceLoader.exists(path) else null


static func _look(style_id: String) -> Dictionary:
	if _looks.has(style_id):
		return _looks[style_id]
	if not _looks.has(DEFAULT_ID):
		_looks[DEFAULT_ID] = {"look": "washi", "palette": PALETTES[DEFAULT_ID], "panel_paper": BASE_LOOK["panel_paper"],
			"plaque": BASE_LOOK["plaque"], "hud": BASE_LOOK["hud"]}
	return _looks[DEFAULT_ID]


static func apply_button(button: Button, style_id: String, role: String = "standard", active: bool = false, scale_factor: float = 1.0) -> void:
	var normalized: String = normalize_id(style_id)
	var density: float = maxf(1.0, scale_factor)
	button.set_meta("ui_style_role", role)
	button.set_meta("ui_style_active", active)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_stylebox_override("normal", button_style(normalized, role, "normal", active, density))
	button.add_theme_stylebox_override("hover", button_style(normalized, role, "hover", active, density))
	button.add_theme_stylebox_override("pressed", button_style(normalized, role, "pressed", active, density))
	button.add_theme_stylebox_override("hover_pressed", button_style(normalized, role, "pressed", active, density))
	button.add_theme_stylebox_override("focus", button_style(normalized, role, "focus", active, density))
	button.add_theme_stylebox_override("disabled", button_style(normalized, role, "disabled", active, density))
	var p: Dictionary = palette(normalized)
	if washi(normalized) and role in ["reading_action", "primary", "selector", "danger_action"]:
		var font: FontVariation = FontVariation.new()
		font.base_font = load("res://assets/fonts/NotoSerifTC.ttf")
		font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 500.0}
		button.add_theme_font_override("font", font)
	var regular_ink: Color = _button_ink(p, role, active, "normal", washi(normalized))
	button.add_theme_color_override("font_color", regular_ink)
	button.add_theme_color_override("font_hover_color", _button_ink(p, role, active, "hover", washi(normalized)))
	button.add_theme_color_override("font_pressed_color", _button_ink(p, role, active, "pressed", washi(normalized)))
	button.add_theme_color_override("font_focus_color", regular_ink)
	button.add_theme_color_override("font_disabled_color", _button_ink(p, role, active, "disabled", washi(normalized)))


static func button_style(style_id: String, role: String, state: String, active: bool = false, scale_factor: float = 1.0) -> StyleBoxFlat:
	if washi(style_id) and role in ["reading_action", "primary", "selector", "danger_action"]:
		var frame: StyleBoxFlat = StyleBoxFlat.new()
		frame.bg_color = Color("#08283d") if not active else Color("#275978")
		frame.border_color = Color("#bfc7ce")
		if state in ["hover", "focus"]:
			frame.bg_color = Color("#204d6a")
			frame.border_color = Color("#d7c18b")
		elif state == "pressed":
			frame.bg_color = Color("#326582")
		elif state == "disabled":
			frame.bg_color = Color("#344553")
			frame.border_color = Color("#6a7b87")
		frame.set_border_width_all(2 if state != "focus" else 3)
		frame.set_corner_radius_all(17)
		frame.content_margin_left = 18.0
		frame.content_margin_right = 18.0
		frame.content_margin_top = 10.0
		frame.content_margin_bottom = 10.0
		return frame
	var p: Dictionary = palette(style_id)
	var density: float = maxf(1.0, scale_factor)
	var is_primary: bool = role in ["primary", "boke_primary", "danger_action", "menu_primary"]
	var is_selector: bool = role == "selector"
	var normal_bg: Color = p["surface"] as Color
	var normal_border: Color = p["rule"] as Color
	var hover_bg: Color = p["surface_hover"] as Color
	var hover_border: Color = p["accent"] as Color
	var pressed_bg: Color = p["accent"] as Color
	var pressed_border: Color = p["focus"] as Color
	var border_width: int = int(p["button_border"])
	var radius: int = int(p["button_radius"])
	var margins: Vector4 = Vector4(12.0, 8.0, 12.0, 8.0) * density

	if role == "quickbar":
		normal_bg = p["quick_active"] as Color if active else Color.TRANSPARENT
		normal_border = p["accent"] as Color if active else Color.TRANSPARENT
		hover_bg = Color((p["accent"] as Color).r, (p["accent"] as Color).g, (p["accent"] as Color).b, 0.14) if not active else (p["quick_active"] as Color).lightened(0.08)
		hover_border = p["rule"] as Color if not active else p["focus"] as Color
		pressed_bg = p["accent"] as Color
		pressed_border = p["focus"] as Color
		border_width = 0 if not active else maxi(1, roundi(float(p["button_border"]) * density))
		radius = 0 if style_id == "cinema" else radius
		margins = Vector4(8.0, 4.0, 8.0, 4.0) * density
	elif role == "advance":
		margins = Vector4(0.0, 0.0, 0.0, 0.0)
		if style_id == "cinema":
			normal_bg = Color.TRANSPARENT
			normal_border = Color.TRANSPARENT
			hover_bg = Color(0.66, 0.82, 0.81, 0.12)
			hover_border = p["accent"] as Color
			pressed_bg = Color(0.66, 0.82, 0.81, 0.2)
			border_width = 0
		elif style_id == "ledger":
			normal_bg = p["accent"] as Color
			normal_border = Color("#fff2d8")
			hover_bg = (p["accent"] as Color).lightened(0.1)
			hover_border = p["focus"] as Color
			pressed_bg = (p["accent"] as Color).darkened(0.12)
			border_width = maxi(1, roundi(2.0 * density))
			radius = roundi(99.0 * density)
		elif washi(style_id):
			normal_bg = p["panel"] as Color
			normal_border = p["accent"] as Color
			hover_bg = p["surface_hover"] as Color
			hover_border = p["focus"] as Color
			pressed_bg = p["accent"] as Color
			pressed_border = p["focus"] as Color
			border_width = maxi(2, roundi(2.0 * density))
			radius = roundi(24.0 * density)
		else:
			normal_bg = p["accent"] as Color
			normal_border = p["text"] as Color
			hover_bg = (p["accent"] as Color).lightened(0.12)
			hover_border = p["text"] as Color
			pressed_bg = (p["accent"] as Color).darkened(0.1)
			border_width = maxi(2, roundi(2.0 * density))
	elif role in ["menu", "menu_toggle"]:
		if style_id == "cinema":
			normal_bg = Color.TRANSPARENT
			normal_border = Color(0.82, 0.88, 0.84, 0.25)
			hover_bg = Color(0.66, 0.82, 0.81, 0.11)
			hover_border = Color(0.66, 0.82, 0.81, 0.55)
		elif style_id == "ledger":
			normal_bg = Color.TRANSPARENT
			normal_border = p["rule"] as Color
			hover_bg = Color(0.66, 0.26, 0.18, 0.07)
			hover_border = p["accent"] as Color
		else:
			normal_bg = p["surface"] as Color
			normal_border = p["text"] as Color
			hover_bg = p["surface_hover"] as Color
			hover_border = p["accent"] as Color
		if role == "menu_toggle" and active:
			normal_bg = Color((p["accent"] as Color).r, (p["accent"] as Color).g, (p["accent"] as Color).b, 0.15)
			normal_border = p["accent"] as Color
			pressed_bg = p["accent"] as Color
		border_width = maxi(1, roundi(float(p["button_border"]) * density))
		margins = Vector4(12.0, 6.0, 12.0, 6.0) * density
	elif role == "choice":
		if style_id == "cinema":
			normal_bg = Color(0.95, 0.95, 0.9, 0.08)
			normal_border = Color(0.85, 0.89, 0.86, 0.28)
			hover_bg = Color(0.76, 0.87, 0.85, 0.17)
			hover_border = p["accent"] as Color
		elif washi(style_id):
			normal_bg = p["surface"] as Color
			normal_border = p["rule"] as Color
			hover_bg = p["surface_hover"] as Color
			hover_border = p["accent"] as Color
			border_width = maxi(1, roundi(density))
		elif style_id == "ledger":
			normal_bg = Color.TRANSPARENT
			normal_border = p["rule"] as Color
			hover_bg = Color(0.66, 0.26, 0.18, 0.08)
			hover_border = p["accent"] as Color
			border_width = maxi(1, roundi(density))
		else:
			normal_bg = Color("#fcfbf6")
			normal_border = p["text"] as Color
			hover_bg = Color("#fff6c6")
			hover_border = p["accent"] as Color
			border_width = maxi(2, roundi(2.0 * density))
		margins = Vector4(10.0, 5.0, 10.0, 5.0) * density
	elif role == "choice_menu":
		if style_id == "ledger":
			normal_bg = p["accent"] as Color
			normal_border = Color("#782f24")
			border_width = maxi(1, roundi(density))
		elif style_id == "manga":
			normal_bg = p["surface"] as Color
			normal_border = p["text"] as Color
			border_width = maxi(2, roundi(2.0 * density))
		elif washi(style_id):
			normal_bg = p["panel"] as Color
			normal_border = p["rule"] as Color
			hover_bg = p["surface_hover"] as Color
			hover_border = p["accent"] as Color
			border_width = maxi(1, roundi(density))
		else:
			normal_bg = Color.TRANSPARENT
			normal_border = Color(0.82, 0.88, 0.84, 0.55)
			border_width = maxi(1, roundi(density))
		margins = Vector4(10.0, 5.0, 10.0, 5.0) * density
	elif role == "subtle":
		normal_bg = Color(0, 0, 0, 0)
		normal_border = p["rule"] as Color
		hover_bg = p["surface_hover"] as Color
		hover_border = p["accent"] as Color
		margins = Vector4(10.0, 6.0, 10.0, 6.0) * density
	elif is_primary:
		normal_bg = p["accent"] as Color
		normal_border = p["focus"] as Color
		hover_bg = (p["accent"] as Color).lightened(0.1)
		hover_border = p["focus"] as Color
		pressed_bg = (p["accent"] as Color).darkened(0.12)
		pressed_border = p["focus"] as Color
		border_width = maxi(1, roundi(float(p["button_border"]) * density))
	elif is_selector and active:
		normal_bg = p["accent"] as Color
		normal_border = p["focus"] as Color
		hover_bg = (p["accent"] as Color).lightened(0.1)
		hover_border = p["focus"] as Color
		pressed_bg = (p["accent"] as Color).darkened(0.1)
		pressed_border = p["focus"] as Color
		border_width = maxi(2, roundi(float(p["button_border"]) * density))
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
	result.set_border_width_all(roundi(float(state_width) * density))
	if role == "advance" and style_id == "cinema":
		result.border_width_left = maxi(1, roundi(density)) if state != "normal" else 0
	if role == "menu" and style_id != "manga":
		result.border_width_left = 0
		result.border_width_top = 0 if style_id == "cinema" else maxi(1, roundi(density))
		result.border_width_right = 0
	if role == "choice" and style_id == "ledger":
		result.border_width_left = 0
		result.border_width_top = 0
		result.border_width_right = 0
	result.set_corner_radius_all(roundi(float(radius) * density))
	result.content_margin_left = margins.x
	result.content_margin_top = margins.y
	result.content_margin_right = margins.z
	result.content_margin_bottom = margins.w
	if washi(style_id) and role in ["standard", "slot_card", "slot_card_empty", "slot_card_invalid"]:
		# Paper chips with a navy rule, as in settings_panel_gintama.tscn.
		result.set_border_width_all(roundi(float(3 if state in ["hover", "focus"] else 2) * density))
		result.set_corner_radius_all(roundi(17.0 * density))
		result.shadow_color = Color(0.03, 0.09, 0.14, 0.22) if state != "focus" else Color(0, 0, 0, 0)
		result.shadow_size = roundi(3.0 * density)
		result.shadow_offset = Vector2(0.0, 4.0) * density
	if style_id == "manga" and role not in ["quickbar", "subtle", "advance"]:
		result.shadow_color = Color(0.08, 0.08, 0.07, 0.22)
		result.shadow_size = 2 if state != "disabled" else 0
		result.shadow_size = roundi(float(result.shadow_size) * density)
		result.shadow_offset = Vector2(2.0, 2.0) * density
	return result


static func panel_style(style_id: String, role: String, scale_factor: float = 1.0) -> StyleBoxFlat:
	var p: Dictionary = palette(style_id)
	var density: float = maxf(1.0, scale_factor)
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
	result.set_border_width_all(roundi(float(border_width) * density))
	if style_id == "ledger" and role in ["menu", "log", "slots", "confirmation", "title_selector"]:
		result.border_width_left = maxi(3, roundi(float(border_width) * density))
		result.border_color = p["accent"] as Color
	if role == "dialogue":
		result.border_width_top = maxi(1, roundi(float(p["panel_border"]) * density))
		if style_id == "ledger":
			result.border_width_left = roundi(6.0 * density)
		elif style_id == "manga":
			result.border_width_top = roundi(5.0 * density)
	result.set_corner_radius_all(roundi(float(radius) * density))
	result.content_margin_left = margins.x * density
	result.content_margin_top = margins.y * density
	result.content_margin_right = margins.z * density
	result.content_margin_bottom = margins.w * density
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


## WCAG contrast ratio between two colours (1 to 21).
static func contrast(a: Color, b: Color) -> float:
	var la: float = _luminance(a)
	var lb: float = _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _luminance(c: Color) -> float:
	var ch: Array[float] = []
	for v: float in [c.r, c.g, c.b]:
		ch.append(v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4))
	return 0.2126 * ch[0] + 0.7152 * ch[1] + 0.0729 * ch[2]


## A character's name colour readable on the paper panels: `ink` if the catalog gives one, else `color` darkened
## until it reaches 4.5:1 against the style's panel colour (body text, WCAG AA).
static func ink_for(info: Dictionary, style_id: String) -> Color:
	var ground: Color = palette(style_id)["panel"] as Color
	if str(info.get("ink", "")).is_valid_html_color():
		return Color(str(info["ink"]))
	var c: Color = Color(str(info.get("color", "#203047")))
	for i: int in 40:
		if contrast(c, ground) >= 4.5:
			break
		c = c.darkened(0.06)
	return c


static func apply_label(label: Label, style_id: String, role: String = "body", scale_factor: float = 1.0) -> void:
	var p: Dictionary = palette(style_id)
	var density: float = maxf(1.0, scale_factor)
	label.set_meta("ui_style_role", role)
	label.add_theme_color_override("font_color", label_color(style_id, role))
	# A character's own ink (dialogue log names) wins over the role colour, on the washi looks only.
	if label.has_meta("ui_style_ink") and washi(style_id):
		label.add_theme_color_override("font_color", label.get_meta("ui_style_ink") as Color)
	if role in ["scene_overlay", "title_overlay"]:
		label.add_theme_color_override("font_outline_color", p["scene_outline"] as Color)
		label.add_theme_constant_override("outline_size", roundi((5.0 if role == "title_overlay" else 4.0) * density))
	else:
		label.add_theme_color_override("font_outline_color", p["text_outline"] as Color)
		label.add_theme_constant_override("outline_size", roundi(1.0 * density))
	if role == "toast":
		var toast: StyleBox = hud_resource(style_id, "toast") as StyleBox
		if toast != null:
			label.add_theme_stylebox_override("normal", toast)
			label.add_theme_color_override("font_color", p["name_ink"] as Color)
			label.add_theme_constant_override("outline_size", 0)
		else:
			label.add_theme_stylebox_override("normal", panel_style(style_id, "toast", density))
	if role in ["toast", "scene_overlay"]:
		set_hud_font(label, style_id)


static func apply_panel(panel: Control, style_id: String, role: String = "menu", scale_factor: float = 1.0) -> void:
	panel.set_meta("ui_style_role", role)
	if role in PAPER_ROLES and not str(_look(style_id)["panel_paper"]).is_empty():
		panel.add_theme_stylebox_override("panel", paper(style_id, panel_style(style_id, role, scale_factor)))
		return
	panel.add_theme_stylebox_override("panel", panel_style(style_id, role, scale_factor))


## The skin's panel paper (gintama_panel_paper.png: frame, waves and blossoms kept whole in the
## corners), with the content margins of `flat`.
static func paper(style_id: String, flat: StyleBox) -> StyleBoxTexture:
	var paper: StyleBoxTexture = StyleBoxTexture.new()
	paper.texture = load(str(_look(style_id)["panel_paper"])) as Texture2D
	paper.texture_margin_left = 280.0
	paper.texture_margin_top = 140.0
	paper.texture_margin_right = 245.0
	paper.texture_margin_bottom = 122.0
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		paper.set_content_margin(side, maxf(flat.get_content_margin(side), 24.0))
	return paper


## A title plaque (第 N 章 on a chapter card, a name on the case file): the skin's `plaque` picture
## (the navy plaque with the cloud), or its name tag when it has none. Its label takes `name_ink`.
static func name_plaque(style_id: String) -> StyleBox:
	var plaque: String = str(_look(style_id)["plaque"])
	if plaque.is_empty():
		return panel_style(style_id, "name")
	var box: StyleBoxTexture = StyleBoxTexture.new()
	box.texture = load(plaque) as Texture2D
	box.texture_margin_left = 60.0
	box.texture_margin_right = 30.0
	box.texture_margin_top = 20.0
	box.texture_margin_bottom = 20.0
	box.content_margin_left = 72.0
	box.content_margin_right = 48.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	return box


## The skin's HUD font on an in-play label or button; the game font when it has none.
static func set_hud_font(control: Control, style_id: String) -> void:
	var font: Font = hud_resource(style_id, "font") as Font
	if font != null:
		control.add_theme_font_override("font", font)
	else:
		control.remove_theme_font_override("font")


static func contrast_ratio(foreground: Color, background: Color) -> float:
	var first: float = _relative_luminance(foreground)
	var second: float = _relative_luminance(background)
	var brighter: float = maxf(first, second)
	var darker: float = minf(first, second)
	return (brighter + 0.05) / (darker + 0.05)


static func _button_ink(p: Dictionary, role: String, active: bool, state: String, framed: bool = false) -> Color:
	if framed and role in ["reading_action", "primary", "selector", "danger_action"]:
		return Color("#99a8b3") if state == "disabled" else Color("#f8f3e9")
	if state == "disabled":
		return p["disabled"] as Color
	if framed and state == "pressed":
		return p["accent_ink"] as Color
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
