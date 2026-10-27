extends SceneTree
## Restyles ui/theme.tres (the push's HUD, result, push report, pause menu, settings panel) in the home screen's
## Taskbar Hero look, applied 2026-10-27: paper panels with a brown edge, dark ink text (white with an outline only on
## the battlefield: FieldLabel), blue buttons, gold primary buttons and selected tabs, Noto Sans CJK, red HP, gold
## morale and green EXP bars. It replaces the theme's styles in place, so every scene using the theme follows. Can be
## rerun (it sets the same values again).
##   godot --headless --path prototypes/hero-horde-idle --script res://tools/theme_taskbar.gd

const THEME := "res://ui/theme.tres"
const BOLD := "res://fonts/NotoSansCJKtc-Bold.otf"
const MEDIUM := "res://fonts/NotoSansCJKtc-Medium.otf"
const INK := Color("4a3424")
const DIM := Color("7a6650")
const PAPER := Color("ead5bd")
const PAPER_DARK := Color("d9bf9c")
const EDGE := Color("a9804f")
const BLUE := Color("3f5f9e")
const BLUE_EDGE := Color("223a6b")
const GOLD := Color("f2c75a")
const GOLD_EDGE := Color("a8792a")
const DISABLED := Color("9c9184")


func _initialize() -> void:
	var theme: Theme = load(THEME)
	theme.default_font = load(MEDIUM)
	theme.set_font(&"font", &"Heading", load(BOLD))
	theme.set_font(&"font", &"PrimaryButton", load(BOLD))
	theme.set_font(&"font", &"Button", load(BOLD))
	# Text: ink on paper; on the battlefield white with a dark outline.
	theme.set_color(&"font_color", &"Label", INK)
	theme.set_color(&"font_outline_color", &"Label", Color("1d2433"))
	theme.set_constant(&"outline_size", &"Label", 0)
	theme.set_color(&"font_color", &"Dim", DIM)
	theme.set_color(&"font_color", &"FieldLabel", Color.WHITE)
	theme.set_color(&"font_outline_color", &"FieldLabel", Color("1d2433"))
	theme.set_constant(&"outline_size", &"FieldLabel", 8)
	# Panels.
	var paper: StyleBoxFlat = _box(PAPER, EDGE, 4, 12, 18)
	paper.shadow_color = Color(0, 0, 0, 0.35)
	paper.shadow_size = 6
	for type: StringName in [&"PanelContainer", &"HudPanel", &"Dialog"]:
		theme.set_stylebox(&"panel", type, paper)
	theme.set_stylebox(&"panel", &"Pill", _box(PAPER_DARK, EDGE, 2, 16, 10))
	theme.set_stylebox(&"panel", &"ScrollContainer", StyleBoxEmpty.new())
	# Buttons: blue; primary gold with ink; tabs blue, gold when chosen; flat ink; cards paper.
	_buttons(theme, &"Button", BLUE, BLUE_EDGE, Color.WHITE)
	_buttons(theme, &"PrimaryButton", GOLD, GOLD_EDGE, INK)
	_buttons(theme, &"PartButton", BLUE, BLUE_EDGE, Color.WHITE)
	_buttons(theme, &"TabButton", BLUE, BLUE_EDGE, Color.WHITE)
	theme.set_stylebox(&"pressed", &"TabButton", _box(GOLD, GOLD_EDGE, 3, 10, 12))
	theme.set_stylebox(&"hover_pressed", &"TabButton", _box(GOLD.lightened(0.1), GOLD_EDGE, 3, 10, 12))
	theme.set_color(&"font_pressed_color", &"TabButton", INK)
	theme.set_color(&"font_hover_pressed_color", &"TabButton", INK)
	for state: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
		theme.set_stylebox(state, &"FlatButton", StyleBoxEmpty.new())
	var card: StyleBoxFlat = _box(Color("f3e4cf"), EDGE, 3, 10, 8)
	theme.set_stylebox(&"normal", &"CardButton", card)
	theme.set_stylebox(&"hover", &"CardButton", _box(Color("fbefdc"), GOLD_EDGE, 3, 10, 8))
	theme.set_stylebox(&"pressed", &"CardButton", _box(Color("fbefdc"), GOLD_EDGE, 5, 10, 8))
	theme.set_stylebox(&"hover_pressed", &"CardButton", _box(Color("fbefdc"), GOLD_EDGE, 5, 10, 8))
	for c: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color", &"font_focus_color"]:
		theme.set_color(c, &"CardButton", INK)
		theme.set_color(c, &"FlatButton", INK)
	# Bars.
	theme.set_stylebox(&"background", &"ProgressBar", _box(Color("3b2f25"), Color("2a211a"), 2, 6, 0))
	theme.set_stylebox(&"fill", &"ProgressBar", _box(Color("7fbf5a"), Color(0, 0, 0, 0), 0, 6, 0))
	theme.set_stylebox(&"fill", &"HpBar", _box(Color("d9573f"), Color(0, 0, 0, 0), 0, 6, 0))
	theme.set_stylebox(&"fill", &"MoraleBar", _box(GOLD, Color(0, 0, 0, 0), 0, 6, 0))
	theme.set_stylebox(&"fill", &"ExpBar", _box(Color("7fbf5a"), Color(0, 0, 0, 0), 0, 6, 0))
	var line := StyleBoxLine.new()
	line.color = Color(EDGE, 0.7)
	line.thickness = 2
	theme.set_stylebox(&"separator", &"HSeparator", line)
	var vline := line.duplicate() as StyleBoxLine
	vline.vertical = true
	theme.set_stylebox(&"separator", &"VSeparator", vline)
	var err: Error = ResourceSaver.save(theme, THEME)
	print("theme saved: ", error_string(err))
	quit(0 if err == OK else 1)


func _box(bg: Color, edge: Color, border: int, radius: int, pad: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = edge
	b.set_border_width_all(border)
	b.set_corner_radius_all(radius)
	b.content_margin_left = pad + 4
	b.content_margin_right = pad + 4
	b.content_margin_top = pad
	b.content_margin_bottom = pad
	return b


func _buttons(theme: Theme, type: StringName, bg: Color, edge: Color, text: Color) -> void:
	theme.set_stylebox(&"normal", type, _box(bg, edge, 3, 10, 10))
	theme.set_stylebox(&"hover", type, _box(bg.lightened(0.12), edge, 3, 10, 10))
	theme.set_stylebox(&"pressed", type, _box(bg.darkened(0.12), edge, 3, 10, 10))
	theme.set_stylebox(&"hover_pressed", type, _box(bg.darkened(0.06), edge, 3, 10, 10))
	theme.set_stylebox(&"disabled", type, _box(DISABLED, DISABLED.darkened(0.3), 3, 10, 10))
	theme.set_stylebox(&"focus", type, StyleBoxEmpty.new())
	for c: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color", &"font_focus_color"]:
		theme.set_color(c, type, text)
	theme.set_color(&"font_disabled_color", type, Color(1, 1, 1, 0.6))
