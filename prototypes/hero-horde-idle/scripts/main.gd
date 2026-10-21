extends Node3D
## One boss push: steps domain/push_sim.gd with game time, feeds the army, boss, squad flags, telegraph marks, bolts
## and HUD, and turns input into sim commands. On the field: tap a squad (or its flag) to select it, then tap the
## ground to send it there; or drag a squad's flag to where it should stand. The part buttons on the boss aim the
## ranged squad. The camera (camera_director.gd) rests on the gameplay framing and only
## makes short moves on 大招, 破防, 第二階段 and the win, never while someone stands in a telegraph. Big hits freeze
## game time for a few frames (hit stop) and shake the camera. The stage (stage.gd) lights the sprites. Every sim
## event also gets its pixel effect (impact_fx.gd), sound (sfx.gd) and phone buzz (godot-kit haptics, on game time).

const PushSim = preload("res://domain/push_sim.gd")
const Haptics = preload("res://addons/proto_kit/haptics.gd")
const PushReport = preload("res://domain/push_report.gd")
const WARN := Color(1.0, 0.4, 0.35)
const GOOD := Color(0.55, 1.0, 0.6)
const GOLD := Color(1.0, 0.85, 0.3)
const VOLLEY_COLOR := Color(1.0, 0.9, 0.45)
const SKILL_COLOR := Color(0.6, 0.95, 1.0)
## Field picking: rays meet this height (mid-body), so a tap on a hero's sprite lands near the hero's feet; a tap
## within PICK_SLACK metres of a squad's block or flag picks that squad.
const PICK_Y := 0.45
const PICK_SLACK := 0.6
## A press that travels this far on the ground before release is a drag.
const DRAG_MIN := 0.35
## A tap within this many viewport pixels of a part's anchor aims at that part (the part buttons are small so they do
## not hide him; the body around them is the bigger target). It wins over a squad behind it on screen.
const PART_PICK := 56.0
## Game time runs this fast during a hit stop.
const HIT_STOP_SCALE := 0.05
const TELE_HIT_STOP := 0.07
## 落石 rocks appear this long before they land.
const ROCK_FALL := 0.45
## What breaking each part takes away, for the banner (PushSim.Part order).
const PART_EFFECTS := ["動作變慢", "不能橫掃", "不能落石"]

@export var volley_shot: CameraShot
@export var break_shot: CameraShot
@export var phase2_shot: CameraShot
@export var won_shot: CameraShot

@onready var _army: MultiMeshInstance3D = %Army
@onready var _boss: Node3D = %Boss
@onready var _bolts: MultiMeshInstance3D = %Bolts
@onready var _hud: CanvasLayer = %Hud
@onready var _camera: Camera3D = %Camera
@onready var _flags: Node3D = %Flags
@onready var _markers: Node3D = %TeleMarkers
@onready var _stage: Node3D = %Stage
@onready var _fx: Node3D = %ImpactFx
@onready var _sfx: Node = %Sfx

var sim: PushSim
var selected: int = PushSim.MELEE
var _flag_nodes: Array = []
## The squad under the press, where it started, and the ground point under the finger once it is a drag (INF = not
## dragging).
var _press_squad: int = -1
var _press_at := Vector2.INF
var _drag_at := Vector2.INF
## The boss part under the press (-1 = none).
var _press_part: int = -1
var _time: float = 0.0
var _hit_stop: float = 0.0
## Whether this telegraph's falling rocks are already in the air.
var _rocks_dropped: bool = false
var haptics := Haptics.new()
var _names: PackedStringArray = PushReport.load_names()


func _ready() -> void:
	_army.lighting = _stage.sprite_light
	haptics.clock = func() -> int: return int(_time * 1000.0)
	for sig: StringName in [&"part_pressed", &"regroup_pressed", &"volley_pressed",
			&"skip_pressed", &"retry_pressed"]:
		_hud.connect(sig, func(_a: Variant = null) -> void: _sfx.play(&"tap"))
	_boss.lighting = _stage.sprite_light
	for flag: Node in _flags.get_children():
		_flag_nodes.append(flag)
	_flag_nodes.sort_custom(func(a: Node, b: Node) -> bool: return a.squad_index < b.squad_index)
	_hud.part_pressed.connect(func(p: int) -> void: sim.aim_at(p))
	_hud.regroup_pressed.connect(func() -> void: sim.regroup())
	_hud.volley_pressed.connect(func() -> void: sim.volley())
	_hud.skip_pressed.connect(func() -> void: sim.skip_muster())
	_hud.retry_pressed.connect(new_push)
	_army.fired.connect(_bolts.fire)
	_army.fell.connect(func(at: Vector3) -> void: _fx.burst(at + Vector3(0.0, 0.05, 0.0), 5, &"dust", 1.2, 1.2, 2, 0.5))
	new_push()


func new_push() -> void:
	sim = PushSim.new(randi())
	for flag: Node in _flag_nodes:
		sim.set_home(flag.squad_index, flag.home)
	sim.event.connect(_on_event)
	_army.setup(sim, _boss_target())
	_boss.reset()
	_bolts.clear()
	_stage.reset()
	_fx.clear()
	_camera.reset()
	_hit_stop = 0.0
	_hud.hide_result()
	selected = PushSim.MELEE
	_press_squad = -1
	_drag_at = Vector2.INF
	_hud.banner("集結！", GOLD, 1.6)


func _process(delta: float) -> void:
	_time += delta
	var dt: float = delta
	if _hit_stop > 0.0:
		_hit_stop -= delta
		dt = delta * HIT_STOP_SCALE
	sim.step(dt)
	_army.step(dt)
	_boss.step(sim, dt)
	_bolts.step(dt)
	_stage.step(sim, dt)
	if sim.tele_kind == PushSim.Attack.ROCKS and sim.tele_t > 0.0 and sim.tele_t <= ROCK_FALL and not _rocks_dropped:
		_rocks_dropped = true
		for shape: Dictionary in sim.tele_shapes:
			_fx.drop(_ground3(shape.c), 6, &"rock", sim.tele_t, 7.0, shape.r * 0.7, 13)
	_fx.step(dt)
	_hud.show_state(sim, selected, delta)
	var warn_progress: float = clampf(1.0 - sim.tele_t / PushSim.TELE_WARN, 0.02, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(_time * 20.0)
	var markers: Array[Node] = _markers.get_children()
	for k: int in markers.size():
		if sim.tele_t > 0.0 and k < sim.tele_shapes.size():
			markers[k].show_shape(sim.tele_shapes[k], warn_progress, pulse)
		else:
			markers[k].off()
	for flag: Node in _flag_nodes:
		var s: int = flag.squad_index
		var dragged: bool = s == _press_squad and _drag_at != Vector2.INF
		flag.show_state(_drag_at if dragged else sim.flag[s], PushSim.SQUAD_NAMES[s], sim.squad_living(s),
			sim.squad_center(s), sim.block_half(s), s == selected and sim.fighting(), dragged, sim.squad_threatened(s) > 0)
	var points: Array = []
	for p: int in PushSim.PART_NAMES.size():
		points.append(_camera.unproject_position(_boss.part_point(p)))
	_hud.place_parts(sim, points, sim.fighting())


## Field input (the HUD's buttons take their own presses first): press on a squad and drag to move its flag; tap a
## squad to select it; tap a part of the boss to aim at it; tap open ground to send the selected squad there.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = _ground(event.position)
		if event.pressed:
			_press_part = _part_under(event.position)
			_press_squad = _squad_under(p) if _press_part < 0 else -1
			_press_at = p
			_drag_at = Vector2.INF
			return
		if _press_part >= 0:
			sim.aim_at(_press_part)
			_press_part = -1
			return
		if _press_squad >= 0 and _drag_at != Vector2.INF:
			if sim.move_flag(_press_squad, _drag_at):
				selected = _press_squad
		elif _press_squad >= 0:
			selected = _press_squad
		elif selected >= 0 and p != Vector2.INF:
			sim.move_flag(selected, p)
		_press_squad = -1
		_drag_at = Vector2.INF
	elif event is InputEventMouseMotion and _press_squad >= 0:
		var p: Vector2 = _ground(event.position)
		if p != Vector2.INF and (_drag_at != Vector2.INF or p.distance_to(_press_at) >= DRAG_MIN):
			_drag_at = p.clamp(PushSim.FIELD_MIN, PushSim.FIELD_MAX)


## The ground point (at PICK_Y) under a screen point; INF when the ray misses.
func _ground(screen: Vector2) -> Vector2:
	var origin: Vector3 = _camera.project_ray_origin(screen)
	var dir: Vector3 = _camera.project_ray_normal(screen)
	if dir.y >= -0.001:
		return Vector2.INF
	var hit: Vector3 = origin + dir * ((PICK_Y - origin.y) / dir.y)
	return Vector2(hit.x, hit.z)


## The unbroken boss part whose anchor is nearest the viewport point, within PART_PICK; -1 if none.
func _part_under(screen: Vector2) -> int:
	if not sim.fighting():
		return -1
	var best: int = -1
	var best_d: float = PART_PICK
	for p: int in PushSim.PART_NAMES.size():
		if sim.broken(p):
			continue
		var d: float = screen.distance_to(_camera.unproject_position(_boss.part_point(p)))
		if d <= best_d:
			best_d = d
			best = p
	return best


## The squad whose block or flag is nearest to ground point p, within PICK_SLACK; -1 if none.
func _squad_under(p: Vector2) -> int:
	if p == Vector2.INF or not sim.fighting():
		return -1
	var best: int = -1
	var best_d: float = PICK_SLACK
	for s: int in PushSim.SQUADS:
		if sim.squad_living(s) == 0:
			continue
		var gap: Vector2 = ((p - sim.squad_center(s)).abs() - sim.block_half(s)).max(Vector2.ZERO)
		var d: float = minf(gap.length(), p.distance_to(sim.flag[s]))
		if d <= best_d:
			best_d = d
			best = s
	return best


func _boss_target() -> Vector3:
	return _boss.global_position + Vector3(0.0, 1.6, 0.0)


func _on_event(kind: StringName, value: float) -> void:
	match kind:
		&"fight":
			_say("推王開始！", GOLD, 1.0)
		&"tele_warn":
			_camera.release()
			_rocks_dropped = false
			_sfx.play(&"warn")
			haptics.buzz(0)
			_hud.banner("%s！ 把旗子拖出紅圈！" % PushSim.ATTACK_NAMES[sim.tele_kind], WARN, value)
		&"tele_hit":
			_camera.add_trauma(0.6)
			_hit_stop = maxf(_hit_stop, TELE_HIT_STOP)
			_boss.hit(0.3)
			_boss.slam()
			_tele_impact()
			if value > 0.0:
				_say("陣亡 %d 人" % int(value), WARN, 1.2)
			elif sim.tele_hit_count > 0:
				_say("%d 人受重傷" % sim.tele_hit_count, WARN, 1.2)
			else:
				_say("閃過了！", GOOD, 1.0)
		&"tele_cancel":
			_say("王倒地！ 預警取消", GOOD, 1.2)
		&"part_break":
			var part: int = int(value)
			var at_part: Vector3 = _boss.part_point(part)
			_shot(break_shot, at_part)
			_boss.hit(1.0)
			_fx.burst(at_part, 30, &"steel", 3.5, 3.5, 4, 0.9)
			_fx.ring(_boss.global_position, 3.4, &"cyan", 0.5)
			_sfx.play(&"break")
			haptics.buzz(2)
			_say("打壞%s！ 王倒地，%s" % [PushSim.PART_NAMES[part], PART_EFFECTS[part]], GOLD, 2.0)
		&"auto":
			_boss.swing()
			if sim.auto_target >= 0:
				var at: Vector3 = _ground3(sim.pos[sim.auto_target])
				_fx.ring(at, 1.1, &"dust", 0.3)
				_fx.burst(at + Vector3(0.0, 0.1, 0.0), 6, &"dust", 1.5, 2.0, 2, 0.45)
			_sfx.play(&"thud")
		&"fallen":
			_sfx.play(&"fall", 0.1)
		&"move", &"regroup":
			_sfx.play(&"move")
		&"phase2":
			_shot(phase2_shot, _boss_target())
			_fx.ring(_boss.global_position, 4.5, &"slam", 0.8)
			_fx.burst(_boss.global_position + Vector3(0.0, 0.2, 0.0), 30, &"rock", 4.5, 4.0, 4)
			_sfx.play(&"phase2")
			haptics.buzz(2)
			_say("第二階段！ 王發狂了", WARN, 1.8)
		&"aim":
			_sfx.play(&"aim")
			haptics.buzz(0)
		&"skill":
			var i: int = int(value)
			if sim.cls[i] in [PushSim.SWORD, PushSim.SPEAR, PushSim.BOW, PushSim.MAGE]:
				for k: int in 3:
					var spread := Vector3(randf_range(-0.5, 0.5), randf_range(-0.4, 0.6), 0.0)
					_bolts.fire(_army.hand(i), _boss_target() + spread, SKILL_COLOR, k * 0.08)
				_boss.hit(0.25)
				_fx.burst(_boss_target(), 5, &"gold" if sim.rarity[i] == 3 else &"cyan", 2.0, 1.5, 2, 0.4)
			_sfx.play(&"skill", 0.08)
		&"revive":
			_sfx.play(&"revive")
			_say("復活！", GOOD, 1.0)
		&"volley":
			_volley(value)
		&"won":
			_hit_stop = 0.0
			_camera.play(won_shot, _boss_target())
			_fx.burst(_boss_target(), 50, &"gold", 4.0, 5.0, 3, 1.4)
			_sfx.play(&"won")
			haptics.buzz(2)
			_show_result(true, "剩 %.1f 秒　存活 %d 人" % [value, sim.living()])
		&"lost":
			_sfx.play(&"lost")
			var why: String = "全軍覆沒" if sim.living() == 0 else "時間到"
			_show_result(false, "%s　王還剩 %d%% 血" % [why, ceili(value * 100.0)])


## A banner that never covers an unanswered telegraph (someone still stands in red): that cue decides who dies.
func _say(text: String, color: Color, seconds: float) -> void:
	if sim.tele_threatens():
		return
	_hud.banner(text, color, seconds)


func _volley(amount: float) -> void:
	_army.volley()
	for i: int in sim.cls.size():
		if sim.alive(i):
			var spread := Vector3(randf_range(-0.6, 0.6), randf_range(-0.5, 0.8), randf_range(-0.4, 0.4))
			_bolts.fire(_army.hand(i), _boss_target() + spread, VOLLEY_COLOR, randf() * 0.3)
	_boss.hit(1.0)
	_stage.flash_volley(_army_center() + Vector3(0.0, 1.5, 0.0))
	_fx.ring(_boss.global_position, 3.6, &"gold", 0.6)
	_fx.burst(_boss_target(), 40, &"gold", 4.0, 4.0, 3, 0.9)
	_sfx.play(&"volley")
	haptics.buzz(2)
	_shot(volley_shot, _boss_target())
	_say("大招！ %d" % roundi(amount), GOLD, 1.4)


## A cinematic move, unless it would take the field away from someone who must step out of red.
func _shot(shot: CameraShot, focus: Vector3) -> void:
	if sim.tele_threatens():
		return
	_hit_stop = maxf(_hit_stop, _camera.play(shot, focus))


func _army_center() -> Vector3:
	var sum := Vector2.ZERO
	var n: int = 0
	for i: int in sim.cls.size():
		if sim.alive(i):
			sum += sim.pos[i]
			n += 1
	var c: Vector2 = sum / maxf(n, 1)
	return Vector3(c.x, 0.0, c.y)


## A telegraphed attack lands: a shockwave and thrown rocks in every shape, louder when it caught people.
func _tele_impact() -> void:
	for shape: Dictionary in sim.tele_shapes:
		var at: Vector3 = _ground3(PushSim.shape_center(shape))
		if shape.kind == &"band":
			_fx.sweep(Vector3(shape.x + 0.6, 0.0, PushSim.FIELD_MIN.y), Vector3(shape.x + 0.6, 0.0, PushSim.FIELD_MAX.y),
				60, &"slam", Vector3(-6.0, 0.0, 0.0))
			continue
		_fx.ring(at, shape.r * 1.1, &"slam", 0.5)
		_fx.burst(at + Vector3(0.0, 0.1, 0.0), 16, &"rock", 3.0, 4.0, 4, 0.8)
		_fx.burst(at + Vector3(0.0, 0.1, 0.0), 10, &"dust", 2.0, 1.5, 3, 0.6)
	_sfx.play(&"slam")
	haptics.buzz(2 if sim.tele_hit_count > 0 else 1)


func _ground3(p: Vector2) -> Vector3:
	return Vector3(p.x, 0.0, p.y)


func _show_result(won: bool, detail: String) -> void:
	var report: Dictionary = PushReport.build(sim, _names)
	_hud.show_result(won, detail, report, sim.cls[report.mvp])
