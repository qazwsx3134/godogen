extends "res://addons/proto_kit/test_kit.gd"
## Combat, weapons, enemies, drops, spawning and the screen flow.
const FontCheck = preload("res://addons/proto_kit/font_check.gd")
const Grid = preload("res://scripts/grid.gd")
const META_PATH = "user://test_playable_meta.json"
func _initialize() -> void:
	run.call_deferred()

## Clears the street and gives the build exactly these weapons at level 1.
func _arm(street: Node2D, ids: Array) -> void:
	street.clear()
	street.player.reset()
	street.arsenal.reset()
	street.spawn_left = 1000.0
	street.phase_index = 0
	street.build.weapons.clear()
	street.build.levels.clear()
	for id: StringName in ids:
		street.build.weapons.append(id)
		street.build.levels[id] = 1

func _settle(street: Node2D, steps: int, dt: float = 1.0 / 30.0) -> void:
	for i: int in steps:
		street.step(dt, Vector2.ZERO, 0.0)

func run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(META_PATH))
	var game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	game.get_node("Services/Meta").save_path = META_PATH
	root.add_child(game)
	game.set_physics_process(false)
	await _frames(2)
	var street = game.street
	var hero = street.player
	game.get_node("%TimeControl").hit_stop_scale = 1.0
	_expect(game.state == game.State.MENU, "starts in menu")
	game.menu.get_node("%Start").pressed.emit()
	_expect(game.state == game.State.RUNNING and street.living_count() == 3, "start button seeds the three opening enemies")
	_expect(game.hud.get_node("%Time").text == "00:00", "HUD clock counts up from 00:00")
	street.coins = 3
	game.refresh_hud()
	_expect(game.hud.get_node("%Coins").text == "金幣  %d" % (3 * game.coin_value), "HUD coins use the same unit as the results payout")
	street.coins = 0
	street.spawn_left = 1000.0
	var original: Vector2 = hero.position
	street.enemies.get_child(0).position = hero.position + Vector2(60, 0)
	game.stick.vector = Vector2(1, 0)
	game._physics_process(0.05)
	_expect(hero.position.x > original.x and street.arsenal.punches == 1, "moving still punches a nearby enemy")
	_expect(game.sound_events.has(&"punch"), "a punch has its own sound")
	_expect(street.camera.position == hero.position, "camera follows the hero")
	game.stick.vector = Vector2.ZERO

	_arm(street, [])
	var kills_before: int = street.kills
	var smoker = street.spawn_enemy(0, hero.position + Vector2(200, 0))
	_expect(not smoker.hp_bar.visible and smoker.hp_bar.size.y <= 8.0, "ordinary enemies hide their thin health bar")
	smoker.hit(10000.0, Vector2.UP)
	_expect(smoker.dead and street.kills == kills_before + 1, "a lethal hit scores one kill")
	smoker.hit(10000.0, Vector2.UP)
	_expect(street.kills == kills_before + 1, "flight cannot score twice")
	var gems: Array = street.pickups.get_children().filter(func(p: Node2D) -> bool: return p.kind == "xp")
	_expect(gems.size() == 1 and is_equal_approx(gems[0].value, 1.0), "a kill drops an XP gem worth the enemy's experience")
	street.grid.rebuild(street.enemies.get_children())
	_expect(street.grid.query(smoker.position, 50.0).is_empty(), "flying enemies are excluded from targeting")
	var flying_at: Vector2 = smoker.position
	smoker.step(0.2, hero.position, street.bounds)
	_expect(smoker.position.distance_to(flying_at) > 200.0, "lethal flight leaves normal movement bounds")
	gems[0].position = hero.position + Vector2(50, 0)
	var xp_before: float = street.build.total_experience
	_settle(street, 15)
	_expect(street.build.total_experience > xp_before and gems[0].is_queued_for_deletion(), "the magnet pulls the gem in and collects it")

	_arm(street, [])
	street.max_gems = 3
	for i: int in 6:
		street.drop("xp", hero.position + Vector2(400, i * 10), 2.0)
	var total: float = 0.0
	for item: Node2D in street.pickups.get_children():
		total += item.value
	_expect(street.pickups.get_child_count() == 4 and is_equal_approx(total, 12.0) and street.big_gem.value >= 6.0, "gems past the cap merge into one big gem without losing XP")
	street.max_gems = 160

	_arm(street, [])
	var light = street.spawn_enemy(0, Vector2(300, 300))
	var car = street.spawn_enemy(2, Vector2(500, 300))
	light.hit(1.0, Vector2.RIGHT)
	car.hit(1.0, Vector2.RIGHT)
	_expect(light.knockback.length() > car.knockback.length() * 4.0, "car resists ordinary knockback")
	var bike = street.spawn_enemy(1, Vector2(300, 600))
	bike.hazard_left = 0.0
	bike.step(0.01, Vector2(500, 600), street.bounds)
	_expect(bike.phase == "warning" and bike.warning.visible, "bike telegraphs before charging")
	var locked: Vector2 = bike.dash_direction
	bike.step(0.1, Vector2(300, 900), street.bounds)
	_expect(bike.dash_direction == locked, "telegraphed lane does not retarget")
	bike.step(0.9, Vector2(300, 900), street.bounds)
	bike.step(0.05, Vector2(300, 900), street.bounds)
	_expect(bike.phase == "dash" and not bike.warning.visible, "bike enters charge after warning")
	_expect(bike.contact_damage() > bike.definition.contact_damage * 2.0, "a charging bike hits harder than a parked one")

	car.face(Vector2.LEFT)
	_expect(car.placeholder.scale.x < 0.0, "vehicle placeholder mirrors for a westward heading")
	var textures: Array[Texture2D] = []
	for i: int in 5:
		var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		textures.append(ImageTexture.create_from_image(image))
	car.direction_textures = textures
	car.art.visible = true
	car.face(Vector2.UP)
	_expect(car.art.texture == textures[4] and not car.art.flip_h, "heading north shows the north drawing")
	car.face(Vector2(-1, 1))
	_expect(car.art.texture == textures[1] and car.art.flip_h, "heading south-west mirrors the south-east drawing")
	car.face(Vector2.DOWN)
	_expect(car.art.texture == textures[0], "heading south shows the south drawing")
	var person = street.spawn_enemy(0, Vector2(700, 300))
	person.face(Vector2.LEFT)
	_expect(person.placeholder.scale.x < 0.0 and person.placeholder.rotation == 0.0, "people only flip, never tilt")

	_arm(street, [])
	hero.attack_cooldown = 1000.0
	street._smoke(hero.position)
	for i: int in 12:
		street.step(0.1, Vector2.ZERO, 0.0)
	_expect(street.hits_taken >= 2 and street.hits_taken <= 3, "smoke repeatedly hurts with a shared invulnerability window")
	_expect(hero.hp < hero.hp_limit and street.damage_sources.has("smoke"), "smoke damage is recorded by source")
	street.hazards.get_child(0).step(4.0)
	await _frames(2)
	_expect(street.hazards.get_child_count() == 0, "smoke expires and is reclaimed")
	for i: int in 30:
		street._smoke(Vector2(200 + i, 200))
	_expect(street.hazards.get_child_count() == street.max_hazards, "smoke clouds are capped")

	_arm(street, [])
	var fat = street.spawn_enemy(3, hero.position + Vector2(50, 0))
	var start: Vector2 = hero.position
	street.step(0.1, Vector2.LEFT, 0.0)
	var slowed: float = start.distance_to(hero.position)
	fat.position = Vector2(1000, 1500)
	var free_start: Vector2 = hero.position
	street.step(0.1, Vector2.LEFT, 0.0)
	_expect(slowed < free_start.distance_to(hero.position) * 0.7, "the fatty's stink aura slows the hero")
	_arm(street, [])
	var fat_a = street.spawn_enemy(3, Vector2(400, 400))
	var fat_b = street.spawn_enemy(3, Vector2(470, 400))
	var fat_c = street.spawn_enemy(3, Vector2(560, 400))
	fat_b.hp = 1.0
	fat_c.hp = 1.0
	fat_a.hit(10000.0, Vector2.LEFT)
	_expect(street.bursts_fired == 0 and street._bursts.size() == 1, "a fatty's fart is queued, not fired inside hit()")
	street.step(0.01, Vector2.ZERO, 0.0)
	_expect(street.bursts_fired == 1 and fat_b.dead and street._bursts.size() == 1, "the fart launches a neighbour, whose own fart waits for the next step")
	street.step(0.01, Vector2.ZERO, 0.0)
	_expect(street.bursts_fired == 2 and fat_c.dead, "fart chains resolve one link per step")
	_expect(game.sound_events.has(&"fart"), "farts have a sound")
	var fart_ring = (load("res://scenes/blast.tscn") as PackedScene).instantiate()
	street.effects.add_child(fart_ring)
	_expect(fart_ring.caption.get_theme_font("font").has_char("噗".unicode_at(0)), "the fart caption uses the Chinese font")

	var g = Grid.new()
	var actors: Array = []
	for i: int in 40:
		actors.append(street.spawn_enemy(0, Vector2(100 + (i * 37) % 900, 100 + (i * 53) % 1400)))
	g.rebuild(actors)
	var probe := Vector2(500, 700)
	var brute: int = actors.filter(func(a: Node2D) -> bool: return a.position.distance_to(probe) <= 260.0 + a.definition.radius).size()
	_expect(g.query(probe, 260.0).size() == brute, "grid query matches a brute-force scan")

	for entry: Array in [[&"wave", "a wave"], [&"slipper", "a slipper"], [&"pearl", "a pearl"], [&"firecracker", "a firecracker"], [&"incense", "incense"], [&"lantern", "a lantern"], [&"kick", "a kick"], [&"cane", "the cane"], [&"homing_slipper", "the homing slipper"], [&"beehive", "a rocket"], [&"mazu", "the permanent incense"], [&"iron_palm", "the iron palm"], [&"pearl_storm", "pearl storm"], [&"pingxi", "sky lanterns"], [&"duster", "the duster"]]:
		_arm(street, [entry[0]])
		street.camera.position = hero.position
		var target = street.spawn_enemy(2, hero.position + Vector2(70, 10))
		target.definition = target.definition.duplicate()
		target.definition.speed = 0.0
		target.setup(30.0, false)
		_settle(street, 60)
		_expect(target.hp < target.max_hp and int(street.arsenal.fired.get(entry[0], 0)) > 0, "%s fires and damages a nearby enemy" % entry[1])

	_arm(street, [&"incense"])
	street.spawn_enemy(2, hero.position + Vector2(300, 0))
	_settle(street, 2)
	var orbiters: int = street.projectiles.get_children().filter(func(p: Node2D) -> bool: return p.mode == "orbit").size()
	_expect(orbiters == 3, "three incense sticks orbit the hero")
	_arm(street, [&"mazu"])
	_settle(street, 200)
	orbiters = street.projectiles.get_children().filter(func(p: Node2D) -> bool: return p.mode == "orbit" and not p.is_queued_for_deletion()).size()
	_expect(orbiters == 6, "Mazu's procession stays and never stacks past its amount")
	var shot = (load("res://scenes/pearl.tscn") as PackedScene).instantiate()
	street.projectiles.add_child(shot)
	var dummy = street.spawn_enemy(0, Vector2(800, 800))
	shot.position = dummy.position
	shot.rehit = 0.5
	_expect(shot.can_hit(dummy, dummy.position), "a projectile can hit an enemy it touches")
	shot.remember(dummy)
	_expect(not shot.can_hit(dummy, dummy.position), "the same projectile cannot re-hit before its interval")
	shot.age += 0.6
	_expect(shot.can_hit(dummy, dummy.position), "a persistent projectile hits again after its interval")

	_arm(street, [])
	var schedule: Resource = street.schedule
	_expect(schedule.index_at(0.0) == 0 and schedule.index_at(305.0) == 5 and schedule.index_at(599.0) == schedule.phases.size() - 1, "the timeline finds the phase for each time")
	street.phase_index = -1
	street.spawn_left = 0.0
	street._spawn(0.01, 125.0, 0)
	var ring: int = street.enemies.get_child_count()
	_expect(ring >= schedule.phases[2].ring, "entering a ring phase surrounds the hero")
	_arm(street, [])
	street.phase_index = -1
	street._spawn(0.01, 245.0, 0)
	var elites: Array = street.enemies.get_children().filter(func(e: Node2D) -> bool: return e.elite)
	_expect(elites.size() == 1 and elites[0].definition.kind == "fatty" and elites[0].hp_bar.visible and elites[0].max_hp > elites[0].definition.max_hp * 10.0, "an elite fatty arrives at 04:00 with a visible health bar")
	elites[0].hit(1e9, Vector2.UP)
	_expect(street.pickups.get_children().any(func(p: Node2D) -> bool: return p.kind == "chest"), "an elite drops a chest")
	_arm(street, [])
	street.phase_index = 0
	for i: int in 400:
		street.spawn_left = 0.0
		street._spawn(0.01, 30.0, street.living_count())
	_expect(street.living_count() <= schedule.phases[0].max_alive, "spawning respects the phase cap")
	var view: Rect2 = street.view_rect()
	var outside: bool = true
	for i: int in 50:
		var at: Vector2 = street.spawn_point()
		outside = outside and street.bounds.has_point(at) and not view.has_point(at)
	_expect(outside, "new enemies appear inside the block but outside the screen")

	game.start_run()
	game.pause_run()
	var elapsed_before: float = game.elapsed
	game._physics_process(1.0)
	_expect(game.state == game.State.PAUSED and game.elapsed == elapsed_before and game.stick.vector == Vector2.ZERO, "pause stops simulation and releases input")
	game.resume_run()
	_expect(not paused and game.state == game.State.RUNNING, "resume restores simulation")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(game.state == game.State.PAUSED, "focus loss pauses and requires explicit resume")
	game.resume_run()

	game.session_duration = 30.0
	game.start_run()
	game.auto_play = true
	for i: int in 120:
		while game.state == game.State.UPGRADE:
			game.choose_upgrade(game.current_offers[0].id)
		if game.state == game.State.RESULTS:
			break
		game._physics_process(0.25)
		_expect(street.living_count() <= street.max_enemies, "living enemies stay bounded")
		await _frames()
	game.auto_play = false
	_expect(game.state == game.State.RESULTS and street.kills > 0, "an autopiloted short run reaches the results")
	_expect(street.enemies.get_child_count() == 0 and street.hazards.get_child_count() == 0 and street.effects.get_child_count() == 0 and street.pickups.get_child_count() == 0, "results reclaim all runtime objects")
	game.results.get_node("%Retry").pressed.emit()
	_expect(game.state == game.State.RUNNING and game.elapsed == 0.0 and street.kills == 0, "result retry button starts a clean run")
	game.session_duration = 600.0

	var authored_title := game.menu.get_node("%Title") as Label
	authored_title.text = "手動修改保留"
	game.show_menu()
	game.start_run()
	_expect(authored_title.text == "手動修改保留", "navigation preserves authored static text")
	var fresh = (load("res://scenes/street.tscn") as PackedScene).instantiate()
	_expect(fresh.get_node("%Player").position == Vector2(600, 840), "runtime movement does not change the source scene")
	_expect(fresh.get_node("%Enemies").get_child_count() == 4, "the street scene shows all four enemy kinds in the editor")
	fresh.free()
	var missing: String = FontCheck.missing_characters(load("res://assets/fonts/NotoSansTC.ttf"))
	_expect(missing.is_empty(), "font contains game text: " + missing)
	for screen: Control in [game.menu, game.hud, game.results, game.pause_panel, game.shop]:
		_expect(screen.get_theme_font("font").has_char("揍".unicode_at(0)), "actual screen theme uses a Chinese font: " + screen.name)
	_expect(game.hud.get_node("%Pause").size.x >= 60.0, "pause touch target has enough width")
	street.camera.offset = Vector2(3, 2)
	street.camera.rotation = 0.01
	game.hud.get_node("%ShakeToggle").button_pressed = false
	_expect(street.camera.offset == Vector2.ZERO and street.camera.rotation == 0.0 and street.shake.shake_scale == 0.0, "disabling shake restores the camera immediately")
	game.show_menu()
	game.queue_free()
	await _frames(2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(META_PATH))
	# The native audio mixer runs on wall time even when test game time is accelerated.
	OS.delay_msec(120)
	await _frames(2)
	print("checks: ", checks)
	_finish("STREET PLAYABLE")
