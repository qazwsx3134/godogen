extends "res://addons/proto_kit/test_kit.gd"
## The 道具 page (scenes/items.tscn) on its own progress: the 職業武庫 and the bag (best first, 新 marks), 換上 and 強化
## from an armory slot, 分解, a charm handed to the march squad, the 遺物 and 素材 tabs, the 新 marks clearing when the
## page is left, everything saved; the page fits a 16:9 screen above the nav bar.
##   godot --headless --path prototypes/hero-horde-idle --script res://tests/test_items.gd

const Progression = preload("res://domain/progression.gd")
const Items = preload("res://domain/items.gd")
const SAVE_TEST := "user://progress_test_items.json"
const NAV_H := 116


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(720, 1280)
	DirAccess.remove_absolute(SAVE_TEST)
	var p := Progression.new(3)
	for id: String in [Items.weapon_id(1, 2), Items.weapon_id(1, 0), Items.charm_id(6), Items.charm_id(0)]:
		p.add_item(id)
	p.stones = 10
	p.relic_stars[0] = 2
	var page: Control = load("res://scenes/items.tscn").instantiate()
	page.progress = p
	page.save_path = SAVE_TEST
	page.offset_bottom = -NAV_H
	root.add_child(page)
	await _frames(3)
	var cells: Array = _cells(page)
	_expect(page.find_child("Armory", true, false).visible and cells.size() == 4, "裝備: the armory and 4 items in the bag")
	_expect(cells[0].entry.id == Items.charm_id(6) and cells[1].entry.id == Items.weapon_id(1, 2),
		"the best first (SSR charm, then the SR weapon)")
	_expect(cells[0].find_child("New", true, false).visible, "a new drop wears 新")
	var detail: Control = page.find_child("Detail", true, false)
	_expect(detail.get_global_rect().end.y <= 1280 - NAV_H + 1, "the detail panel sits above the nav bar (%s)" % detail.get_global_rect())

	await _press(page.find_child("ArmorySlots", true, false).get_child(1))
	var main: Button = page.find_child("DetailMain", true, false)
	_expect(main.text.contains("斷鋼長劍"), "the empty 劍 slot offers the SR sword (%s)" % main.text)
	await _press(main)
	_expect(p.armory[1] == 2 and Progression.load_from(SAVE_TEST).armory[1] == 2, "換上 equips it, saved")
	_expect(main.text.contains("強化") and not main.disabled, "then 強化 (%s)" % main.text)
	await _press(main)
	_expect(p.armory_level[1] == 2 and p.stones == 9, "強化 spends 1 強化石 for Lv.2")

	cells = _cells(page)
	var worse: Button = cells.filter(func(c: Button) -> bool: return c.entry.id == Items.weapon_id(1, 0))[0]
	await _press(worse)
	await _press(page.find_child("DetailSalvage", true, false))
	_expect(not p.bag.has(Items.weapon_id(1, 0)) and p.stones == 9 + Items.SALVAGE[0], "分解 the worse sword into 強化石")
	await _press(_cells(page)[0])
	_expect(main.text.begins_with("給 "), "a charm goes to someone (%s)" % main.text)
	await _press(main)
	_expect(p.charm[p.march[0]] == 6, "the SSR charm goes to the first of the march squad")

	await _press(page.find_child("TabRelic", true, false))
	cells = _cells(page)
	_expect(not page.find_child("Armory", true, false).visible and cells.size() == Items.RELICS.size(), "遺物 lists every relic")
	_expect(cells[0].find_child("Corner", true, false).text == "★2" and cells[1].find_child("Corner", true, false).text == "",
		"a found relic shows its stars, the others are empty")
	await _press(page.find_child("TabMaterial", true, false))
	cells = _cells(page)
	_expect(cells.size() == 3 and cells[1].find_child("Corner", true, false).text == str(p.stones)
		and cells[2].find_child("Corner", true, false).text == str(p.tickets), "素材: 突破素材, 強化石 and 招募券")

	p.add_item(Items.charm_id(1))
	page.visible = false
	_expect(p.fresh.is_empty() and Progression.load_from(SAVE_TEST).fresh.is_empty(), "leaving the page clears 新, saved")
	page.queue_free()
	DirAccess.remove_absolute(SAVE_TEST)
	_finish("ITEMS TESTS")


func _cells(page: Node) -> Array:
	return page.find_child("Cells", true, false).get_children().filter(func(c: Node) -> bool: return c.visible)
