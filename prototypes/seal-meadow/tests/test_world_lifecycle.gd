extends "res://addons/proto_kit/test_kit.gd"
## Cross-zone death, persisted respawn and interrupted portal fades.
const SaveSlots = preload("res://addons/proto_kit/save_slots.gd")
const Terrain = preload("res://scripts/terrain_height.gd")
const SAVE := "user://test_world_lifecycle/save.json"
var main: Node3D
var player: Node3D
var town_portal: Node3D

func _init() -> void:
	_run.call_deferred()

func _open() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.save_path = SAVE
	root.add_child(main)
	await _frames(4)
	main.set_process(false)
	player = main.player
	player.set_process(false)
	player.respawn_seconds = 0.03
	for m: Node3D in get_nodes_in_group("monster"):
		m.set_process(false)
	for portal: Node3D in get_nodes_in_group("portal"):
		if portal.arrival.x > 100.0:
			town_portal = portal

func _run() -> void:
	for path: String in [SAVE, SAVE + ".bak"]:
		DirAccess.remove_absolute(path)
	await _open()
	await main.travel(town_portal)
	_expect(main.zone == "town" and player.bounds_center == Terrain.TOWN_CENTER,
		"travel prepares town movement bounds")
	player.pet.stage = 2
	player.pet.type = "leaf"
	player.gold = 123
	player.bag.add("apple", 3)
	player.refresh_stats()
	main.save_game()
	main.queue_free()
	await _frames(3)
	await _open()
	_expect(main.zone == "town", "town save reopens in town")
	var deaths := [0]
	player.message.connect(func(text: String, _color: Color) -> void:
		if text.begins_with("你倒下"):
			deaths[0] += 1)
	player.set_mounted(true)
	player.take_damage(player.max_hp + 1)
	player.take_damage(player.max_hp + 1)
	await create_timer(0.06).timeout
	_expect(deaths[0] == 1 and not player.dead and player.hp == player.max_hp,
		"duplicate lethal events create one death and one full-health respawn")
	_expect(main.zone == "meadow" and player.bounds_center == Vector2.ZERO,
		"respawning at the meadow sign restores meadow zone and movement bounds")
	var at_spawn: Vector3 = player.position
	_expect(at_spawn.distance_to(player._spawn) < 0.01 and not player.mounted,
		"reopened town character respawns on foot at the original sign")
	main.pet_follower._process(0.0)
	_expect(main.pet_follower.global_position.distance_to(player.global_position) < 2.0,
		"one existing follower returns with the respawned player")
	_expect(main.rig.global_position.distance_to(player.global_position + Vector3.UP) < 0.01,
		"respawn camera immediately follows the new position")
	var saved: Dictionary = SaveSlots.restore(SAVE, main.SAVE_VERSION)
	_expect(saved.error == "" and absf(saved.data.x - at_spawn.x) < 0.01
		and absf(saved.data.z - at_spawn.z) < 0.01,
		"respawn position is checkpointed instead of reopening the old town position")
	player.move_to(at_spawn + Vector3(1, 0, 0))
	player._process(0.01)
	_expect(player.position.distance_to(at_spawn) < 0.2,
		"first movement after respawn cannot snap the player back toward town")
	_expect(player.gold == 123 and player.bag.count("apple") == 3 and player.pet.stage == 2,
		"respawn preserves inventory, gold and pet evolution")
	player._has_goal = false
	player.target = null
	player._since_hit = 99.0
	main.travel(town_portal)
	await _frames(1)
	player.take_damage(player.max_hp + 1)
	await create_timer(0.7).timeout
	_expect(not player.dead and not main._travelling and main.zone == "meadow"
		and player.position.distance_to(player._spawn) < 0.01,
		"death during portal fade cannot teleport a respawned character to the cancelled destination")
	_expect(not main.hud.fade_rect.visible, "interrupted portal restores the visible game")
	main.queue_free()
	await _frames(3)
	await _open()
	_expect(main.zone == "meadow" and player.position.distance_to(player._spawn) < 0.01,
		"reopening after interrupted travel restores the respawn checkpoint")
	main.queue_free()
	await _frames(2)
	_finish("SEAL MEADOW WORLD LIFECYCLE TESTS")
