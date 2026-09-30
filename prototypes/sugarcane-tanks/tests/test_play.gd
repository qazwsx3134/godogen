extends "res://addons/proto_kit/test_kit.gd"
## Plays the real main scene. Run with --fixed-fps 60 so game time runs faster than
## the real-time timeouts:
##   godot --headless --path . --fixed-fps 60 --script res://tests/test_play.gd
##
## 1. Joystick drag moves the hero, and the hero does not throw while moving.
## 2. The bot clears room 1; a real button press picks a card; the door opens;
##    walking in loads room 2.
## 3. Starting at the boss room, the boss bar appears, the final boss opens with its red circles
##    (one under the hero, spread over the floor), and killing the boss ends the chapter.
## 4. A tank winds up, dashes and runs the hero over (crushed).
## 5. Without god mode the hero gets hurt, dies, and "再來一次" reloads a fresh run.
## 6. A red circle hurts a hero whose centre is inside it when it blows up, not one just outside;
##    the bot walks out of a circle in time. Below half HP the boss drops more circles, filling faster.
## 7. HUD: the joystick base follows the finger and parks again (always visible); clearing a room adds
##    coins and the HUD count matches; the boss room swaps the HUD layout; HP follows damage; the
##    defeat screen shows the run's coins and a restart starts at 0.

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1080, 1920)
	await _joystick_and_room_flow()
	await _boss_room()
	await _tank_crush()
	await _aoe_damage()
	await _aoe_enraged()
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
	var base: Control = main.get_node("%Hud").get_node("%Joystick").get_node("%Base")
	var parked: Vector2 = base.global_position
	_expect(base.visible, "the joystick base is shown before any touch")
	await _mouse(Vector2(540, 1500), true)
	await _move(Vector2(540, 1380))
	await _frames(3)
	_expect(base.global_position.distance_to(Vector2(540, 1500) - base.size * 0.5) < 2.0, "the joystick base appears under the finger")
	var thrown_while_moving: int = main.volleys_thrown
	await create_timer(0.4).timeout
	_expect(hero.global_position.y < start.y - 40.0, "dragging the joystick up moves the hero up")
	_expect(main.volleys_thrown == thrown_while_moving, "no throwing while moving")
	await _mouse(Vector2(540, 1380), false)
	_expect(base.visible and base.global_position.distance_to(parked) < 2.0, "releasing parks the joystick base again, still visible")
	await _until(func() -> bool: return main.volleys_thrown > thrown_while_moving, "releasing the stick starts throwing", 3.0)

	main.autoplay = true
	var panel: Control = main.get_node("%ChoicePanel")
	await _until(func() -> bool: return panel.visible, "room 1 clear opens the level-up panel", 40.0)
	_expect(main.coins > 0, "clearing the room collects coins")
	_expect(main.get_node("%Hud").get_node("%CoinLabel").text == str(main.coins), "the HUD coin count matches")
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
	var hud: Control = main.get_node("%Hud")
	var boss_panel: Control = hud.get_node("%BossPanel")
	await _until(func() -> bool: return boss_panel.visible, "boss bar appears in the boss room", 5.0)
	_expect(not hud.get_node("%PlayerPanel").visible and hud.get_node("%BottomHeroPanel").visible and not hud.get_node("%AbilityChips").visible,
		"the boss room hides the player block and ability slots, and shows the hero's HP at the bottom")
	_expect(hud.get_node("%HpLabel").text == "%d / %d" % [main.stats.hp, main.stats.max_hp], "the HUD starts with the hero's HP")
	await _until(func() -> bool: return not _circles(main).is_empty(), "the final boss drops red circles", 15.0)
	var circles: Array = _circles(main)
	var boss: Node2D = main.room.get_node("%Enemies").get_child(0)
	var hero: Node2D = main.get_node("%Hero")
	_expect(circles.size() == boss.aoe_count, "the first round drops %d circles" % boss.aoe_count)
	_expect(circles.any(func(c: Node2D) -> bool: return c.global_position.distance_to(hero.global_position) < 60.0), "one circle is under the hero")
	var apart: bool = true
	for i: int in circles.size():
		_expect(Rect2(60, 260, 960, 1500).has_point(circles[i].global_position), "circle %d is on the floor" % i)
		for j: int in range(i + 1, circles.size()):
			apart = apart and circles[i].global_position.distance_to(circles[j].global_position) >= circles[i].radius * boss.aoe_spacing - 0.01
	_expect(apart, "no two circles are closer than aoe_spacing radii (they do not pile up)")
	await _until(func() -> bool: return main.state == main.State.WON, "killing the boss clears the chapter", 90.0)
	_expect(main.get_node("%ResultPanel").visible, "chapter clear screen shows")
	_expect(not boss_panel.visible, "boss bar hides after the kill")
	_expect(hud.get_node("%PlayerPanel").visible and not hud.get_node("%BottomHeroPanel").visible, "the room layout returns after the boss")
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
	_expect(main.get_node("%Hud").get_node("%HpLabel").text == "%d / %d" % [main.stats.hp, main.stats.max_hp], "the HUD HP follows the damage")
	main.stats.take_damage(main.stats.hp - 1)
	hero.refresh_hp()
	main.coins = 12   # as if picked up during the run
	await _until(func() -> bool: return hero.dead, "the next hit kills the hero", 20.0)
	var result: Control = main.get_node("%ResultPanel")
	await _until(func() -> bool: return result.visible, "defeat screen shows", 5.0)
	_expect(result.get_node("%CoinsLabel").text == "金幣 12", "the defeat screen shows the run's coins")
	var old_id: int = main.get_instance_id()
	await _press(result.get_node("%RestartButton"))
	await _until(func() -> bool:
		return current_scene != null and current_scene.get_instance_id() != old_id and current_scene.is_node_ready(),
		"restart loads a fresh main", 5.0)
	var fresh: Node = current_scene
	if fresh != null and fresh.get_instance_id() != old_id:
		_expect(fresh.room_index == 0 and fresh.stats.level == 1, "restart begins at room 1, level 1")
		_expect(fresh.coins == 0 and fresh.get_node("%Hud").get_node("%CoinLabel").text == "0", "restart starts with no coins")
		_expect(not paused and is_equal_approx(Engine.time_scale, 1.0), "restart is not paused or slowed")
		fresh.queue_free()
	await _frames(2)

## Red circles that have not blown up yet.
func _circles(main: Node) -> Array:
	return main.get_node("%EnemyShots").get_children().filter(func(c: Node) -> bool: return c.has_method(&"is_aoe") and c.is_aoe())

## Drops a circle centred `radii` radii to the right of the hero.
func _drop_circle(main: Node, hero: Node2D, radii: float, time: float) -> Node2D:
	var circle: Node2D = (load("res://effects/aoe_circle.tscn") as PackedScene).instantiate() as Node2D
	circle.game = main
	circle.telegraph_time = time
	circle.position = hero.global_position + Vector2.RIGHT * circle.radius * radii
	main.get_node("%EnemyShots").add_child(circle)
	return circle

## Drops a circle and waits until it has blown up.
func _blow_up(main: Node, hero: Node2D, radii: float, time: float = 0.3) -> Node2D:
	var circle: Node2D = _drop_circle(main, hero, radii, time)
	await _until(func() -> bool: return circle.exploded, "a red circle blows up", 5.0)
	await _frames(2)
	return circle

## Only the hero's centre counts: 13 px outside the rim (its body reaches in) is safe, 13 px inside hurts.
## Outside is tested first: a hit starts the hero's invulnerability, which would hide a false hit after it.
func _aoe_damage() -> void:
	var main: Node = await _spawn_main(10)
	var hero: CharacterBody2D = main.get_node("%Hero")
	hero.god_mode = false
	hero.active = false   # stand still and do not throw
	main.room.process_mode = Node.PROCESS_MODE_DISABLED   # the boss never wakes up, only the circles act
	var hp_before: int = main.stats.hp
	await _blow_up(main, hero, 1.1)
	_expect(main.stats.hp == hp_before, "a hero just outside a red circle takes no damage")
	var inside: Node2D = await _blow_up(main, hero, 0.9)
	_expect(hp_before - main.stats.hp == inside.damage, "a hero inside a red circle takes its damage")
	hp_before = main.stats.hp
	main.autoplay = true
	hero.active = true
	var under: Node2D = await _blow_up(main, hero, 0.0, 1.0)
	_expect(main.stats.hp == hp_before, "the bot walks out of a red circle before it blows up")
	_expect(hero.global_position.distance_to(under.global_position) > under.radius, "the bot ends outside the circle")
	# The hero dying stops EnemyShots: a circle that is still filling freezes like a bullet and never blows up.
	var pending: Node2D = _drop_circle(main, hero, 3.0, 0.6)
	hero.take_hit(9999)
	await create_timer(1.2).timeout
	_expect(hero.dead and is_instance_valid(pending) and not pending.exploded, "a dead hero freezes red circles like bullets")
	main.queue_free()
	await _frames(2)

func _aoe_enraged() -> void:
	var main: Node = await _spawn_main(10)
	var boss: Node2D = main.room.get_node("%Enemies").get_child(0)
	boss.hp = boss.max_hp / 4
	await _until(func() -> bool: return not _circles(main).is_empty(), "the wounded boss drops red circles", 15.0)
	var circles: Array = _circles(main)
	_expect(circles.size() == boss.aoe_count_enraged and boss.aoe_count_enraged > boss.aoe_count, "below half HP the boss drops more circles")
	_expect(circles[0].telegraph_time == boss.aoe_telegraph_time_enraged and boss.aoe_telegraph_time_enraged < boss.aoe_telegraph_time, "and they fill faster")
	main.queue_free()
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
	_expect(main.get_node("%Hud").get_node("%HpLabel").text == "%d / %d" % [main.stats.hp, main.stats.max_hp], "the HUD HP follows the crush")
	main.queue_free()
	await _frames(2)
