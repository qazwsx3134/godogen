class_name Main
extends Node3D
## One run of Luffy at Marineford: move, Gum-Gum Rocket (the dash button, sweeping through the crowd), auto moves
## learned on level-up (Pistol first), Gear 2 and Conqueror's Haki on buttons, a Marine army on a spawn budget,
## launched bodies bowling into the crowd, kill streaks, XP and level-up cards; an act's story runs on top (act.gd).
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
## New enemies appear this far ahead of the player (the route runs toward -Z), spread across the corridor.
@export var spawn_radius: float = 55.0
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
@export var streak_titles: Dictionary = {50: "海軍殺手", 100: "勢不可擋", 300: "戰場之鬼", 500: "海賊王的器量"}
@export var dust_color: Color = Color(0.85, 0.7, 0.52, 0.85)
@export var spark_color: Color = Color(1.0, 0.85, 0.6)
@export_group("Will")
## Will 0..100 (the `dominance` name stays) fills from kills and feats; full lets Conqueror's Haki fire.
@export var dominance_per_kill: float = 0.35
@export var dominance_per_elite: float = 15.0
@export var dominance_per_dodge: float = 3.0
## Every this many kills in one streak adds `dominance_streak_bonus`.
@export var dominance_streak_step: int = 25
@export var dominance_streak_bonus: float = 4.0
## Stage names at 0 / 25 / 50 / 75 / 100 %.
@export var dominance_stages: PackedStringArray = PackedStringArray(["意志", "高漲", "沸騰", "覺醒", "霸王"])
@export_group("Rocket")
## Gum-Gum Rocket (the dash): what it does to whoever it passes through, per frame of the dash.
@export var rocket_radius: float = 1.5
@export var rocket_damage: float = 7.0
@export var rocket_push: float = 18.0
@export_group("Hormone")
## Ivankov's tension hormone (act 4 on): once per act a lethal hit leaves this share of max HP and this long of
## invulnerability instead (docs: 荷爾蒙, 改編).
@export var hormone_hp: float = 0.5
@export var hormone_grace: float = 2.0
@export_group("Growth")
## XP for the next level: round(xp_base + xp_linear * L + L ^ xp_power).
@export var xp_base: float = 6.0
@export var xp_linear: float = 4.0
@export var xp_power: float = 1.6
@export var base_magnet: float = 3.0
## The UI is laid out for a screen whose short side is this many logical pixels, in landscape and portrait alike.
@export var ui_short_side: int = 540
@export_group("Story")
## Act played when QA does not pick one (scenes/acts/act_<n>.tscn); 0 = the free-run sandbox (tests, perf).
@export var default_act: int = 4

const QaConfig = preload("res://scripts/qa_config.gd")
const SpriteSet = preload("res://scripts/sprite_set.gd")
## HUD names of the route's waypoints (scenes/route.tscn Waypoints).
const GOAL_NAMES := {&"Waypoint1": "廣場", &"Garp": "卡普", &"Platform": "處刑台"}

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
var _shot_clock: float = 0.0
## Frames left in the start-of-run shader warm-up, and the nodes it showed (to hide again).
var _warm_frames: int = 0
var _warm_shown: Array[GeometryInstance3D] = []
var _warm_from: Array[Transform3D] = []
var _perf_start_usec: int = 0
var _perf_last_usec: int = 0
var _perf_samples := PackedFloat32Array()
## The act being played (null in the sandbox), whether it still has to begin (after the warm-up), the cutscene on
## screen, and the story unlocks (gear2, haki, hormone).
var act: Act
var _act_pending: bool = false
var _cutscene: Cutscene
var unlocked: Dictionary = {}
var hormone_used: bool = false
## While the Haki's fainted bodies are flushed, kills give no will (one wave would refill the meter).
var _mute_will: bool = false
## Story blockers standing on the route (blocker.gd), also in jutsu.targets.
var _blockers: Array[Node3D] = []

signal _cutscene_done

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
@onready var route: Route = %Route
@onready var fist: FistStreak = %FistStreak
@onready var rig: CameraRig = %CameraRig
@onready var hud: Hud = %Hud
@onready var sfx: Node = %Sfx
@onready var story: StoryUi = %StoryUi


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
	var cast: RefCounted = SpriteSet.load_set(qa.density)
	player.use_sheet(cast.luffy)
	var kind_sheets: Array = []
	var heights := PackedFloat32Array()
	for def: EnemyDef in horde.defs:
		kind_sheets.append(cast.vice_admiral if def.elite else cast.marine)
		heights.append(SpriteSet.HEIGHTS["vice_admiral" if def.elite else "marine"])
	horde.use_sheets(kind_sheets, heights)
	fist.px_per_m = 1.0 / cast.luffy.meters_per_px
	# The ground and landmarks share the characters' pixel density.
	var px_per_m: float = 1.0 / cast.luffy.meters_per_px
	for node: Node in route.find_children("*", "MeshInstance3D", true, false):
		var material := (node as MeshInstance3D).material_override as ShaderMaterial
		if material and material.shader and material.shader.get_shader_uniform_list().any(func(u: Dictionary) -> bool: return u.name == "px_per_m"):
			material.set_shader_parameter(&"px_per_m", px_per_m)
	if qa.start_z != 0.0:
		player.position.z = qa.start_z
		rig.global_position = player.global_position
	if qa.warmup:
		_begin_warm_up()
	if not qa.cam.is_empty() and not rig.use_preset(qa.cam):
		push_warning("unknown camera preset: " + qa.cam)
	if qa.cam_height > 0.0 or qa.cam_back >= 0.0 or qa.cam_ahead >= 0.0 or qa.fov > 0.0:
		rig.set_view(qa.cam_height if qa.cam_height > 0.0 else rig.height, qa.cam_back if qa.cam_back >= 0.0 else rig.back,
			qa.cam_ahead if qa.cam_ahead >= 0.0 else rig.look_ahead, rig.look_height, qa.fov if qa.fov > 0.0 else rig.fov)
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
	jutsu.gear_changed.connect(_on_gear)
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
	story.skip_pressed.connect(func() -> void:
		if _cutscene:
			_cutscene.skip())
	# Measurement switches (perf, stress, shot) mean the sandbox unless an act is asked for: a title card or a
	# cutscene inside a perf window would measure the story, not the crowd.
	var measuring: bool = qa.perf > 0.0 or qa.stress > 0 or not qa.shot.is_empty() or not qa.cutscene.is_empty()
	_load_act(qa.act if qa.act >= 0 else (0 if measuring else default_act))
	if qa.stress > 0:
		for i: int in qa.stress:
			_spawn_one(_spawn_kinds[i % _spawn_kinds.size()], rng.randf_range(8.0, spawn_radius))


func _process(delta: float) -> void:
	if _warm_frames == 0 and not _warm_shown.is_empty():
		_end_warm_up()
	var real_dt: float = minf(delta, 0.1)
	_hit_stop = maxf(_hit_stop - real_dt, 0.0)
	_hit_stop_ready = maxf(_hit_stop_ready - real_dt, 0.0)
	if not qa.cutscene.is_empty() and _warm_shown.is_empty():
		var path: String = "res://scenes/cutscenes/%s.tscn" % qa.cutscene
		qa.cutscene = ""
		if ResourceLoader.exists(path):
			_paused = true
			play_cutscene(load(path)).connect(func() -> void: _paused = false, CONNECT_ONE_SHOT)
	if _act_pending and _warm_shown.is_empty():
		_act_pending = false
		act.begin(story, self)
	var held: bool = act != null and act.holds_game()
	time_scale = 0.0 if (_paused or finished or held) else (hit_stop_scale if _hit_stop > 0.0 else 1.0)
	var dt: float = real_dt * time_scale
	var started: int = Time.get_ticks_usec()
	# The warm-up's frames do not advance the game: anything it showed is hidden again, and an effect the game
	# started during them would be swallowed. Its pooled samples are committed (drawn) without ageing.
	if not _warm_shown.is_empty():
		fx.step(0.0)
	elif dt > 0.0:
		_simulate(dt)
	sim_usec = Time.get_ticks_usec() - started
	if act and not _act_pending:
		act.step(dt, player.ground())
	glow.commit()
	dust.commit()
	horde.commit()
	gems.commit()
	rig.step(dt, real_dt)
	var at: Vector2 = player.ground()
	decor.follow(at)
	_prop_material.set_shader_parameter(&"focus", player.global_position)
	hud.show_susanoo(jutsu.gear_learned(), jutsu.gear_ratio())
	hud.show_dominance(dominance / 100.0, dominance_stages[mini(int(dominance / 25.0), dominance_stages.size() - 1)], ultimate.learned)
	hud.show_stats(level, float(xp) / _xp_needed(), player.hp, player.max_hp, kills, player.dash_ready / player.dash_cooldown)
	hud.show_goal(_goal_text(), clampf(route.progress(at) / route.progress(Vector2(0.0, route.end_z)), 0.0, 1.0))
	_update_perf(real_dt)
	if qa.perf > 0.0:
		_record_perf()
	if _warm_frames > 0:
		_warm_frames -= 1
	if not qa.shot.is_empty():
		_shot_clock += real_dt
		if _shot_clock >= qa.shot_delay:
			_take_shot()
	if qa.autoplay and hud.level_up_open():
		hud.pick_card(0)


func _simulate(dt: float) -> void:
	elapsed += dt
	var input: Vector2 = _autopilot() if qa.autoplay else _read_input()
	if Input.is_action_just_pressed(&"dash"):
		player.dash(input)
	if qa.ult_at >= 0.0 and elapsed >= qa.ult_at:
		qa.ult_at = -1.0
		dominance = 100.0
	if (Input.is_action_just_pressed(&"ultimate") or (qa.autoplay and dominance >= 100.0)) and _ultimate_ready():
		_fire_ultimate()
	if (Input.is_action_just_pressed(&"susanoo") or qa.autoplay) and jutsu.raise_gear():
		pass
	ultimate.step(dt)
	if ultimate.active():
		player._invuln = maxf(player._invuln, 0.2)
	var was: Vector2 = player.ground()
	player.move(dt, input, (1.0 + upgrades.stat(PassiveDef.Stat.SPEED)) * jutsu.speed_factor())
	var pushed: Vector2 = decor.push_out(_out_of_blockers(player.ground()), player.radius, was)
	player.position = Vector3(pushed.x, 0.0, pushed.y)
	if player.is_dashing():
		_rocket_sweep()
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
	_mute_will = false
	var gained: int = gems.step(dt, player.ground(), base_magnet * (1.0 + upgrades.stat(PassiveDef.Stat.MAGNET)))
	if gained > 0:
		sfx.play(&"pickup", 0.06)
		_add_xp(gained)
	_streak_left -= dt
	_banner_hold -= dt
	if _streak_left <= 0.0:
		streak = 0
	fx.step(dt)
	fist.step(dt)
	numbers.step(dt)
	_spawn(dt)
	if act == null and elapsed >= run_seconds and not finished:
		_finish(true)


func _read_input() -> Vector2:
	var v: Vector2 = hud.stick.vector
	if v == Vector2.ZERO:
		v = Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")
	return v


## QA autopilot: pushes forward along the route, sidesteps the thickest crowd, dashes ahead when boxed in.
func _autopilot() -> Vector2:
	var at: Vector2 = player.ground()
	var away: Vector2 = horde.threat(at, 6.0)
	if rng.randf() < 0.003:
		_auto_turn = -_auto_turn
	var out := Vector2(0.0, -1.0)
	if away.length() > 0.05:
		out += Vector2(away.normalized().x + 0.6 * _auto_turn, 0.0) * minf(away.length(), 1.5)
	out = out.normalized()
	if away.length() > 2.5:
		player.dash(Vector2(out.x, -1.0).normalized())
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
	var target: int = maxi(_army_target(), qa.stress)
	_budget += (budget_base + target / budget_divisor) * dt
	var alive: int = horde.alive()
	while alive < target:
		var kind: int = _pick_kind()
		var cost: float = horde.defs[kind].cost
		if _budget < cost:
			break
		_budget -= cost
		if not _spawn_one(kind, spawn_radius + rng.randf_range(0.0, 4.0)):
			break
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


## Spawns `ahead` meters in front of the player across the corridor. Returns false (no spawn) when the route ends
## before that: enemies never appear inside the view or on the player.
func _spawn_one(kind: int, ahead: float) -> bool:
	var z: float = player.ground().y - ahead
	if z < route.end_z + horde.defs[kind].radius:
		return false
	var half: float = route.floor_half(z)
	var at := Vector2(rng.randf_range(-half, half), z)
	horde.spawn(kind, decor.push_out(at, horde.defs[kind].radius))
	return true


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
	ultimate.learned = jutsu.level_of_kind(JutsuDef.Kind.HAKI) > 0 or unlocked.get("haki", false)
	player.set_max_hp(player.base_max_hp + upgrades.stat(PassiveDef.Stat.MAX_HP))


func _on_struck(kind: int, hits: int, crits: int, at: Vector3, heavy: bool) -> void:
	var from: Vector3 = player.global_position
	var to_strike := Vector2(at.x - from.x, at.z - from.z)
	match kind:
		JutsuDef.Kind.PISTOL:
			# The arm stretches from the shoulder to the fist: where the punch stopped.
			fist.play(from, jutsu.aim, maxf(to_strike.length(), 1.5))
			sfx.play(&"swing")
		JutsuDef.Kind.GATLING:
			fist.play(from, to_strike.normalized() if to_strike.length() > 0.1 else jutsu.aim, maxf(to_strike.length(), 1.2))
			sfx.play(&"swing", 0.03)
		JutsuDef.Kind.GIGANT:
			sfx.play(&"slam", 0.05)
			rig.add_trauma(0.45, 0.7)
		JutsuDef.Kind.BAZOOKA:
			sfx.play(&"slam", 0.05)
			rig.add_trauma(0.2, 0.5)
		_:
			sfx.play(&"swing")
	if hits <= 0:
		return
	sfx.play(&"crit" if crits > 0 else &"hit")
	if (heavy or hits >= hit_stop_min_hits) and _hit_stop_ready <= 0.0:
		_hit_stop = minf(hit_stop_base + hit_stop_per_hit * hits, hit_stop_max)
		_hit_stop_ready = hit_stop_cooldown
	rig.add_trauma(0.08 + 0.02 * hits + (0.08 if heavy else 0.0), 0.55)
	fx.dust_burst(at, 4 if not heavy else 6, 4.0, 1.1, dust_color)
	fx.flash(at + Vector3(0, 1.0, 0), 1.8 if not heavy else 2.6, spark_color)
	if crits > 0:
		numbers.show_hit(at + Vector3(0, 1.6, 0), 28.0 * jutsu.might * jutsu.crit_multiplier, true)


## Every hit on Luffy goes through here. Ivankov's hormone turns the first lethal one of the act into a stand-up.
func _hurt_player(amount: float, from: Vector2, element: int = EnemyJutsu.Element.NONE) -> void:
	if player.dead or player.is_invulnerable():
		return
	if amount >= player.hp and unlocked.get("hormone", false) and not hormone_used:
		hormone_used = true
		player.hp = player.max_hp * hormone_hp
		player._invuln = hormone_grace
		rig.add_trauma(0.6)
		hud.flash(0.6)
		fx.ring(player.global_position + Vector3(0, 0.3, 0), 6.0, Color(1.0, 0.45, 0.75), 0.4)
		story.toast("伊萬科夫", "荷爾蒙發動！再站起來！", "ivankov", Color("ff7ac0"))
		return
	if player.take_hit(amount):
		rig.add_trauma(0.45, 0.6)
		sfx.play(&"hurt")
		if element == EnemyJutsu.Element.WATER:
			player.slow(enemy_jutsu.water_slow_time, enemy_jutsu.water_slow)


## Gum-Gum Rocket: Luffy flings himself, and whoever he passes through is struck and thrown aside.
func _rocket_sweep() -> void:
	var at: Vector2 = player.ground()
	var damage: float = rocket_damage * jutsu.might
	horde.damage_circle(at, rocket_radius, damage, rocket_push)
	for b: Node3D in _blockers:
		if not b.is_down() and b.ground().distance_to(at) <= rocket_radius + b.radius:
			b.take_strike(damage, (b.ground() - at).normalized() * rocket_push)


## Keeps the player's circle out of every standing blocker's circle.
func _out_of_blockers(p: Vector2) -> Vector2:
	for b: Node3D in _blockers:
		if b.is_down():
			continue
		var away: Vector2 = p - b.ground()
		var min_d: float = b.radius + player.radius
		if away.length() < min_d:
			p = b.ground() + (away.normalized() if away.length() > 0.001 else Vector2(0.0, 1.0)) * min_d
	return p


func _gain_dominance(amount: float) -> void:
	dominance = minf(dominance + amount, 100.0)


func _ultimate_ready() -> bool:
	return ultimate.learned and not ultimate.active() and dominance >= 100.0


func _fire_ultimate() -> void:
	if qa.perf > 0.0:
		print("ULT fired t=%.2f" % elapsed)
	dominance = 0.0
	ultimate.fire(player.global_position)
	# The spike's stand-in ultimate (the crush is still Madara's) wears the Haki banner the real one will use.
	hud.show_banner("霸王色霸氣", "蒙奇・D・魯夫", Color("ffd16b"))
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
	_mute_will = true
	if count > 0:
		hud.show_combo(count, "霸王色")
		_banner_hold = 1.5


func _on_gear(active: bool, _level: int) -> void:
	if active:
		sfx.play(&"ultimate")
		rig.add_trauma(0.3)
		fx.ring(player.global_position + Vector3(0, 0.3, 0), 6.0, Color(1.0, 0.55, 0.5), 0.4)
		story.line("魯夫", "二檔！", 1.2)


func _on_dodged(from: Vector3, to: Vector3) -> void:
	_gain_dominance(dominance_per_dodge)
	sfx.play(&"dodge")
	# No hit stop here: the game keeps running so the dodge never feels like a stall; the afterimage, a red flash
	# and a small shake carry it.
	rig.add_trauma(0.12, 0.3)
	fx.flash(from + Vector3(0, 1.2, 0), 2.2, Color(1.0, 0.25, 0.25))
	fx.ring(to + Vector3(0, 0.2, 0), 3.0, Color(1.0, 0.3, 0.3), 0.25)


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
	kills += 1
	streak += 1
	if not _mute_will:
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


## The next waypoint ahead and how far it is (meters along the route).
func _goal_text() -> String:
	var z: float = player.ground().y
	if act:
		var goal: Dictionary = act.next_goal()
		return "%s %d m" % [goal.name, maxi(ceili((z - goal.z) * -act.heading), 0)] if not goal.is_empty() else act.title
	for marker: Node3D in route.get_node(^"Waypoints").get_children():
		if marker.position.z < z - 0.5:
			return "%s %d m" % [GOAL_NAMES.get(marker.name, String(marker.name)), ceili(z - marker.position.z)]
	return GOAL_NAMES[&"Platform"]


## Loads and places act `id` (0 = no act: the free-run sandbox). It begins once the warm-up is over.
func _load_act(id: int) -> void:
	if id <= 0:
		return
	var path: String = "res://scenes/acts/act_%d.tscn" % id
	if not ResourceLoader.exists(path):
		push_warning("no act scene " + path)
		return
	act = (load(path) as PackedScene).instantiate()
	add_child(act)
	if qa.start_z == 0.0:
		player.position.z = act.start_z
		rig.global_position = player.global_position
	if act.army_curve.size() > 0:
		army_curve = act.army_curve
	for what: String in act.unlocked:
		unlock(what)
	for entry: String in act.kit:
		_learn_to(entry.get_slice(":", 0), maxi(entry.get_slice(":", 1).to_int(), 1))
	if qa.autoplay:
		story.auto_advance = 0.6
	act.cleared.connect(func() -> void: _finish(true))
	_act_pending = true


## Learns move `id` (data/jutsu/<id>.tres) up to `level`.
func _learn_to(id: String, level: int) -> void:
	var path: String = "res://data/jutsu/%s.tres" % id
	if not ResourceLoader.exists(path):
		push_warning("no move " + path)
		return
	var def: JutsuDef = load(path)
	while jutsu.level_of(def) < mini(level, def.max_level):
		jutsu.learn(def)
	_apply_upgrades()


## Act host (CALL blocker, arg "<character>:<hits>"): a blocker stands 7 m ahead of the player until Luffy has hit
## it that many times; the Signal fires when it is knocked away.
func blocker(arg: String) -> Signal:
	var b: Node3D = (load("res://scenes/blocker.tscn") as PackedScene).instantiate()
	b.set(&"character", arg.get_slice(":", 0))
	b.set(&"hits_needed", maxi(arg.get_slice(":", 1).to_int(), 1))
	b.set(&"facing", Vector3(0.0, 0.0, -act.heading if act else 1.0))
	b.set(&"anim", &"block" if arg.begins_with("garp") else &"idle")
	add_child(b)
	var at: Vector2 = decor.push_out(player.ground() + Vector2(0.0, 7.0 * (act.heading if act else -1.0)), b.radius)
	b.global_position = Vector3(at.x, 0.0, at.y)
	_blockers.append(b)
	jutsu.targets.append(b)
	b.beaten.connect(func() -> void:
		_blockers.erase(b)
		jutsu.targets.erase(b)
		rig.add_trauma(0.6)
		sfx.play(&"elite")
		b.queue_free.call_deferred(), CONNECT_ONE_SHOT)
	return b.beaten


## Act host: plays a cutscene scene with the game held; the returned Signal fires when it ends or is skipped.
func play_cutscene(scene: PackedScene) -> Signal:
	var cs: Cutscene = scene.instantiate()
	add_child(cs)
	_cutscene = cs
	story.cinema(true)
	hud.visible = false
	rig.borrow(cs.shot)
	cs.line.connect(func(speaker: String, text: String, seconds: float) -> void: story.line(speaker, text, seconds))
	cs.effect.connect(_on_cutscene_effect)
	cs.ended.connect(func() -> void:
		story.cinema(false)
		hud.visible = true
		rig.release(cs.blend_out)
		_cutscene = null
		cs.queue_free()
		_cutscene_done.emit(), CONNECT_ONE_SHOT)
	cs.start()
	if qa.skip_cutscenes:
		cs.skip.call_deferred()
	return _cutscene_done


func _on_cutscene_effect(kind: StringName, amount: float) -> void:
	if kind == &"shake":
		rig.add_trauma(amount)
	elif kind == &"flash":
		hud.flash(amount)


## Act host: the full-width banner.
func story_banner(title: String, subtitle: String, color: Color, portrait_id: String) -> void:
	hud.show_banner(title, subtitle, color, StoryUi.portrait(portrait_id))


## Act host (CALL unlock): a story unlock (gear2, haki, hormone) becomes available.
func unlock(what: String) -> void:
	unlocked[what] = true
	if what == "haki":
		ultimate.learned = true


## Act host (CALL bridge): "closed" sinks the bridge into the crack and blocks it; "rise" raises it (the Signal
## fires when it is up and walkable).
func bridge(state: String) -> Variant:
	var mesh := route.get_node(^"Bridge") as Node3D
	if state == "closed":
		route.bridge_open = false
		mesh.position.y = -route.trench_depth - 1.5
		return null
	var tween := create_tween()
	tween.tween_property(mesh, "position:y", -0.5, 1.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: route.bridge_open = true)
	rig.add_trauma(0.5)
	sfx.play(&"slam")
	return tween.finished


## Act host (CALL haki): the story's Haki — fires the Haki ultimate now; the Signal fires when it has landed.
func haki(_arg: String) -> Signal:
	unlock("haki")
	_fire_ultimate()
	return ultimate.crushed


## The web build has no shader cache: a material is compiled the first time it is drawn, which stalled the first
## ultimate by 62-87 ms (13-31 ms with this warm-up). So for the first `_warm_frames` frames, while the screen is
## darkened and the game does not advance, every effect is drawn once in front of the camera: hidden nodes (damage
## number labels included) shown, one of each pooled effect committed. Then the samples go and the game starts.
func _begin_warm_up() -> void:
	_warm_frames = 3
	var ahead: Vector3 = player.global_position + Vector3(0.0, 1.0, -6.0)
	for node: Node in find_children("*", "GeometryInstance3D", true, false):
		var geo := node as GeometryInstance3D
		if not geo.visible and not get_node(^"%Previews").is_ancestor_of(geo):
			# Off-screen geometry is culled and never compiled: bring it in front of the camera for these frames.
			_warm_shown.append(geo)
			_warm_from.append(geo.global_transform)
			geo.global_position = ahead
			geo.visible = true
	fx.spark(ahead, Color.WHITE)
	fx.ring(ahead, 2.0, Color.WHITE)
	fx.flash(ahead, 2.0, Color.WHITE)
	fx.flame(ahead, 1.0, Color.WHITE)
	fx.dust(ahead, 1.0, Color.WHITE)
	hud.flash(0.0)
	(hud.get_node(^"%Darken") as CanvasItem).modulate.a = 1.0


func _end_warm_up() -> void:
	fx.clear()
	for i: int in _warm_shown.size():
		_warm_shown[i].visible = false
		_warm_shown[i].global_transform = _warm_from[i]
	_warm_shown.clear()
	_warm_from.clear()
	hud.darken(0.0)


## QA: wall-clock frame times after the warm-up (the game clock would hide stalls); prints a PERF line and quits.
func _record_perf() -> void:
	var now: int = Time.get_ticks_usec()
	if _perf_start_usec == 0:
		_perf_start_usec = now
	var since: float = (now - _perf_start_usec) / 1000000.0
	if since >= qa.perf_warmup and _perf_last_usec > 0:
		_perf_samples.append((now - _perf_last_usec) / 1000.0)
	_perf_last_usec = now
	if since < qa.perf_warmup + qa.perf:
		return
	var sorted := _perf_samples.duplicate()
	sorted.sort()
	var in_view: int = 0
	for i: int in horde.count:
		var p: Vector2 = horde._pos[i]
		if rig.camera.is_position_in_frustum(Vector3(p.x, 0.5, p.y)):
			in_view += 1
	var size: Vector2i = CameraRig.render_size(get_viewport())
	print("PERF frames=%d avg=%.2f p95=%.2f max=%.2f ms enemies=%d in_view=%d render=%dx%d renderer=%s adapter=%s" % [
		sorted.size(), _mean(sorted), sorted[int(sorted.size() * 0.95)], sorted[sorted.size() - 1], horde.alive(), in_view,
		size.x, size.y, RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name()])
	qa.perf = 0.0
	if not OS.has_feature("web"):
		get_tree().quit()


static func _mean(values: PackedFloat32Array) -> float:
	var total: float = 0.0
	for v: float in values:
		total += v
	return total / maxf(values.size(), 1.0)


## QA: saves the frame and prints where the player and the execution platform land on screen, then quits.
func _take_shot() -> void:
	var cam: Camera3D = rig.camera
	var size: Vector2 = get_viewport().get_visible_rect().size
	var image_scale: float = float(CameraRig.render_size(get_viewport()).y) / size.y
	var feet: Vector2 = cam.unproject_position(player.global_position)
	# The sprite faces the camera fully (lean 1), so its height runs along the camera's up, not world up.
	var head: Vector2 = cam.unproject_position(player.global_position + cam.global_basis.y * SpriteSet.HEIGHTS["luffy"])
	var deck: Node3D = route.get_node(^"Landmarks/PlatformDeck")
	var deck_top: Vector2 = cam.unproject_position(deck.global_position + Vector3(0.0, 0.7, 0.0))
	var base: Node3D = route.get_node(^"Landmarks/PlatformBase")
	var base_foot: Vector2 = cam.unproject_position(base.global_position - Vector3(0.0, 1.5, -10.0))
	print("SHOT cam=%s height=%.1f back=%.1f ahead=%.1f fov=%.0f pitch=%.1f viewport=%dx%d" % [qa.cam, rig.height, rig.back,
		rig.look_ahead, rig.fov, rig.center_pitch(), size.x, size.y])
	print("SHOT player_feet_y=%.2f luffy_px=%.0f image px (%.0f logical, density %s art %d px) eye_dist=%.1f m" % [
		feet.y / size.y, (feet.y - head.y) * image_scale, feet.y - head.y, qa.density,
		roundi(SpriteSet.HEIGHTS["luffy"] / player.sheet.meters_per_px), cam.global_position.distance_to(player.global_position)])
	print("SHOT platform_deck_y=%.2f platform_base_y=%.2f behind_camera=%s (0 = top edge, 1 = bottom)" % [deck_top.y / size.y,
		base_foot.y / size.y, cam.is_position_behind(deck.global_position)])
	var image: Image = get_viewport().get_texture().get_image()
	var err: int = image.save_png(qa.shot)
	print("SHOT saved %s %dx%d" % [qa.shot, image.get_width(), image.get_height()] if err == OK else "SHOT save failed: %d" % err)
	get_tree().quit()


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
