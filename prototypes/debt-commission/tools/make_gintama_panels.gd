extends SceneTree
## 銀魂和紙的設定面板與標題卡（只影響 gintama 這一款）：
##   godot --headless --path . --script res://tools/make_gintama_panels.gd -- textures
##   godot --headless --path . --import
##   godot --headless --path . --script res://tools/make_gintama_panels.gd -- scenes [--force]
## `textures` derives two plain pieces from the extracted cutouts (the originals are kept: the dialogue
## box uses the paper's advance triangle and the nameplate's speaker): gintama_panel_paper.png (paper
## without the triangle) and gintama_heading_plaque.png (nameplate without the speaker icon).
## `scenes` writes scenes/ui/settings_panel_gintama.tscn, game_over_gintama.tscn and
## chapter_result_gintama.tscn, and restyles the cards of title_screen_gintama.tscn and
## menu_panel_gintama.tscn. The saved scenes are the source files from then on: the game
## and the tests never run this, and it refuses to rewrite them unless --force is given (check
## `git diff` first). Node counts and owners are checked before packing and after reading back.

const SettingsScript: Script = preload("res://scripts/settings_panel.gd")
const UI: String = "res://assets/ui/"
const PAPER_SRC: String = UI + "gintama_extracted_paper.png"
const PLAQUE_SRC: String = UI + "gintama_extracted_nameplate.png"
const PAPER: String = UI + "gintama_panel_paper.png"
const PLAQUE: String = UI + "gintama_heading_plaque.png"
const SERIF: String = "res://assets/fonts/NotoSerifTC.ttf"
const SETTINGS_OUT: String = "res://scenes/ui/settings_panel_gintama.tscn"
const TITLE_SCENE: String = "res://scenes/ui/title_screen_gintama.tscn"
const MENU_SCENE: String = "res://scenes/ui/menu_panel_gintama.tscn"
## Shared overlay → its gintama copy (a paper card around the shared column).
const OVERLAYS: Array[Array] = [
	["res://scenes/ui/game_over.tscn", "res://scenes/ui/game_over_gintama.tscn"],
	["res://scenes/ui/chapter_result.tscn", "res://scenes/ui/chapter_result_gintama.tscn"],
]
const MUTED: Color = Color("#536174")
const SEAL_RED: Color = Color("#963e4b")
## The paper's plain rows and columns (measured): everything outside them is frame, waves or blossoms.
const PAPER_MARGINS: Vector4 = Vector4(280, 140, 245, 122)  # left, top, right, bottom: rows 140-168 stretch
const PLAQUE_MARGINS: Vector4 = Vector4(64, 20, 40, 20)
const NAVY: Color = Color("#08283d")
const INK: Color = Color("#203047")
const CREAM: Color = Color("#f8f3e9")
const GOLD: Color = Color("#d7c18b")
const SILVER: Color = Color("#bfc7ce")

const ROWS: Array[Array] = [
	["TextSpeed", "文字速度", ["慢", "標準", "快", "瞬間"]],
	["AutoSpeed", "自動播放速度", ["慢", "標準", "快"]],
	["BgmVolume", "背景音樂音量", ["關", "25", "50", "75", "100"]],
	["SeVolume", "音效音量", ["關", "25", "50", "75", "100"]],
	["FontSize", "對話字級", ["小", "標準", "大"]],
	["PaperOpacity", "紙面透明度", ["65%", "82%", "100%"]],
]

var _serif: FontVariation = null
var _serif_bold: FontVariation = null


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var ok: bool = false
	if args.has("textures"):
		ok = _make_textures()
	elif args.has("scenes"):
		_serif = _font(500.0)
		_serif_bold = _font(800.0)
		var force: bool = args.has("--force")
		ok = _make_settings(force) and _restyle_title(force) and _restyle_menu(force)
		for pair: Array in OVERLAYS:
			ok = ok and _make_overlay(str(pair[0]), str(pair[1]), force)
	else:
		printerr("usage: -- textures | -- scenes [--force]")
	quit(0 if ok else 1)


# ---------------------------------------------------------------- textures

func _make_textures() -> bool:
	var paper: Image = Image.load_from_file(PAPER_SRC)
	# The advance triangle: the saturated blue in the lower right. Each of its pixels takes the paper
	# from the same column, just above the triangle (plain rows).
	var box: Rect2i = _bbox(paper, Rect2i(700, 140, 300, 120), func(c: Color) -> bool: return c.a > 0.5 and c.b - c.r > 0.25)
	if not box.has_area():
		printerr("paper: no triangle found")
		return false
	box = box.grow(4)
	for y: int in range(box.position.y, box.end.y):
		for x: int in range(box.position.x, box.end.x):
			paper.set_pixel(x, y, paper.get_pixel(x, y - box.size.y - 2))
	paper.save_png(PAPER)
	print("%s: triangle %s painted over" % [PAPER, box])
	var plaque: Image = Image.load_from_file(PLAQUE_SRC)
	# The speaker icon: light pixels right of the middle, inside the gold rim. Each takes the navy
	# from the same row, to its left.
	var icon: Rect2i = _bbox(plaque, Rect2i(200, 18, 115, 46), func(c: Color) -> bool: return c.a > 0.5 and c.get_luminance() > 0.45)
	if not icon.has_area():
		printerr("plaque: no icon found")
		return false
	icon = icon.grow(3)
	for y: int in range(icon.position.y, icon.end.y):
		for x: int in range(icon.position.x, icon.end.x):
			plaque.set_pixel(x, y, plaque.get_pixel(x - icon.size.x - 4, y))
	plaque.save_png(PLAQUE)
	print("%s: icon %s painted over" % [PLAQUE, icon])
	return true


func _bbox(image: Image, area: Rect2i, hit: Callable) -> Rect2i:
	var found: Rect2i = Rect2i()
	var any: bool = false
	for y: int in range(area.position.y, mini(area.end.y, image.get_height())):
		for x: int in range(area.position.x, mini(area.end.x, image.get_width())):
			if hit.call(image.get_pixel(x, y)):
				found = Rect2i(x, y, 1, 1) if not any else found.merge(Rect2i(x, y, 1, 1))
				any = true
	return found


# ---------------------------------------------------------------- styles

func _font(weight: float) -> FontVariation:
	var font: FontVariation = FontVariation.new()
	font.base_font = load(SERIF) as Font
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return font


func _paper_style(content: Vector4) -> StyleBoxTexture:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = load(PAPER) as Texture2D
	style.texture_margin_left = PAPER_MARGINS.x
	style.texture_margin_top = PAPER_MARGINS.y
	style.texture_margin_right = PAPER_MARGINS.z
	style.texture_margin_bottom = PAPER_MARGINS.w
	style.content_margin_left = content.x
	style.content_margin_top = content.y
	style.content_margin_right = content.z
	style.content_margin_bottom = content.w
	return style


func _plaque_style() -> StyleBoxTexture:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = load(PLAQUE) as Texture2D
	style.texture_margin_left = PLAQUE_MARGINS.x
	style.texture_margin_top = PLAQUE_MARGINS.y
	style.texture_margin_right = PLAQUE_MARGINS.z
	style.texture_margin_bottom = PLAQUE_MARGINS.w
	style.content_margin_left = 96.0
	style.content_margin_right = 64.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	return style


## A navy-and-silver pill (the toolbar buttons of the dialogue box), or a paper chip with a navy rule.
func _pill(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(30)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	style.shadow_color = Color(0.03, 0.09, 0.14, 0.22)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 4)
	return style


## normal / hover / pressed / disabled / focus for a `kind` of button: "primary" (navy), "plain"
## (paper chip; pressed = the chosen one, navy with a gold rim).
func _button_styles(button: Button, kind: String) -> void:
	var navy: StyleBoxFlat = _pill(NAVY, SILVER, 3)
	var navy_hover: StyleBoxFlat = _pill(Color("#204d6a"), GOLD, 3)
	var chosen: StyleBoxFlat = _pill(NAVY, GOLD, 4)
	var chip: StyleBoxFlat = _pill(Color("#fbf7ee"), Color("#385673"), 2)
	var chip_hover: StyleBoxFlat = _pill(Color("#e6edf1"), Color("#203e5e"), 3)
	var off: StyleBoxFlat = _pill(Color("#ddd8ce"), Color("#a9b1b8"), 2)
	var focus: StyleBoxFlat = _pill(Color(0, 0, 0, 0), GOLD, 4)
	focus.shadow_size = 0
	var primary: bool = kind == "primary"
	button.add_theme_stylebox_override("normal", navy if primary else chip)
	button.add_theme_stylebox_override("hover", navy_hover if primary else chip_hover)
	button.add_theme_stylebox_override("pressed", chosen)
	button.add_theme_stylebox_override("hover_pressed", chosen)
	button.add_theme_stylebox_override("disabled", off)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_font_override("font", _serif)
	var ink: Color = CREAM if primary else INK
	for state: String in ["font_color", "font_focus_color", "font_hover_color"]:
		button.add_theme_color_override(state, ink)
	button.add_theme_color_override("font_pressed_color", CREAM)
	button.add_theme_color_override("font_hover_pressed_color", CREAM)
	button.add_theme_color_override("font_disabled_color", Color("#77766f"))


# ---------------------------------------------------------------- settings

func _make_settings(force: bool) -> bool:
	if FileAccess.file_exists(SETTINGS_OUT) and not force:
		print("%s exists; kept (it is the source now)" % SETTINGS_OUT)
		return true
	var root: Panel = Panel.new()
	root.name = "SettingsPanel"
	root.set_script(SettingsScript)
	root.set("paint_from_style", false)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim: StyleBoxFlat = StyleBoxFlat.new()
	dim.bg_color = Color(0.02, 0.06, 0.1, 0.55)
	root.add_theme_stylebox_override("panel", dim)
	var theme: Theme = Theme.new()
	theme.default_font = _serif
	root.theme = theme

	var area: MarginContainer = _add(root, MarginContainer.new(), "Area", root)
	area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right"]:
		area.add_theme_constant_override("margin_" + side, 28)
	area.add_theme_constant_override("margin_top", 96)  # room for the plaque crossing the top edge
	area.add_theme_constant_override("margin_bottom", 40)
	var card: PanelContainer = _add(area, PanelContainer.new(), "Card", root)
	card.add_theme_stylebox_override("panel", _paper_style(Vector4(60, 104, 60, 120)))
	var layout: VBoxContainer = _add(card, VBoxContainer.new(), "Layout", root)
	layout.add_theme_constant_override("separation", 20)
	var scroll: ScrollContainer = _add(layout, ScrollContainer.new(), "SettingsScroll", root)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var rows: VBoxContainer = _add(scroll, VBoxContainer.new(), "Rows", root)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 14)
	for index: int in range(ROWS.size()):
		var spec: Array = ROWS[index]
		if index > 0:
			var rule: ColorRect = _add(rows, ColorRect.new(), "%sRule" % spec[0], root)
			rule.custom_minimum_size = Vector2(0, 2)
			rule.color = Color(0.22, 0.34, 0.45, 0.22)
		var label: Label = _add(rows, Label.new(), "%sLabel" % spec[0], root)
		label.text = "◆ " + str(spec[1])
		label.add_theme_font_override("font", _serif_bold)
		label.add_theme_font_size_override("font_size", 44)
		label.add_theme_color_override("font_color", INK)
		var row: HBoxContainer = _add(rows, HBoxContainer.new(), str(spec[0]), root, true)
		row.add_theme_constant_override("separation", 14)
		var group: ButtonGroup = ButtonGroup.new()
		for choice: int in range((spec[2] as Array).size()):
			var button: Button = _add(row, Button.new(), "%s%d" % [spec[0], choice], root)
			button.text = str(spec[2][choice])
			button.custom_minimum_size = Vector2(0, 136)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.toggle_mode = true
			button.button_group = group
			button.add_theme_font_size_override("font_size", 42)
			_button_styles(button, "plain")

	# The heading plaque crosses the card's top edge (as the speaker plaque does on the dialogue box).
	var head: HBoxContainer = _add(root, HBoxContainer.new(), "Header", root)
	head.anchor_right = 1.0
	head.offset_left = 28.0
	head.offset_right = -28.0
	head.offset_top = 40.0
	head.offset_bottom = 172.0
	var plaque: PanelContainer = _add(head, PanelContainer.new(), "Plaque", root)
	plaque.add_theme_stylebox_override("panel", _plaque_style())
	plaque.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plaque.custom_minimum_size = Vector2(440, 112)
	var heading: Label = _add(plaque, Label.new(), "Heading", root)
	heading.text = "設　定"
	heading.add_theme_font_override("font", _serif_bold)
	heading.add_theme_font_size_override("font_size", 52)
	heading.add_theme_color_override("font_color", CREAM)
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var spacer: Control = _add(head, Control.new(), "Spacer", root)
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var close: Button = _add(head, Button.new(), "Close", root, true)
	close.text = "×"
	close.custom_minimum_size = Vector2(132, 132)
	close.add_theme_font_size_override("font_size", 64)
	_button_styles(close, "primary")
	return _save(root, SETTINGS_OUT)


# ---------------------------------------------------------------- title card

func _restyle_title(force: bool) -> bool:
	var root: Control = (load(TITLE_SCENE) as PackedScene).instantiate() as Control
	var card: PanelContainer = root.get_node("CardArea/Card") as PanelContainer
	if card.get_theme_stylebox("panel") is StyleBoxTexture and not force:
		print("%s already has the washi card; kept" % TITLE_SCENE)
		root.free()
		return true
	var area: MarginContainer = root.get_node("CardArea") as MarginContainer
	area.add_theme_constant_override("margin_left", 28)
	area.add_theme_constant_override("margin_right", 28)
	area.add_theme_constant_override("margin_bottom", 48)
	card.add_theme_stylebox_override("panel", _paper_style(Vector4(0, 0, 0, 0)))
	var frame: Node = card.get_node_or_null("Frame")
	if frame != null:  # the drawn frame of the flat edition; the paper is the frame now
		card.remove_child(frame)
		frame.free()
	var padding: MarginContainer = card.get_node("Padding") as MarginContainer
	padding.add_theme_constant_override("margin_left", 60)
	padding.add_theme_constant_override("margin_right", 60)
	padding.add_theme_constant_override("margin_top", 52)
	padding.add_theme_constant_override("margin_bottom", 116)  # clears the waves in the lower corners
	var column: Node = padding.get_node("Column")
	var story: Button = column.get_node("StorySwitch") as Button
	var plaque: StyleBoxTexture = _plaque_style()
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		story.add_theme_stylebox_override(state, plaque if state != "focus" else StyleBoxEmpty.new())
	story.modulate = Color.WHITE
	for state: String in ["font_color", "font_focus_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color"]:
		story.add_theme_color_override(state, CREAM)
	story.add_theme_font_override("font", _serif)
	story.add_theme_font_size_override("font_size", 36)
	var logo: Label = column.get_node("Logo") as Label
	logo.add_theme_font_override("font", _serif_bold)
	logo.add_theme_color_override("font_color", NAVY)
	logo.add_theme_color_override("font_outline_color", CREAM)
	logo.add_theme_constant_override("outline_size", 10)
	logo.add_theme_constant_override("line_spacing", -18)
	logo.add_theme_font_size_override("font_size", 124)
	var tagline: Label = column.get_node("Tagline") as Label
	tagline.add_theme_font_override("font", _serif)
	tagline.add_theme_color_override("font_color", Color("#536174"))
	# A thin gold-and-navy rule under the tagline, as on the paper's inner border.
	var old_rule: Node = column.get_node_or_null("TaglineRule")
	if old_rule != null:
		column.remove_child(old_rule)
		old_rule.free()
	var rule: ColorRect = ColorRect.new()
	rule.name = "TaglineRule"
	rule.custom_minimum_size = Vector2(0, 3)
	rule.color = Color(0.84, 0.76, 0.55, 0.9)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(rule)
	column.move_child(rule, (column.get_node("Tagline") as Node).get_index() + 1)
	rule.owner = root
	_button_styles(column.get_node("Begin") as Button, "primary")
	_button_styles(column.get_node("Continue") as Button, "primary")
	for name: String in ["LoadRow/Load", "LoadRow/Settings"]:
		_button_styles(column.get_node(name) as Button, "plain")
	for name: String in ["Style_cinema", "Style_ledger", "Style_manga", "Style_gintama"]:
		_button_styles(column.get_node("Styles/" + name) as Button, "plain")
	return _save(root, TITLE_SCENE)


# ---------------------------------------------------------------- 目錄

func _restyle_menu(force: bool) -> bool:
	var root: Control = (load(MENU_SCENE) as PackedScene).instantiate() as Control
	var panel: PanelContainer = root.get_node("Area/Center/Panel") as PanelContainer
	if panel.get_theme_stylebox("panel") is StyleBoxTexture and not force:
		print("%s already has the washi card; kept" % MENU_SCENE)
		root.free()
		return true
	panel.add_theme_stylebox_override("panel", _paper_style(Vector4(0, 0, 0, 0)))
	var frame: Node = panel.get_node_or_null("Frame")
	if frame != null:  # the drawn frame of the flat edition; the paper is the frame now
		panel.remove_child(frame)
		frame.free()
	var padding: MarginContainer = panel.get_node("Padding") as MarginContainer
	for side: String in ["left", "right"]:
		padding.add_theme_constant_override("margin_" + side, 56)
	padding.add_theme_constant_override("margin_top", 48)
	padding.add_theme_constant_override("margin_bottom", 116)  # clears the waves in the lower corners
	var heading: Label = root.get_node("Area/Center/Panel/Padding/Column/Heading/HeadingText/Heading") as Label
	heading.add_theme_stylebox_override("normal", _plaque_style())
	heading.add_theme_color_override("font_color", CREAM)
	heading.add_theme_font_override("font", _serif_bold)
	heading.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var kicker: Label = root.get_node("Area/Center/Panel/Padding/Column/Heading/HeadingText/Kicker") as Label
	kicker.add_theme_font_override("font", _serif)
	kicker.add_theme_color_override("font_color", MUTED)
	_button_styles(root.get_node("%Close") as Button, "primary")
	# Rows without a ui_style_role are paper chips (the quick actions keep the toolbar's navy).
	for node: Node in _all(root.get_node("%Rows")):
		if node is Button and not node.has_meta("ui_style_role"):
			_button_styles(node as Button, "plain")
	(root.get_node("Dim") as ColorRect).color = Color(0.02, 0.06, 0.1, 0.55)
	return _save(root, MENU_SCENE)


# ---------------------------------------------------------------- Game Over／章節結算

## `src`'s column on a paper card over a navy dim, navy ink, serif type and the washi buttons.
func _make_overlay(src: String, out: String, force: bool) -> bool:
	if FileAccess.file_exists(out) and not force:
		print("%s exists; kept (it is the source now)" % out)
		return true
	var root: Control = (load(src) as PackedScene).instantiate() as Control
	var theme: Theme = Theme.new()
	theme.default_font = _serif
	root.theme = theme
	root.z_index = 2  # above the dialogue box's speaker plaque (NameOverlap, z_index 1)
	(root.get_node("Dim") as ColorRect).color = Color(0.02, 0.06, 0.1, 0.78)
	var center: Node = root.get_node("Center")
	var column: Control = center.get_node("Column") as Control
	var card: PanelContainer = _add(center, PanelContainer.new(), "Card", root)
	card.add_theme_stylebox_override("panel", _paper_style(Vector4(56, 72, 56, 124)))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.reparent(card, false)
	for node: Node in _all(column):
		node.owner = root
		# The card adds its paper margins: narrower columns keep it inside a 320 px wide phone.
		if node is Control and (node as Control).custom_minimum_size.x > 640.0:
			(node as Control).custom_minimum_size.x = 640.0
	for node: Node in _all(column):
		if node is Button:
			var primary: bool = node.name in ["Retry", "Next"]
			_button_styles(node as Button, "primary" if primary else "plain")
			(node as Button).add_theme_font_override("font", _serif_bold if primary else _serif)
		elif node is Label:
			var label: Label = node as Label
			var ink: Color = INK
			if label.name in ["Heading"]:
				ink = NAVY
				label.add_theme_font_override("font", _serif_bold)
			elif label.name == "Grade":
				ink = SEAL_RED
				label.add_theme_font_override("font", _serif_bold)
			elif label.name.ends_with("Caption") or label.name == "Message":
				ink = MUTED
			label.add_theme_color_override("font_color", ink)
		elif node.name == "Glasses":
			node.set("frame_color", NAVY)
			node.set("crack_color", MUTED)
	return _save(root, out)


# ---------------------------------------------------------------- saving

func _add(parent: Node, node: Node, node_name: String, owner_node: Node, unique: bool = false) -> Node:
	node.name = node_name
	parent.add_child(node)
	node.owner = owner_node
	node.unique_name_in_owner = unique
	return node


func _save(root: Node, path: String) -> bool:
	var nodes: Array[Node] = _all(root)
	for node: Node in nodes:
		if node != root and node.owner != root and node.owner == null:
			printerr("%s: %s has no owner" % [path, root.get_path_to(node)])
			return false
	var packed: PackedScene = PackedScene.new()
	if packed.pack(root) != OK or ResourceSaver.save(packed, path) != OK:
		printerr("%s: pack or save failed" % path)
		return false
	var expected: int = nodes.size()
	root.free()
	var back: Node = (ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).instantiate()
	var actual: int = _all(back).size()
	back.free()
	print("%s: %d nodes built, %d after reading it back" % [path, expected, actual])
	return expected == actual


func _all(node: Node) -> Array[Node]:
	var nodes: Array[Node] = [node]
	for child: Node in node.get_children():
		nodes.append_array(_all(child))
	return nodes
