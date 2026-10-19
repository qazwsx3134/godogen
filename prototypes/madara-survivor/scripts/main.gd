class_name Main
extends Node3D
## One run of the Madara slice: move, dash, auto jutsu learned on level-up (taijutsu first, then the war fan and the
## growing Great Fireball), a ninja army on a spawn budget, launched bodies bowling into the crowd, kill streaks
## with titles, chakra (XP) and level-up cards.
## Systems are plain nodes in main.tscn; this script steps them in a fixed order each frame on game time (`dt`),
## which hit stop slows and level-up pauses. Engine.time_scale is never touched.

@export var run_seconds: float = 600.0
@export_group("Army")
## Alive-enemy target over the run as (seconds, count) pairs, the roadmap's 20 -> 60 -> 120 -> 200 -> 300 curve.
@export var army_curve: PackedVector2Array = PackedVector2Array([
	Vector2(0, 20), Vector2(120, 60), Vector2(240, 120), Vector2(360, 200), Vector2(480, 300), Vector2(600, 340)])
## Budget points earned per second: base + target / budget_divisor (a bigger army refills faster).
@export var budget_base: float = 2.0
@export var budget_divisor: float = 8.0
@export var spawn_radius: float = 26.0
@export var elite_times: PackedFloat32Array = PackedFloat32Array([240.0, 420.0])
@export_group("Feel")
## Hit stop of a heavy strike (combo finisher, fan, fireball, or `hit_stop_min_hits`+ hits):
## base + per_hit * hits, at most max; never more often than every `cooldown` real seconds.
@export var hit_stop_min_hits: int = 3
@export var hit_stop_base: float = 0.035
@export var hit_stop_per_hit: float = 0.004
@export var hit_stop_max: float = 0.09
@export var hit_stop_cooldown: float = 0.16
@export var hit_stop_scale: float = 0.04
## A kill within this many seconds of the last one keeps the streak going.
@export var streak_gap: float = 1.2
## The banner shows once a streak reaches this many kills.
@export var streak_show: int = 5
## (kills, title) for the streak banner.
@export var streak_titles: Dictionary = {50: "SHINOBI HUNTER", 100: "UNSTOPPABLE", 300: "BATTLEFIELD DEMON", 500: "GOD OF SHINOBI"}
@export var dust_color: Color = Color(0.85, 0.7, 0.52, 0.85)
@export var spark_color: Color = Color(1.0, 0.85, 0.6)
@export_group("Dominance")
## Dominance 0..100 fills from kills and feats; full lets Chibaku Tensei fire (doc1: BATTLE DOMINANCE).
@export var dominance_per_kill: float = 0.35
@export var dominance_per_elite: float = 15.0
@export var dominance_per_dodge: float = 3.0
## Every this many kills in one streak adds `dominance_streak_bonus`.
@export var dominance_streak_step: int = 25
@export var dominance_streak_bonus: float = 4.0
## Stage names at 0 / 25 / 50 / 75 / 100 %.
@export var dominance_stages: PackedStringArray = PackedStringArray(["支配", "壓迫", "支配中", "壓倒", "戰場之神"])
@export_group("Growth")
## XP for the next level: round(xp_base + xp_linear * L + L ^ xp_power).
@export var xp_base: float = 6.0
@export var xp_linear: float = 4.0
@export var xp_power: float = 1.6
@export var base_magnet: float = 3.0
## The UI is laid out for a screen whose short side is this many logical pixels, in landscape and portrait alike.
@export var ui_short_side: int = 540

const QaConfig = preload("res://scripts/qa_config.gd")

var elapsed: float = 0.0
var level: int = 1
var xp: int = 0
var kills: int = 0
var streak: int = 0
var dominance: float = 0.0
## While this runs the streak banner keeps a special title (the ultimate's count) instead of the streak's.
var _banner_hold: float = 0.0
var best_streak: int = 0
var finished: bool = false
## Game-clock factor for this frame: 1 normally, hit_stop_scale during a hit stop, 0 while a menu is open.
var time_scale: float = 1.0
var sim_usec: int = 0

var qa: RefCounted
var rng := RandomNumberGenerator.new()

var _budget: float = 0.0
var _hit_stop: float = 0.0
var _hit_stop_ready: float = 0.0
var _streak_left: float = 0.0
var _paused: bool = false
var _pending_levels: int = 0
var _options: Array[Dictionary] = []
var _next_elite: int = 0
var _spawn_kinds: Array[int] = []
var _elite_kind: int = -1
var _perf_clock: float = 0.0
var _frames: int = 0
var _sim_accum: int = 0
var _auto_turn: float = 1.0
var _prop_material: ShaderMaterial

@onready var player: Player = %Player
@onready var horde: Horde = %Horde
@onready var jutsu: Jutsu = %Jutsu
@onready var enemy_jutsu: EnemyJutsu = %EnemyJutsu
@onready var ultimate: Ultimate = %Ultimate
@onready var upgrades: Upgrades = %Upgrades
@onready var gems: Gems = %Gems
@onready var glow: GlowPool = %Glow
@onready var dust: GlowPool = %Dust
@onready var fx: Fx = %Fx
@onready var numbers: DamageNumbers = %Numbers
@onready var decor: Decor = %Decor
@onready var ground: MeshInstance3D = %Ground
@onready var rig: CameraRig = %CameraRig
@onready var hud: Hud = %Hud
@onready var sfx: Node = %Sfx


func _ready() -> void:
	qa = QaConfig.current()
	get_window().size_changed.connect(_fit_ui)
	_fit_ui()
	if qa.seed >= 0:
		rng.seed = qa.seed
		seed(qa.seed)
	else:
		rng.randomize()
	if qa.duration > 0.0:
		run_seconds = qa.duration
	hud.set_perf_visible(qa.show_perf)
	if qa.pitch > 0.0 or qa.distance > 0.0:
		rig.set_view(qa.pitch if qa.pitch > 0.0 else 42.0, qa.distance if qa.distance > 0.0 else 13.0)
	get_node(^"%Previews").visible = false
	_prop_material = decor.multimesh.mesh.surface_get_material(1)
	for k: int in horde.defs.size():
		if horde.defs[k].elite:
			_elite_kind = k
		else:
			_spawn_kinds.append(k)
	horde.killed.connect(_on_killed)
	horde.collided.connect(_on_collided)
	jutsu.struck.connect(_on_struck)
	horde.cast.connect(enemy_jutsu.cast)
	enemy_jutsu.hit_player.connect(func(amount: float, from: Vector2, element: int) -> void: _hurt_player(amount, from, element))
	enemy_jutsu.reflected.connect(_on_reflected)
	player.dodged.connect(_on_dodged)
	ultimate.crushed.connect(_on_crushed)
	jutsu.susanoo_changed.connect(_on_susanoo)
	jutsu.posed.connect(player.pose)
	player.died.connect(func() -> void: _finish(false))
	player.dashed.connect(_on_dashed)
	hud.option_picked.connect(_on_option_picked)
	hud.restart_pressed.connect(func() -> void: get_tree().reload_current_scene())
	decor.follow(player.ground())
	for entry: String in qa.learn.split(",", false):
		var path: String = "res://data/jutsu/%s.tres" % entry.get_slice(":", 0)
		if ResourceLoader.exists(path):
			for k: int in maxi(entry.get_slice(":", 1).to_int(), 1):
				jutsu.learn(load(path))
	_apply_upgrades()
	if qa.dominance >= 0.0:
		dominance = qa.dominance
	if qa.stress > 0:
		for i: int in qa.stress:
			_spawn_one(_spawn_kinds[i % _spawn_kinds.size()], rng.randf_range(7.0, spawn_radius))


func _process(delta: float) -> void:
	var real_dt: float = minf(delta, 0.1)
	_hit_stop = maxf(_hit_stop - real_dt, 0.0)
	_hit_stop_ready = maxf(_hit_stop_ready - real_dt, 0.0)
	time_scale = 0.0 if (_paused or finished) else (hit_stop_scale if _hit_stop > 0.0 else 1.0)
	var dt: float = real_dt * time_scale
	var started: int = Time.get_ticks_usec()
	if dt > 0.0:
		_simulate(dt)
	sim_usec = Time.get_ticks_usec() - started
	glow.commit()
	dust.commit()
	horde.commit()
	gems.commit()
	rig.step(dt, real_dt)
	var at: Vector2 = player.ground()
	decor.follow(at)
	_prop_material.set_shader_parameter(&"focus", player.global_position)
	ground.position = Vector3(roundf(at.x), 0.0, roundf(at.y))
	hud.show_susanoo(jutsu.susanoo_learned(), jutsu.susanoo_ratio())
	hud.show_dominance(dominance / 100.0, dominance_stages[mini(int(dominance / 25.0), dominance_stages.size() - 1)], ultimate.learned)
	hud.show_stats(level, float(xp) / _xp_needed(), player.hp, player.max_hp, elapsed, kills, player.dash_ready / player.dash_cooldown)
	_update_perf(real_dt)
	if qa.autoplay and hud.level_up_open():
		hud.pick_card(0)


func _simulate(dt: float) -> void:
	elapsed += dt
	var input: Vector2 = _autopilot() if qa.autoplay else _read_input()
	if Input.is_action_just_pressed(&"dash"):
		player.dash(input)
	if (Input.is_action_just_pressed(&"ultimate") or (qa.autoplay and dominance >= 100.0)) and _ultimate_ready():
		_fire_ultimate()
	if (Input.is_action_just_pressed(&"susanoo") or qa.autoplay) and jutsu.raise_susanoo():
		pass
	ultimate.step(dt)
	if ultimate.active():
		player._invuln = maxf(player._invuln, 0.2)
	player.move(dt, input, 1.0 + upgrades.stat(PassiveDef.Stat.SPEED))
	var pushed: Vector2 = decor.push_out(player.ground(), player.radius)
	player.position = Vector3(pushed.x, 0.0, pushed.y)
	player.heal(upgrades.stat(PassiveDef.Stat.REGEN) * dt)
	var touch: float = horde.step(dt, player.ground(), player.radius)
	if touch > 0.0:
		_hurt_player(touch, horde.touch_from)
	jutsu.global_position = player.global_position
	jutsu.step(dt)
	enemy_jutsu.step(dt, player.ground(), player.radius)
	if jutsu.striking():
		player.face(jutsu.aim)
	else:
		player.face(input)
	horde.flush_dead()
	var gained: int = gems.step(dt, player.ground(), base_magnet * (1.0 + upgrades.stat(PassiveDef.Stat.MAGNET)))
	if gained > 0:
		sfx.play(&"pickup", 0.06)
		_add_xp(gained)
	_streak_left -= dt
	_banner_hold -= dt
	if _streak_left <= 0.0:
		streak = 0
	for at: Vector3 in horde.burning_positions(24):
		if rng.randf() < 0.35:
			fx.flame(at, 0.7, jutsu.fire_color)
	fx.step(dt)
	numbers.step(dt)
	_spawn(dt)
	if elapsed >= run_seconds and not finished:
		_finish(true)


func _read_input() -> Vector2:
	var v: Vector2 = hud.stick.vector
	if v == Vector2.ZERO:
		v = Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")
	return v


## QA autopilot: kites around the crowd so the Gunbai keeps swinging, and dashes out when boxed in.
func _autopilot() -> Vector2:
	var at: Vector2 = player.ground()
	var away: Vector2 = horde.threat(at, 6.0)
	if away.length() < 0.05:
		return Vector2(cos(elapsed * 0.6), sin(elapsed * 0.6)) * 0.7
	var dir: Vector2 = away.normalized()
	if rng.randf() < 0.003:
		_auto_turn = -_auto_turn
	var out: Vector2 = (dir * 0.7 + dir.orthogonal() * _auto_turn).normalized()
	if away.length() > 2.5:
		player.dash(out)
	return out


func _army_target() -> int:
	var curve := army_curve
	if elapsed <= curve[0].x:
		return int(curve[0].y)
	for i: int in range(1, curve.size()):
		if elapsed <= curve[i].x:
			var t: float = (elapsed - curve[i - 1].x) / (curve[i].x - curve[i - 1].x)
			return int(lerpf(curve[i - 1].y, curve[i].y, t))
	return int(curve[curve.size() - 1].y)


func _spawn(dt: float) -> void:
	var target: int = _army_target()
	_budget += (budget_base + target / budget_divisor) * dt
	var alive: int = horde.alive()
	while alive < target:
		var kind: int = _pick_kind()
		var cost: float = horde.defs[kind].cost
		if _budget < cost:
			break
		_budget -= cost
		_spawn_one(kind, spawn_radius + rng.randf_range(0.0, 4.0))
		alive += 1
	_budget = minf(_budget, 40.0)
	if _next_elite < elite_times.size() and elapsed >= elite_times[_next_elite]:
		_next_elite += 1
		if _elite_kind >= 0:
			_spawn_one(_elite_kind, spawn_radius * 0.7)


func _pick_kind() -> int:
	var total: float = 0.0
	for k: int in _spawn_kinds:
		if horde.defs[k].appears_at <= elapsed:
			total += horde.defs[k].weight
	var pick: float = rng.randf() * total
	for k: int in _spawn_kinds:
		var def: EnemyDef = horde.defs[k]
		if def.appears_at > elapsed:
			continue
		pick -= def.weight
		if pick <= 0.0:
			return k
	return _spawn_kinds[0]


func _spawn_one(kind: int, radius: float) -> void:
	var angle: float = rng.randf() * TAU
	var at: Vector2 = player.ground() + Vector2(cos(angle), sin(angle)) * radius
	horde.spawn(kind, decor.push_out(at, horde.defs[kind].radius))


func _xp_needed() -> int:
	return roundi(xp_base + xp_linear * level + pow(level, xp_power))


func _add_xp(amount: int) -> void:
	xp += amount
	while xp >= _xp_needed():
		xp -= _xp_needed()
		level += 1
		_pending_levels += 1
	if _pending_levels > 0 and not _paused:
		_open_level_up()


func _open_level_up() -> void:
	_options = upgrades.roll(rng, level)
	if _options.is_empty():
		_pending_levels = 0
		return
	_paused = true
	sfx.play(&"level_up")
	fx.ring(player.global_position + Vector3(0, 0.2, 0), 7.0, Color(0.5, 0.75, 1.0), 0.5)
	hud.show_level_up(_options)


func _on_option_picked(index: int) -> void:
	if index < _options.size():
		upgrades.apply(_options[index])
		_apply_upgrades()
	_options.clear()
	_pending_levels -= 1
	_paused = false
	hud.close_level_up()
	if _pending_levels > 0:
		_open_level_up()


func _apply_upgrades() -> void:
	jutsu.might = 1.0 + upgrades.stat(PassiveDef.Stat.MIGHT)
	jutsu.area = 1.0 + upgrades.stat(PassiveDef.Stat.AREA)
	jutsu.haste = 1.0 + upgrades.stat(PassiveDef.Stat.HASTE)
	jutsu.crit_bonus = upgrades.stat(PassiveDef.Stat.CRIT)
	ultimate.learned = jutsu.level_of_kind(JutsuDef.Kind.CHIBAKU) > 0
	player.set_max_hp(player.base_max_hp + upgrades.stat(PassiveDef.Stat.MAX_HP))


func _on_struck(kind: int, hits: int, crits: int, at: Vector3, heavy: bool) -> void:
	if kind == JutsuDef.Kind.SUSANOO:
		sfx.play(&"slam", 0.05)
		rig.add_trauma(0.3, 0.6)
	elif kind != JutsuDef.Kind.FIREBALL:
		sfx.play(&"swing")
	else:
		sfx.play(&"slam", 0.05)
		rig.add_trauma(0.22, 0.55)
	if hits <= 0:
		return
	sfx.play(&"crit" if crits > 0 else &"hit")
	if (heavy or hits >= hit_stop_min_hits) and _hit_stop_ready <= 0.0:
		_hit_stop = minf(hit_stop_base + hit_stop_per_hit * hits, hit_stop_max)
		_hit_stop_ready = hit_stop_cooldown
	rig.add_trauma(0.08 + 0.02 * hits + (0.08 if heavy else 0.0), 0.55)
	if kind != JutsuDef.Kind.FIREBALL:
		fx.dust_burst(at, 4 if not heavy else 6, 4.0, 1.1, dust_color)
		fx.flash(at + Vector3(0, 1.0, 0), 1.8 if not heavy else 2.6, spark_color)
	if crits > 0:
		numbers.show_hit(at + Vector3(0, 1.6, 0), 22.0 * jutsu.might * jutsu.crit_multiplier, true)


## Every hit on Madara goes through here: the Sharingan dodges it when a charge is ready.
func _hurt_player(amount: float, from: Vector2, element: int = EnemyJutsu.Element.NONE) -> void:
	if player.dead or player.is_invulnerable():
		return
	if jutsu.try_dodge():
		# Slip toward open ground: away from the crowd, not only away from the one attacker.
		var crowd: Vector2 = horde.threat(player.ground(), 6.0)
		var threat_at: Vector2 = player.ground() - crowd.normalized() if crowd.length() > 0.01 else from
		player.dodge(threat_at, jutsu.dodge_grace())
		return
	if player.take_hit(amount * jutsu.damage_taken()):
		rig.add_trauma(0.45, 0.6)
		sfx.play(&"hurt")
		if element == EnemyJutsu.Element.WATER:
			player.slow(enemy_jutsu.water_slow_time, enemy_jutsu.water_slow)


func _gain_dominance(amount: float) -> void:
	dominance = minf(dominance + amount, 100.0)


func _ultimate_ready() -> bool:
	return ultimate.learned and not ultimate.active() and dominance >= 100.0


func _fire_ultimate() -> void:
	dominance = 0.0
	ultimate.fire(player.global_position)
	hud.darken(1.0)
	sfx.play(&"ultimate")
	rig.add_trauma(0.3)


func _on_crushed(count: int, at: Vector3) -> void:
	hud.darken(0.0)
	hud.flash(1.0)
	_hit_stop = 0.3
	_hit_stop_ready = hit_stop_cooldown
	rig.add_trauma(1.0)
	sfx.play(&"slam")
	if count > 0:
		hud.show_combo(count, "地爆天星")
		_banner_hold = 1.5


func _on_susanoo(active: bool, stage: int) -> void:
	player.show_susanoo(active, stage)
	rig.zoom_to(1.25 + 0.05 * stage if active else 1.0)
	if active:
		sfx.play(&"ultimate")
		rig.add_trauma(0.5)
		fx.ring(player.global_position + Vector3(0, 0.3, 0), 10.0, Color(0.7, 0.45, 1.0), 0.5)


func _on_dodged(from: Vector3, to: Vector3) -> void:
	_gain_dominance(dominance_per_dodge)
	sfx.play(&"dodge")
	# No hit stop here: the game keeps running so the dodge never feels like a stall; the afterimage, a red flash
	# and a small shake carry it.
	rig.add_trauma(0.12, 0.3)
	fx.flash(from + Vector3(0, 1.2, 0), 2.2, Color(1.0, 0.25, 0.25))
	fx.ring(to + Vector3(0, 0.2, 0), 3.0, Color(1.0, 0.3, 0.3), 0.25)
	jutsu.afterimage_burst(from)


func _on_reflected(count: int, at: Vector3) -> void:
	sfx.play(&"reflect")
	fx.flash(at, 2.4, Color(1.0, 0.9, 0.7))
	rig.add_trauma(0.12, 0.4)


func _on_collided(at: Vector3, with_rock: bool) -> void:
	if with_rock:
		sfx.play(&"slam", 0.05)
		rig.add_trauma(0.18, 0.5)
		fx.dust_burst(at, 7, 5.0, 1.6, dust_color)
	else:
		fx.spark(at, spark_color, 0.9)
		fx.dust(at - Vector3(0, 0.6, 0), 1.0, dust_color, Vector3.ZERO, 0.35)


func _on_killed(at: Vector3, def: EnemyDef, burning: bool) -> void:
	if burning:
		jutsu.burning_death(at)
	kills += 1
	streak += 1
	_gain_dominance(dominance_per_kill + (dominance_streak_bonus if streak % dominance_streak_step == 0 else 0.0))
	if def.elite:
		_gain_dominance(dominance_per_elite)
	best_streak = maxi(best_streak, streak)
	_streak_left = streak_gap
	sfx.play(&"kill", 0.05)
	gems.drop(Vector2(at.x, at.z), def.xp)
	if streak >= streak_show and _banner_hold <= 0.0:
		hud.show_combo(streak, _title_for(streak))
	if def.elite:
		_hit_stop = maxf(_hit_stop, 0.14)
		rig.add_trauma(0.7)
		sfx.play(&"elite")
		numbers.show_hit(at + Vector3(0, 2.5, 0), def.hp, true)
		gems.pull_all()


func _title_for(count: int) -> String:
	var title: String = ""
	var best: int = 0
	for threshold: int in streak_titles:
		if count >= threshold and threshold >= best:
			best = threshold
			title = streak_titles[threshold]
	return title


func _on_dashed(from: Vector3, direction: Vector2) -> void:
	sfx.play(&"dash")
	for i: int in 4:
		fx.dust(from + Vector3(direction.x, 0.3, direction.y) * (i * 0.9), 1.3, dust_color, Vector3(-direction.x, 0.8, -direction.y) * 2.0, 0.45)


func _finish(won: bool) -> void:
	finished = true
	hud.show_result(won, elapsed, kills, level, best_streak)


func _fit_ui() -> void:
	var size: Vector2 = Vector2(get_window().size)
	var scale: float = ui_short_side / maxf(minf(size.x, size.y), 1.0)
	get_window().content_scale_size = Vector2i(roundi(size.x * scale), roundi(size.y * scale))


func _update_perf(real_dt: float) -> void:
	_frames += 1
	_sim_accum += sim_usec
	_perf_clock += real_dt
	if _perf_clock < 0.5:
		return
	var fps: float = _frames / _perf_clock
	var draws: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	hud.show_perf("%d fps · sim %.1f ms · draw %d · 敵 %d · %s" % [roundi(fps), _sim_accum / 1000.0 / _frames, draws, horde.count, RenderingServer.get_current_rendering_method()])
	_perf_clock = 0.0
	_frames = 0
	_sim_accum = 0
