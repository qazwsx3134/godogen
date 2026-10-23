extends "res://addons/proto_kit/test_kit.gd"
## The 養成 screen (scenes/growth.tscn) driven like a player, on its own progress and save file: a card per hero of
## the class tab, the five march slots, levelling a class, a hero's details, ascending, swapping a hero into the march
## squad, 行軍 1 小時 and 一鍵養成, each saved. Instantiates the scene and finds nodes by name.
##   godot --headless --path prototypes/hero-horde-idle --script res://tests/test_growth.gd

const PushSim = preload("res://domain/push_sim.gd")
const Progression = preload("res://domain/progression.gd")
const SAVE_TEST := "user://progress_test_growth.json"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(720, 1280)
	var p := Progression.new()
	p.gold = 1000
	p.shards = 2
	var screen: Control = (load("res://scenes/growth.tscn") as PackedScene).instantiate()
	screen.progress = p
	screen.save_path = SAVE_TEST
	root.add_child(screen)
	await _frames(3)
	var cards: Node = screen.find_child("Cards", true, false)
	_expect(cards.get_child_count() == PushSim.ROSTER[0], "the 盾 tab shows its %d heroes (got %d)" % [PushSim.ROSTER[0], cards.get_child_count()])
	_expect(screen.find_child("MarchSlots", true, false).get_child_count() == Progression.MARCH_SIZE, "five march slots")

	await _press(screen.find_child("Tab_1", true, false))
	await _frames(2)
	_expect(screen.selected_class == 1 and cards.get_child_count() == PushSim.ROSTER[1], "the 劍 tab shows the 20 swords")
	var level: int = p.class_level[1]
	await _press(screen.find_child("ClassUp", true, false))
	_expect(p.class_level[1] == level + 1 and p.gold < 1000, "升級 raises the 劍 class level for gold")
	_expect(FileAccess.file_exists(SAVE_TEST), "every change is saved")

	# A non-marching N sword: details, ascension, then into march slot 2.
	var hero: int = -1
	for card: Node in cards.get_children():
		if not p.in_march(card.hero) and p.rarity(card.hero) == 0:  # an N
			hero = card.hero
			await _press(card)
			break
	_expect(screen.selected_hero == hero and screen.find_child("DetailName", true, false).text != "", "a tapped card opens the hero's details")
	var detail: Control = screen.find_child("Detail", true, false)
	_expect(detail.visible and not screen.get_node("Margins").visible, "details occupy their own page")
	_expect(screen.find_child("SkillName", true, false).text == "無專屬招牌技", "N heroes do not inherit SSR signatures")
	await _press(screen.find_child("Ascend", true, false))
	_expect(p.ascension[hero] == 1 and p.shards == 1, "突破 spends a shard on the hero")
	await _press(screen.find_child("Back", true, false))
	_expect(not detail.visible and screen.selected_class == 1, "back restores the selected roster tab")
	await _press(screen.find_child("MarchSlots", true, false).get_child(1))
	_expect(screen.selected_slot == 1, "tapping a march slot picks it")
	await _press(screen.find_child("Back", true, false))
	await _press(screen.find_child("Tab_1", true, false))
	await _frames(1)
	screen.select_hero(hero)
	await _press(screen.find_child("SendMarch", true, false))
	_expect(p.march[1] == hero, "派去行軍 puts the hero into the picked slot")

	_expect(screen.find_child("SendMarch", true, false).disabled, "a dispatched hero cannot be sent twice")
	await _press(screen.find_child("Back", true, false))
	var gold: int = p.gold
	await _press(screen.find_child("MarchHour", true, false))
	_expect(p.gold > gold and p.hero_level[hero] > 1, "行軍 1 小時 pays gold and levels the march squad")
	_expect(screen.find_child("Toast", true, false).text.contains("金幣"), "the toast says what the march brought back")
	var levels: int = 0
	for c: int in p.class_level.size():
		levels += p.class_level[c]
	await _press(screen.find_child("AutoSpend", true, false))
	var after: int = 0
	for c: int in p.class_level.size():
		after += p.class_level[c]
	_expect(after > levels, "一鍵養成 spends the gold on class levels")
	var saved: RefCounted = Progression.load_from(SAVE_TEST)
	_expect(saved.march[1] == hero and saved.gold == p.gold, "the save holds the latest state")
	DirAccess.remove_absolute(SAVE_TEST)
	_finish("GROWTH UI TESTS")
