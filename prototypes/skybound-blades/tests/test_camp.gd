extends "res://addons/proto_kit/test_kit.gd"
## Camp window actions (game/camp_menu.gd) applied to a Run and Profile: shop, selling, the
## warehouse and equipment, and the in-camp gate.

const Tuning = preload("res://domain/tuning.gd")
const Run = preload("res://domain/run.gd")
const Profile = preload("res://domain/profile.gd")
const CampMenu = preload("res://game/camp_menu.gd")

var tuning: Tuning
var menu: CampMenu


func _init() -> void:
	tuning = Tuning.load_default()
	menu = CampMenu.new(tuning)
	test_camp_shop_buys_with_gold()
	test_camp_actions_need_the_camp_except_gear()
	test_camp_sell_materials_and_gear()
	test_camp_warehouse_round_trip()
	test_camp_rows_cover_every_page()
	_finish("CAMP")


func test_camp_shop_buys_with_gold() -> void:
	var r := Run.new(tuning, "c1")
	var p := Profile.new()
	r.gold = 30
	menu.apply({"type": "buy", "item": "tonic_small", "qty": 1}, r, p, true)
	_expect(r.gold == 18 and r.free_count("tonic_small") == 1, "shop: 12 gold buys one free tonic")
	_expect(menu.apply({"type": "buy", "item": "emergency_kit", "qty": 1}, r, p, true) == "金幣不足" and r.gold == 18,
		"shop: not enough gold changes nothing")


func test_camp_actions_need_the_camp_except_gear() -> void:
	var r := Run.new(tuning, "c2")
	var p := Profile.new()
	r.gold = 100
	_expect(menu.apply({"type": "buy", "item": "tonic_small", "qty": 1}, r, p, false) == "回到營地才能使用" and r.gold == 100,
		"gate: no shopping in the field")
	var cap := r.make_gear("cloth_cap", "plain")
	menu.apply({"type": "equip", "role": "leader", "id": cap.id}, r, p, false)
	_expect(r.holder_of(cap.id) == "leader", "gate: gear can be changed in the field")


func test_camp_sell_materials_and_gear() -> void:
	var r := Run.new(tuning, "c3")
	var p := Profile.new()
	r.add_item("green_core", 3)
	menu.apply({"type": "sell_item", "item": "green_core", "qty": 3}, r, p, true)
	_expect(r.gold == 6 and r.count("green_core") == 0, "sell: materials at their sell price")
	var coat := r.make_gear("hard_leather", "fine")
	menu.apply({"type": "sell_gear", "id": coat.id}, r, p, true)
	_expect(r.gold == 6 + 35 and not r.gear.has(coat.id), "sell: gear at half its buy price")
	var worn: String = r.equipped.leader.weapon
	_expect(menu.apply({"type": "sell_gear", "id": worn}, r, p, true) == "這件不能賣", "sell: worn or issued gear is refused")


func test_camp_warehouse_round_trip() -> void:
	var r := Run.new(tuning, "c4")
	var p := Profile.new()
	r.gold = 70
	menu.apply({"type": "deposit_gold", "amount": 70}, r, p, true)
	menu.apply({"type": "withdraw_gold", "amount": 50}, r, p, true)
	_expect(r.gold == 50 and p.warehouse_gold == 20, "warehouse: gold in and out")
	r.add_item("green_core", 2)
	menu.apply({"type": "deposit_item", "item": "green_core", "qty": 2}, r, p, true)
	menu.apply({"type": "withdraw_item", "item": "green_core", "qty": 2}, r, p, true)
	_expect(r.count("green_core") == 2 and p.warehouse_items.is_empty(), "warehouse: items in and out")


func test_camp_rows_cover_every_page() -> void:
	var r := Run.new(tuning, "c5")
	var p := Profile.new()
	r.make_gear("novice_sword", "rare")
	var tabs := menu.tabs(r, p, true, 0.0)
	_expect(tabs.keys() == ["補給", "倉庫", "委託", "裝備"], "pages: four tabs")
	_expect(tabs["委託"].rows.size() == 4, "pages: the four floor-1 quests are listed")
	var gear_rows: Array = tabs["裝備"].rows
	_expect(String(gear_rows[-1].detail).contains("→ 攻擊 +2"), "pages: a bag item shows its stat change (%s)" % gear_rows[-1].detail)
