extends "res://addons/proto_kit/test_kit.gd"
## The run on the real main scene (the sandbox, no act): Luffy starts with the Pistol, moves learned on level-up,
## launched bodies bowl into the crowd and slam into rocks, kills and streaks, cards, the Pistol's straight punch,
## Ivankov's hormone, Conqueror's Haki, Gear 2, a story blocker, the Rocket sweep, two-finger touch, death.
## Every move file's kind matches its id (the enum ints are saved in data/jutsu).
## Run with game time: godot-kit/tools/run_tests.sh prototypes/luffy-marineford core:60


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.default_act = 0  # the free-run sandbox: no story holds the clock
	root.add_child(main)
	await _frames(2)
	var horde: Horde = main.horde

	_expect(main.player != null and horde != null and main.jutsu != null, "main scene wires its systems")
	_expect(main.jutsu.owned.size() == 1 and main.jutsu.owned[0].kind == JutsuDef.Kind.PISTOL, "Luffy starts with the Pistol only")
	var kinds := {"pistol": JutsuDef.Kind.PISTOL, "gatling": JutsuDef.Kind.GATLING, "bazooka": JutsuDef.Kind.BAZOOKA,
		"gigant": JutsuDef.Kind.GIGANT, "whip": JutsuDef.Kind.WHIP, "haki": JutsuDef.Kind.HAKI, "gear2": JutsuDef.Kind.GEAR2}
	for id: String in kinds:
		var def: JutsuDef = load("res://data/jutsu/%s.tres" % id)
		_expect(def.id == StringName(id) and def.kind == kinds[id], "data/jutsu/%s.tres is kind %s" % [id, JutsuDef.Kind.keys()[kinds[id]]])
	for def: JutsuDef in main.upgrades.jutsu_pool:
		_expect(def.kind != JutsuDef.Kind.HAKI, "Haki is never a card (the story unlocks it)")
	_expect(not main.get_node(^"%Previews").visible, "editor previews are hidden in a run")
	_expect(horde.defs.size() == 7, "seven enemy types (three of them casters) are loaded from data/enemies")
	_expect(main.decor.blocking_rocks() > 0, "the desert has rock pillars that block")
	await _until(func() -> bool: return horde.count >= 10, "the army spawns around Luffy", 10.0)

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
	_expect(horde.damage_cone(at, Vector2.RIGHT, 4.4, deg_to_rad(60.0), 1.0, 0.0) == 0, "the cone misses what is behind Luffy")
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
	_expect(main._title_for(120) == "勢不可擋", "a 120-kill streak earns 勢不可擋")

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

	# Pistol: a straight punch hits the first body in line; from level 4 it pierces three.
	var pistol: JutsuDef = load("res://data/jutsu/pistol.tres")
	horde.clear()
	for k: int in 3:
		horde.spawn(0, at + Vector2(2.0 + 1.3 * k, 0.0), 50.0)
	horde.step(0.0, at, 0.0)
	var punches: Array[Vector3] = []
	var on_struck := func(kind: int, hits: int, _c: int, where: Vector3, _h: bool) -> void:
		if kind == JutsuDef.Kind.PISTOL:
			punches.append(Vector3(hits, where.x, where.z))
	main.jutsu.struck.connect(on_struck)
	main.jutsu.global_position = Vector3(at.x, 0.0, at.y)
	main.jutsu._pistol(at, 1, 1.0)
	_expect(punches.size() == 1 and int(punches[0].x) == 1, "a level-1 Pistol hits only the first in line (%s)" % [punches])
	_expect(punches.size() == 1 and absf(punches[0].y - (at.x + 2.0)) < 0.8, "the fist stops at the body it hit")
	horde.clear()
	for k: int in 3:
		horde.spawn(0, at + Vector2(2.0 + 1.3 * k, 0.0), 50.0)
	horde.step(0.0, at, 0.0)
	punches.clear()
	main.jutsu._pistol(at, 4, 1.0)
	_expect(punches.size() == 1 and int(punches[0].x) == 3, "a level-4 Pistol pierces three")
	main.jutsu.struck.disconnect(on_struck)
	horde.clear()
	_expect(main.jutsu.level_of(pistol) >= 1, "the Pistol stays learned")

	# Ivankov's hormone: the first lethal hit of the act leaves half health instead; the second kills.
	main.unlock("hormone")
	main.player._invuln = 0.0
	main.player.hp = 10.0
	main._hurt_player(50.0, main.player.ground() + Vector2(1.0, 0.0))
	_expect(not main.player.dead and is_equal_approx(main.player.hp, main.player.max_hp * main.hormone_hp), "the hormone stands Luffy back up at half health")
	_expect(main.player.is_invulnerable(), "and keeps him invulnerable for a moment")
	_expect(main.story.toast_count() > 0, "Ivankov's toast says so")
	main.player.hp = main.player.max_hp

	# Enemy attacks: casters throw fire; earth spikes erupt under Luffy after the warning.
	horde.clear()
	var me: Vector2 = main.player.ground()
	main.enemy_jutsu.cast(EnemyJutsu.Element.FIRE, Vector3(me.x + 3.0, 1.0, me.y), me)
	_expect(main.enemy_jutsu.projectiles() == 1, "a fire caster's shot is in the air")
	main.enemy_jutsu.cast(EnemyJutsu.Element.EARTH, Vector3(me.x + 8.0, 1.0, me.y), me)
	var earth_hits: Array[int] = [0]
	main.enemy_jutsu.hit_player.connect(func(_a: float, _f: Vector2, element: int) -> void:
		if element == EnemyJutsu.Element.EARTH:
			earth_hits[0] += 1)
	for f: int in 80:
		main.enemy_jutsu.step(1.0 / 60.0, me, main.player.radius)
	_expect(earth_hits[0] == 1, "earth spikes erupt under Luffy after the warning")

	# Conqueror's Haki: common Marines faint (kills, no will refill), elites are only shoved back.
	horde.clear()
	main.jutsu.learn(load("res://data/jutsu/haki.tres"))
	main._apply_upgrades()
	_expect(main.ultimate.learned, "learning Haki arms the ultimate")
	for k: int in 40:
		horde.spawn(0, me + Vector2.from_angle(TAU * k / 40.0) * randf_range(4.0, 20.0))
	var elite_kind: int = main._elite_kind
	var elite: int = horde.spawn(elite_kind, me + Vector2(6.0, 0.0))
	horde.step(0.0, me, 0.0)
	var elite_before: Vector2 = horde.position_of(elite)
	main.dominance = 100.0
	_expect(main._ultimate_ready(), "a full will meter readies Haki")
	var kills_pre: int = main.kills
	main._fire_ultimate()
	_expect(main.dominance == 0.0 and main.ultimate.active(), "firing spends the will and starts the build-up")
	await _until(func() -> bool: return not main.ultimate.active(), "the Haki wave lands", 10.0)
	await _frames(3)
	_expect(main.kills - kills_pre >= 38, "the common Marines in range faint (%d)" % (main.kills - kills_pre))
	_expect(main.dominance < 5.0, "the fainted give no will back (%.1f)" % main.dominance)
	# The elite walks in during the build-up, then the wave shoves it 4 m back out.
	var elite_now: int = -1
	for i: int in horde.count:
		if horde.is_alive(i) and horde._kind[i] == elite_kind:
			elite_now = i
	_expect(elite_now >= 0, "the elite still stands after the Haki")
	_expect(elite_now >= 0 and horde.position_of(elite_now).distance_to(me) >= 5.0, "and is shoved back (%.1f m away, started %.1f m)" % [
		horde.position_of(elite_now).distance_to(me) if elite_now >= 0 else -1.0, elite_before.distance_to(me)])
	horde.clear()

	# Gear 2: its button starts it once, Luffy moves faster, then it cools down.
	main.jutsu.learn(load("res://data/jutsu/gear2.tres"))
	_expect(main.jutsu.raise_gear(), "a learned Gear 2 starts")
	_expect(not main.jutsu.raise_gear(), "it cannot be started twice")
	_expect(main.jutsu.speed_factor() > 1.0, "Gear 2 makes Luffy faster")
	main.jutsu.gear_left = 0.01
	main.jutsu.step(0.02)
	_expect(not main.jutsu.gear_active() and main.jutsu.gear_cooldown > 0.0, "when it ends it cools down")

	# A story blocker: it stands in the way until Luffy has struck it enough, then it is knocked away.
	horde.clear()
	var beaten: Array[bool] = [false]
	var blocked: Signal = main.blocker("garp:3")
	blocked.connect(func() -> void: beaten[0] = true)
	var garp: Node3D = main._blockers[0]
	_expect(main.jutsu.targets.has(garp), "the blocker is a target of Luffy's moves")
	var into: Vector2 = main._out_of_blockers(garp.ground())
	_expect(into.distance_to(garp.ground()) >= garp.radius + main.player.radius - 0.01, "Luffy cannot walk through the blocker")
	var here: Vector2 = garp.ground() + Vector2(0.0, 3.0)
	main.jutsu.global_position = Vector3(here.x, 0.0, here.y)
	for k: int in 3:
		garp.set(&"_recover", 0.0)
		main.jutsu._pistol(here, 3, 1.0)
	await _until(func() -> bool: return beaten[0], "three Pistol hits knock the blocker away", 3.0)
	await _frames(2)
	_expect(main._blockers.is_empty() and main.jutsu.targets.is_empty(), "a beaten blocker leaves the targets")

	# Gum-Gum Rocket: the dash strikes whoever it passes through.
	horde.clear()
	var dash_from: Vector2 = main.player.ground()
	var in_path: int = horde.spawn(0, dash_from + Vector2(1.0, 0.0), 50.0)
	horde.step(0.0, dash_from, 0.0)
	main._rocket_sweep()
	_expect(horde.is_flying(in_path) or not horde.is_alive(in_path), "the Rocket throws the Marine in its path aside")
	horde.clear()

	# Two fingers: one steers on the left, the other taps dash on the right, at the same time.
	await _two_finger_dash(main)

	# Dash moves fast and has a cooldown.
	main.player.dash_ready = 0.0
	var start: Vector3 = main.player.position
	_expect(main.player.dash(Vector2.RIGHT), "Luffy can Rocket")
	_expect(not main.player.dash(Vector2.RIGHT), "the dash has a cooldown")
	for f: int in 12:
		main.player.move(1.0 / 60.0, Vector2.ZERO, 1.0)
	_expect(main.player.position.distance_to(start) > 3.0, "a dash covers ground")

	# The jutsu strike on their own.
	var kills_mid: int = main.kills
	await _until(func() -> bool:
		if main.hud.level_up_open():
			main.hud.pick_card(0)
		return main.kills > kills_mid, "the auto moves kill Marines", 20.0)

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
	_expect(dashes[0] == 1, "a second finger on the Rocket button fires it while steering")
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
