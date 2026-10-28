extends SceneTree
## Applied 2026-10-28 (author's round 5): the 英雄 detail shows less at once. Top: portrait, name, Lv and tags, and the
## two equipment slots beside the portrait (tap one: %EquipPopup lists the bag's pieces, compares the chosen one with
## the worn one, 裝備 / 強化武器). Then attack, HP, 突破 and a 數值明細 button (%StatsPopup), the three skills, and the
## action row 突破 · 升級 · 上陣 · 隊長 (升級 opens %LevelPopup: the EXP bar and the three 經驗藥水 sizes). The EXP bar,
## the inline breakdown and the inline swap list go. Skips the page if %LevelPopup exists.
##   godot --headless --path prototypes/hero-horde-idle --script res://tools/build_hero_detail_v2.gd

const SceneBuilder = preload("res://addons/proto_kit/scene_builder.gd")
const PATH := "res://scenes/pages/heroes.tscn"
const UI := "res://ui/%s.tres"
const BOLD := "res://fonts/NotoSansCJKtc-Bold.otf"
const MEDIUM := "res://fonts/NotoSansCJKtc-Medium.otf"
const INK := Color(0.30, 0.31, 0.29)
const SOFT := Color(0.52, 0.53, 0.50)
const GONE := ["PetExperience", "PetExperienceText", "BreakdownPanel", "BreakdownTitle", "BreakdownHint", "EquipPanel",
	"EquipTitle", "EquipHint", "UpgradeWeapon", "SwapLabel", "SwapScroll", "SwapEmpty"]
## New rects in %HeroDetail's coordinates.
const AT := {
	"DetailPanel": Rect2(22, 96, 897, 476), "PortraitFrame": Rect2(39, 112, 200, 260),
	"DetailPortrait": Rect2(48, 118, 182, 248), "PetName": Rect2(260, 106, 640, 46), "PetLevel": Rect2(260, 154, 120, 36),
	"PetStatus": Rect2(384, 154, 521, 36), "WeaponSlot": Rect2(260, 200, 645, 84), "CharmSlot": Rect2(260, 292, 645, 84),
	"Stat0": Rect2(39, 396, 220, 40), "Stat1": Rect2(270, 396, 240, 40), "Stat2": Rect2(520, 396, 180, 40),
	"Skill0": Rect2(39, 452, 866, 36), "Skill1": Rect2(39, 490, 866, 36), "Skill2": Rect2(39, 528, 866, 36),
	"ActionRow": Rect2(30, 596, 881, 72)}


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var opened: Dictionary = SceneBuilder.open_scene(PATH)
	var root: Control = opened.root
	var detail: Control = root.get_node("HeroDetail")
	if detail.get_node_or_null("LevelPopup") != null:
		root.free()
		quit(0)
		return
	var grid: Control = detail.get_node("FactorGrid")
	detail.remove_child(grid)
	for n: String in GONE:
		detail.get_node(n).free()
	for n: String in AT:
		var c: Control = detail.get_node(n)
		c.position = AT[n].position
		c.size = AT[n].size
	(detail.get_node("PetStatus") as Label).add_theme_font_size_override(&"font_size", 24)
	for slot: String in ["WeaponSlot", "CharmSlot"]:
		var b: Control = detail.get_node(slot)
		_rect(b.get_node("Icon"), Rect2(10, 8, 68, 68))
		_rect(b.get_node("Title"), Rect2(90, 4, 540, 40))
		_rect(b.get_node("Note"), Rect2(90, 42, 540, 36))
	var row: HBoxContainer = detail.get_node("ActionRow")
	row.add_theme_constant_override(&"separation", 14)
	var level: Button = row.get_node("PotionButton")
	level.name = "LevelButton"
	level.text = "升級"
	row.move_child(level, 1)
	_put(detail, _button("數值明細", "sao_button", INK, 24), "StatsButton", Rect2(710, 392, 195, 48), true)
	_stats_popup(detail, grid)
	_equip_popup(detail)
	_level_popup(detail)
	quit(0 if SceneBuilder.save_scene(root, PATH, {"overwrite": true, "expected_refs": opened.refs}).ok else 1)


func _rect(c: Control, r: Rect2) -> void:
	c.position = r.position
	c.size = r.size


func _put(parent: Node, c: Control, name: String, r: Rect2, unique: bool = false) -> Control:
	c.name = name
	parent.add_child(c)
	_rect(c, r)
	if unique:
		SceneBuilder.unique(c)
	return c


func _label(text: String, size: int, color: Color = INK, bold: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override(&"font", load(BOLD if bold else MEDIUM))
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, style: String, ink: Color, size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_stylebox_override(&"normal", load(UI % style))
	var hover: String = "sao_primary_hover" if style == "sao_primary" else "sao_button_hover"
	b.add_theme_stylebox_override(&"hover", load(UI % hover))
	b.add_theme_stylebox_override(&"pressed", load(UI % hover))
	b.add_theme_stylebox_override(&"disabled", load(UI % "sao_disabled"))
	b.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	b.add_theme_font_override(&"font", load(BOLD))
	b.add_theme_font_size_override(&"font_size", size)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(key, ink)
	b.add_theme_color_override(&"font_disabled_color", Color(0.55, 0.56, 0.54))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


func _panel(style: String) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override(&"panel", load(UI % style))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## A pop-up over the detail: a dimmed backdrop (tap = close) and a white window with a title strip and 關閉.
## Returns the window; its parts are named <prefix>Dim, <prefix>Title, <prefix>Close.
func _popup(detail: Control, name: String, title: String, window: Rect2) -> Control:
	var pop := Control.new()
	_put(detail, pop, name, Rect2(0, 0, 941, 995), true)
	pop.visible = false
	pop.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	_put(pop, dim, "Dim", Rect2(0, 0, 941, 995))
	var win: Panel = _panel("sao_window")
	win.mouse_filter = Control.MOUSE_FILTER_STOP
	_put(pop, win, "Window", window)
	_put(win, _panel("sao_titlebar"), "TitleBar", Rect2(0, 0, window.size.x, 76))
	_put(win, _label(title, 34), name.replace("Popup", "Title"), Rect2(28, 0, 500, 76), true)
	_put(win, _button("關閉", "sao_button", INK, 24), name.replace("Popup", "Close"), Rect2(window.size.x - 170, 14, 146, 50), true)
	return win


func _stats_popup(detail: Control, grid: Control) -> void:
	var win: Control = _popup(detail, "StatsPopup", "數值明細", Rect2(60, 230, 820, 470))
	_put(win, _label("全部相乘＝目前的攻擊與生命", 22, SOFT, false), "StatsHint", Rect2(30, 90, 760, 36))
	win.add_child(grid)
	_rect(grid, Rect2(30, 136, 760, 300))
	(grid as GridContainer).columns = 2
	(grid as GridContainer).add_theme_constant_override(&"v_separation", 10)
	for l: Node in grid.get_children():
		(l as Control).custom_minimum_size = Vector2(370, 36)
		(l as Label).add_theme_font_size_override(&"font_size", 26)


func _equip_popup(detail: Control) -> void:
	var win: Control = _popup(detail, "EquipPopup", "更換裝備", Rect2(40, 100, 860, 800))
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_put(win, icon, "CurrentIcon", Rect2(30, 96, 96, 96), true)
	_put(win, _label("目前：未裝備", 28), "CurrentName", Rect2(144, 94, 690, 44), true)
	var text: Label = _label("", 22, SOFT, false)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_put(win, text, "CurrentText", Rect2(144, 140, 690, 60), true)
	_put(win, _panel("sao_section"), "Line", Rect2(24, 214, 812, 8))
	_put(win, _label("背包裡可以換的：點一件看比較", 24), "CandidateLabel", Rect2(30, 226, 800, 40), true)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_put(win, scroll, "CandidateScroll", Rect2(30, 272, 800, 236), true)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override(&"h_separation", 12)
	grid.add_theme_constant_override(&"v_separation", 12)
	grid.name = "CandidateGrid"
	scroll.add_child(grid)
	SceneBuilder.unique(grid)
	_put(win, _label("背包裡沒有可以換的", 24, SOFT, false), "CandidateEmpty", Rect2(30, 272, 800, 60), true)
	var compare: Label = _label("", 24, INK, false)
	compare.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	compare.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_put(win, compare, "CompareText", Rect2(30, 520, 800, 140), true)
	_put(win, _button("強化武器", "sao_button", INK, 26), "UpgradeButton", Rect2(30, 690, 380, 80), true)
	_put(win, _button("裝備", "sao_primary", Color.WHITE, 30), "EquipConfirm", Rect2(450, 690, 380, 80), true)


func _level_popup(detail: Control) -> void:
	var win: Control = _popup(detail, "LevelPopup", "升級", Rect2(60, 160, 820, 680))
	_put(win, _label("Lv.14", 32), "LevelLine", Rect2(30, 96, 760, 48), true)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.add_theme_stylebox_override(&"background", load(UI % "sao_track"))
	bar.add_theme_stylebox_override(&"fill", load(UI % "sao_fill"))
	_put(win, bar, "ExpBar", Rect2(30, 152, 760, 22), true)
	_put(win, _label("0 / 0", 22, SOFT, false), "ExpText", Rect2(30, 180, 760, 34), true)
	for k: int in 3:
		var y: float = 236.0 + k * 140.0
		_put(win, _panel("sao_section"), "PotionLine%d" % k, Rect2(24, y - 10, 772, 8))
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_put(win, icon, "PotionIcon%d" % k, Rect2(30, y + 8, 80, 80), true)
		_put(win, _label("經驗藥水", 28), "PotionName%d" % k, Rect2(126, y + 4, 330, 44), true)
		_put(win, _label("+500 經驗　有 0 瓶", 22, SOFT, false), "PotionInfo%d" % k, Rect2(126, y + 48, 330, 40), true)
		_put(win, _button("用 1 瓶", "sao_button", INK, 24), "UseOne%d" % k, Rect2(470, y + 16, 150, 64), true)
		_put(win, _button("升 1 級", "sao_button", INK, 24), "UseLevel%d" % k, Rect2(636, y + 16, 150, 64), true)
