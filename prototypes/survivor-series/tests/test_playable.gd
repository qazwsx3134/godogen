extends "res://addons/proto_kit/test_kit.gd"
const FontCheck = preload("res://addons/proto_kit/font_check.gd")
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await _frames(2)
	var street = game.street
	var hero = street.player
	game.get_node("%TimeControl").hit_stop_scale = 1.0
	_expect(game.state == game.State.MENU, "starts in menu")
	game.menu.get_node("%Start").pressed.emit()
	_expect(game.state == game.State.RUNNING and street.living_count() == 3, "start button seeds all three enemy types")
	var initial_speed: float = hero.move_speed
	var original: Vector2 = hero.position
	game.stick.vector = Vector2(1,0)
	game._physics_process(0.05)
	_expect(hero.position.x > original.x and street.punches == 1, "moving still attacks a nearby enemy")
	_expect(game.sound_events.has(&"hit") and game.sound_events.has(&"punch"), "ordinary hit emits distinct audio events")
	var smoker = street.enemies.get_child(0)
	_expect(smoker.hp_bar.size.y <= 8.0, "enemy health bar stays thin after theme resolution")
	var killed_before: int = street.kills
	smoker.hit(10000.0,Vector2.UP)
	_expect(smoker.dead and street.kills == killed_before + 1, "lethal hit immediately scores one kill")
	smoker.hit(10000.0,Vector2.UP)
	_expect(street.kills == killed_before + 1, "flight cannot score twice")
	_expect(street.nearest_enemy() != smoker, "flight is excluded from target selection")
	_expect(game.sound_events.has(&"launch"), "lethal hit has a launch sound")
	var flying_at: Vector2 = smoker.position
	smoker.step(0.2,hero.position,street.bounds)
	_expect(smoker.position.distance_to(flying_at) > 200.0, "lethal flight leaves normal movement bounds")
	street.clear()
	var light = street.spawn_enemy(0,Vector2(200,300))
	var car = street.spawn_enemy(2,Vector2(300,300))
	light.hit(1.0,Vector2.RIGHT)
	car.hit(1.0,Vector2.RIGHT)
	_expect(light.knockback.length() > car.knockback.length() * 4.0, "car resists ordinary knockback")
	var bike = street.spawn_enemy(1,Vector2(100,250))
	bike.hazard_left = 0.0
	bike.step(0.01,Vector2(200,250),street.bounds)
	_expect(bike.phase == "warning" and bike.warning.visible, "bike telegraphs before charging")
	var locked_direction: Vector2 = bike.dash_direction
	bike.step(0.1,Vector2(100,600),street.bounds)
	_expect(bike.dash_direction == locked_direction, "telegraphed lane does not retarget")
	bike.step(0.9,Vector2(100,600),street.bounds)
	bike.step(0.05,Vector2(100,600),street.bounds)
	_expect(bike.phase == "dash" and not bike.warning.visible, "bike enters charge after warning")
	street.clear()
	street.spawn_left = 1000.0
	hero.attack_cooldown = 1000.0
	street._smoke(hero.position)
	for i: int in 12:
		street.step(0.1,Vector2.ZERO,0.0)
	_expect(street.hits_taken >= 2 and street.hits_taken <= 3, "smoke repeatedly hurts with a shared cooldown")
	_expect(hero.move_speed == initial_speed, "smoke does not slow the hero")
	_expect(street.hazards.get_child_count() == 1, "smoke hazard persists before expiry")
	street.hazards.get_child(0).step(4.0)
	await _frames(2)
	_expect(street.hazards.get_child_count() == 0, "smoke expires and is reclaimed")
	game.pause_run()
	var elapsed_before: float = game.elapsed
	game._physics_process(1.0)
	_expect(game.state == game.State.PAUSED and game.elapsed == elapsed_before and game.stick.vector == Vector2.ZERO, "pause stops simulation and releases input")
	game.resume_run()
	_expect(not paused and game.state == game.State.RUNNING, "resume restores simulation")
	game.start_run()
	_expect(street.kills == 0 and street.hits_taken == 0 and street.punches == 0 and street.hazards.get_child_count() == 0, "retry resets run state")
	game.stick.vector = Vector2.ZERO
	for i: int in 180:
		while game.state == game.State.UPGRADE:
			game.choose_upgrade(game.current_offers[0].id)
		game._physics_process(0.5)
		if i % 15 == 0:
			_expect(street.living_count() <= street.max_enemies, "spawn count remains bounded")
		await _frames()
	_expect(game.state == game.State.RESULTS and is_equal_approx(game.elapsed,90.0), "full 90-second game-time run finishes")
	_expect(street.enemies.get_child_count() == 0 and street.hazards.get_child_count() == 0 and street.effects.get_child_count() == 0, "finish reclaims all runtime objects")
	_expect(game.results.visible and game.sound_events.has(&"finish"), "finish shows results and audio event")
	game.results.get_node("%Retry").pressed.emit()
	_expect(game.state == game.State.RUNNING and game.elapsed == 0.0 and street.kills == 0, "result retry button starts a clean run")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(game.state == game.State.PAUSED, "focus loss pauses and requires explicit resume")
	game.resume_run()
	var authored_title := game.menu.get_node("%Title") as Label
	authored_title.text = "手動修改保留"
	game.show_menu()
	game.start_run()
	_expect(authored_title.text == "手動修改保留", "navigation preserves authored static text")
	var fresh = (load("res://scenes/street.tscn") as PackedScene).instantiate()
	_expect(fresh.get_node("%Player").position == Vector2(270,650), "runtime movement does not change source scene")
	fresh.free()
	var missing: String = FontCheck.missing_characters(load("res://assets/fonts/NotoSansTC.ttf"))
	_expect(missing.is_empty(), "font contains game text: " + missing)
	for screen: Control in [game.menu, game.hud, game.results, game.pause_panel]:
		_expect(screen.get_theme_font("font").has_char("揍".unicode_at(0)), "actual screen theme uses a Chinese font: " + screen.name)
	_expect(game.hud.get_node("%Pause").size.x >= 60.0, "pause touch target has enough width")
	street.camera.offset = Vector2(3,2)
	street.camera.rotation = 0.01
	game.hud.get_node("%ShakeToggle").button_pressed = false
	_expect(street.camera.offset == Vector2.ZERO and street.camera.rotation == 0.0 and street.shake.shake_scale == 0.0, "disabling shake restores the camera immediately")
	game.show_menu()
	game.queue_free()
	await _frames(2)
	# The native audio mixer runs on wall time even when test game time is accelerated.
	OS.delay_msec(120)
	await _frames(2)
	print("checks: ", checks)
	_finish("STREET PLAYABLE")
