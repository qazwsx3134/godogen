extends SceneTree
## The SAO-style UI kit (docs/SAO_UI_SPEC.md), applied 2026-10-28: one scene per HUD component in scenes/ui_kit/
## (gauge, unit bar, boss bar, timer bar, toast, party card) and scenes/ui_kit/ui_kit_gallery.tscn, every component and
## the menu-layer styles on one page to look at in the editor. Styles come from ui/sao_*.tres (tools/sao_style.gd).
## Skips scenes that exist (they may be edited by hand); delete one to rebuild it.
##   godot --headless --path prototypes/hero-horde-idle --script res://tools/build_ui_kit.gd

const SceneBuilder = preload("res://addons/proto_kit/scene_builder.gd")
const KIT := "res://scenes/ui_kit/%s.tscn"
const UI := "res://ui/%s.tres"
const BOLD := "res://fonts/NotoSansCJKtc-Bold.otf"
const MEDIUM := "res://fonts/NotoSansCJKtc-Medium.otf"
const WHITE := Color(0.96, 0.97, 0.98)
const OUTLINE := Color(0.06, 0.07, 0.09)
const TICK := Color(0.90, 0.92, 0.94, 0.9)


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var ok: bool = true
	ok = _save(_gauge(), "sao_gauge") and ok
	ok = _save(_unit_bar(), "sao_unit_bar") and ok
	ok = _save(_boss_bar(), "sao_boss_bar") and ok
	ok = _save(_timer_bar(), "sao_timer_bar") and ok
	ok = _save(_toast(), "sao_toast") and ok
	ok = _save(_party_card(), "sao_party_card") and ok
	ok = _save(_gallery(), "ui_kit_gallery") and ok
	quit(0 if ok else 1)


func _save(root: Node, key: String) -> bool:
	var path: String = KIT % key
	if root == null:
		return true
	var refs: Array = []
	for n: Node in root.find_children("*", "", true, false):
		if n.scene_file_path != "" and not refs.has(n.scene_file_path) and not _inside_instance(n, root):
			refs.append(n.scene_file_path)
	return SceneBuilder.save_scene(root, path, {"expected_refs": refs}).ok


## Whether n sits inside another sub-scene instance (its own scene file is then that instance's business).
func _inside_instance(n: Node, root: Node) -> bool:
	var up: Node = n.get_parent()
	while up != null and up != root:
		if up.scene_file_path != "":
			return true
		up = up.get_parent()
	return false


func _exists(key: String) -> bool:
	return FileAccess.file_exists(KIT % key)


func _label(text: String, size: int, color: Color = WHITE, outline: int = 6) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override(&"font", load(BOLD))
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	l.add_theme_color_override(&"font_outline_color", OUTLINE)
	l.add_theme_constant_override(&"outline_size", outline)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _panel(style: String) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override(&"panel", load(UI % style))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _put(parent: Node, c: Control, name: String, rect: Rect2, unique: bool = false) -> Control:
	c.name = name
	parent.add_child(c)
	c.position = rect.position
	c.size = rect.size
	if unique:
		SceneBuilder.unique(c)
	return c


func _root(name: String, size: Vector2, script: String = "") -> Control:
	var c := Control.new()
	c.name = name
	c.size = size
	c.custom_minimum_size = size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if script != "":
		c.set_script(load(script))
	return c


## Stretches c across its parent's width: `left` and `right` in from the sides, `top`..`bottom` fixed rows.
func _stretch(c: Control, left: float, top: float, right: float, bottom: float) -> void:
	c.anchor_left = 0.0
	c.anchor_right = 1.0
	c.anchor_top = 0.0
	c.anchor_bottom = 0.0
	c.offset_left = left
	c.offset_right = -right
	c.offset_top = top
	c.offset_bottom = bottom


## A gauge instance in a component.
func _gauge_in(parent: Node, rect: Rect2, fill: String = "", by_health: bool = true) -> Control:
	var g: ProgressBar = SceneBuilder.add(parent, SceneBuilder.unique(SceneBuilder.instance(KIT % "sao_gauge")), "Gauge")
	g.position = rect.position
	g.size = rect.size
	g.custom_minimum_size = Vector2.ZERO
	g.by_health = by_health
	if fill != "":
		g.add_theme_stylebox_override(&"fill", load(UI % fill))
	return g


## A diamond: a square frame turned 45 degrees about its centre.
func _diamond(parent: Node, name: String, center: Vector2, side: float) -> Panel:
	var d: Panel = _panel("sao_diamond")
	_put(parent, d, name, Rect2(center - Vector2(side, side) / 2.0, Vector2(side, side)))
	d.pivot_offset = Vector2(side, side) / 2.0
	d.rotation = PI / 4.0
	return d


## Small light ticks on a strip's four corners.
func _ticks(parent: Node, size: Vector2) -> void:
	var k: int = 0
	for corner: Vector2 in [Vector2.ZERO, Vector2(size.x, 0), Vector2(0, size.y), size]:
		for horizontal: bool in [true, false]:
			var t := ColorRect.new()
			t.color = TICK
			t.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var s: Vector2 = Vector2(12, 2) if horizontal else Vector2(2, 12)
			var at: Vector2 = Vector2(corner.x - (s.x if corner.x > 0 else 0.0), corner.y - (s.y if corner.y > 0 else 0.0))
			_put(parent, t, "Tick%d" % k, Rect2(at, s))
			k += 1


# --- components ---------------------------------------------------------------------------------------------------

func _gauge() -> Node:
	if _exists("sao_gauge"):
		return null
	var g := ProgressBar.new()
	g.name = "SaoGauge"
	g.set_script(load("res://scripts/ui_kit/sao_gauge.gd"))
	g.show_percentage = false
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.max_value = 1.0
	g.value = 0.8
	g.size = Vector2(300, 24)
	g.custom_minimum_size = Vector2(60, 8)
	g.add_theme_stylebox_override(&"background", load(UI % "sao_gauge"))
	g.add_theme_stylebox_override(&"fill", load(UI % "sao_gauge_green"))
	return g


func _unit_bar() -> Node:
	if _exists("sao_unit_bar"):
		return null
	var root: Control = _root("SaoUnitBar", Vector2(72, 14), "res://scripts/ui_kit/sao_unit_bar.gd")
	_stretch(_put(root, _panel("sao_hud_frame"), "Frame", Rect2(0, 0, 72, 14)), 0, 0, 0, 14)
	_stretch(_gauge_in(root, Rect2(4, 3, 62, 8)), 4, 3, 6, 11)
	return root


func _boss_bar() -> Node:
	if _exists("sao_boss_bar"):
		return null
	var root: Control = _root("SaoBossBar", Vector2(660, 84), "res://scripts/ui_kit/sao_boss_bar.gd")
	var name_label: Label = _label("棍棒巨魔", 30)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stretch(_put(root, name_label, "BossName", Rect2(60, 0, 540, 40), true), 60, 0, 60, 40)
	var bars: Label = _label("×2", 22)
	bars.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_put(root, bars, "Bars", Rect2(560, 6, 96, 34), true)
	bars.anchor_left = 1.0
	bars.anchor_right = 1.0
	bars.offset_left = -100
	bars.offset_right = -4
	_stretch(_put(root, _panel("sao_hud_frame"), "Frame", Rect2(0, 44, 660, 32)), 0, 44, 0, 76)
	for side: int in 2:
		var cap := ColorRect.new()
		cap.color = TICK
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_put(root, cap, "Cap%d" % side, Rect2(-4 if side == 0 else 656, 40, 8, 40))
		if side == 1:
			cap.anchor_left = 1.0
			cap.anchor_right = 1.0
			cap.offset_left = -4
			cap.offset_right = 4
	_stretch(_gauge_in(root, Rect2(14, 50, 622, 20), "sao_gauge_boss", false), 14, 50, 24, 70)
	return root


func _timer_bar() -> Node:
	if _exists("sao_timer_bar"):
		return null
	var root: Control = _root("SaoTimerBar", Vector2(660, 16), "res://scripts/ui_kit/sao_timer_bar.gd")
	_stretch(_put(root, _panel("sao_hud_frame"), "Frame", Rect2(0, 0, 660, 16)), 0, 0, 0, 16)
	_stretch(_gauge_in(root, Rect2(6, 4, 640, 8), "sao_gauge_cyan", false), 6, 4, 14, 12)
	return root


func _toast() -> Node:
	if _exists("sao_toast"):
		return null
	var root: Control = _root("SaoToast", Vector2(560, 64), "res://scripts/ui_kit/sao_toast.gd")
	_put(root, _panel("sao_hud_glass"), "Glass", Rect2(0, 0, 560, 64))
	_ticks(root, Vector2(560, 64))
	_diamond(root, "Mark", Vector2(38, 32), 26)
	var dot: Panel = _diamond(root, "MarkCore", Vector2(38, 32), 10)
	dot.add_theme_stylebox_override(&"panel", load(UI % "sao_primary"))
	_put(root, _label("打倒《棍棒巨魔》。", 26), "Text", Rect2(70, 0, 476, 64), true)
	return root


func _party_card() -> Node:
	if _exists("sao_party_card"):
		return null
	var root: Control = _root("SaoPartyCard", Vector2(380, 118), "res://scripts/ui_kit/sao_party_card.gd")
	_put(root, _panel("sao_hud_glass"), "Glass", Rect2(0, 0, 380, 84))
	var rail := ColorRect.new()
	rail.color = TICK
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_put(root, rail, "Rail", Rect2(-8, 0, 3, 118))
	_diamond(root, "PortraitFrame", Vector2(44, 42), 52)
	var portrait := TextureRect.new()
	portrait.texture = load("res://assets/atlas/portrait.tres")
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_put(root, portrait, "Portrait", Rect2(24, 22, 40, 40), true)
	_put(root, _label("歐芙", 26), "MemberName", Rect2(92, 6, 270, 38), true)
	_gauge_in(root, Rect2(92, 50, 270, 18))
	var status := _label("行軍中", 22, Color(0.85, 1.0, 0.85))
	_put(root, status, "Status", Rect2(0, 86, 300, 32), true)
	return root


# --- gallery ------------------------------------------------------------------------------------------------------

func _gallery() -> Node:
	if _exists("ui_kit_gallery"):
		return null
	var root: Control = _root("UiKitGallery", Vector2(941, 1672))
	var sky := TextureRect.new()
	sky.texture = load("res://assets/atlas/battle_sky.tres")
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_put(root, sky, "Backdrop", Rect2(0, 0, 941, 960))
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	_put(root, dim, "Dim", Rect2(0, 0, 941, 960))
	var menu := ColorRect.new()
	menu.color = Color(0.70, 0.74, 0.78)
	_put(root, menu, "MenuBackdrop", Rect2(0, 960, 941, 712))
	var y: float = 20.0
	_caption(root, "HUD 層：戰鬥畫面上（深色玻璃＋細框＋斜切血條）", y)
	y += 50.0
	_caption(root, "樓層王血條 sao_boss_bar", y)
	_place(root, "sao_boss_bar", "BossBar", Vector2(140, y + 34))
	y += 140.0
	_caption(root, "倒數長條 sao_timer_bar", y)
	_place(root, "sao_timer_bar", "TimerBar", Vector2(140, y + 40))
	y += 90.0
	_caption(root, "頭上血條 sao_unit_bar（綠／黃／紅）", y)
	for k: int in 3:
		var bar: Control = _place(root, "sao_unit_bar", "UnitBar%d" % k, Vector2(140 + k * 110, y + 44))
		(bar.get_node("Gauge") as ProgressBar).value = [0.9, 0.4, 0.12][k]
		bar.get_node("Gauge").add_theme_stylebox_override(&"fill", load(UI % ["sao_gauge_green", "sao_gauge_yellow", "sao_gauge_red"][k]))
	y += 90.0
	_caption(root, "通知條 sao_toast", y)
	_place(root, "sao_toast", "Toast", Vector2(140, y + 40))
	y += 130.0
	_caption(root, "隊伍卡 sao_party_card", y)
	_place(root, "sao_party_card", "PartyCard", Vector2(150, y + 40))
	y = 980.0
	_caption(root, "選單層：白色視窗、標題列、刻線、白鈕／金色主要鈕、圓形導覽", y, Color(0.18, 0.19, 0.21), 0)
	var window: Panel = _panel("sao_window")
	_put(root, window, "Window", Rect2(40, y + 50, 560, 330))
	_put(window, _panel("sao_titlebar"), "TitleBar", Rect2(0, 0, 560, 70))
	_put(window, _label("視窗標題", 34, Color(0.30, 0.31, 0.29), 0), "Title", Rect2(24, 0, 400, 70))
	_put(window, _panel("sao_section"), "Section", Rect2(20, 150, 520, 170))
	_put(window, _label("區塊之間用上方刻線分隔", 24, Color(0.52, 0.53, 0.50), 0), "Body", Rect2(24, 84, 500, 50))
	var b := _menu_button("一般按鈕", "sao_button", Color(0.30, 0.31, 0.29))
	_put(window, b, "Button", Rect2(24, 180, 240, 64))
	var primary := _menu_button("主要按鈕", "sao_primary", Color.WHITE)
	_put(window, primary, "Primary", Rect2(290, 180, 240, 64))
	var card: Panel = _panel("sao_card")
	_put(window, card, "Card", Rect2(24, 256, 240, 56))
	var stripe := ColorRect.new()
	stripe.color = Color("d08a16")
	_put(card, stripe, "RarityBar", Rect2(2, 4, 8, 48))
	_put(card, _label("白底卡＋稀有度色條", 20, Color(0.30, 0.31, 0.29), 0), "Text", Rect2(18, 0, 220, 56))
	var nav_bar: Panel = _panel("sao_bar")
	_put(root, nav_bar, "NavSample", Rect2(640, y + 50, 260, 140))
	for k: int in 2:
		var cx: float = 70.0 + k * 120.0
		_put(nav_bar, _panel("sao_ring" if k == 0 else "sao_ring_active"), "Ring%d" % k, Rect2(cx - 50, 10, 100, 100))
		_put(nav_bar, _panel("sao_disc"), "Disc%d" % k, Rect2(cx - 45, 15, 90, 90))
	return root


func _caption(root: Control, text: String, y: float, color: Color = WHITE, outline: int = 6) -> void:
	_put(root, _label(text, 26, color, outline), "Caption%d" % root.get_child_count(), Rect2(40, y, 860, 40))


func _place(root: Control, key: String, name: String, at: Vector2) -> Control:
	var c: Control = SceneBuilder.add(root, SceneBuilder.instance(KIT % key), name)
	c.position = at
	return c


func _menu_button(text: String, style: String, ink: Color) -> Button:
	var b := Button.new()
	b.text = text
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(state, load(UI % style))
	b.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	b.add_theme_font_override(&"font", load(BOLD))
	b.add_theme_font_size_override(&"font_size", 26)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(key, ink)
	return b
