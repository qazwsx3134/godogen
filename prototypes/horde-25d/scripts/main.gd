class_name Main
extends Node3D
## One run: the game clock, spawning, XP and level-ups, win and loss. Systems are plain nodes in main.tscn; this
## script steps them in a fixed order each frame on game time (`dt`), which hit stop slows and level-up pauses.
## Engine.time_scale is never touched, so UI, tweens and the camera shake keep real time.

@export var run_seconds: float = 300.0
## Spawns per second: base + growth * minutes, and the alive cap: base + growth * minutes.
@export var spawn_rate_base: float = 2.0
@export var spawn_rate_growth: float = 5.0
@export var alive_cap_base: int = 120
@export var alive_cap_growth: int = 110
@export var spawn_radius: float = 28.0
## Seconds into the run when an elite appears.
@export var elite_times: PackedFloat32Array = PackedFloat32Array([60.0, 120.0, 180.0, 240.0])
## Seconds into the run when a ring of enemies closes in from every side, and how many.
@export var surge_times: PackedFloat32Array = PackedFloat32Array([90.0, 210.0])
@export var surge_count: int = 90
## XP for the next level: round(xp_base + xp_linear * L + L ^ xp_power), the reference game's curve.
@export var xp_base: float = 8.0
@export var xp_linear: float = 5.5
@export var xp_power: float = 1.8
@export var hit_stop_scale: float = 0.05
@export var elite_kill_stop: float = 0.12
@export var hurt_stop: float = 0.06
@export var spark_color: Color = Color(1.0, 0.95, 0.7)
## The UI is laid out for a screen whose short side is this many logical pixels, in landscape and portrait alike
## (the reference keeps a phone's short side at 480), so a portrait phone gets the same text size as a landscape one.
@export var ui_short_side: int = 540

const QaConfig = preload("res://scripts/qa_config.gd")

var elapsed: float = 0.0
var level: int = 1
var xp: int = 0
var kills: int = 0
var finished: bool = false
## Game-clock factor for this frame: 1 normally, hit_stop_scale during a hit stop, 0 while a menu is open.
var time_scale: float = 1.0
## Microseconds the simulation took last frame (horde + weapons + pickups), for the performance line.
var sim_usec: int = 0

var qa: RefCounted
var rng := RandomNumberGenerator.new()

var _spawn_budget: float = 0.0
var _hit_stop: float = 0.0
var _paused: bool = false
var _pending_levels: int = 0
var _options: Array[Dictionary] = []
var _next_elite: int = 0
var _next_surge: int = 0
var _spawn_kinds: Array[int] = []
var _elite_kind: int = -1
var _perf_clock: float = 0.0
var _frames: int = 0
var _sim_accum: int = 0
var _auto_turn: float = 1.0
var _prop_material: ShaderMaterial

@onready var player: Player = %Player
@onready var horde: Horde = %Horde
@onready var arsenal: Arsenal = %Arsenal
@onready var gems: Gems = %Gems
@onready var glow: GlowPool = %Glow
@onready var fx: Fx = %Fx
@onready var numbers: DamageNumbers = %Numbers
@onready var decor: Decor = %Decor
@onready var ground: MeshInstance3D = %Ground
@onready var rig: CameraRig = %CameraRig
@onready var hud: Hud = %Hud


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
	for k: int in horde.defs.size():
		if horde.defs[k].elite:
			_elite_kind = k
		else:
			_spawn_kinds.append(k)
	horde.killed.connect(_on_killed)
	horde.damaged.connect(_on_hurt)
	player.died.connect(_on_player_died)
	hud.option_picked.connect(_on_option_picked)
	hud.restart_pressed.connect(func() -> void: get_tree().reload_current_scene())
	get_node(^"%Previews").visible = false
	_prop_material = decor.multimesh.mesh.surface_get_material(1)
	if qa.stress > 0:
		for i: int in qa.stress:
			_spawn_one(_spawn_kinds[i % _spawn_kinds.size()], rng.randf_range(6.0, spawn_radius))


func _process(delta: float) -> void:
	var real_dt: float = minf(delta, 0.1)
	_hit_stop = maxf(_hit_stop - real_dt, 0.0)
	time_scale = 0.0 if (_paused or finished) else (hit_stop_scale if _hit_stop > 0.0 else 1.0)
	var dt: float = real_dt * time_scale
	var started: int = Time.get_ticks_usec()
	if dt > 0.0:
		_simulate(dt)
	sim_usec = Time.get_ticks_usec() - started
	glow.commit()
	horde.commit()
	gems.commit()
	rig.step(dt, real_dt)
	var at: Vector2 = player.ground()
	decor.follow(at)
	_prop_material.set_shader_parameter(&"focus", player.global_position)
	ground.position = Vector3(roundf(at.x), 0.0, roundf(at.y))
	hud.show_stats(level, float(xp) / _xp_needed(), player.hp, player.max_hp, elapsed, kills)
	_update_perf(real_dt)
	if qa.autoplay and hud.level_up_open():
		_on_option_picked(0)


func _simulate(dt: float) -> void:
	elapsed += dt
	var input: Vector2 = _autopilot() if qa.autoplay else _read_input()
	player.move(dt, input, arsenal.speed_scale())
	player.heal(arsenal.stat(PassiveDef.Stat.REGEN) * dt)
	var touch: float = horde.step(dt, player.ground(), player.radius)
	if touch > 0.0 and player.take_hit(touch):
		rig.add_trauma(0.45, 0.6)
		_hit_stop = maxf(_hit_stop, hurt_stop)
	arsenal.global_position = player.global_position
	arsenal.step(dt)
	horde.flush_dead()
	var gained: int = gems.step(dt, player.ground(), arsenal.magnet())
	if gained > 0:
		_add_xp(gained)
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


## QA autopilot: runs from the crowd and circles, so a soak run lasts and keeps fighting.
func _autopilot() -> Vector2:
	var at: Vector2 = player.ground()
	var away: Vector2 = horde.threat(at, 9.0)
	if away.length() < 0.05:
		return Vector2(cos(elapsed * 0.7), sin(elapsed * 0.7)) * 0.6
	var dir: Vector2 = away.normalized()
	if rng.randf() < 0.002:
		_auto_turn = -_auto_turn
	return (dir + dir.orthogonal() * 0.8 * _auto_turn).normalized()


func _spawn(dt: float) -> void:
	var minutes: float = elapsed / 60.0
	var cap: int = alive_cap_base + int(alive_cap_growth * minutes)
	_spawn_budget += (spawn_rate_base + spawn_rate_growth * minutes) * dt
	while _spawn_budget >= 1.0:
		_spawn_budget -= 1.0
		if horde.count < cap:
			_spawn_one(_pick_kind(), spawn_radius + rng.randf_range(0.0, 4.0))
	if _next_elite < elite_times.size() and elapsed >= elite_times[_next_elite]:
		_next_elite += 1
		if _elite_kind >= 0:
			_spawn_one(_elite_kind, spawn_radius * 0.8, 1.0 + 0.5 * _next_elite)
	if _next_surge < surge_times.size() and elapsed >= surge_times[_next_surge]:
		_next_surge += 1
		var kind: int = _spawn_kinds[0]
		for i: int in surge_count:
			var angle: float = TAU * i / surge_count
			horde.spawn(kind, player.ground() + Vector2(cos(angle), sin(angle)) * spawn_radius)


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


func _spawn_one(kind: int, radius: float, hp_scale: float = 1.0) -> void:
	var angle: float = rng.randf() * TAU
	horde.spawn(kind, player.ground() + Vector2(cos(angle), sin(angle)) * radius, hp_scale)


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
	_options = arsenal.roll_options(rng)
	if _options.is_empty():
		_pending_levels = 0
		return
	_paused = true
	hud.show_level_up(_options)


func _on_option_picked(index: int) -> void:
	if index < _options.size():
		var option: Dictionary = _options[index]
		arsenal.apply_option(option)
		if option.has("passive") and option.passive.stat == PassiveDef.Stat.MAX_HP:
			player.set_max_hp(player.base_max_hp + arsenal.stat(PassiveDef.Stat.MAX_HP))
	_options.clear()
	_pending_levels -= 1
	_paused = false
	hud.close_level_up()
	if _pending_levels > 0:
		_open_level_up()


func _on_hurt(at: Vector3, amount: float) -> void:
	fx.spark(at, spark_color)
	numbers.show_hit(at, amount)


func _on_killed(at: Vector3, def: EnemyDef) -> void:
	kills += 1
	gems.drop(Vector2(at.x, at.z), def.xp)
	fx.puff(at, def.size, def.tint.lerp(Color.WHITE, 0.5))
	if def.elite:
		_hit_stop = maxf(_hit_stop, elite_kill_stop)
		rig.add_trauma(0.7)
		gems.pull_all()
	else:
		rig.add_trauma(0.08, 0.3)


func _on_player_died() -> void:
	_finish(false)


func _finish(won: bool) -> void:
	finished = true
	hud.show_result(won, elapsed, kills, level)


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
	var method: String = RenderingServer.get_current_rendering_method()
	hud.show_perf("%d fps · sim %.1f ms · draw %d · 敵 %d · 光 %d · %s" % [roundi(fps), _sim_accum / 1000.0 / _frames, draws, horde.count, glow.last_drawn, method])
	_perf_clock = 0.0
	_frames = 0
	_sim_accum = 0
