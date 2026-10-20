extends Node3D
## One boss push: steps domain/push_sim.gd with game time, feeds the army, boss, zone tiles, bolts and HUD, and
## turns input into sim commands. On the field: tap a zone to select it, then its ◀ ▶ arrows move it to the other
## column; or drag from one zone to another. Fixed camera; it only punches in on 破防 and 大招 and shakes on big hits.

const PushSim = preload("res://domain/push_sim.gd")
const WARN := Color(1.0, 0.4, 0.35)
const GOOD := Color(0.55, 1.0, 0.6)
const GOLD := Color(1.0, 0.85, 0.3)
const VOLLEY_COLOR := Color(1.0, 0.9, 0.45)
const SKILL_COLOR := Color(0.6, 0.95, 1.0)
## Field picking: rays meet this height (mid-body), so a tap on a hero's sprite lands in the hero's own zone; a
## point in a gap or just outside goes to the nearest zone within PICK_SLACK metres.
const PICK_Y := 0.45
const PICK_SLACK := 0.9
## Arrows sit this far outside the selected zone's side edge.
const ARROW_OUT := 0.45

@onready var _army: MultiMeshInstance3D = %Army
@onready var _boss: Node3D = %Boss
@onready var _bolts: MultiMeshInstance3D = %Bolts
@onready var _hud: CanvasLayer = %Hud
@onready var _camera: Camera3D = %Camera
@onready var _zones: Node3D = %Zones

var sim: PushSim
var selected: int = 3
var _tiles: Array = []
var _drag_from: int = -1
var _hover: int = -1
var _base_fov: float
var _punch: float = 0.0
var _trauma: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	_base_fov = _camera.fov
	for tile: Node in _zones.get_children():
		_tiles.append(tile)
	_tiles.sort_custom(func(a: Node, b: Node) -> bool: return a.zone_index < b.zone_index)
	_hud.arrow_pressed.connect(_arrow)
	_hud.regroup_pressed.connect(func() -> void: sim.regroup())
	_hud.volley_pressed.connect(func() -> void: sim.volley())
	_hud.weak_point_pressed.connect(func() -> void: sim.tap_weak_point())
	_hud.skip_pressed.connect(func() -> void: sim.skip_muster())
	_hud.retry_pressed.connect(new_push)
	_army.fired.connect(_bolts.fire)
	new_push()


func new_push() -> void:
	sim = PushSim.new(randi())
	for tile: Node in _tiles:
		sim.set_zone(tile.zone_index, tile.ground_center(), tile.half_size())
	sim.event.connect(_on_event)
	_army.setup(sim, _boss_target())
	_boss.reset()
	_bolts.clear()
	_hud.hide_result()
	selected = 3
	_hud.banner("集結！", GOLD, 1.6)


func _process(delta: float) -> void:
	_time += delta
	sim.step(delta)
	_army.step(delta)
	_boss.step(sim, delta)
	_bolts.step(delta)
	_hud.show_state(sim, selected, delta)
	var warn_progress: float = 1.0 - sim.tele_t / PushSim.TELE_WARN
	var pulse: float = 0.5 + 0.5 * sin(_time * 20.0)
	for tile: Node in _tiles:
		var z: int = tile.zone_index
		var warned: bool = sim.tele_t > 0.0 and z in sim.tele_zones
		tile.show_state(PushSim.ZONE_NAMES[z], sim.living_in(z), z == selected,
			z == _hover and _drag_from >= 0, maxf(warn_progress, 0.02) if warned else 0.0, pulse)
	_place_arrows()
	var weak_open: bool = sim.weak_t > 0.0 and sim.fighting()
	_hud.place_weak_point(_camera.unproject_position(_boss.weak_point()), weak_open)
	_punch = maxf(_punch - delta * 1.5, 0.0)
	_trauma = maxf(_trauma - delta * 1.8, 0.0)
	_camera.fov = _base_fov - 5.0 * sin(minf(_punch, 1.0) * PI * 0.5)
	var shake: float = _trauma * _trauma
	_camera.h_offset = sin(_time * 53.0) * 0.2 * shake
	_camera.v_offset = sin(_time * 41.0 + 1.3) * 0.16 * shake


## Field input (the HUD's buttons take their own presses first): tap selects a zone, a drag moves it.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var z: int = _zone_under(event.position)
		if event.pressed:
			_drag_from = z
			_hover = z
		else:
			if _drag_from >= 0 and z >= 0 and z != _drag_from:
				if sim.move_zone(_drag_from, z):
					selected = z
			elif z >= 0:
				selected = z
			_drag_from = -1
			_hover = -1
	elif event is InputEventMouseMotion and _drag_from >= 0:
		_hover = _zone_under(event.position)


func _zone_under(screen: Vector2) -> int:
	var origin: Vector3 = _camera.project_ray_origin(screen)
	var dir: Vector3 = _camera.project_ray_normal(screen)
	if dir.y >= -0.001:
		return -1
	var hit: Vector3 = origin + dir * ((PICK_Y - origin.y) / dir.y)
	return sim.zone_near(Vector2(hit.x, hit.z), PICK_SLACK)


## The zone in the other column of the same row: -1 = to the left (遠), +1 = to the right (近).
func _neighbour(z: int, side: int) -> int:
	var col: int = z % 2
	if (side < 0 and col == 0) or (side > 0 and col == PushSim.NEAR):
		return -1
	return z + side


func _arrow(side: int) -> void:
	var to: int = _neighbour(selected, side)
	if to >= 0 and sim.move_zone(selected, to):
		selected = to


func _place_arrows() -> void:
	var shown: bool = sim.fighting() and selected >= 0 and sim.living_in(selected) > 0
	for side: int in [-1, 1]:
		var to: int = _neighbour(selected, side) if shown else -1
		var c: Vector2 = sim.zone_center[maxi(selected, 0)]
		var edge := Vector3(c.x + side * (sim.zone_half[maxi(selected, 0)].x + ARROW_OUT), PICK_Y, c.y)
		_hud.place_arrow(side, _camera.unproject_position(edge), to >= 0)


func _boss_target() -> Vector3:
	return _boss.global_position + Vector3(0.0, 1.6, 0.0)


func _on_event(kind: StringName, value: float) -> void:
	match kind:
		&"fight":
			_say("推王開始！", GOLD, 1.0)
		&"tele_warn":
			_hud.banner("%s！ 移開紅區！" % PushSim.ATTACK_NAMES[sim.tele_kind], WARN, value)
		&"tele_hit":
			_trauma = minf(_trauma + 0.6, 1.0)
			_boss.hit(0.3)
			if value > 0.0:
				_say("陣亡 %d 人" % int(value), WARN, 1.2)
			elif sim.tele_hit_count > 0:
				_say("%d 人受重傷" % sim.tele_hit_count, WARN, 1.2)
			else:
				_say("閃過了！", GOOD, 1.0)
		&"auto":
			_boss.swing()
		&"phase2":
			_punch = 1.0
			_trauma = 0.8
			_say("第二階段！ 王發狂了", WARN, 1.8)
		&"weak_open":
			_say("弱點露出！ 點它！", GOLD, 1.2)
		&"weak_hit":
			_boss.hit(0.8)
			_say("弱點命中！ 破防 %d%%" % roundi(value * 100.0), GOLD, 1.0)
		&"break":
			_punch = 1.0
			_trauma = minf(_trauma + 0.4, 1.0)
			_say("破防！ 全軍傷害提高！", GOLD, 1.6)
		&"skill":
			var i: int = int(value)
			if sim.cls[i] in [PushSim.SWORD, PushSim.SPEAR, PushSim.BOW, PushSim.MAGE]:
				for k: int in 3:
					var spread := Vector3(randf_range(-0.5, 0.5), randf_range(-0.4, 0.6), 0.0)
					_bolts.fire(_army.hand(i), _boss_target() + spread, SKILL_COLOR, k * 0.08)
				_boss.hit(0.25)
		&"revive":
			_say("復活！", GOOD, 1.0)
		&"volley":
			_volley(value)
		&"won":
			_punch = 1.0
			_trauma = 1.0
			_hud.show_result(true, "剩 %.1f 秒　存活 %d 人" % [value, sim.living()])
		&"lost":
			var why: String = "全軍覆沒" if sim.living() == 0 else "時間到"
			_hud.show_result(false, "%s　王還剩 %d%% 血" % [why, ceili(value * 100.0)])


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
	_punch = 1.0
	_trauma = 1.0
	_say("大招！ %d" % roundi(amount), GOLD, 1.4)
