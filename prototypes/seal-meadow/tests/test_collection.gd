extends "res://addons/proto_kit/test_kit.gd"
## S19: real kill events, legacy policy, one-time rewards, inventory transaction and UI.

const SaveSlots = preload("res://addons/proto_kit/save_slots.gd")
const Book = preload("res://scripts/collection_book.gd")
const BASE := "user://test_collection/"

var main: Node3D
var player: Node3D


func _init() -> void:
	_run.call_deferred()


func _clear(name: String) -> String:
	var path := BASE.path_join(name + ".json")
	for p: String in [path, path + ".bak"]:
		DirAccess.remove_absolute(p)
	return path


func _open(name: String) -> void:
	if main:
		main.queue_free()
		await _frames(2)
	main = load("res://scenes/main.tscn").instantiate()
	main.save_path = BASE.path_join(name + ".json")
	root.add_child(main)
	await _frames(3)
	player = main.get_node("%Player")


func _run() -> void:
	await _test_kill_and_claim()
	await _test_full_bag()
	await _test_old_save()
	await _test_unknown_progress()
	main.queue_free()
	await _frames(2)
	_finish("SEAL MEADOW COLLECTION TESTS")


func _test_kill_and_claim() -> void:
	_clear("kill")
	await _open("kill")
	var m: Node3D = get_nodes_in_group("monster").filter(func(n: Node3D) -> bool:
		return n.scene_file_path.ends_with("slime.tscn"))[0]
	m.set_process(false)
	m.hp = 1
	m.respawn_seconds = 1000.0
	main.combat.attack(player, m, 100, 1.0, false)
	main.combat.attack(player, m, 100, 1.0, false)
	_expect(player.collection.kills.get("slime", 0) == 1, "a kill records one discovery; striking a dead monster adds nothing")
	var hud: CanvasLayer = main.get_node("%HUD")
	await _press(hud.collection_button)
	_expect(hud.collection_window.visible and hud.collection_window.monsters_text.text.contains("蓬蓬果凍"),
		"the collection UI shows a discovered monster")
	_expect(hud.collection_window.monsters_text.text.contains("？？？"), "undiscovered monsters show a location hint")
	var rows: Array = hud.collection_window.rows.get_children().filter(func(n: Node) -> bool: return not n.is_queued_for_deletion())
	_expect(rows.size() == Book.ACHIEVEMENTS.size(), "the achievement list shows every planned goal")
	await _press(rows[0].claim_button)
	_expect(player.gold == 30 and player.collection.fame() == 5 and "first_slime" in player.collection.claimed,
		"claiming awards gold and fame once")
	_expect(player.collection.claim(player, "first_slime") == "claimed" and player.gold == 30,
		"the same achievement cannot award twice")
	await _open("kill")
	_expect(player.gold == 30 and player.collection.fame() == 5 and player.collection.kills.get("slime", 0) == 1,
		"discovery, reward and claim survive restart")
	_expect(player.collection.claim(player, "first_slime") == "claimed", "restart does not permit another claim")


func _test_full_bag() -> void:
	_clear("full")
	await _open("full")
	player.pet.stage = 2
	player.bag.add("iron_sword", player.bag.capacity)
	var before: Array = player.bag.to_data()
	_expect(player.collection.claim(player, "pet_evolved") == "bag_full", "a full bag refuses the pet achievement reward")
	_expect(player.bag.to_data() == before and player.collection.fame() == 0 and "pet_evolved" not in player.collection.claimed,
		"a refused reward changes neither inventory nor achievement state")
	player.bag.remove("iron_sword", 2)
	_expect(player.collection.claim(player, "pet_evolved") == "" and player.bag.count("crystal") == 2,
		"the reward can be claimed after making room")
	_expect(player.collection.claim(player, "pet_evolved") == "claimed" and player.bag.count("crystal") == 2,
		"item rewards cannot be duplicated")


func _test_old_save() -> void:
	var path := _clear("legacy")
	SaveSlots.save(path, {"level": 2, "quests": {"index": 1, "accepted": false, "progress": 0}}, 4)
	await _open("legacy")
	_expect(player.collection.kills.get("slime", 0) == 0, "old saves do not invent historical monster kills")
	_expect(player.collection.progress(Book.ACHIEVEMENTS[2], player) == 1, "a completed quest is recognized from old saves")
	_expect(player.collection.claim(player, "first_quest") == "" and player.gold == 100,
		"a retroactively qualified goal can be claimed once")


func _test_unknown_progress() -> void:
	var path := _clear("unknown")
	SaveSlots.save(path, {"collection": {"kills": {"future_beast": 3}, "claimed": ["future_badge"]}}, 5)
	await _open("unknown")
	main.save_game()
	await _open("unknown")
	_expect(player.collection.kills.get("future_beast", 0) == 3 and "future_badge" in player.collection.claimed,
		"unknown collection entries survive a save and reload")
