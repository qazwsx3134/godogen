extends "res://addons/proto_kit/test_kit.gd"
## The 養成 screen (scenes/growth.tscn) driven like a player, on its own progress and save file: a card per hero of
## the class tab, the five march slots, levelling a class; a hero's own page (an N: no 招牌技 but the 晉升 step; an SSR:
## the 招牌技; 設為隊長, at most three), ascending, 英雄名冊 back to the roster, swapping a hero into the march squad,
## and 一鍵養成 (in the header), each saved. Instantiates the scene and finds nodes by name.
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
	p.shards = 3
	var screen: Control = (load("res://scenes/growth.tscn") as PackedScene).instantiate()
	screen.progress = p
	screen.save_path = SAVE_TEST
	# Static text and spacing edited in the scene are what the running screen shows.
	(screen.find_child("Hint", true, false) as Label).text = "編輯器改的提示"
	(screen.find_child("Roster", true, false).get_node("Column") as VBoxContainer).add_theme_constant_override(&"separation", 20)
	root.add_child(screen)
	await _frames(3)
	_expect((screen.find_child("Hint", true, false) as Label).text == "編輯器改的提示" and
		(screen.find_child("Roster", true, false).get_node("Column") as VBoxContainer).get_theme_constant(&"separation") == 20,
		"a hint text and a spacing edited in the scene survive at runtime")
	var cards: Node = screen.find_child("Cards", true, false)
	var page: Control = screen.find_child("HeroPage", true, false)
	var roster: Control = screen.find_child("Roster", true, false)
	_expect(cards.get_child_count() == PushSim.ROSTER[0], "the 盾 tab shows its %d heroes (got %d)" % [PushSim.ROSTER[0], cards.get_child_count()])
	_expect(screen.find_child("MarchSlots", true, false).get_child_count() == Progression.MARCH_SIZE, "five march slots")
	_expect(not page.visible and roster.visible, "the screen opens on the roster")

	await _press(screen.find_child("Tab_1", true, false))
	await _frames(2)
	_expect(screen.selected_class == 1 and cards.get_child_count() == PushSim.ROSTER[1], "the 劍 tab shows the 20 swords")
	var level: int = p.class_level[1]
	await _press(screen.find_child("ClassUp", true, false))
	_expect(p.class_level[1] == level + 1 and p.gold < 1000, "升級 raises the 劍 class level for gold")
	_expect(screen.find_child("ClassLevel", true, false).text == str(level + 1), "the class panel shows the new level")
	_expect(FileAccess.file_exists(SAVE_TEST), "every change is saved")

	# The first card of the 劍 tab is an SSR: its page shows the 招牌技, not the 晉升 step.
	await _press(cards.get_child(0))
	var ssr: int = screen.selected_hero
	_expect(page.visible and not roster.visible, "a tapped card opens the hero's own page")
	_expect(p.rarity(ssr) == PushSim.SSR and page.find_child("SigSection", true, false).visible and
		not page.find_child("PromoteSection", true, false).visible, "an SSR's page shows its 招牌技")
	_expect(page.find_child("SigName", true, false).text == "斷鋼斬", "the SSR sword's 招牌技 is 斷鋼斬")
	var captain: Button = page.find_child("CaptainToggle", true, false)
	await _press(captain)
	_expect(p.is_captain(ssr) and captain.text.begins_with("取消隊長") and captain.text.contains("團 +"),
		"設為隊長 makes the hero a captain, the button telling their 團's boost (%s)" % captain.text)
	await _press(page.find_child("Back", true, false))
	_expect((cards.get_child(0).find_child("CaptainChip", true, false) as Control).visible, "the captain's card wears the 長 chip")
	p.captains = PackedInt32Array([ssr, 1, 2])
	await _press(cards.get_child(1))
	_expect(captain.disabled and captain.text.contains("已滿"), "a fourth captain cannot be picked")
	p.captains = PackedInt32Array([ssr])
	await _press(page.find_child("Back", true, false))
	_expect(not page.visible and roster.visible and screen.selected_class == 1, "英雄名冊 goes back to the same tab")

	# A non-marching N sword: its page, ascension, then into march slot 2.
	var hero: int = -1
	for card: Node in cards.get_children():
		if not p.in_march(card.hero) and p.rarity(card.hero) == 0:  # an N
			hero = card.hero
			await _press(card)
			break
	_expect(screen.selected_hero == hero and page.find_child("HeroName", true, false).text != "", "the N's page opens")
	_expect(not page.find_child("SigSection", true, false).visible and page.find_child("PromoteSection", true, false).visible,
		"an N has no 招牌技; its page shows the next rarity step instead")
	await _press(page.find_child("Ascend", true, false))
	_expect(p.ascension[hero] == 1 and p.shards == 2, "突破 spends a shard on the hero")
	_expect(page.find_child("AscendLine", true, false).text.contains("★1"), "the page shows the new ascension")
	_expect(page.find_child("PromoteName", true, false).text.contains("1 次"), "one more ascension to the next rarity")
	await _press(page.find_child("Ascend", true, false))
	_expect(p.rarity(hero) == 1 and p.shards == 0, "the second 突破 (2 shards) promotes the N to R")
	_expect((page.find_child("Ascend", true, false) as Button).disabled, "突破 greys out without shards")
	await _press(page.find_child("Back", true, false))

	await _press(screen.find_child("MarchSlots", true, false).get_child(1))
	_expect(screen.selected_slot == 1 and page.visible and screen.selected_hero == p.march[1],
		"tapping a march slot picks it and opens the hero in it")
	_expect((page.find_child("SendMarch", true, false) as Button).disabled, "a marching hero cannot be sent again")
	await _press(page.find_child("Back", true, false))
	screen.select_hero(hero)
	await _press(page.find_child("SendMarch", true, false))
	_expect(p.march[1] == hero, "派去行軍 puts the hero into the picked slot")
	await _press(page.find_child("Back", true, false))

	p.gold += 3000
	screen.refresh()
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
