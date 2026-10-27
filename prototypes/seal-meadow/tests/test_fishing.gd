extends "res://addons/proto_kit/test_kit.gd"
## S33: reachable pond, actual UI, foreground time, atomic bait/reward and interruption.

const SAVE := "user://test_fishing/save.json"
const Fishing = preload("res://scripts/fishing.gd")
const Shop = preload("res://scripts/shop.gd")
const SaveSlots = preload("res://addons/proto_kit/save_slots.gd")

var main: Node3D
var player: Node3D
var hud: CanvasLayer


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for path: String in [SAVE, SAVE + ".bak"]:
		DirAccess.remove_absolute(path)
	main = load("res://scenes/main.tscn").instantiate()
	main.save_path = SAVE
	root.add_child(main)
	await _frames(5)
	player = main.get_node("%Player")
	hud = main.get_node("%HUD")
	for m: Node3D in get_nodes_in_group("monster"):
		m.set_process(false)
	player.set_process(false)
	main.set_process(false)
	var spot: Node3D = main.get_node("%FishingSpot")
	player.move_to(spot.global_position)
	main._fishing_goal = spot
	for i in 1800:
		player._process(1.0 / 60.0)
		main._process(1.0 / 60.0)
		if hud.fishing_window.visible:
			break
	_expect(hud.fishing_window.visible, "the pond can be reached from the starting point without crossing the water")
	_expect(main._flat_distance(player, spot) <= main.fishing_distance, "fishing opens only near the spot")
	await _press(hud.fishing_window.action_button)
	_expect(not main.fishing.active and hud.fishing_window.status.text.contains("釣餌不足"), "a cast needs bait")
	player.gold = 20
	_expect(Shop.buy(player, "fishing_bait", 2) == "" and player.gold == 10, "bait can be bought from the village shop")
	await _press(hud.fishing_window.action_button)
	_expect(main.fishing.active and player.bag.count(Fishing.BAIT) == 2, "starting a cast reserves no bait")
	main.clock.now = main.fishing.ends_at + 0.01
	main._process(0.01)
	var caught: int = player.bag.count("pond_fish") + player.bag.count("jelly_gel")
	_expect(not main.fishing.active and caught == 1 and player.bag.count(Fishing.BAIT) == 1,
		"a completed cast spends one bait and awards one catch")
	var restored: Dictionary = SaveSlots.restore(SAVE, main.SAVE_VERSION)
	_expect(restored.error == "" and restored.data.bag.size() >= 1, "the completed catch is checkpointed")
	main._process(1.0)
	_expect(player.bag.count("pond_fish") + player.bag.count("jelly_gel") == 1, "a settled cast cannot award twice")
	await _press(hud.fishing_window.action_button)
	await _press(hud.fishing_window.action_button)
	main.clock.now += Fishing.DURATION + 1.0
	main._process(0.01)
	_expect(not main.fishing.active and player.bag.count(Fishing.BAIT) == 1,
		"stopping a cast consumes no bait and a stale completion awards nothing")
	player.bag.slots.clear()
	player.bag.add(Fishing.BAIT, 2)
	player.bag.add("iron_sword", 11)
	main.start_fishing()
	main.clock.now = main.fishing.ends_at + 0.01
	main._process(0.01)
	_expect(player.bag.count(Fishing.BAIT) == 2 and hud.fishing_window.status.text.contains("背包已滿"),
		"a full bag cancels settlement without consuming bait")
	main.start_fishing()
	main.clock.set_away(true)
	_expect(not main.fishing.active and player.bag.count(Fishing.BAIT) == 2, "backgrounding cancels the cast without a cost")
	main.clock.set_away(false)
	await _frames(main.clock.resume_frames + 1)
	main.start_fishing()
	player.take_damage(1, null)
	_expect(not main.fishing.active and player.bag.count(Fishing.BAIT) == 2, "damage interrupts the cast without a cost")
	main.start_fishing()
	player.global_position += Vector3(0.2, 0, 0)
	main._process(0.01)
	_expect(not main.fishing.active and player.bag.count(Fishing.BAIT) == 2, "moving interrupts the cast without a cost")
	player.global_position = spot.global_position + Vector3(4, 0, 0)
	main.start_fishing()
	_expect(not main.fishing.active and hud.fishing_window.status.text.contains("靠近"), "a cast cannot start away from the pond")
	main.queue_free()
	await _frames(2)
	_finish("SEAL MEADOW FISHING TESTS")
