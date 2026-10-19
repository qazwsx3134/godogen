extends "res://addons/proto_kit/test_kit.gd"
## The slice on the real main scene: taijutsu first, jutsu learned on level-up (fan, growing fireball, burning
## ground), launched bodies bowl into the crowd and slam into rocks, kills and streaks, cards, two-finger touch,
## dash, death.
## Run with game time: godot-kit/tools/run_tests.sh prototypes/madara-survivor core:60


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _frames(2)
	var horde: Horde = main.horde

	_expect(main.player != null and horde != null and main.jutsu != null, "main scene wires its systems")
	_expect(main.jutsu.owned.size() == 1 and main.jutsu.owned[0].kind == JutsuDef.Kind.TAIJUTSU, "Madara starts with taijutsu only")
	_expect(not main.get_node(^"%Previews").visible, "editor previews are hidden in a run")
	_expect(horde.defs.size() == 7, "seven enemy types (three of them casters) are loaded from data/enemies")
	_expect(main.decor.blocking_rocks() > 0, "the desert has rock pillars that block")
	await _until(func() -> bool: return horde.count >= 10, "the army spawns around Madara", 10.0)

	# A heavy cone hit (the fan) one-shots a genin and launches it.
	horde.clear()
	var at: Vector2 = main.player.ground()
	var front: int = horde.spawn(0, at + Vector2(2.0, 0.0))
	horde.step(0.0, at, 0.0)
	var hits: int = horde.damage_cone(at, Vector2.RIGHT, 4.4, deg_to_rad(60.0), 26.0, 22.0)
	_expect(hits == 1, "the cone hits the ninja in front")
	_expect(horde.is_flying(front) and not horde.is_alive(front), "a level-1 swing kills a genin and launches the body")
	var behind_cone: int = horde.spawn(0, at + Vector2(-2.0, 0.0))
	horde.step(0.0, at, 0.0)
	_expect(horde.damage_cone(at, Vector2.RIGHT, 4.4, deg_to_rad(60.0), 1.0, 0.0) == 0, "the cone misses what is behind Madara")
	horde.clear()

	# Bowling: a launched body flies into a line of ninjas and launches them in turn.
	var line_start: Vector2 = at + Vector2(0.0, 6.0)
	var shooter: int = horde.spawn(0, line_start)
	for k: int in 4:
		horde.spawn(0, line_start + Vector2(1.2 + 1.1 * k, 0.0))
	horde.step(0.0, at, 0.0)
	horde.hurt(shooter, 1.0, Vector2(24.0, 0.0))
	var flying_max: int = 0
	for f: int in 20:
		horde.step(1.0 / 60.0, at, 0.0)
		var flying: int = 0
		for i: int in horde.count:
			if horde.is_flying(i):
				flying += 1
		flying_max = maxi(flying_max, flying)
	_expect(flying_max >= 3, "a launched ninja knocks the ones behind it flying (chain of %d)" % flying_max)
	horde.clear()

	# Rocks stop flying bodies and block walking.
	var rock := _find_rock(main.decor, at)
	_expect(rock.size() == 2, "a rock pillar is indexed near the start")
	if rock.size() == 2:
		var r_pos: Vector2 = rock[0]
		var pushed: Vector2 = main.decor.push_out(r_pos, 0.5)
		_expect(pushed.distance_to(r_pos) > 0.5, "standing inside a pillar is pushed out of it")

	# Kills count, streaks build, chakra drops.
	var kills_before: int = main.kills
	for k: int in 6:
		var i: int = horde.spawn(0, at + Vector2(3.0, 0.0))
		horde.step(0.0, at, 0.0)
		horde.hurt(i, 999.0, Vector2.ZERO)
	horde.flush_dead()
	_expect(main.kills - kills_before == 6, "every kill counts")
	_expect(main.streak >= 6 and main.hud.combo_visible(), "six quick kills show the streak banner")
	_expect(main.gems.count >= 1, "kills drop chakra")
	_expect(main._title_for(120) == "UNSTOPPABLE", "a 120-kill streak earns UNSTOPPABLE")

	# Level-up cards stop time and apply; level 2 always offers a new jutsu.
	main._add_xp(main._xp_needed())
	await _frames(2)
	_expect(main.hud.level_up_open() and main.hud.card_count() == 3, "levelling up offers three cards")
	var has_new: bool = false
	for option: Dictionary in main._options:
		if option.has("jutsu") and option.level == 1:
			has_new = true
	_expect(has_new, "the level-2 cards include a new jutsu")
	_expect(main.time_scale == 0.0, "game time stops while the cards are open")
	var before: int = main.upgrades.total_levels()
	main.hud.pick_card(0)
	await _frames(2)
	_expect(not main.hud.level_up_open() and main.time_scale > 0.0, "picking a card resumes the run")
	_expect(main.upgrades.total_levels() == before + 1, "the picked upgrade is applied")

	# The Great Fireball grows with its level and leaves burning ground from level 3.
	var fire: JutsuDef = load("res://data/jutsu/fireball.tres")
	# The level-2 card picked above may already have been the fireball, so check the step, not the absolute level.
	var fire_before: int = main.jutsu.level_of(fire)
	main.jutsu.learn(fire)
	_expect(main.jutsu.level_of(fire) == fire_before + 1, "learning the fireball raises it by one level")
	_expect(Jutsu.BALL_SIZE[4] > Jutsu.BALL_SIZE[0] * 4.0, "the level-5 fireball is far bigger than the level-1 one")
	for k: int in 2:
		main.jutsu.learn(fire)
	horde.clear()
	var burn_target: int = horde.spawn(2, at + Vector2(0.0, -8.0))
	horde.step(0.0, at, 0.0)
	main.jutsu._explode(at + Vector2(0.0, -8.0), 3)
	_expect(main.jutsu._zone_pos.size() >= 1, "a level-3 fireball leaves burning ground")
	_expect(horde.is_burning(burn_target), "the blast sets the heavy ninja on fire")
	horde.clear()

	# Sharingan: with a charge ready, a hit becomes a dodge that leaves an afterimage and costs no health.
	var eye: JutsuDef = load("res://data/jutsu/sharingan.tres")
	main.jutsu.learn(eye)
	_expect(main.jutsu.eye_charges == 1, "learning the Sharingan readies one dodge")
	main.player._invuln = 0.0
	var hp_before: float = main.player.hp
	var spot: Vector3 = main.player.global_position
	main._hurt_player(20.0, main.player.ground() + Vector2(1.0, 0.0))
	_expect(main.player.hp == hp_before, "a read hit costs no health")
	_expect(main.player.global_position.distance_to(spot) > 2.0, "Madara slips aside")
	var ghost_seen: bool = false
	for ghost: Node in main.player.get_node(^"%Ghosts").get_children():
		if (ghost as Node3D).visible and (ghost as Node3D).global_position.distance_to(spot) < 0.1:
			ghost_seen = true
	_expect(ghost_seen, "an afterimage stays where he stood")
	_expect(main.jutsu.eye_charges == 0, "the dodge spends the charge")
	main.player._invuln = 0.0
	main._hurt_player(20.0, main.player.ground() + Vector2(1.0, 0.0))
	_expect(main.player.hp < hp_before, "without a charge the next hit lands")
	main.player.hp = main.player.max_hp

	# Ninja jutsu: casters throw fire, the fan swats it back into the army.
	horde.clear()
	var me: Vector2 = main.player.ground()
	main.enemy_jutsu.cast(EnemyJutsu.Element.FIRE, Vector3(me.x + 3.0, 1.0, me.y), me)
	_expect(main.enemy_jutsu.projectiles() == 1, "a fire caster's fireball is in the air")
	var victim: int = horde.spawn(0, me + Vector2(6.0, 0.0))
	horde.step(0.0, me, 0.0)
	var swatted: int = main.enemy_jutsu.reflect_cone(me, Vector2.RIGHT, 4.5, deg_to_rad(70.0))
	_expect(swatted == 1, "the fan reflects the fireball")
	for f: int in 30:
		horde.step(1.0 / 60.0, me, 0.0)
		main.enemy_jutsu.step(1.0 / 60.0, me, 0.0)
	_expect(not horde.is_alive(victim), "the reflected fireball kills the ninja it hits")
	horde.clear()
	main.enemy_jutsu.cast(EnemyJutsu.Element.EARTH, Vector3(me.x + 8.0, 1.0, me.y), me)
	var earth_hits: Array[int] = [0]
	main.enemy_jutsu.hit_player.connect(func(_a: float, _f: Vector2, element: int) -> void:
		if element == EnemyJutsu.Element.EARTH:
			earth_hits[0] += 1)
	for f: int in 80:
		main.enemy_jutsu.step(1.0 / 60.0, me, main.player.radius)
	_expect(earth_hits[0] == 1, "earth spikes erupt under Madara after the warning")

	# Wood Release roots a crowd in place.
	horde.clear()
	var rooted: int = horde.spawn(0, me + Vector2(4.0, 0.0))
	horde.step(0.0, me, 0.0)
	_expect(horde.bind_circle(me + Vector2(4.0, 0.0), 3.0, 2.0, 1.0) == 1, "the roots catch the ninja in the circle")
	var before_pos: Vector2 = horde.position_of(rooted)
	for f: int in 30:
		horde.step(1.0 / 60.0, me, 0.0)
	_expect(horde.position_of(rooted).distance_to(before_pos) < 0.05, "a bound ninja stays where the roots hold it")

	# Chibaku Tensei: learned late, fired at full Dominance, lifts the crowd and crushes it.
	horde.clear()
	var chibaku: JutsuDef = load("res://data/jutsu/chibaku.tres")
	_expect(chibaku.min_player_level >= 8, "Chibaku Tensei is a late-game card")
	main.jutsu.learn(chibaku)
	main._apply_upgrades()
	_expect(main.ultimate.learned, "learning it arms the ultimate")
	for k: int in 40:
		horde.spawn(0, me + Vector2.from_angle(TAU * k / 40.0) * randf_range(4.0, 20.0))
	horde.step(0.0, me, 0.0)
	main.dominance = 100.0
	_expect(main._ultimate_ready(), "full Dominance readies the ultimate")
	var kills_pre: int = main.kills
	main._fire_ultimate()
	_expect(main.dominance == 0.0 and main.ultimate.active(), "firing spends Dominance and starts the gather")
	_expect(horde.captured() >= 35, "the crowd is torn off the ground (%d captured)" % horde.captured())
	await _until(func() -> bool: return not main.ultimate.active(), "the core crushes the crowd", 10.0)
	await _frames(3)
	_expect(main.kills - kills_pre >= 35, "everything in the core dies (%d)" % (main.kills - kills_pre))
	horde.clear()

	# Susanoo: raised by its button, guards most damage, swings on its own, then cools down.
	var sus: JutsuDef = load("res://data/jutsu/susanoo.tres")
	main.jutsu.learn(sus)
	_expect(main.jutsu.raise_susanoo(), "a learned Susanoo rises")
	_expect(not main.jutsu.raise_susanoo(), "it cannot be raised twice")
	_expect(is_equal_approx(main.jutsu.damage_taken(), 0.3), "Susanoo takes 70% of the damage")
	horde.clear()
	for k: int in 6:
		horde.spawn(0, me + Vector2(3.0 + k * 0.4, 0.0))
	var kills_sus: int = main.kills
	for f: int in 90:
		horde.step(1.0 / 60.0, me, 0.0)
		main.jutsu.step(1.0 / 60.0)
		horde.flush_dead()
	_expect(main.kills > kills_sus, "Susanoo's strikes kill on their own")
	main.jutsu.susanoo_left = 0.01
	main.jutsu.step(0.02)
	_expect(not main.jutsu.susanoo_active() and main.jutsu.susanoo_cooldown > 0.0, "when it fades it cools down")
	horde.clear()

	# Two fingers: one steers on the left, the other taps dash on the right, at the same time.
	await _two_finger_dash(main)

	# Dash moves fast and has a cooldown.
	main.player.dash_ready = 0.0
	var start: Vector3 = main.player.position
	_expect(main.player.dash(Vector2.RIGHT), "Madara can dash")
	_expect(not main.player.dash(Vector2.RIGHT), "the dash has a cooldown")
	for f: int in 12:
		main.player.move(1.0 / 60.0, Vector2.ZERO, 1.0)
	_expect(main.player.position.distance_to(start) > 3.0, "a dash covers ground")

	# The jutsu strike on their own.
	var kills_mid: int = main.kills
	await _until(func() -> bool:
		if main.hud.level_up_open():
			main.hud.pick_card(0)
		return main.kills > kills_mid, "the auto jutsu kill ninjas", 20.0)

	main.player._invuln = 0.0
	main.player.take_hit(99999.0)
	await _frames(2)
	_expect(main.finished and main.hud.result_open(), "dying ends the run and shows the result")

	main.queue_free()
	await _frames(2)
	_finish("CORE TESTS")


func _two_finger_dash(main: Main) -> void:
	# Kills earlier in the suite may have opened level-up cards (which turn the stick off): pick them first.
	while main.hud.level_up_open():
		main.hud.pick_card(0)
		await _frames(1)
	var stick: TouchStick = main.hud.stick
	var button: TouchButton = main.hud.dash_button
	var size: Vector2 = stick.size
	var left: Vector2 = stick.global_position + Vector2(size.x * 0.2, size.y * 0.6)
	_finger(0, left, true)
	_finger_drag(0, left + Vector2(80.0, 0.0))
	await _frames(1)
	_expect(stick.held() and stick.vector.x > 0.3, "a finger on the left steers the stick")
	main.player.dash_ready = 0.0
	var dashes: Array[int] = [0]
	main.player.dashed.connect(func(_from: Vector3, _dir: Vector2) -> void: dashes[0] += 1)
	_finger(1, button.get_global_rect().get_center(), true)
	await _frames(2)
	_expect(dashes[0] == 1, "a second finger on the dash button dashes while steering")
	_finger(1, button.get_global_rect().get_center(), false)
	await _frames(1)
	_expect(stick.held() and stick.vector != Vector2.ZERO, "lifting the dash finger does not release the stick")
	_finger(0, left + Vector2(80.0, 0.0), false)
	await _frames(1)
	_expect(not stick.held() and stick.vector == Vector2.ZERO, "lifting the steering finger releases the stick")


func _finger(index: int, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = pressed
	root.push_input(event, true)


func _finger_drag(index: int, at: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = at
	root.push_input(event, true)


## [position, radius] of a blocking rock near `at`, or [] when none is indexed.
func _find_rock(decor: Decor, at: Vector2) -> Array:
	for r: float in range(4, 60, 2):
		for k: int in 48:
			var p: Vector2 = at + Vector2.from_angle(TAU * k / 48.0) * r
			var pushed: Vector2 = decor.push_out(p, 0.01)
			if pushed != p:
				return [p, 0.0]
	return []
