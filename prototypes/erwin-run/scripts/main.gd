extends Node2D
## The run: title → 2.5-minute gallop (titans, thrown rocks) → the ape boss → the captain's finisher → ending.
## One _physics_process drives every actor in a fixed order so a run is deterministic for a given seed.
## User args: --bot (auto-play), --boss (start at the boss), --autostart (skip the title), --seed=N.

enum S { TITLE, RUN, BOSS, LEVI, ENDING, OVER }

const Titan := preload("res://scenes/titan.tscn")
const Rock := preload("res://scenes/rock.tscn")
const Warning := preload("res://scenes/warning.tscn")
const Haptics := preload("res://addons/proto_kit/haptics.gd")
const CameraShake := preload("res://addons/proto_kit/camera_shake.gd")

const GROUND_Y := 318.0
const PLAYER_X := 120.0
const BOSS_TIME := 150.0
const WARN_TIME := 0.95
const ROCK_LOW_Y := GROUND_Y - 16.0
const ROCK_MID_Y := GROUND_Y - 60.0
const MAX_HP := 3
const SAVE_PATH := "user://erwin_run.cfg"
## Parallax factor of each scrolling layer (1.0 = ground speed).
const LAYERS := {&"Sky": 0.04, &"Far": 0.14, &"Mid": 0.38, &"Ruins": 0.6, &"Ground": 1.0}

@export var run_track: AudioStream
@export var boss_track: AudioStream
@export var end_track: AudioStream

@onready var sfx: Node = %Sfx
@onready var music: Node = %Music
@onready var time_control: Node = %TimeControl
@onready var player: Node2D = %Player
@onready var obstacles: Node2D = %Obstacles
@onready var beast: Node2D = %Beast
@onready var beast_far: Sprite2D = %BeastFar
@onready var levi: Node2D = %Levi
@onready var levi_sprite: Sprite2D = $World/Levi/Sprite
@onready var wall_gate: Sprite2D = %WallGate
@onready var fx: Node2D = %Fx
@onready var camera: Camera2D = %Camera
@onready var hud: CanvasLayer = %Hud
@onready var screens: CanvasLayer = %Screens
@onready var confetti: Node2D = $Screens/UI/Ending/Confetti

var state := S.TITLE
var rng := RandomNumberGenerator.new()
var shake := CameraShake.new()
var haptics := Haptics.new()
var bot := false
var t := 0.0
var speed := 0.0
var distance := 0.0
var hp := MAX_HP
var bonus := 0
var kills := 0
var parries := 0
var perfects := 0
var combo := 0
var best_combo := 0
var hits_taken := 0
var reached_boss := false
var best := 0
var next_spawn := 0.0
var pending: Array = []        # [time, Callable] spawns queued by combo patterns
var warnings: Array = []       # {node, left, y}
var drifting: Array = []       # effect nodes that scroll with the ground
var dust_t := 0.0
var taught := {}
var boss_phase := ""
var boss_timer := 0.0
var boss_attacks := 0
var boss_target := Vector2.ZERO
var wall_start := Vector2.ZERO


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	bot = bot or "--bot" in args
	rng.seed = 1014
	for a in args:
		if a.begins_with("--seed="):
			rng.seed = int(a.trim_prefix("--seed="))
	shake.camera = camera
	shake.max_offset = Vector2(14.0, 10.0)
	wall_start = wall_gate.position
	fx.palettes.merge({
		"steel": ["#141c28", "#4f6078", "#a3b4cc", "#e2ecf8", "#ffffff"],
		"blood": ["#260404", "#6e0e0e", "#be2618", "#f06848", "#ffd2c2"],
		"steam": ["#2e2a36", "#7e7888", "#bcb8c6", "#e8e4ee", "#ffffff"],
		"rock": ["#1c1816", "#4a423c", "#7a7068", "#aea496", "#ddd4c6"],
		"dust": ["#2a2016", "#6a5236", "#a08460", "#cdb68e", "#efe2c4"],
		"wing": ["#0c1a3a", "#2346a0", "#4f86e8", "#a6c8ff", "#ffffff"],
	}, true)
	confetti.palettes = fx.palettes
	screens.start_pressed.connect(func() -> void: _start(false))
	screens.retry_pressed.connect(_start)
	screens.resume_pressed.connect(_toggle_pause)
	screens.mute_toggled.connect(func(m: bool) -> void:
		AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Master"), m))
	hud.pause_pressed.connect(_toggle_pause)
	player.landed.connect(_on_landed)
	best = _load_best()
	_reset_world(false)
	hud.set_running(false)
	screens.show_title(best)
	music.play(run_track)
	if "--autostart" in args or "--bot" in args or "--boss" in args:
		_start.call_deferred("--boss" in args)


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		_toggle_pause()
		return
	if get_tree().paused:
		return
	if state == S.TITLE:
		if event is InputEventKey and event.pressed and not event.echo:
			_start(false)
		return
	if state != S.RUN and state != S.BOSS:
		return
	if event.is_action_pressed(&"jump"):
		_jump()
	elif event.is_action_pressed(&"slash"):
		_slash()
	elif event is InputEventScreenTouch and event.pressed:
		_tap(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and event.device != InputEvent.DEVICE_ID_EMULATION:
		_tap(event.position)


## A touch or click anywhere, letterbox bars included: left half jumps, right half slashes.
func _tap(at: Vector2) -> void:
	if hud.pause_button.visible and hud.pause_button.get_global_rect().has_point(at):
		return
	var slash: bool = at.x >= get_viewport().get_visible_rect().size.x / 2.0
	hud.press_pad(slash)
	if slash:
		_slash()
	else:
		_jump()


func _jump() -> void:
	if player.jump():
		sfx.play(&"jump")
		fx.burst(player.position + Vector2(0, -2), &"dust", 6, 40.0)


func _slash() -> void:
	if player.slash():
		sfx.play(&"slash")
		fx.slash(player.blade_tip() + Vector2(18, 0), -0.35, 52.0, 1.9, &"steel", true)


func _toggle_pause() -> void:
	if state != S.RUN and state != S.BOSS:
		return
	var paused := not get_tree().paused
	get_tree().paused = paused
	screens.show_only(screens.pause_panel if paused else null)
	sfx.play(&"ui")


# ---------------------------------------------------------------- run flow

func _start(from_boss: bool) -> void:
	get_tree().paused = false
	_phone_fullscreen()
	sfx.play(&"ui")
	_reset_world(from_boss)
	state = S.RUN
	screens.hide_all()
	hud.set_running(true)
	if from_boss:
		_start_boss()
	else:
		music.play(run_track)
		hud.show_banner("調查兵團，出擊！", "目標：牆外的獸之巨人", 1.8)
		var touch := DisplayServer.is_touchscreen_available()
		hud.show_hint("點左半邊：跳躍　　點右半邊：斬擊・彈反" if touch
				else "空白鍵／↑：跳躍　　J／→：斬擊・彈反", 3.2)


## On a phone browser, the first start (a user gesture) asks for fullscreen and a landscape lock. Android Chrome
## honours both; iPhone Safari has neither and simply keeps the page as it is.
func _phone_fullscreen() -> void:
	if not OS.has_feature("web") or not DisplayServer.is_touchscreen_available():
		return
	JavaScriptBridge.eval("""try { var d = document.documentElement;
		if (!document.fullscreenElement && d.requestFullscreen) d.requestFullscreen({navigationUI: 'hide'})
			.then(function () { if (screen.orientation && screen.orientation.lock) return screen.orientation.lock('landscape'); })
			.catch(function () {}); } catch (e) {}""", true)


func _reset_world(from_boss: bool) -> void:
	for child in obstacles.get_children():
		child.queue_free()
	for w in warnings:
		w.node.queue_free()
	warnings.clear()
	pending.clear()
	for d in drifting:
		if is_instance_valid(d):
			d.queue_free()
	drifting.clear()
	fx.clear()
	confetti.clear()
	time_control.reset()
	hp = MAX_HP
	bonus = 0
	kills = 0
	parries = 0
	perfects = 0
	combo = 0
	best_combo = 0
	hits_taken = 0
	distance = 0.0
	taught.clear()
	t = BOSS_TIME if from_boss else 0.0
	reached_boss = from_boss
	speed = 160.0 if from_boss else 185.0
	next_spawn = 3.2
	player.reset()
	player.position.x = PLAYER_X
	beast.visible = false
	beast.rotation = 0.0
	beast.modulate = Color.WHITE
	beast.set_extension(0.0)
	beast.pose(beast.POSE_IDLE)
	levi.visible = false
	beast_far.visible = false
	wall_gate.visible = not from_boss
	wall_gate.position = wall_start
	%Ruins.modulate.a = 0.0 if from_boss else 1.0
	_tint_sky(1.0 if from_boss else 0.0)
	hud.set_hp(hp)
	hud.set_combo(0)
	hud.set_progress(t / BOSS_TIME)


func _physics_process(delta: float) -> void:
	shake.step(delta)
	if state == S.TITLE:
		_scroll(120.0, delta)
		player.step(delta)
		return
	match state:
		S.RUN:
			t += delta
			speed = lerpf(185.0, 330.0, clampf(t / BOSS_TIME, 0.0, 1.0))
			_direct(delta)
			if t >= BOSS_TIME and obstacles.get_child_count() == 0 and warnings.is_empty():
				_start_boss()
		S.BOSS:
			_boss_step(delta)
	distance += speed * delta
	_scroll(speed, delta)
	_zones()
	player.step(delta)
	for o in obstacles.get_children():
		if not o.is_queued_for_deletion():
			if o.has_method(&"front"):
				o.step(delta, speed)
			else:
				o.step(delta)
	_step_warnings(delta)
	if bot and (state == S.RUN or state == S.BOSS):
		_bot_think()
	if state == S.RUN or state == S.BOSS:
		_resolve()
	_dust(delta)
	hud.set_progress(minf(t, BOSS_TIME) / BOSS_TIME)
	hud.set_score(score(), kills)


## World x of the screen's right edge: the camera sits at x 320 and wide phones show more on both sides.
func right_edge() -> float:
	return camera.position.x + get_viewport_rect().size.x / 2.0


func score() -> int:
	return int(distance / 10.0) + bonus


func _scroll(world_speed: float, delta: float) -> void:
	for layer_name in LAYERS:
		var layer: Parallax2D = get_node("%" + layer_name)
		layer.scroll_offset.x -= world_speed * LAYERS[layer_name] * delta
	if wall_gate.visible:
		wall_gate.position.x -= world_speed * 0.5 * delta
		if wall_gate.position.x < -wall_gate.texture.get_width() - 20.0:
			wall_gate.visible = false
	for d in drifting:
		if is_instance_valid(d):
			d.position.x -= world_speed * delta
	drifting = drifting.filter(func(d: Variant) -> bool: return is_instance_valid(d))


## Ruins fade into open fields, the sky turns to dusk, and the boss shows on the horizon near the end.
func _zones() -> void:
	if state != S.RUN:
		return
	%Ruins.modulate.a = clampf(1.0 - (t - 42.0) / 6.0, 0.0, 1.0)
	_tint_sky(clampf((t - 105.0) / 40.0, 0.0, 1.0))
	if t > 47.0 and _teach(&"fields"):
		hud.show_banner("牆外平原", "巨人變多了，保持節奏", 1.6)
	if t > 118.0 and _teach(&"far_beast"):
		hud.show_banner("遠方傳來巨響……", "巨石是從那裡丟過來的", 1.8)
	beast_far.visible = t > 118.0
	if beast_far.visible:
		beast_far.modulate.a = clampf((t - 118.0) / 6.0, 0.0, 1.0) * 0.85


func _tint_sky(k: float) -> void:
	%Sky.modulate = Color.WHITE.lerp(Color(1.0, 0.62, 0.5), k)
	%Far.modulate = Color.WHITE.lerp(Color(0.85, 0.6, 0.62), k)
	%Mid.modulate = Color.WHITE.lerp(Color(0.86, 0.7, 0.66), k)


# ---------------------------------------------------------------- spawning

func _direct(delta: float) -> void:
	for p in pending.duplicate():
		if t >= p[0]:
			pending.erase(p)
			p[1].call()
	if t > BOSS_TIME - 3.0:
		return
	next_spawn -= delta
	if next_spawn > 0.0:
		return
	var p := t / BOSS_TIME
	var roll := rng.randf()
	if t < 22.0:
		_spawn_titan(&"tall" if roll < 0.6 else &"fat")
	elif t < 48.0:
		if roll < 0.55:
			_spawn_titan(&"tall" if rng.randf() < 0.5 else &"fat")
		else:
			_spawn_rock(rng.randf() < 0.6)
	elif t < 92.0:
		if roll < 0.32:
			_spawn_titan(&"tall" if rng.randf() < 0.5 else &"fat")
		elif roll < 0.52:
			_spawn_titan(&"runner")
		else:
			_spawn_rock(rng.randf() < 0.45)
	else:
		if roll < 0.22:
			_spawn_titan(&"tall" if rng.randf() < 0.5 else &"fat")
		elif roll < 0.4:
			_spawn_titan(&"runner")
		elif roll < 0.7:
			_spawn_rock(rng.randf() < 0.4)
		elif roll < 0.85:  # titan, then a rock right behind it
			_spawn_titan(&"tall")
			pending.append([t + 0.7, _spawn_rock.bind(false)])
		else:  # low rock then a high one: jump, then parry (or parry both)
			_spawn_rock(true)
			pending.append([t + 0.55, _spawn_rock.bind(false)])
	next_spawn = lerpf(2.3, 1.15, p) + rng.randf() * lerpf(0.9, 0.5, p)


func _spawn_titan(kind: StringName) -> void:
	var titan := Titan.instantiate()
	obstacles.add_child(titan)
	titan.setup(kind)
	titan.position = Vector2(right_edge() + 60.0, GROUND_Y)
	if kind == &"runner" and _teach(&"runner"):
		hud.show_banner("奇行種！", "跑得特別快，提早出刀", 1.6)
	elif _teach(&"titan"):
		hud.show_hint("巨人靠近時按斬擊，砍他的後頸！", 2.6)


func _spawn_rock(low: bool) -> void:
	var y := ROCK_LOW_Y if low else ROCK_MID_Y
	var node := Warning.instantiate()
	node.position = Vector2(right_edge() - 22.0, y)
	add_child(node)
	warnings.append({"node": node, "left": WARN_TIME, "y": y, "low": low})
	sfx.play(&"warn")
	if _teach(&"rock"):
		hud.show_hint("巨石飛來！斬擊彈反，低的也能跳過", 2.6)
	if beast_far.visible:  # the far-off boss is the one throwing
		beast_far.frame = 1
		get_tree().create_timer(0.35, false).timeout.connect(func() -> void: beast_far.frame = 0)


func _step_warnings(delta: float) -> void:
	for w in warnings.duplicate():
		w.left -= delta
		w.node.visible = int(w.left * 10.0) % 2 == 0
		if w.left <= 0.0:
			warnings.erase(w)
			w.node.queue_free()
			if state == S.RUN or (state == S.BOSS and w.get("boss", false) == false):
				var rock := Rock.instantiate()
				obstacles.add_child(rock)
				rock.setup(Vector2(right_edge() + 30.0, w.y), Vector2(-(speed + 270.0), 0.0), rng.randi() % 3, w.low)
				sfx.play(&"rock")


func _teach(topic: StringName) -> bool:
	if taught.has(topic):
		return false
	taught[topic] = true
	return true


# ---------------------------------------------------------------- hits

func _resolve() -> void:
	var zone: Rect2 = player.slash_zone()
	var body: Rect2 = player.hurtbox()
	if player.slash_active():
		for o in obstacles.get_children():
			if o.is_queued_for_deletion():
				continue
			if o.has_method(&"front"):
				if not o.dead and zone.intersects(o.hurtbox()):
					_kill_titan(o)
			elif not o.parried and o.visible and zone.has_point(o.position):
				_parry(o)
		if boss_phase == "reach_thrust" and zone.intersects(beast.hand_rect()):
			_cut_arm()
			return
	if player.invulnerable():
		return
	for o in obstacles.get_children():
		if o.is_queued_for_deletion():
			continue
		if o.has_method(&"front"):
			if not o.dead and not o.hit_player and body.intersects(o.hurtbox()):
				o.hit_player = true
				_damage()
				return
		elif not o.parried and o.visible and body.intersects(o.hurtbox()):
			_shatter(o)
			_damage()
			return


func _kill_titan(titan: Node2D) -> void:
	var perfect: bool = titan.front() - (PLAYER_X + 30.0) < 42.0
	titan.die()
	kills += 1
	_success(100, perfect)
	var nape: Vector2 = titan.nape()
	fx.slash(nape, -0.7, 34.0, 1.6, &"steel", true)
	fx.burst(nape, &"blood", 14, 95.0)
	fx.spark(nape, Vector2(1.0, -0.4), &"steam", 6)
	var steam: Node2D = fx.effect(&"smoke", titan.position + Vector2(0, -6), Vector2(64, 96), 1.6, &"steam", {}, Vector2(0.5, 1.0))
	if steam:
		steam.z_index = -6  # behind the actors (Fx itself sits above them)
		drifting.append(steam)
	fx.caption(nape + Vector2(0, -16), "完美討伐！" if perfect else "討伐！", &"gold" if perfect else &"steel")
	sfx.play(&"kill")
	sfx.play(&"steam")
	time_control.hit_stop(0.09 if perfect else 0.05, perfect)
	shake.add_trauma(0.32 if perfect else 0.22, 0.5)
	haptics.buzz(1)


func _parry(rock: Node2D) -> void:
	var perfect: bool = rock.position.x - PLAYER_X < 52.0
	var to := Vector2.INF
	if state == S.BOSS:
		to = beast.face.global_position
		rock.struck_target.connect(_rock_hits_boss.bind(rock.position))
	rock.parry(to)
	parries += 1
	_success(150, perfect)
	fx.star(rock.position, &"gold", true)
	fx.ring(rock.position, 6.0, 38.0, &"gold", 0.25, 2)
	fx.spark(rock.position, Vector2(1.0, -0.7), &"gold", 8)
	fx.caption(rock.position + Vector2(0, -22), "完美彈反！" if perfect else "彈反！", &"gold")
	sfx.play(&"parry")
	time_control.hit_stop(0.1 if perfect else 0.06, perfect)
	shake.add_trauma(0.25, 0.45)
	haptics.buzz(1)


func _success(points: int, perfect: bool) -> void:
	combo += 1
	best_combo = maxi(best_combo, combo)
	if perfect:
		perfects += 1
		sfx.play(&"perfect")
	bonus += int(points * (2.0 if perfect else 1.0) * (1.0 + minf(combo, 20) * 0.1))
	hud.set_combo(combo)


func _shatter(rock: Node2D) -> void:
	fx.burst(rock.position, &"rock", 14, 90.0)
	sfx.play(&"shatter")
	rock.queue_free()


func _damage() -> void:
	hp -= 1
	hits_taken += 1
	combo = 0
	hud.set_combo(0)
	hud.set_hp(hp)
	hud.hurt_flash()
	player.hurt()
	fx.burst(player.position + Vector2(0, -50), &"blood", 10, 70.0)
	sfx.play(&"hurt")
	shake.add_trauma(0.6)
	time_control.hit_stop(0.12, true)
	haptics.buzz(2)
	if hp <= 0:
		_game_over()


func _on_landed() -> void:
	sfx.play(&"land")
	fx.burst(player.position, &"dust", 5, 35.0)


func _dust(delta: float) -> void:
	dust_t += delta
	if dust_t < 0.09 or player.air or speed < 20.0:
		return
	dust_t = 0.0
	var c: Array = fx.tones(&"dust")
	fx.particle(player.position + Vector2(-28.0 + rng.randf_range(-6, 6), -2.0),
			Vector2(-speed * 0.35 - rng.randf_range(10, 40), -rng.randf_range(8, 30)),
			c[2 + rng.randi() % 2], 0.45, 2, 40.0)


# ---------------------------------------------------------------- boss

func _start_boss() -> void:
	state = S.BOSS
	reached_boss = true
	boss_phase = "intro"
	boss_timer = 0.0
	boss_attacks = 0
	beast_far.visible = false
	beast.visible = true
	beast.pose(beast.POSE_IDLE)
	beast.position = Vector2(790.0, GROUND_Y)
	music.play(boss_track)
	hud.show_banner("獸之巨人", "斬斷伸來的手臂，或把巨石彈回去！", 3.0)
	var tw := create_tween()
	tw.tween_property(beast, "position:x", 520.0, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		sfx.play(&"roar")
		shake.add_trauma(0.75)
		fx.ring(beast.face.global_position, 10.0, 120.0, &"steam", 0.5, 2)
		haptics.buzz(2))


func _boss_step(delta: float) -> void:
	boss_timer += delta
	speed = move_toward(speed, 150.0, 60.0 * delta)
	match boss_phase:
		"intro":
			if boss_timer > 3.8:
				_boss_next()
		"idle":
			if boss_timer > 1.1:
				_boss_next()
		"reach_wind":
			beast.rotation = -0.06 * minf(1.0, boss_timer / 0.3)
			if int(boss_timer * 8.0) % 2 == 0:
				beast.body.modulate = Color(1.5, 1.1, 1.1)
			else:
				beast.body.modulate = Color.WHITE
			if boss_timer > 1.05:
				beast.body.modulate = Color.WHITE
				boss_phase = "reach_thrust"
				boss_timer = 0.0
				sfx.play(&"reach")
		"reach_thrust":
			# fast lunge to 62%, then a slower grab: the hand lingers in blade range before it lands
			var e := boss_timer / 0.22 * 0.62 if boss_timer < 0.22 else 0.62 + (boss_timer - 0.22) / 0.55 * 0.38
			beast.set_extension(minf(e, 1.0))
			beast.rotation = lerpf(-0.06, 0.05, minf(1.0, boss_timer / 0.3))
			if not player.invulnerable() and beast.hand_rect().intersects(player.hurtbox()):
				_damage()
				_boss_retract()
			elif boss_timer > 0.85:
				_boss_retract()
		"reach_retract":
			beast.set_extension(maxf(0.0, beast.extension - delta * 2.2))
			beast.rotation = move_toward(beast.rotation, 0.0, delta * 0.4)
			if beast.extension <= 0.0:
				boss_phase = "idle"
				boss_timer = 0.0
		"throw_wind":
			if boss_timer > 0.85:
				beast.pose(beast.POSE_IDLE)
				_boss_throw(boss_attacks % 4 == 0)
				boss_phase = "idle"
				boss_timer = -0.4


func _boss_next() -> void:
	boss_attacks += 1
	boss_timer = 0.0
	if boss_attacks % 2 == 1:
		boss_phase = "reach_wind"
		boss_target = Vector2(PLAYER_X + 8.0, GROUND_Y - 44.0)
		beast.aim(boss_target)
		var warn := Warning.instantiate()
		warn.position = Vector2(PLAYER_X + 70.0, GROUND_Y - 110.0)
		add_child(warn)
		warnings.append({"node": warn, "left": 1.0, "y": 0.0, "low": false, "boss": true})
		sfx.play(&"warn")
		if _teach(&"reach"):
			hud.show_hint("手臂伸過來了！手到眼前時斬擊！", 2.2)
	else:
		boss_phase = "throw_wind"
		beast.pose(beast.POSE_THROW)
		if _teach(&"throw"):
			hud.show_hint("把巨石彈回去砸他的臉！", 2.2)


func _boss_retract() -> void:
	boss_phase = "reach_retract"
	boss_timer = 0.0


func _boss_throw(double: bool) -> void:
	var from: Vector2 = beast.hand_rock.global_position
	var heights := [ROCK_MID_Y, ROCK_LOW_Y] if double else [ROCK_MID_Y if rng.randf() < 0.6 else ROCK_LOW_Y]
	for i in heights.size():
		var target := Vector2(PLAYER_X, heights[i])
		var rock := Rock.instantiate()
		obstacles.add_child(rock)
		var vel := (target - from).normalized() * 470.0
		rock.setup(from, vel, rng.randi() % 3, heights[i] == ROCK_LOW_Y, 0.5 * i)
	sfx.play(&"rock")
	shake.add_trauma(0.2)


func _rock_hits_boss(_from: Vector2) -> void:
	if state != S.BOSS:
		return
	var face: Vector2 = beast.face.global_position
	fx.effect(&"explosion", face, Vector2.ONE * 90.0, 0.6, &"rock")
	fx.burst(face, &"rock", 16, 120.0)
	beast.flash()
	sfx.play(&"shatter")
	sfx.play(&"roar")
	shake.add_trauma(0.7)
	_finale()


func _cut_arm() -> void:
	var hand: Vector2 = beast.hand_position()
	kills += 1
	_success(500, true)
	fx.slash(hand, -0.5, 60.0, 2.2, &"steel", true)
	fx.burst(hand, &"blood", 22, 140.0)
	fx.burst(hand, &"steam", 12, 70.0)
	fx.caption(hand + Vector2(0, -30), "斬斷！", &"gold", 0.9)
	beast.flash(Color(2.5, 1.2, 1.2))
	sfx.play(&"kill")
	sfx.play(&"roar")
	shake.add_trauma(0.8)
	_boss_retract()
	_finale()


# ---------------------------------------------------------------- finale

func _finale() -> void:
	state = S.LEVI
	boss_phase = ""
	hud.set_running(false)
	hud.top.visible = true
	for w in warnings:
		w.node.queue_free()
	warnings.clear()
	for o in obstacles.get_children():
		if not o.has_method(&"front") and not o.parried:
			_shatter(o)
	time_control.hit_stop(0.3, true)
	haptics.buzz(2)
	hud.show_hint("", 0.0)
	await get_tree().create_timer(0.35).timeout
	hud.show_banner("兵長！！", "", 1.4)
	sfx.play(&"levi")
	create_tween().tween_property(self, "speed", 0.0, 1.4)
	create_tween().tween_property(player, "gait", 0.35, 1.4)
	create_tween().tween_property(beast, "rotation", 0.0, 0.3)
	beast.set_extension(0.0)
	levi.visible = true
	levi.position = Vector2(-40.0, 70.0)
	levi.rotation = 0.0
	levi_sprite.frame = 0
	var centre := Vector2(beast.position.x - 10.0, GROUND_Y - 150.0)
	await _levi_to(centre + Vector2(-110.0, -90.0), 0.42)
	for i in 18:
		levi_sprite.frame = 1 + i % 3
		var a := i * 1.05
		var spot := centre + Vector2(cos(a) * 92.0, sin(a) * 118.0)
		await _levi_to(spot, 0.075)
		fx.slash(spot, a + PI / 2.0, 44.0, 2.4, &"steel", true)
		fx.burst(spot.lerp(centre, 0.4), &"blood", 6, 80.0)
		if i % 3 == 0:
			fx.burst(spot, &"steam", 5, 50.0)
		beast.flash()
		sfx.play(&"spin", 0.0)
		shake.add_trauma(0.14, 0.5)
	var nape := Vector2(beast.position.x + 18.0, GROUND_Y - 245.0)
	levi_sprite.frame = 2
	await _levi_to(nape, 0.12)
	fx.slash(nape, -0.8, 80.0, 2.6, &"steel", true)
	fx.slash(nape, 0.6, 64.0, 2.2, &"gold", true)
	fx.ring(nape, 10.0, 150.0, &"steam", 0.6, 3)
	fx.effect(&"explosion", nape, Vector2.ONE * 130.0, 0.7, &"blood")
	fx.caption(nape + Vector2(-20, -30), "斬！！", &"gold", 1.2)
	hud.hurt_flash(Color(1, 1, 1))
	sfx.play(&"boss_down")
	sfx.play(&"kill")
	time_control.hit_stop(0.35, true)
	shake.add_trauma(1.0)
	haptics.buzz(2)
	beast.pose(beast.POSE_DOWN)
	var down := create_tween().set_parallel()
	down.tween_property(beast, "rotation", 0.2, 1.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	down.tween_property(beast, "position:y", GROUND_Y + 40.0, 2.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	down.tween_property(beast, "modulate", Color(0.6, 0.5, 0.5, 1.0), 2.0)
	for k in 3:
		var steam: Node2D = fx.effect(&"smoke", beast.position + Vector2(-70.0 + k * 70.0, 10.0), Vector2(90, 150), 3.5,
				&"steam", {}, Vector2(0.5, 1.0))
		if steam:
			steam.z_index = -6
	_steam_column()
	levi_sprite.frame = 4
	var land := create_tween()
	land.tween_property(levi, "position", Vector2(PLAYER_X + 78.0, GROUND_Y), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await land.finished
	fx.burst(levi.position, &"dust", 8, 50.0)
	await get_tree().create_timer(0.6).timeout
	fx.caption(levi.position + Vector2(0, -78), "嘖…生日快樂，團長。", &"steel", 2.6)
	await get_tree().create_timer(2.8).timeout
	_ending()


## Wisps of steam rising off the fallen boss while the ending plays out.
func _steam_column() -> void:
	while state == S.LEVI:
		var at := beast.position + Vector2(rng.randf_range(-90.0, 90.0), rng.randf_range(-120.0, -10.0))
		fx.particle(at, Vector2(rng.randf_range(-8, 8), -rng.randf_range(30, 60)), fx.tones(&"steam")[3], 1.2, 3)
		await get_tree().create_timer(0.05).timeout


func _levi_to(at: Vector2, seconds: float) -> void:
	var from := levi.position
	var tw := create_tween()
	tw.tween_property(levi, "position", at, seconds)
	await tw.finished
	for k in 4:
		fx.particle(from.lerp(at, k / 4.0), Vector2.ZERO, Color("#a3b4cc"), 0.18, 2)


func _ending() -> void:
	state = S.ENDING
	_save_best()
	sfx.play(&"victory")
	music.play(end_track)
	await screens.fade_to(1.0, 0.6)
	hud.set_running(false)
	hud.top.visible = false
	screens.show_ending(_stats())
	await screens.fade_to(0.0, 0.6)
	while state == S.ENDING:
		var at := Vector2(rng.randf_range(40.0, 600.0), rng.randf_range(20.0, 120.0))
		confetti.burst(at, [&"gold", &"wing", &"blood", &"steel"][rng.randi() % 4], 14, 80.0)
		confetti.star(at, &"gold")
		await get_tree().create_timer(0.35).timeout


func _game_over() -> void:
	state = S.OVER
	boss_phase = ""
	player.alive = false
	_save_best()
	sfx.play(&"fall")
	music.stop()
	create_tween().tween_property(self, "speed", 0.0, 1.0)
	var tw := create_tween().set_parallel()
	tw.tween_property(player, "rotation", -0.5, 0.5)
	tw.tween_property(player, "gait", 0.0, 0.8)
	beast.set_extension(0.0)
	await get_tree().create_timer(1.3).timeout
	sfx.play(&"over")
	hud.set_running(false)
	screens.show_over(_stats(), reached_boss)


func _stats() -> String:
	return "分數 %06d　最高 %06d\n討伐 %d　彈反 %d　完美 %d　最高連擊 %d" % [
		score(), maxi(best, score()), kills, parries, perfects, best_combo]


# ---------------------------------------------------------------- bot (tests, --bot)

func _bot_think() -> void:
	var px: float = player.position.x
	for o in obstacles.get_children():
		if o.is_queued_for_deletion():
			continue
		if o.has_method(&"front"):
			if not o.dead and o.front() - px < 100.0 and o.front() - px > -20.0:
				_slash()
				return
		elif not o.parried and o.visible and o.position.x - px < 64.0 and o.position.x - px > 0.0:
			_slash()
			return
	if boss_phase == "reach_thrust" and player.slash_zone().intersects(beast.hand_rect()):
		_slash()


# ---------------------------------------------------------------- save

func _load_best() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return 0
	return int(cfg.get_value("run", "best", 0))


func _save_best() -> void:
	best = maxi(best, score())
	var cfg := ConfigFile.new()
	cfg.set_value("run", "best", best)
	cfg.save(SAVE_PATH)
