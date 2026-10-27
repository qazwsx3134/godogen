extends SceneTree
## Second authoring pass on the home screen (after tools/build_fusion_ui.gd), applied 2026-10-27:
##   天賦     scenes/components/talent_node.tscn (a ring, the icon, the level, the name) and the 天賦 page's star map:
##            nine talent nodes in %TalentTree (scripts/talent_links.gd draws the edges), a detail panel and 點亮
##   裝備     the 專屬飾品 holder steps through every hero (◀ ▶) instead of the five march slots; 一鍵裝備
##   英雄     a 裝備 button in the action row (opens the 裝備 page on that hero)
##   頂欄     gold and 招募券 frames move left; a 總覽 button sits left of the settings gear
##   長螢幕   home.tscn gets %SkyFill, the sky above the strip on screens taller than 941 x 1672 (home.gd _fit)
##   字級     every small text on the pages and components grows (x1.3 up to 24 px, x1.15 up to 32), one-line labels
##            end in "…" instead of running into their neighbours; the pages' default font size goes to 30
## Each step checks its own mark and skips a scene it already changed (it may since be edited by hand).
##   godot --headless --path prototypes/hero-horde-idle --script res://tools/build_fusion_ui_v2.gd

const SceneBuilder = preload("res://addons/proto_kit/scene_builder.gd")
const Talents = preload("res://domain/talents.gd")
const PAGE := "res://scenes/pages/%s.tscn"
const NODE := "res://scenes/components/talent_node.tscn"
const HEADER := "res://scenes/components/header.tscn"
const BOLD := "res://fonts/NotoSansCJKtc-Bold.otf"
const MEDIUM := "res://fonts/NotoSansCJKtc-Medium.otf"
const INK := Color("4a3424")
const READABLE := "fusion_readable"
## Where each talent node stands in the star map (TalentTree coordinates): roots on top, 專精 at the bottom.
const NODE_AT := {0: Vector2(110, 10), 5: Vector2(370, 10), 1: Vector2(630, 10), 2: Vector2(20, 196),
	4: Vector2(370, 196), 3: Vector2(720, 196), 7: Vector2(20, 382), 6: Vector2(240, 382), 8: Vector2(630, 382)}
const COMPONENTS := ["header", "navigation", "inventory_card", "equipment_item_card", "equipment_bag_card", "stage_card",
	"product_card"]
const PAGES := ["overview", "train", "backpack", "heroes", "equipment", "adventure", "store"]


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var ok: bool = _talent_node()
	ok = _train() and ok
	ok = _equipment() and ok
	ok = _heroes() and ok
	ok = _header() and ok
	ok = _home_sky() and ok
	for key: String in PAGES:
		ok = _readable(PAGE % key) and ok
	for key: String in COMPONENTS:
		ok = _readable("res://scenes/components/%s.tscn" % key) and ok
	quit(0 if ok else 1)


# --- helpers ----------------------------------------------------------------------------------------------------

func _label(text: String, size: int, color: Color, bold: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override(&"font", load(BOLD if bold else MEDIUM))
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	return l


func _button(text: String, style: String, size: int) -> Button:
	var b := Button.new()
	b.text = text
	var box: StyleBox = load("res://ui/%s.tres" % style)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, box)
	b.add_theme_font_override(&"font", load(BOLD))
	b.add_theme_font_size_override(&"font_size", size)
	b.add_theme_color_override(&"font_color", Color.WHITE)
	b.add_theme_color_override(&"font_hover_color", Color("fff6d8"))
	b.add_theme_color_override(&"font_disabled_color", Color(1, 1, 1, 0.45))
	return b


func _put(parent: Node, c: Control, name: String, pos: Vector2, size: Vector2, unique: bool = true) -> Control:
	c.name = name
	parent.add_child(c)
	c.position = pos
	c.size = size
	c.unique_name_in_owner = unique
	return c


func _save(opened: Dictionary, path: String, extra_refs: Array = []) -> bool:
	var refs: Array = opened.refs.duplicate()
	for r: String in extra_refs:
		if not refs.has(r):
			refs.append(r)
	return SceneBuilder.save_scene(opened.root, path, {"overwrite": true, "expected_refs": refs}).ok


# --- 天賦 -------------------------------------------------------------------------------------------------------

func _talent_node() -> bool:
	if FileAccess.file_exists(NODE):
		return true
	var b := Button.new()
	b.name = "TalentNode"
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(150, 176)
	b.size = b.custom_minimum_size
	var ring := Panel.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color("2f3446")
	box.border_color = Color("8a7f6a")
	box.set_border_width_all(6)
	box.set_corner_radius_all(60)
	ring.add_theme_stylebox_override(&"panel", box)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_put(b, ring, "Ring", Vector2(15, 0), Vector2(120, 120), false)
	var icon := TextureRect.new()
	icon.texture = load("res://assets/atlas/training_0.tres")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_put(b, icon, "Icon", Vector2(31, 16), Vector2(88, 88), false)
	var level: Label = _label("0/200", 24, Color.WHITE)
	level.add_theme_color_override(&"font_outline_color", Color("1d2433"))
	level.add_theme_constant_override(&"outline_size", 7)
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_put(b, level, "Level", Vector2(0, 92), Vector2(150, 32), false)
	var title: Label = _label("劍術", 30, INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_put(b, title, "Title", Vector2(0, 126), Vector2(150, 46), false)
	return SceneBuilder.save_scene(b, NODE).ok


func _train() -> bool:
	var path: String = PAGE % "train"
	var opened: Dictionary = SceneBuilder.open_scene(path)
	var root: Control = opened.root
	if root.get_node_or_null("TalentTree") != null:
		root.free()
		return true
	var old: Node = root.get_node("TrainingScroll")
	root.remove_child(old)
	old.free()
	opened.refs = opened.refs.filter(func(r: String) -> bool: return not r.ends_with("training_row.tscn"))
	(root.get_node("PageTitle") as Label).text = "天賦"
	(root.get_node("TrainingSubtitle") as Label).text = "用金幣點亮節點，全軍立即變強；點亮上面的，下面的才會亮起。"
	var tree := Control.new()
	tree.set_script(load("res://scripts/talent_links.gd"))
	_put(root, tree, "TalentTree", Vector2(26, 646), Vector2(889, 560))
	for k: int in Talents.count():
		var node: Control = SceneBuilder.add(tree, SceneBuilder.instance(NODE), "Node%d" % k)
		node.position = NODE_AT[k]
		(node.get_node("Title") as Label).text = Talents.ROWS[k].name
	var frame := Panel.new()
	frame.add_theme_stylebox_override(&"panel", load("res://ui/card.tres"))
	_put(root, frame, "DetailFrame", Vector2(26, 1214), Vector2(889, 292), false)
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_put(root, icon, "DetailIcon", Vector2(48, 1236), Vector2(110, 110))
	_put(root, _label("劍術　Lv. 0／200", 38, INK), "DetailName", Vector2(180, 1226), Vector2(715, 54))
	var text: Label = _label("全軍攻擊 ×1.08", 28, INK, false)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_put(root, text, "DetailText", Vector2(180, 1282), Vector2(715, 76))
	_put(root, _label("", 26, Color("b04a32"), false), "DetailNeed", Vector2(180, 1356), Vector2(715, 40))
	_put(root, _label("3000 金幣", 34, INK), "DetailCost", Vector2(48, 1410), Vector2(480, 70))
	_put(root, _button("點亮", "gold", 38), "LightButton", Vector2(560, 1398), Vector2(334, 94))
	return _save(opened, path, [NODE])


# --- 裝備、英雄、頂欄 ---------------------------------------------------------------------------------------------

func _equipment() -> bool:
	var path: String = PAGE % "equipment"
	var opened: Dictionary = SceneBuilder.open_scene(path)
	var root: Control = opened.root
	if root.get_node_or_null("AutoEquipButton") != null:
		root.free()
		return true
	for k: int in 5:
		(root.get_node("SquadPick%d" % k) as CanvasItem).visible = false
	_put(root, _button("◀", "blue", 28), "PrevHolder", Vector2(196, 954), Vector2(84, 46))
	var name: Label = _label("英雄名字", 28, INK)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_put(root, name, "HolderName", Vector2(286, 954), Vector2(520, 46))
	_put(root, _button("▶", "blue", 28), "NextHolder", Vector2(812, 954), Vector2(94, 46))
	_put(root, _button("一鍵裝備", "gold", 28), "AutoEquipButton", Vector2(690, 536), Vector2(223, 56))
	return _save(opened, path)


func _heroes() -> bool:
	var path: String = PAGE % "heroes"
	var opened: Dictionary = SceneBuilder.open_scene(path)
	var root: Control = opened.root
	var row: Node = root.get_node("ActionRow")
	if row.get_node_or_null("EquipButton") != null:
		root.free()
		return true
	var b: Button = _button("裝備", "blue", 26)
	b.name = "EquipButton"
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(b)
	b.unique_name_in_owner = true
	return _save(opened, path)


func _header() -> bool:
	var opened: Dictionary = SceneBuilder.open_scene(HEADER)
	var root: Control = opened.root
	if root.get_node_or_null("OverviewButton") != null:
		root.free()
		return true
	for n: String in ["GoldFrame", "GoldIcon", "GoldBadge", "GemFrame", "GemIcon", "GemBadge"]:
		(root.get_node(n) as Control).position.x -= 92
	var gear: Button = root.get_node("SettingsButton")
	var overview: Button = gear.duplicate()
	overview.name = "OverviewButton"
	for c: Node in overview.get_children():
		overview.remove_child(c)
		c.free()
	root.add_child(overview)
	overview.position = gear.position - Vector2(92, 0)
	overview.size = gear.size
	overview.text = "總覽"
	overview.add_theme_font_override(&"font", load(BOLD))
	overview.add_theme_font_size_override(&"font_size", 26)
	overview.add_theme_color_override(&"font_color", Color.WHITE)
	overview.add_theme_color_override(&"font_hover_color", Color("fff1b8"))
	return _save(opened, HEADER)


func _home_sky() -> bool:
	var path := "res://scenes/home.tscn"
	var opened: Dictionary = SceneBuilder.open_scene(path)
	var root: Control = opened.root
	if root.get_node_or_null("SkyFill") != null:
		root.free()
		return true
	var sky := ColorRect.new()
	sky.color = Color("5a97e2")
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_put(root, sky, "SkyFill", Vector2(0, 0), Vector2(941, 110))
	root.move_child(sky, 1)
	return _save(opened, path)


# --- 字級 -------------------------------------------------------------------------------------------------------

func _readable(path: String) -> bool:
	var opened: Dictionary = SceneBuilder.open_scene(path)
	var root: Control = opened.root
	if root.has_meta(READABLE):
		root.free()
		return true
	root.set_meta(READABLE, true)
	if root.theme != null and root.theme.default_font_size > 0 and root.theme.default_font_size < 30:
		root.theme = root.theme.duplicate()
		root.theme.default_font_size = 30
	_grow(root, root)
	return _save(opened, path)


func _grow(root: Node, n: Node) -> void:
	if n != root and n.owner != root:
		return
	if n is Label or n is Button:
		var c := n as Control
		if c.has_theme_font_size_override(&"font_size"):
			var size: int = c.get_theme_font_size(&"font_size")
			if size <= 24:
				c.add_theme_font_size_override(&"font_size", roundi(size * 1.3))
			elif size <= 32:
				c.add_theme_font_size_override(&"font_size", roundi(size * 1.15))
		if n is Label and (n as Label).autowrap_mode == TextServer.AUTOWRAP_OFF:
			(n as Label).text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for child: Node in n.get_children():
		_grow(root, child)
