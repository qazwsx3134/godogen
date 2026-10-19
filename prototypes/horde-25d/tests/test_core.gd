extends "res://addons/proto_kit/test_kit.gd"
## Core loop on the real main scene: spawning, hits and kills, gems and XP, level-up cards, death.
## Run with game time: godot-kit/tools/run_tests.sh prototypes/horde-25d core:60


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _frames(2)

	_expect(main.player != null and main.horde != null and main.arsenal != null, "main scene wires its systems")
	_expect(not main.get_node(^"%Previews").visible, "editor previews are hidden in a run")
	_expect(main.arsenal.weapons.size() == 1, "the run starts with one weapon")
	_expect(main.horde.defs.size() == 4, "four enemy types are loaded from data/enemies")

	await _until(func() -> bool: return main.horde.count >= 5, "enemies spawn around the player", 10.0)
	_expect(main.horde.multimesh.visible_instance_count == main.horde.count, "the horde MultiMesh draws every enemy")

	# A kill drops a gem and counts.
	var kills_before: int = main.kills
	var at := Vector2(3.0, 0.0) + main.player.ground()
	main.horde.spawn(0, at)
	main.horde.step(0.0, main.player.ground(), main.player.radius)
	var hits: int = main.horde.damage_circle(at, 0.5, 1000.0, 0.0)
	_expect(hits >= 1, "damage_circle hits an enemy standing in it")
	main.horde.flush_dead()
	_expect(main.kills > kills_before, "a killed enemy counts as a kill")
	_expect(main.gems.count >= 1, "a killed enemy drops a gem")

	# Enough XP opens the level-up cards and stops game time.
	main.player.take_hit(-1.0)
	main._add_xp(main._xp_needed())
	await _frames(2)
	_expect(main.hud.level_up_open(), "levelling up opens the card panel")
	_expect(main.hud.card_count() == 3, "three cards are offered")
	_expect(main.time_scale == 0.0, "game time stops while the cards are open")
	var owned: int = main.arsenal.weapons.size() + main.arsenal.passives.size()
	var level_of_first: int = 0
	main.hud._cards.get_child(0).pressed.emit()
	await _frames(2)
	_expect(not main.hud.level_up_open(), "picking a card closes the panel")
	_expect(main.time_scale > 0.0, "game time resumes after the pick")
	var owned_after: int = main.arsenal.weapons.size() + main.arsenal.passives.size()
	var levels_after: int = 0
	for l: int in main.arsenal.weapon_levels:
		levels_after += l
	for l: int in main.arsenal.passive_levels:
		levels_after += l
	_expect(owned_after > owned or levels_after > 1 + level_of_first, "the picked card is applied")

	# Weapons kill on their own.
	var kills_mid: int = main.kills
	await _until(func() -> bool: return main.kills > kills_mid, "the auto weapons kill enemies", 20.0)

	# Death shows the result.
	main.player._invuln = 0.0
	main.player.take_hit(99999.0)
	await _frames(2)
	_expect(main.finished and main.hud.result_open(), "dying ends the run and shows the result")

	main.queue_free()
	await _frames(2)
	_finish("CORE TESTS")
