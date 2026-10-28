extends SceneTree
## Third authoring pass on the 英雄 page (2026-10-28, the 裝備 tab folds into it): the page opens on the roster, which
## takes the whole panel, with 一鍵裝備 in the title row; tapping a hero opens %HeroDetail over the page (not over the
## nav bar): the hero's card and actions (moved from the page), 數值明細 (twelve %Factor labels) and 裝備欄位 (the
## class's 職業武庫 weapon, the hero's own charm, 強化, and the bag's pieces for the chosen slot in %SwapGrid).
## Skips the page if %HeroDetail is already there (the scene may since be edited by hand).
##   godot --headless --path prototypes/hero-horde-idle --script res://tools/build_hero_detail.gd

const SceneBuilder = preload("res://addons/proto_kit/scene_builder.gd")
const PATH := "res://scenes/pages/heroes.tscn"
const BOLD := "res://fonts/NotoSansCJKtc-Bold.otf"
const MEDIUM := "res://fonts/NotoSansCJKtc-Medium.otf"
const INK := Color("4a3424")
const SOFT := Color("7a6450")
## The page's panel (ContentPanel) in page coordinates; %HeroDetail covers it.
const TOP := 525.0
## How far the moved card goes up: the overlay has a title row and no hint line.
const LIFT := 30.0
const MOVED := ["DetailPanel", "PortraitFrame", "DetailPortrait", "PetName", "PetLevel", "PetExperience",
	"PetExperienceText", "PetStatus", "Stat0", "Stat1", "Stat2", "Skill0", "Skill1", "Skill2", "ActionRow"]
const UNUSED := ["PetStatSpeed", "PetStatCrit", "PetStatRegen", "PetBonusSpeed", "PetBonusCrit", "PetBonusRegen"]
const ROSTER := ["CollectionTitle", "CollectionCount", "BondLine", "FormFilter", "HeroScroll"]
## The roster's panel moves from y 1016 to just under the hint line.
const ROSTER_TOP := 646.0


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var opened: Dictionary = SceneBuilder.open_scene(PATH)
	var root: Control = opened.root
	if root.get_node_or_null("HeroDetail") != null:
		print("skip: %HeroDetail exists")
		root.free()
		quit(0)
		return
	for n: String in UNUSED:
		root.get_node(n).free()
	root.get_node("ActionRow/EquipButton").free()
	_roster(root)
	_detail(root)
	var ok: bool = SceneBuilder.save_scene(root, PATH, {"overwrite": true, "expected_refs": opened.refs}).ok
	quit(0 if ok else 1)


func _label(text: String, size: int, color: Color, bold: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override(&"font", load(BOLD if bold else MEDIUM))
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, style: String, size: int, color: Color = Color.WHITE) -> Button:
	var b := Button.new()
	b.text = text
	var box: StyleBox = load("res://ui/%s.tres" % style)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, box)
	b.add_theme_font_override(&"font", load(BOLD))
	b.add_theme_font_size_override(&"font_size", size)
	for key: String in ["font_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(key, color)
	b.add_theme_color_override(&"font_hover_color", color.lerp(Color("fff6d8"), 0.5) if color == Color.WHITE else color)
	b.add_theme_color_override(&"font_disabled_color", Color(color, 0.45))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


func _panel(style: String) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override(&"panel", load("res://ui/%s.tres" % style))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## Puts c under parent at a rect given in page coordinates (parent at page y `parent_y`).
func _put(parent: Node, c: Control, name: String, rect: Rect2, parent_y: float = TOP, unique: bool = true) -> Control:
	c.name = name
	parent.add_child(c)
	c.position = rect.position - Vector2(0, parent_y)
	c.size = rect.size
	if unique:
		SceneBuilder.unique(c)
	return c


func _roster(root: Control) -> void:
	var panel: Control = root.get_node("CollectionPanel")
	var shift: float = ROSTER_TOP - panel.position.y
	panel.position.y = ROSTER_TOP
	panel.size.y -= shift
	for n: String in ROSTER:
		var c: Control = root.get_node(n)
		c.position.y += shift
	var scroll: Control = root.get_node("HeroScroll")
	scroll.size.y -= shift
	(root.get_node("DetailHint") as Label).text = "點英雄看數值明細、技能與裝備；一鍵裝備替全部英雄換上最好的"
	var auto: Button = _button("一鍵裝備", "gold", 30, INK)
	_put(root, auto, "AutoEquipButton", Rect2(640, 541, 265, 58), 0.0)


func _detail(root: Control) -> void:
	var detail := Control.new()
	_put(root, detail, "HeroDetail", Rect2(0, TOP, 941, 995), 0.0)
	detail.mouse_filter = Control.MOUSE_FILTER_STOP
	detail.visible = false
	var backdrop: Control = root.get_node("ContentPanel").duplicate()
	backdrop.unique_name_in_owner = false
	_put(detail, backdrop, "Backdrop", Rect2(8, TOP, 925, 995), TOP, false)
	_put(detail, _label("英雄詳情", 40, INK), "DetailTitle", Rect2(40, 538, 400, 66), TOP, false)
	_put(detail, _button("返回名冊", "blue", 28), "CloseButton", Rect2(705, 543, 200, 56))
	for n: String in MOVED:
		var c: Control = root.get_node(n)
		var page_pos: Vector2 = c.position
		root.remove_child(c)
		detail.add_child(c)
		c.position = page_pos - Vector2(0, TOP + LIFT)
	# 數值明細: what makes the hero's attack and HP, one factor per label (home fills them, hides the rest).
	_put(detail, _panel("card"), "BreakdownPanel", Rect2(22, 986, 897, 180), TOP, false)
	_put(detail, _label("數值明細", 28, INK), "BreakdownTitle", Rect2(39, 990, 300, 40), TOP, false)
	_put(detail, _label("全部相乘＝目前的攻擊與生命", 22, SOFT, false), "BreakdownHint", Rect2(340, 990, 560, 40), TOP, false)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override(&"h_separation", 12)
	grid.add_theme_constant_override(&"v_separation", 2)
	_put(detail, grid, "FactorGrid", Rect2(39, 1030, 864, 132))
	for k: int in 12:
		var l: Label = _label("等級 ×1.00", 24, INK, false)
		l.custom_minimum_size = Vector2(280, 32)
		l.name = "Factor%d" % k
		grid.add_child(l)
		SceneBuilder.unique(l)
	# 裝備欄位: the class's shared weapon and the hero's own charm; tap one to list the bag's pieces for it.
	_put(detail, _panel("card"), "EquipPanel", Rect2(22, 1176, 897, 330), TOP, false)
	_put(detail, _label("裝備欄位", 28, INK), "EquipTitle", Rect2(39, 1180, 300, 40), TOP, false)
	_put(detail, _label("點欄位，再點下方的裝備換上", 22, SOFT, false), "EquipHint", Rect2(340, 1180, 560, 40), TOP, false)
	_slot(detail, "WeaponSlot", Rect2(39, 1226, 420, 100), "武器")
	_slot(detail, "CharmSlot", Rect2(479, 1226, 420, 100), "飾品")
	_put(detail, _button("強化", "blue", 24), "UpgradeWeapon", Rect2(39, 1334, 420, 50))
	_put(detail, _label("", 22, SOFT, false), "SwapLabel", Rect2(479, 1334, 420, 50))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_put(detail, scroll, "SwapScroll", Rect2(39, 1392, 860, 106))
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	row.name = "SwapGrid"
	scroll.add_child(row)
	SceneBuilder.unique(row)
	_put(detail, _label("背包裡沒有可以換的", 22, SOFT, false), "SwapEmpty", Rect2(39, 1392, 860, 70))


## An equipment slot: a button (style swaps when chosen) with the piece's icon, its name and a note line.
func _slot(detail: Control, name: String, rect: Rect2, kind: String) -> void:
	var b: Button = _button("", "slot", 22, INK)
	_put(detail, b, name, rect)
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.name = "Icon"
	b.add_child(icon)
	icon.position = Vector2(10, 10)
	icon.size = Vector2(80, 80)
	var title: Label = _label(kind, 26, INK)
	title.name = "Title"
	b.add_child(title)
	title.position = Vector2(100, 8)
	title.size = Vector2(310, 44)
	var note: Label = _label("", 20, SOFT, false)
	note.name = "Note"
	b.add_child(note)
	note.position = Vector2(100, 52)
	note.size = Vector2(310, 40)
