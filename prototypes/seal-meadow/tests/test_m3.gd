extends "res://addons/proto_kit/test_kit.gd"
## M3: pet care and evolution, refining, and their saves, on the real main scene.
## godot --headless --path . -s tests/test_m3.gd

const Refine = preload("res://scripts/refine.gd")
const SAVE := "user://test_m3/save.json"

var main: Node3D
var player: Node3D


func _init() -> void:
	_run.call_deferred()


func _fresh() -> void:
	if main:
		main.queue_free()
		await _frames(2)
	main = load("res://scenes/main.tscn").instantiate()
	main.save_path = SAVE
	root.add_child(main)
	await _frames(3)
	player = main.get_node("%Player")


func _run() -> void:
	for f in [SAVE, SAVE + ".bak"]:
		DirAccess.remove_absolute(f)
	await _fresh()
	await _test_pet()
	_test_evolve()
	await _test_refine()
	main.save_game()
	var pet: Dictionary = player.pet.to_dict()
	pet.erase("hunger")  # keeps draining between the save and the check
	var gear: Dictionary = player.gear.duplicate(true)
	var atk: int = player.attack_power
	await _fresh()
	var pet_now: Dictionary = player.pet.to_dict()
	pet_now.erase("hunger")
	_expect(pet_now == pet and player.gear == gear and player.attack_power == atk,
		"pet, refine levels and the attack they give survive a restart")
	main.queue_free()
	_finish("SEAL MEADOW M3 TESTS")


func _test_pet() -> void:
	var pet = player.pet
	var atk0: int = player.attack_power
	_expect(pet.stats().get("atk", 0) >= 1, "the seedling gives attack")
	player.bag.add("apple", 5)
	pet.wants = "apple"
	var r := {}
	_expect(player.feed_pet("apple", r) == "" and player.bag.count("apple") == 4 and r.wanted and r.xp > 0,
		"feeding uses one apple, wanted food gives more XP")
	_expect(player.feed_pet("clover") == "not_food" and player.feed_pet("jelly_gel") == "none", "only foods, only if owned")
	# hunger: drains in the meadow, not in the village, never kills
	pet.hunger = 1.0
	main.zone = "meadow"
	await _frames(30)
	var after_meadow: float = pet.hunger
	_expect(after_meadow < 1.0, "hunger drains in the meadow")
	main.zone = "town"
	await _frames(30)
	_expect(is_equal_approx(pet.hunger, after_meadow), "hunger pauses in the village")
	main.zone = "meadow"
	var clock: Node = main.get_node("%GameClock")
	clock.set_away(true)
	var h: float = pet.hunger
	await _frames(10)
	_expect(is_equal_approx(pet.hunger, h), "hunger pauses while the app is in the background")
	clock.set_away(false)
	await _frames(clock.resume_frames + 1)
	pet.tick(100000.0)
	_expect(pet.alive, "an empty bar never makes the pet leave (D09)")
	_expect(player.attack_power >= atk0, "pet bonus still applies")


func _test_evolve() -> void:
	var pet = player.pet
	var r := {}
	_expect(player.evolve_pet(r) == "not_ready", "no evolution before +9")
	pet.level = 9
	pet.xp = pet.xp_to_next()
	player.bag.remove("clover", player.bag.count("clover"))
	player.bag.add("boar_tusk", 1)
	_expect(player.evolve_pet(r) == "materials" and player.bag.count("boar_tusk") == 1, "missing clover: nothing used up")
	player.bag.add("clover", 1)
	player.pet_rng.seed = 1
	var atk: int = player.attack_power
	_expect(player.evolve_pet(r) == "" and player.bag.count("clover") == 0 and player.bag.count("boar_tusk") == 0,
		"evolution uses both materials")
	if r.get("ok", false):
		_expect(pet.stage == 2 and pet.type in ["leaf", "thorn"] and player.attack_power > atk, "evolved pet is stronger")


func _test_refine() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	_expect(Refine.attempt(player, "weapon", rng) == "none", "nothing worn, nothing to refine")
	player.bag.add("iron_sword", 1)
	player.equip("iron_sword")
	var atk: int = player.attack_power
	_expect(Refine.attempt(player, "weapon", rng) == "stone", "no crystal: refused")
	player.bag.add("crystal", 3)
	for i in 3:
		Refine.attempt(player, "weapon", rng)
	_expect(player.refine_level("weapon") == 3 and player.bag.count("crystal") == 0 and player.attack_power == atk + 6,
		"three crystals: +3, +2 attack each")
	player.bag.add("ruby", 30)
	var fails := 0
	while player.refine_level("weapon") < Refine.max_level():
		var level: int = player.refine_level("weapon")
		var r := {}
		Refine.attempt(player, "weapon", rng, r)
		if not r.ok:
			fails += 1
			_expect(player.refine_level("weapon") == level, "a failed ruby step keeps the level (D10)")
	_expect(Refine.attempt(player, "weapon", rng) == "max", "+6 is the top")
	_expect(player.bag.count("ruby") == 30 - 3 - fails, "one ruby per try, success or not")
	# UI: the first tap only arms the button
	main.get_node("%HUD").open_npc()
	await _frames(2)
	var hud: Node = main.get_node("%HUD")
	var first: Node = hud.shop_rows.get_child(hud.shop_rows.get_child_count() - 1)
	player.hp = player.max_hp * 0.5
	player._since_hit = 99.0
	await _frames(10)
	_expect(is_instance_valid(first) and not first.is_queued_for_deletion(), "HP regen does not rebuild the open shop list")
	player.unequip("weapon")
	player.bag.add("cloth_tunic", 1)
	player.equip("cloth_tunic")
	player.bag.add("crystal", 1)
	hud.refresh()
	await _frames(2)
	var rows: Array = hud.refine_rows.get_children().filter(func(r: Node) -> bool: return not r.is_queued_for_deletion())
	await _press(rows[0].action_button)
	_expect(player.refine_level("body") == 0 and player.bag.count("crystal") == 1, "first tap only asks to confirm")
	rows = hud.refine_rows.get_children().filter(func(r: Node) -> bool: return not r.is_queued_for_deletion())
	await _press(rows[0].action_button)
	_expect(player.refine_level("body") == 1 and player.bag.count("crystal") == 0, "second tap refines")
