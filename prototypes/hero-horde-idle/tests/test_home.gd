extends "res://addons/proto_kit/test_kit.gd"
## The home screen (scenes/home.tscn) played through its real buttons, on a save kept aside:
##   it opens on 總覽 with the offline report when time was away; the nav buttons switch the seven pages, the
##   header avatar comes back to 總覽; the 行軍 strip keeps its march across page switches and a kill pays gold
##   訓練 buys a talent; 英雄 selects a hero and sends them marching (the strip restarts with the new squad)
##   裝備 puts a weapon from the bag in its class's armory; 背包 salvages a piece; 冒險 sends the march to another
##   stage; 商店 pulls a 十連 and shows the results
##   the saved scene is the source: a static text edited in it stays when the screen runs
##   godot --headless --path prototypes/hero-horde-idle --script res://tests/test_home.gd
const Progression = preload("res://domain/progression.gd")
const Items = preload("res://domain/items.gd")
const Talents = preload("res://domain/talents.gd")
const HOME := "res://scenes/home.tscn"
const SAVE := "user://progress_home_test.json"
const NOW := 1_800_000_000

var home: Control


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var p := Progression.new(5)
	p.cleared = 1
	p.march_stage = 2
	p.gold = 20000
	p.tickets = 10
	p.march_since = NOW - 2 * 3600
	var w: Dictionary = p.new_item(Items.weapon_id(1, 2))
	p.add_item(w)
	var junk: Dictionary = p.new_item(Items.charm_id(0))
	p.add_item(junk)
	home = load(HOME).instantiate()
	home.progress = p
	home.save_path = SAVE
	home.clock = func() -> int: return NOW
	root.add_child(home)
	await _frames(2)
	_expect(home.tab == &"overview" and home.get_node("%Overview").visible, "opens on 總覽")
	_expect(home.get_node("%Dialog").visible and home.get_node("%DialogTitle").text == "離線戰報" and p.gold > 20000,
		"two hours away: the offline report, gold paid (%d)" % p.gold)
	home.get_node("%DialogOk").pressed.emit()

	# Nav: each button opens its page; 總覽 returns to 總覽; the strip keeps marching.
	var nav: Control = home.get_node("%Navigation")
	var tabs: Array = [&"train", &"backpack", &"heroes", &"adventure", &"store"]
	var arena: Node2D = home.get_node("%MarchArena")
	var sim: RefCounted = arena.sim
	for k: int in tabs.size():
		(nav.get_child(k) as Button).pressed.emit()
		await _frames(1)
		_expect(home.tab == tabs[k] and home.get_node("%Pages").get_child(k + 1).visible, "nav %d opens %s" % [k, tabs[k]])
	_expect(arena.sim == sim, "switching pages keeps the same march")
	home.get_node("%Header").get_node("OverviewButton").pressed.emit()
	_expect(home.tab == &"overview", "the 總覽 button returns to 總覽")
	var gold: int = p.gold
	for k: int in 1200:
		arena.step(0.05)
		if arena.sim.kills > 0:
			break
	_expect(arena.sim.kills > 0 and p.gold > gold, "a march kill pays gold (%d -> %d)" % [gold, p.gold])

	# 天賦.
	home.show_tab(&"train")
	var train: Control = home.get_node("%Train")
	(train.get_node("%TalentTree").get_node("Node%d" % Talents.SWORD) as Button).pressed.emit()
	gold = p.gold
	train.get_node("%LightButton").pressed.emit()
	_expect(p.talent[Talents.SWORD] == 1 and p.gold == gold - 3000, "點亮 劍術 for 3000 gold")

	# 英雄: select a hero not marching and send them (the squad has 3 slots: call one back first).
	home.show_tab(&"heroes")
	var heroes: Control = home.get_node("%Heroes")
	heroes.select(99)
	heroes.get_node("%MarchButton").pressed.emit()
	_expect(not p.in_march(99), "下陣 calls the healer back")
	heroes.select(51)
	var before: RefCounted = arena.sim
	heroes.get_node("%MarchButton").pressed.emit()
	_expect(p.in_march(51) and arena.sim != before and arena.sim.hero.has(51), "上陣 sends 51 marching; the strip restarts with them")
	heroes.close_detail()
	_expect(not heroes.get_node("%HeroDetail").visible, "the page shows the roster")
	var card: Control = heroes.get_node("%HeroGrid").get_child(0)
	(card.get_node("SelectButton") as Button).pressed.emit()
	_expect(heroes.selected == heroes._order[0] and heroes.get_node("%HeroDetail").visible,
		"a roster card opens its hero's detail over the page")
	heroes.get_node("%StatsButton").pressed.emit()
	var shown: int = 0
	for l: Node in heroes.get_node("%FactorGrid").get_children():
		shown += 1 if (l as Label).visible else 0
	_expect(heroes.get_node("%StatsPopup").visible and shown >= 2, "數值明細 opens a pop-up listing the sources (%d)" % shown)
	heroes.get_node("%StatsClose").pressed.emit()
	home.show_tab(&"train")
	home.show_tab(&"heroes")
	_expect(not heroes.get_node("%HeroDetail").visible, "coming back to 英雄 opens the roster")

	# 裝備: a 劍 hero's weapon slot opens the picker; pick the SR sword, compare, 裝備.
	heroes.open_detail(33)
	heroes.get_node("%WeaponSlot").pressed.emit()
	var swap: Control = heroes.get_node("%CandidateGrid").get_child(0)
	_expect(heroes.get_node("%EquipPopup").visible and swap.visible and heroes._swaps[0].uid == w.uid,
		"the 劍 weapon slot opens the picker with the bag's SR sword")
	(swap.get_node("SelectButton") as Button).pressed.emit()
	_expect(heroes.picked == w.uid and heroes.get_node("%CompareText").text.contains("換上"), "picking it shows the comparison")
	heroes.get_node("%EquipConfirm").pressed.emit()
	_expect(p.weapon_rarity(1) == 2 and p.bag_index(w.uid) < 0, "裝備 puts the SR sword in the 劍 armory")
	heroes.get_node("%EquipClose").pressed.emit()
	# 升級: a hero who is not marching drinks a medium potion (3000 EXP) and levels up.
	p.potions = PackedInt32Array([0, 1, 0])
	heroes.open_detail(60)
	var lv: int = p.hero_level[60]
	heroes.get_node("%LevelButton").pressed.emit()
	heroes.get_node("%UseOne1").pressed.emit()
	_expect(heroes.get_node("%LevelPopup").visible and not p.in_march(60) and p.hero_level[60] > lv and p.potions[1] == 0,
		"升級 with a 經驗藥水 levels a resting hero")
	heroes.close_detail()

	# 背包: salvage the charm.
	home.show_tab(&"backpack")
	var backpack: Control = home.get_node("%Backpack")
	backpack.selected = {"kind": "piece", "item": junk}
	var stones: int = p.stones
	backpack.get_node("%SalvageButton").pressed.emit()
	_expect(p.bag_index(junk.uid) < 0 and p.stones == stones + Items.SALVAGE[0], "分解 turns the charm into 強化石")

	# 冒險: march at 1-1.
	home.show_tab(&"adventure")
	var adventure: Control = home.get_node("%Adventure")
	(adventure.get_node("%StageGrid").get_child(0).get_node("SelectButton") as Button).pressed.emit()
	adventure.get_node("%MarchHereButton").pressed.emit()
	_expect(p.march_stage == 1 and arena.sim.stage == 1, "在此行軍 moves the march to 1-1")

	# 商店: a 十連.
	home.show_tab(&"store")
	var store: Control = home.get_node("%Store")
	store.clock = func() -> int: return NOW
	(store.get_node("%ProductGrid").get_child(1).get_node("BuyButton") as Button).pressed.emit()
	await _frames(1)
	_expect(p.tickets == 0 and p.pulls == 10 and home.get_node("%DialogTitle").text == "招募結果", "十連: ten pulls, the results shown")
	_expect(FileAccess.file_exists(SAVE), "changes are saved")
	home.get_node("%Dialog").visible = false
	# Back from the background: the time away is paid on the next tick; a short one only goes to the log.
	gold = p.gold
	home.clock = func() -> int: return NOW + 2 * 3600
	home._tick_in = 0.0
	home._process(0.016)
	_expect(p.gold > gold and home.get_node("%Dialog").visible, "two hours in the background: paid on return, with the report")
	home.get_node("%Dialog").visible = false
	gold = p.gold
	home.clock = func() -> int: return NOW + 2 * 3600 + 180
	home._tick_in = 0.0
	home._process(0.016)
	_expect(p.gold > gold and not home.get_node("%Dialog").visible, "three minutes away (a push): paid into the log, no dialog")
	home.queue_free()
	await _frames(2)
	DirAccess.remove_absolute(SAVE)
	await _edited_scene()
	_finish("HOME TESTS")


## A static text edited in the saved page scene stays when the screen runs.
func _edited_scene() -> void:
	var packed: PackedScene = load("res://scenes/pages/train.tscn")
	var page: Control = packed.instantiate()
	(page.get_node("PageTitle") as Label).text = "編輯器改的標題"
	var edited := PackedScene.new()
	edited.pack(page)
	page.free()
	var copy: Control = edited.instantiate()
	copy.progress = Progression.new(1)
	root.add_child(copy)
	copy.refresh()
	await _frames(1)
	_expect((copy.get_node("PageTitle") as Label).text == "編輯器改的標題", "a page title edited in the scene stays at runtime")
	copy.queue_free()

