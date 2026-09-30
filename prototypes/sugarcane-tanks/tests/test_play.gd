extends "res://addons/proto_kit/test_kit.gd"
## Plays the real main scene. Run with --fixed-fps 60 so game time runs faster than
## the real-time timeouts:
##   godot --headless --path . --fixed-fps 60 --script res://tests/test_play.gd
##
## 1. Joystick drag moves the hero, and the hero does not throw while moving.
## 2. The bot clears room 1; a real button press picks a card; the door opens;
##    walking in loads room 2.
## 3. Starting at the boss room, the boss bar appears and killing the boss ends the chapter.
## 4. A tank winds up, dashes and runs the hero over (crushed).
## 5. Without god mode the hero gets hurt, dies, and "再來一次" reloads a fresh run.

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1080, 1920)
	await _joystick_and_room_flow()
	await _boss_room()
	await _tank_crush()
	await _death_and_restart()
	_finish("PLAY TESTS")

func _spawn_main(room_number: int) -> Node:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	main.room_index = room_number - 1
	root.add_child(main)
	main.get_node("%Hero").god_mode = true
	await _frames(2)
	return main

func _joystick_and_room_flow() -> void:
	var main: Node = await _spawn_main(1)
	var hero: CharacterBody2D = main.get_node("%Hero")
	var start: Vector2 = hero.global_position
	await _mouse(Vector2(540, 1500), true)
	await _move(Vector2(540, 1380))
	await _frames(3)
	var thrown_while_moving: int = main.volleys_thrown
	await create_timer(0.4).timeout
	_expect(hero.global_position.y < start.y - 40.0, "dragging the joystick up moves the hero up")
	_expect(main.volleys_thrown == thrown_while_moving, "no throwing while moving")
	await _mouse(Vector2(540, 1380), false)
	await _until(func() -> bool: return main.volleys_thrown > thrown_while_moving, "releasing the stick starts throwing", 3.0)

	main.autoplay = true
	var panel: Control = main.get_node("%ChoicePanel")
	await _until(func() -> bool: return panel.visible, "room 1 clear opens the level-up panel", 40.0)
	_expect(main.get_tree().paused, "the game pauses while choosing")
	_expect(main.stats.level >= 2, "room 1 EXP reaches level 2")
	_expect(main.state == main.State.REWARD, "door stays locked while choosing")
	var card: Button = panel.cards()[0]
	await _frames(2)
	await _press(card)
	await _until(func() -> bool: return not panel.visible, "pressing a card closes the panel", 3.0)
	var picked: int = 0
	for id: StringName in main.stats.stacks:
		picked += main.stats.count(id)
	_expect(picked == 1, "the pressed card was taken")
	_expect(main.get_node("%Hud").get_node("%AbilityChips").get_child_count() == 1, "HUD shows the picked ability")
	await _until(func() -> bool: return main.state == main.State.DOOR, "door opens after the pick", 10.0)
	await _until(func() -> bool: return main.room_index == 1 and main.state == main.State.FIGHT, "walking into the door loads room 2", 15.0)
	_expect(main.get_node("%RoomHolder").get_child_count() == 1, "only the current room is loaded")
	main.queue_free()
	root.get_tree().paused = false
	await _frames(2)

func _boss_room() -> void:
	var main: Node = await _spawn_main(10)
	main.autoplay = true
	main.auto_pick = true
	for i: int in 5:
		main.stats.add_ability(&"attack_boost")
		main.stats.add_ability(&"attack_speed")
	var boss_panel: Control = main.get_node("%Hud").get_node("%BossPanel")
	await _until(func() -> bool: return boss_panel.visible, "boss bar appears in the boss room", 5.0)
	await _until(func() -> bool: return main.state == main.State.WON, "killing the boss clears the chapter", 90.0)
	_expect(main.get_node("%ResultPanel").visible, "chapter clear screen shows")
	_expect(not boss_panel.visible, "boss bar hides after the kill")
	main.queue_free()
	await _frames(2)

func _death_and_restart() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	main.room_index = 5   # room 6: plates and rats, the hero just stands there
	root.add_child(main)
	current_scene = main
	await _frames(2)
	var hero: CharacterBody2D = main.get_node("%Hero")
	var full: int = main.stats.hp
	await _until(func() -> bool: return main.stats.hp < full, "standing still, the hero gets hurt", 20.0)
	_expect(hero.get_node("%HpLabel").text == str(main.stats.hp), "HP label shows current HP")
	main.stats.take_damage(main.stats.hp - 1)
	hero.refresh_hp()
	await _until(func() -> bool: return hero.dead, "the next hit kills the hero", 20.0)
	var result: Control = main.get_node("%ResultPanel")
	await _until(func() -> bool: return result.visible, "defeat screen shows", 5.0)
	var old_id: int = main.get_instance_id()
	await _press(result.get_node("%RestartButton"))
	await _until(func() -> bool:
		return current_scene != null and current_scene.get_instance_id() != old_id and current_scene.is_node_ready(),
		"restart loads a fresh main", 5.0)
	var fresh: Node = current_scene
	if fresh != null and fresh.get_instance_id() != old_id:
		_expect(fresh.room_index == 0 and fresh.stats.level == 1, "restart begins at room 1, level 1")
		_expect(not paused and is_equal_approx(Engine.time_scale, 1.0), "restart is not paused or slowed")
		fresh.queue_free()
	await _frames(2)

func _tank_crush() -> void:
	var main: Node = await _spawn_main(2)   # room 2: four rats and one tank
	var hero: CharacterBody2D = main.get_node("%Hero")
	hero.god_mode = false
	hero.active = false   # stand still and do not throw
	var tank: Node2D = null
	for enemy: Node in main.room.get_node("%Enemies").get_children():
		if enemy.scene_file_path.ends_with("tank.tscn"):
			tank = enemy
		else:
			enemy.queue_free()
	_expect(tank != null, "room 2 has a tank")
	await _until(func() -> bool: return tank.phase == tank.Phase.WINDUP, "the tank winds up before dashing", 15.0)
	_expect(tank.get_node("%DashLine").visible, "a red line warns where it will dash")
	var hp_before: int = main.stats.hp
	await _until(func() -> bool: return main.stats.hp < hp_before, "the dash runs the hero over", 10.0)
	_expect(hero.last_hit_crushed, "the hit counts as crushed (hero flattens)")
	_expect(hp_before - main.stats.hp == tank.crush_damage, "crush does crush_damage")
	main.queue_free()
	await _frames(2)
