extends "res://addons/proto_kit/test_kit.gd"
const Build = preload("res://scripts/run_build.gd")
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var config: Resource = load("res://data/progression.tres")
	var b = Build.new(config)
	b.award(14)
	_expect(b.level == 3 and b.experience == 1 and b.pending_choices == 2, "XP overflow preserves remainder and queues both levels")
	var offers: Array[Resource] = b.offers()
	_expect(offers.size() == 3 and offers[0].id == &"wave" and offers[1].id == &"kick" and offers[2].id == &"sweep", "first choice offers three distinct attack modes")
	_expect(not b.pick(&"wave_power"), "wave enhancement requires the wave")
	_expect(b.pick(&"wave") and b.count(&"wave") == 1, "picking an attack consumes one pending choice")
	_expect(not b.pick(&"wave"), "one-time unlock cannot stack")
	b.pending_choices = 100
	for item: Resource in config.upgrades:
		for i: int in item.max_stacks:
			_expect(b.pick(item.id) if b.count(item.id) < item.max_stacks else true, "legal upgrade remains pickable: " + String(item.id))
		_expect(not b.eligible(item), "max-stack upgrade is excluded: " + String(item.id))
	_expect(b.offers().is_empty(), "exhausted catalogue returns no invented duplicate choices")
	_expect(not b.pick(&"unknown"), "unknown upgrade is rejected")
	var fresh_build = Build.new(config)
	_expect(fresh_build.level == 1 and fresh_build.stacks.is_empty() and fresh_build.summary() == "基礎拳擊", "new run does not inherit mutable build state")
	fresh_build.rng.seed = 17
	fresh_build.award(5)
	fresh_build.pick(&"wave")
	for i: int in 15:
		var distinct: Dictionary = {}
		for item: Resource in fresh_build.offers():
			_expect(not distinct.has(item.id) and fresh_build.eligible(item), "random choices are distinct and legal")
			distinct[item.id] = true
	var game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await _frames(2)
	game.get_node("%TimeControl").hit_stop_scale = 1.0
	game.start_run()
	var street = game.street
	var hero = street.player
	var before_move: Vector2 = hero.position
	hero.punch(Vector2.LEFT)
	hero.step(0.01,Vector2.RIGHT,street.bounds)
	_expect(hero.visual.scale.x < 0.0 and hero.position.x > before_move.x, "moving preserves the active punch facing while locomotion continues")
	hero.reset()
	street.spawn_left = 1000
	var car = street.spawn_enemy(2,hero.position + Vector2(160,0))
	car.hit(10000,Vector2.RIGHT)
	var xp: int = street.build.total_experience
	_expect(xp == 3, "car kill awards its configured XP")
	car.hit(10000,Vector2.RIGHT)
	_expect(street.build.total_experience == xp, "lethal flight cannot award XP twice")
	game.gain_experience(2)
	game._physics_process(0.01)
	_expect(game.state == game.State.UPGRADE and paused and game.upgrade_panel.options.get_child_count() == 3, "level opens three scene cards and freezes world")
	var time_before: float = game.elapsed
	game._physics_process(10)
	_expect(game.elapsed == time_before and game.stick.vector == Vector2.ZERO, "selection freezes time and releases held input")
	_expect(not game.choose_upgrade(&"not_offered"), "cannot pick an unoffered card")
	game.upgrade_panel.options.get_child(0).pressed.emit()
	_expect(game.state == game.State.RUNNING and not paused and street.build.count(&"wave") == 1, "real card signal selects wave and resumes")
	street.clear()
	hero.reset()
	street.punches = 0
	street.spawn_left = 1000
	var target = street.spawn_enemy(2,hero.position + Vector2(65,0))
	target.definition = target.definition.duplicate()
	target.definition.speed = 0.0
	street.step(0.01,Vector2.ZERO,0)
	street.step(0.45,Vector2.ZERO,0)
	_expect(street.waves_fired == 1 and street.projectiles.get_child_count() == 1, "wave unlock adds a projectile every second punch")
	var wave = street.projectiles.get_child(0)
	var before: Vector2 = wave.step(0.5)
	_expect(wave.can_hit(target,before), "swept wave hits a target between frames")
	wave.remember(target)
	_expect(not wave.can_hit(target,before), "one projectile never hits the same target twice")
	street.clear()
	hero.reset()
	hero.attack_cooldown = 1000
	street.spawn_left = 1000
	var near = street.spawn_enemy(0,hero.position + Vector2(60,0))
	var far = street.spawn_enemy(0,hero.position + Vector2(200,0))
	street.build.pending_choices = 1
	street.build.pick(&"kick")
	street._roundhouse()
	_expect(near.hp < near.definition.max_hp and far.hp == far.definition.max_hp and street.kicks == 1, "roundhouse damages nearby enemies only")
	street.clear()
	hero.reset()
	street.spawn_left = 1000
	street.punches = 0
	street.build.pending_choices = 1
	street.build.pick(&"sweep")
	var front = street.spawn_enemy(0,hero.position + Vector2(45,0))
	var front_second = street.spawn_enemy(0,hero.position + Vector2(65,10))
	var behind = street.spawn_enemy(0,hero.position + Vector2(-80,0))
	street.step(0.01,Vector2.ZERO,0)
	_expect(front.hp < 68 and front_second.hp < 68 and behind.hp == 68, "sweep adds front targets without hitting behind the hero")
	game.gain_experience(40)
	game._physics_process(0.01)
	var old_generation: int = game.upgrade_generation
	var old_card = game.upgrade_panel.options.get_child(0)
	old_card.pressed.emit()
	var pending_before: int = street.build.pending_choices
	_expect(game.state == game.State.UPGRADE and game.upgrade_generation > old_generation, "multi-level XP opens the next pending selection")
	old_card.pressed.emit()
	_expect(street.build.pending_choices == pending_before, "stale card event cannot spend another queued choice")
	_expect(not game.choose_upgrade(game.current_offers[0].id,old_generation), "stale selection generation is rejected")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(game.state == game.State.UPGRADE and paused, "focus loss cannot bypass upgrade selection")
	while game.state == game.State.UPGRADE:
		game.choose_upgrade(game.current_offers[0].id)
	game.elapsed = 89.9
	street.build.award(100)
	game._physics_process(0.2)
	_expect(game.state == game.State.RESULTS and not game.upgrade_panel.visible, "end of run wins over late pending upgrades")
	_expect(street.projectiles.get_child_count() == 0, "finish reclaims attack projectiles")
	game.start_run()
	_expect(street.build.level == 1 and street.build.experience == 0 and street.build.stacks.is_empty() and street.best_combo == 0 and street.waves_fired == 0, "retry resets XP, attacks and combo")
	var player_scene = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	_expect(player_scene.get_node("Motion/Visual").position == Vector2.ZERO, "animation never changes authored player transform")
	player_scene.free()
	game.show_menu()
	game.queue_free()
	await _frames(2)
	OS.delay_msec(120)
	await _frames(2)
	print("checks: ",checks)
	_finish("STREET GROWTH")
