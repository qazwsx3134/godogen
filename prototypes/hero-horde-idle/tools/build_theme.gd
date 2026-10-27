extends SceneTree
## One-time authoring tool for ui/theme.tres, the 墨綠暖白 look (art_src/ui_concepts/detail_refinement_v2): dark green
## panels with thin bronze lines, warm white text, a warm white primary button and outlined secondary ones, a serif
## face for names and numbers. Overwrites the theme (it is a resource: tune it in the editor afterwards, and do not
## re-run this over those edits).
##   godot --headless --path prototypes/hero-horde-idle --script res://tools/build_theme.gd
## Type variations:
##   Heading       Label in the serif face (names, levels, multipliers)
##   Dim           Label in the secondary text colour
##   FieldLabel    Label with a dark outline, for text straight over the battlefield
##   PrimaryButton the one main action of a screen (warm white)
##   TabButton     flat; the pressed one is underlined in bronze
##   CardButton    a hero portrait card; the pressed one is framed in gold
##   FlatButton    text only (back)
##   HudPanel      PanelContainer over the battlefield (more see-through)
##   Pill          a small inset box (the phase, the timer)
##   PartButton    a boss part over the field: room under the name for its HP bar
##   HpBar, MoraleBar, ExpBar  ProgressBar fills

const PATH := "res://ui/theme.tres"
const SANS := "res://ui/fonts/NotoSansTC.ttf"
const SERIF := "res://ui/fonts/NotoSerifTC-Bold.otf"

const PANEL := Color(0.075, 0.125, 0.11, 0.94)
const LINE := Color("4f5446")
const BRONZE := Color("a9875a")
const GOLD := Color("d9b26e")
const TEXT := Color("ece6dc")
const DIM := Color("b3ac9d")
const FAINT := Color("7c776b")
const PAPER := Color("ddd5c6")
const INK := Color("23261f")


func _initialize() -> void:
	var theme := Theme.new()
	theme.default_font = load(SANS)
	theme.default_font_size = 28
	var serif: Font = load(SERIF)

	theme.set_color(&"font_color", &"Label", TEXT)
	theme.set_constant(&"outline_size", &"Label", 0)
	theme.set_color(&"font_outline_color", &"Label", Color(0.02, 0.04, 0.03))
	_variation(theme, &"Heading", &"Label")
	theme.set_font(&"font", &"Heading", serif)
	_variation(theme, &"Dim", &"Label")
	theme.set_color(&"font_color", &"Dim", DIM)
	_variation(theme, &"FieldLabel", &"Label")
	theme.set_constant(&"outline_size", &"FieldLabel", 10)

	# Secondary buttons: outlined in bronze on the panel colour.
	theme.set_font_size(&"font_size", &"Button", 28)
	for state: StringName in [&"font_color", &"font_hover_color", &"font_focus_color", &"font_hover_pressed_color"]:
		theme.set_color(state, &"Button", TEXT)
	theme.set_color(&"font_pressed_color", &"Button", GOLD)
	theme.set_color(&"font_disabled_color", &"Button", FAINT)
	theme.set_stylebox(&"normal", &"Button", _box(PANEL, BRONZE, 2))
	theme.set_stylebox(&"hover", &"Button", _box(PANEL.lightened(0.06), GOLD, 2))
	theme.set_stylebox(&"pressed", &"Button", _box(Color(0.13, 0.19, 0.16, 0.96), GOLD, 2))
	theme.set_stylebox(&"disabled", &"Button", _box(Color(0.07, 0.1, 0.09, 0.8), LINE, 2))
	theme.set_stylebox(&"focus", &"Button", StyleBoxEmpty.new())

	_variation(theme, &"PrimaryButton", &"Button")
	for state: StringName in [&"font_color", &"font_hover_color", &"font_focus_color", &"font_pressed_color", &"font_hover_pressed_color"]:
		theme.set_color(state, &"PrimaryButton", INK)
	theme.set_color(&"font_disabled_color", &"PrimaryButton", Color("8d887c"))
	theme.set_font(&"font", &"PrimaryButton", serif)
	theme.set_stylebox(&"normal", &"PrimaryButton", _box(PAPER, Color("8f7048"), 3))
	theme.set_stylebox(&"hover", &"PrimaryButton", _box(PAPER.lightened(0.08), Color("8f7048"), 3))
	theme.set_stylebox(&"pressed", &"PrimaryButton", _box(PAPER.darkened(0.12), Color("8f7048"), 3))
	theme.set_stylebox(&"disabled", &"PrimaryButton", _box(Color("4a4b43"), LINE, 3))

	_variation(theme, &"TabButton", &"Button")
	theme.set_color(&"font_color", &"TabButton", DIM)
	theme.set_color(&"font_hover_color", &"TabButton", TEXT)
	theme.set_color(&"font_pressed_color", &"TabButton", TEXT)
	theme.set_color(&"font_hover_pressed_color", &"TabButton", TEXT)
	var tab := _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0)
	var tab_on := _box(Color(1, 1, 1, 0.04), BRONZE, 0)
	tab_on.border_width_bottom = 4
	for state: StringName in [&"normal", &"hover", &"disabled"]:
		theme.set_stylebox(state, &"TabButton", tab)
	theme.set_stylebox(&"pressed", &"TabButton", tab_on)

	_variation(theme, &"CardButton", &"Button")
	theme.set_stylebox(&"normal", &"CardButton", _box(Color(0.09, 0.14, 0.12, 0.95), LINE, 2))
	theme.set_stylebox(&"hover", &"CardButton", _box(Color(0.11, 0.17, 0.14, 0.95), BRONZE, 2))
	theme.set_stylebox(&"pressed", &"CardButton", _box(Color(0.14, 0.2, 0.16, 0.98), GOLD, 4))
	theme.set_stylebox(&"hover_pressed", &"CardButton", _box(Color(0.14, 0.2, 0.16, 0.98), GOLD, 4))

	_variation(theme, &"FlatButton", &"Button")
	var flat := StyleBoxEmpty.new()
	flat.content_margin_left = 4.0
	flat.content_margin_right = 12.0
	for state: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
		theme.set_stylebox(state, &"FlatButton", flat)

	theme.set_stylebox(&"panel", &"PanelContainer", _box(PANEL, LINE, 2))
	_variation(theme, &"HudPanel", &"PanelContainer")
	theme.set_stylebox(&"panel", &"HudPanel", _box(Color(0.06, 0.1, 0.09, 0.86), BRONZE, 2))
	_variation(theme, &"Pill", &"PanelContainer")
	theme.set_stylebox(&"panel", &"Pill", _box(Color(0.03, 0.05, 0.04, 0.7), LINE, 2, 10))

	_variation(theme, &"PartButton", &"Button")
	theme.set_font_size(&"font_size", &"PartButton", 24)
	theme.set_color(&"font_disabled_color", &"PartButton", DIM)
	for state: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
		var part := (theme.get_stylebox(state, &"Button") as StyleBoxFlat).duplicate() as StyleBoxFlat
		part.content_margin_top = 2.0
		part.content_margin_bottom = 16.0
		theme.set_stylebox(state, &"PartButton", part)

	theme.set_stylebox(&"background", &"ProgressBar", _box(Color(0.04, 0.06, 0.05, 0.9), LINE, 1, 0))
	theme.set_stylebox(&"fill", &"ProgressBar", _box(BRONZE, Color(0, 0, 0, 0), 0, 0))
	theme.set_constant(&"outline_size", &"ProgressBar", 0)
	for spec: Array in [[&"HpBar", Color("b5432f")], [&"MoraleBar", GOLD], [&"ExpBar", Color("af8d62")]]:
		_variation(theme, spec[0], &"ProgressBar")
		theme.set_stylebox(&"fill", spec[0], _box(spec[1], Color(0, 0, 0, 0), 0, 0))

	var line := StyleBoxLine.new()
	line.color = LINE
	line.thickness = 2
	theme.set_stylebox(&"separator", &"HSeparator", line)
	theme.set_constant(&"separation", &"HSeparator", 2)
	var vline := StyleBoxLine.new()
	vline.color = LINE
	vline.thickness = 2
	vline.vertical = true
	theme.set_stylebox(&"separator", &"VSeparator", vline)
	theme.set_constant(&"separation", &"VSeparator", 2)

	theme.set_stylebox(&"panel", &"ScrollContainer", StyleBoxEmpty.new())
	var error: Error = ResourceSaver.save(theme, PATH)
	print("theme: ", error_string(error))
	quit(0 if error == OK else 1)


func _variation(theme: Theme, name: StringName, base: StringName) -> void:
	theme.set_type_variation(name, base)


func _box(fill: Color, border: Color, width: int, margin: int = 12) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(2)
	box.content_margin_left = margin
	box.content_margin_right = margin
	box.content_margin_top = margin / 2.0
	box.content_margin_bottom = margin / 2.0
	return box
