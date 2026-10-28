extends SceneTree
## Applied 2026-10-28 (author: 總覽、背包、英雄、冒險 are crammed): more room and fewer words. The hint lines under the
## page titles go; the roster and the bag go from 5 to 4 columns with wider gaps (the hero card grows to 200 x 150 so
## "SSR Lv14" and 行軍中 no longer overlap; the bag card's count moves to its top-right corner); 總覽's sections and
## 待辦 buttons get space between them; 冒險 drops its long notes. Marks each scene it changed (meta ux_spacing).
##   godot --headless --path prototypes/hero-horde-idle --script res://tools/ux_spacing.gd

const SceneBuilder = preload("res://addons/proto_kit/scene_builder.gd")
const MARK := &"ux_spacing"


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var ok: bool = _scene("res://scenes/components/equipment_item_card.tscn", _hero_card)
	ok = _scene("res://scenes/components/inventory_card.tscn", _bag_card) and ok
	ok = _scene("res://scenes/pages/heroes.tscn", _heroes) and ok
	ok = _scene("res://scenes/pages/backpack.tscn", _backpack) and ok
	ok = _scene("res://scenes/pages/overview.tscn", _overview) and ok
	ok = _scene("res://scenes/pages/adventure.tscn", _adventure) and ok
	quit(0 if ok else 1)


func _scene(path: String, change: Callable) -> bool:
	var opened: Dictionary = SceneBuilder.open_scene(path)
	var root: Node = opened.root
	if root.has_meta(MARK):
		root.free()
		return true
	change.call(root)
	root.set_meta(MARK, true)
	return SceneBuilder.save_scene(root, path, {"overwrite": true, "expected_refs": opened.refs}).ok


func _rect(root: Node, path: String, r: Rect2, font: int = 0) -> Control:
	var c: Control = root.get_node(path)
	c.position = r.position
	c.size = r.size
	if font > 0:
		c.add_theme_font_size_override(&"font_size", font)
	return c


func _hide(root: Node, path: String) -> void:
	(root.get_node(path) as CanvasItem).visible = false


func _hero_card(root: Node) -> void:
	var c := root as Control
	c.custom_minimum_size = Vector2(200, 150)
	c.size = c.custom_minimum_size
	_rect(root, "Frame", Rect2(0, 0, 200, 150))
	_rect(root, "SelectButton", Rect2(0, 0, 200, 150))
	_rect(root, "RarityBar", Rect2(2, 4, 8, 142))
	_rect(root, "Icon", Rect2(62, 8, 76, 70))
	_rect(root, "Title", Rect2(16, 80, 176, 34), 26)
	(_rect(root, "Level", Rect2(16, 114, 100, 30), 22) as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	(_rect(root, "EquippedBy", Rect2(104, 114, 88, 30), 18) as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _bag_card(root: Node) -> void:
	_rect(root, "Icon", Rect2(36, 30, 90, 90))
	(_rect(root, "Quantity", Rect2(70, 6, 86, 30), 22) as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_rect(root, "Title", Rect2(12, 140, 144, 44), 24)


func _grid(grid: GridContainer, h: int, v: int) -> void:
	grid.columns = 4
	grid.add_theme_constant_override(&"h_separation", h)
	grid.add_theme_constant_override(&"v_separation", v)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _heroes(root: Node) -> void:
	_hide(root, "DetailHint")
	_grid(root.get_node("HeroScroll/HeroGrid"), 20, 16)


func _backpack(root: Node) -> void:
	_hide(root, "BackpackSubtitle")
	(_rect(root, "FilterRow", Rect2(28, 622, 885, 58)) as HBoxContainer).add_theme_constant_override(&"separation", 12)
	_rect(root, "InventoryFrame", Rect2(21, 696, 899, 610))
	_rect(root, "ItemsGridScroll", Rect2(35, 714, 870, 578))
	_grid(root.get_node("ItemsGridScroll/ItemsGrid"), 24, 18)
	(root.get_node("InfoText") as Label).text = "點選物品看詳情"
	_rect(root, "InfoName", Rect2(44, 1336, 590, 44))
	_rect(root, "InfoText", Rect2(44, 1384, 590, 112), 24)


func _overview(root: Node) -> void:
	_rect(root, "MarchStatus", Rect2(34, 618, 873, 40), 26)
	_rect(root, "HeroSummaryFrame", Rect2(27, 668, 886, 290))
	_rect(root, "LeaderPortrait", Rect2(44, 686, 110, 110))
	_rect(root, "LeaderName", Rect2(174, 684, 721, 44))
	_rect(root, "SquadLine", Rect2(174, 732, 721, 40), 26)
	_rect(root, "SquadRow", Rect2(44, 814, 855, 76))
	_rect(root, "BondLabel", Rect2(44, 902, 855, 44), 26)
	_rect(root, "TodoFrame", Rect2(27, 978, 886, 248))
	_rect(root, "TodoTitle", Rect2(46, 990, 838, 42))
	var todo: VBoxContainer = _rect(root, "TodoList", Rect2(44, 1040, 852, 176))
	todo.add_theme_constant_override(&"separation", 14)
	for b: Node in todo.get_children():
		(b as Control).add_theme_font_size_override(&"font_size", 26)
	_rect(root, "LogFrame", Rect2(27, 1244, 886, 262))
	_rect(root, "LogTitle", Rect2(46, 1254, 838, 42))
	_rect(root, "CombatLogScroll", Rect2(44, 1302, 845, 192))
	(root.get_node("CombatLogScroll/CombatLog") as Control).add_theme_font_size_override(&"font_size", 24)


func _adventure(root: Node) -> void:
	_hide(root, "LaunchNote")
	(root.get_node("RouteTitle") as Label).text = "選擇樓層"
	var hint: Label = _rect(root, "DepartHint", Rect2(60, 1380, 820, 70), 24)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
