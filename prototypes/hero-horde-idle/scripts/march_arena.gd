extends Node2D
## The 行軍 strip on top of every page (scenes/march_arena.tscn): plays domain/march_sim.gd with the player's march
## squad and draws it. The home screen moves this one node into the shown page's BattleSocket (the ground line), so
## switching pages never restarts a fight; bind_scenery() makes that page's landscape layers scroll while the squad
## marches on between 段 (Taskbar Hero's battle_parallax shader: far layers slower).
## A kill is paid at once (progression.gd march_kill) and reported with `killed`; a fall steps the march back a stage
## (march_lost) and starts again after RECOVER_TIME. restart() picks up a changed squad, stage or growth.

signal killed(got: Dictionary)
signal logged(text: String)

const MarchSim = preload("res://domain/march_sim.gd")
const Stages = preload("res://domain/stages.gd")
const Army = preload("res://scripts/army.gd")
const Portraits = preload("res://scripts/portraits.gd")
const PARALLAX := preload("res://shaders/battle_parallax.gdshader")

## The front hero stands at FRONT_X, the rest SPACING apart behind it in their lane order; monsters keep their lane
## distance from the front (PX pixels per lane unit).
const FRONT_X := 470.0
const SPACING := 105.0
const PX := 90.0
const RECOVER_TIME := 2.0
const WALK_PX := 260.0
## Monsters by region; the 段's big one wears the second look, larger.
const LOOKS := [["SlimeVisual", "MushroomVisual"], ["AquaVisual", "FoxVisual"], ["MushroomVisual", "SoldierVisual"]]
const ELITE_SCALE := 1.35
const RUN := [0, 1, 2, 3]
const ATTACK := [4, 5, 6]
const READY := 4
const DOWN := 7
const CAST := 8
const GOLD := Color("f2cd5c")
const HURT := Color("ff8a7a")
const HEAL := Color("8fe388")

var progress: RefCounted = null
var sim: MarchSim = null
var running: bool = true
## The squad grew (levels, gear, talents): the next 段 starts with the new numbers.
var pending: bool = false
var travel_pixels: float = 0.0
var _recover_t: float = 0.0
var _scenery: Array = []
var _t: float = 0.0

@onready var _heroes: Node2D = %Heroes
@onready var _enemies: Node2D = %Enemies
@onready var _wave_label: Label = %WaveLabel


## Starts marching with `p` (progression.gd).
func start(p: RefCounted) -> void:
	progress = p
	restart()


## A new march with the squad and stage as they are now.
func restart() -> void:
	if progress == null:
		return
	sim = MarchSim.new(randi(), progress.march_units(), progress.march_stage, progress.cooldown_mult())
	_recover_t = 0.0
	pending = false
	for k: int in _heroes.get_child_count():
		var unit: Node2D = _heroes.get_child(k)
		unit.visible = k < sim.hero.size()
		if unit.visible:
			unit.set_appearance("Hero")
			unit.position = Vector2(_hero_x(k), 0.0)
			unit.modulate = Color.WHITE
	_label()


## The page's landscape layers scroll with the march (Taskbar Hero battle_parallax).
func bind_scenery(page: Node) -> void:
	_scenery.clear()
	for node: Node in page.get_children():
		if not node is TextureRect:
			continue
		var n: String = node.name
		if not (n == "DistantLandscape" or n == "Ground" or n.begins_with("LowerLandscape") or n.begins_with("LowerPatch")):
			continue
		var rect := node as TextureRect
		var atlas := rect.texture as AtlasTexture
		if atlas == null or atlas.atlas == null:
			continue
		var mat := ShaderMaterial.new()
		mat.shader = PARALLAX
		var total: Vector2 = atlas.atlas.get_size()
		mat.set_shader_parameter("region_uv", Vector4(atlas.region.position.x / total.x, atlas.region.position.y / total.y,
			atlas.region.size.x / total.x, atlas.region.size.y / total.y))
		mat.set_shader_parameter("region_width", atlas.region.size.x)
		var depth: float = 0.12 if n == "DistantLandscape" else (1.0 if n == "Ground" else 0.65)
		mat.set_shader_parameter("depth_far", depth)
		mat.set_shader_parameter("depth_near", depth)
		mat.set_shader_parameter("travel_pixels", travel_pixels)
		rect.material = mat
		_scenery.append(mat)


func _process(delta: float) -> void:
	if running and sim != null:
		step(delta)


## A frame never advances the march more than this (the first frame back from the background can be minutes long;
## that time is paid offline instead).
const MAX_STEP := 0.25


## Advances the march by dt (tests call it directly).
func step(dt: float) -> void:
	dt = minf(dt, MAX_STEP)
	_t += dt
	if _recover_t > 0.0:
		_recover_t -= dt
		if _recover_t <= 0.0:
			restart()
		return
	sim.step(dt)
	for e: Dictionary in sim.take_events():
		_on_event(e)
	if sim.walking():
		travel_pixels += WALK_PX * dt
		for mat: ShaderMaterial in _scenery:
			mat.set_shader_parameter("travel_pixels", travel_pixels)
	_draw_heroes()
	_draw_enemies()


func _on_event(e: Dictionary) -> void:
	match e.kind:
		&"hit":
			_enemy_node(e.enemy).pop("%d" % roundi(e.amount), Color("fff2b3") if e.crit else Color.WHITE)
		&"enemy_hit":
			_heroes.get_child(e.hero).pop("-%d" % roundi(e.amount), HURT)
		&"heal":
			_heroes.get_child(e.target).pop("+%d" % roundi(e.amount), HEAL)
		&"kill":
			var got: Dictionary = progress.march_kill(e.stage, e.elite)
			_heroes.get_child(0).pop("+%d 金幣" % got.gold, GOLD)
			killed.emit(got)
		&"wave":
			_label()
			if e.wave == MarchSim.WAVES - 1:
				logged.emit("%s：強敵出現" % Stages.label(sim.stage))
		&"travel":
			logged.emit("%s：清除一段，繼續前進" % Stages.label(sim.stage))
			if pending:
				_restart_walking()
		&"lost":
			var from: int = sim.stage
			progress.march_lost()
			logged.emit("小隊在 %s 倒下，退回 %s 休整" % [Stages.label(from), Stages.label(progress.march_stage)])
			_recover_t = RECOVER_TIME


## A new march with the new numbers, picked up while the squad walks on (the walk carries over).
func _restart_walking() -> void:
	restart()
	sim.travel_t = MarchSim.TRAVEL_TIME


## Hero k's place: FRONT_X less SPACING per hero standing ahead of them.
func _hero_x(k: int) -> float:
	var ahead: int = 0
	for j: int in sim.hx.size():
		if sim.hx[j] > sim.hx[k] or (sim.hx[j] == sim.hx[k] and j < k):
			ahead += 1
	return FRONT_X - SPACING * ahead


func _front_hx() -> float:
	var best: float = -INF
	for x: float in sim.hx:
		best = maxf(best, x)
	return best


func _enemy_node(k: int) -> Node2D:
	return _enemies.get_child(mini(k, _enemies.get_child_count() - 1))


func _label() -> void:
	if sim == null:
		return
	var s: int = sim.stage
	_wave_label.text = "%s %s　行軍中" % [Stages.label(s), Stages.REGIONS[Stages.region(s)].name]


func _draw_heroes() -> void:
	for k: int in sim.hero.size():
		var unit: Node2D = _heroes.get_child(k)
		var row: int = Portraits.row_of(sim.form[k], sim.cls[k])
		var cell: int = READY
		if not sim.alive(k):
			cell = DOWN
			unit.modulate = Color(0.45, 0.45, 0.5)
		elif sim.walking():
			cell = RUN[int(_t * 9.0 + k * 1.7) % RUN.size()]
		elif sim.cast_at[k] >= 0.0 and sim.t - sim.cast_at[k] < 0.45:
			cell = CAST
		elif sim.hit_at[k] >= 0.0 and sim.t - sim.hit_at[k] < 0.36:
			cell = ATTACK[mini(int((sim.t - sim.hit_at[k]) / 0.12), 2)]
		if sim.alive(k):
			unit.modulate = Color.WHITE
		unit.set_hero_cell(row, cell, Army.tint(sim.hero[k], sim.cls[k]).lerp(Color.WHITE, 0.5))
		unit.set_health(sim.hp[k] / sim.max_hp[k])


func _draw_enemies() -> void:
	var looks: Array = LOOKS[Stages.region(sim.stage)]
	for k: int in _enemies.get_child_count():
		var unit: Node2D = _enemies.get_child(k)
		unit.visible = k < sim.ex.size() and sim.ehp[k] > 0.0
		if not unit.visible:
			continue
		var elite: bool = sim.elite[k] == 1
		var look: String = looks[1] if elite else looks[0]
		if unit.appearance != look:
			unit.set_appearance(look)
		unit.scale = Vector2.ONE * (ELITE_SCALE if elite else 1.0)
		var bob: float = 0.0 if sim.ehit_at[k] < 0.0 or sim.t - sim.ehit_at[k] > 0.2 else -10.0
		unit.position = Vector2(FRONT_X + (sim.ex[k] - _front_hx()) * PX + bob, 0.0)
		unit.set_health(sim.ehp[k] / sim.emax[k])
