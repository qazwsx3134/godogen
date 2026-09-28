extends Node2D
## Owns battle phases; changing UI page never restarts a wave.
signal wave_changed(stage: String, wave: int, phase: String)
const WAVES_PER_STAGE := 3
const ADVANCE_SECONDS := 1.15
const PARALLAX := preload("res://shaders/battle_parallax.gdshader")
@export var auto_simulate: bool = true
var wave: int = 1
var phase: String = "combat"
var advance_elapsed: float = 0.0
var travel_pixels: float = 0.0
var near_distance: float = 0.0
var far_distance: float = 0.0
var cleared_waves: int = 0
var world_offset: float = 0.0
var _units: Array[CombatUnit] = []
var _home: Dictionary = {}
var _march_from: Dictionary = {}
var _scenery_materials: Dictionary = {}
var _last_page: Node
var _practice: bool = false
@onready var game: Node = get_node("/root/Game")
@onready var wave_label: Label = %WaveLabel

func _ready() -> void:
	for child: Node in get_children():
		if child is CombatUnit:
			_units.append(child)
			child.arena_token = get_instance_id()
			_home[child.unit_data.unit_id] = child.position
			child.set_physics_process(false)
	if game.has_signal("changed"):
		game.changed.connect(sync_party)
	sync_party()
	_start_wave()

func live_units() -> Array[CombatUnit]:
	return _units

func find_unit(id: String) -> CombatUnit:
	for unit: CombatUnit in _units:
		if unit.unit_data.unit_id == id:
			return unit
	return null

func sync_party() -> void:
	if not game.has_method("hero_info"):
		return
	for unit: CombatUnit in _units:
		var id: String = unit.unit_data.unit_id
		if id == "knight":
			unit.apply_stats(game.hero_info().stats)
		elif unit.faction == "hero":
			var was_active := unit.active
			unit.set_active(id in game.deployed)
			unit.apply_stats(game.monster_info(id).stats)
			if phase == "advance" and unit.active and not was_active:
				# Joining during travel must enter the same march as the current party.
				var destination: Vector2 = _home[id] + Vector2(cleared_waves*941.0,0)
				_march_from[unit] = _home[id] + Vector2(world_offset,0)
				unit.position = (_march_from[unit] as Vector2).lerp(destination,advance_elapsed/ADVANCE_SECONDS)

func set_training_mode(value: bool) -> void:
	_practice = value
	for unit: CombatUnit in _units:
		if unit.faction == "enemy":
			unit.set_appearance("DummyVisual" if value else ("SoldierVisual" if wave == 2 else "SlimeVisual"))

func _physics_process(delta: float) -> void:
	if auto_simulate:
		simulate_step(delta)

func simulate_step(delta: float) -> void:
	if delta <= 0.0 or game.combat_paused:
		return
	_bind_scenery()
	if phase == "advance":
		advance_elapsed = minf(advance_elapsed+delta,ADVANCE_SECONDS)
		var ratio := advance_elapsed/ADVANCE_SECONDS
		for unit: CombatUnit in _units:
			if unit.faction == "hero" and unit.active:
				# Actors advance in world space while the camera tracks the next encounter.
				var destination: Vector2 = _home[unit.unit_data.unit_id] + Vector2(cleared_waves*941.0,0)
				unit.position = (_march_from[unit] as Vector2).lerp(destination,ratio)
				unit.get_node("Visuals").position.y = sin(ratio*TAU*7.0)*2.0
		position.x = -lerpf(world_offset,cleared_waves*941.0,ratio)
		wave_label.position.x = 20.0 - position.x
		travel_pixels = lerpf(world_offset,cleared_waves*941.0,ratio)
		near_distance = travel_pixels
		far_distance = travel_pixels*0.12
		_apply_parallax()
		if advance_elapsed >= ADVANCE_SECONDS:
			world_offset = cleared_waves*941.0
			wave += 1
			if wave > WAVES_PER_STAGE:
				wave = 1
				var parts: PackedStringArray = str(game.current_stage).split("-")
				var next := int(parts[1])+1
				game.current_stage = "99-99" if int(parts[0]) == 99 and next > 99 else "%d-%d" % [int(parts[0])+(1 if next > 99 else 0),1 if next > 99 else next]
				game.stage_changed.emit(game.current_stage)
			_start_wave()
		return
	for unit: CombatUnit in _units:
		unit.simulate_step(delta)
	var remaining := 0
	for unit: CombatUnit in _units:
		if unit.faction == "enemy" and not unit.is_dead:
			remaining += 1
	wave_label.text = "%s  ·  第 %d / %d 波  ·  敵人 %d" % [game.current_stage,wave,WAVES_PER_STAGE,remaining]
	if remaining == 0:
		_begin_advance()

func _begin_advance() -> void:
	phase = "advance"
	advance_elapsed = 0.0
	cleared_waves += 1
	for unit: CombatUnit in _units:
		unit.battle_locked = true
		if unit.faction == "hero" and unit.active:
			if unit.is_dead:
				unit._revive()
			_march_from[unit] = unit.position
	wave_label.text = "第 %d 波擊破！  向前行軍 →" % wave
	wave_changed.emit(game.current_stage,wave,phase)

func _start_wave() -> void:
	phase = "combat"
	for unit: CombatUnit in _units:
		unit.battle_locked = false
		unit.get_node("Visuals").position.y = 0.0
		unit.spawn_global_position = to_global(_home[unit.unit_data.unit_id] + Vector2(world_offset,0))
		if unit.faction == "enemy":
			unit.unit_data.max_health = 100 + wave*30 + mini(game.kills/9,100)*5
			unit.unit_data.attack = 8 + wave*2
			unit.unit_data.defense = wave*2
			unit.unit_data.gold_reward = 12 + wave*2
			unit._revive()
		unit.current_target = null
	set_training_mode(_practice)
	wave_label.text = "%s  ·  第 %d / %d 波" % [game.current_stage,wave,WAVES_PER_STAGE]
	wave_changed.emit(game.current_stage,wave,phase)

func _bind_scenery() -> void:
	var page: Node = get_parent().get_parent()
	if page == _last_page:
		return
	_last_page = page
	_scenery_materials.clear()
	for node: Node in page.get_children():
		if not node is TextureRect:
			continue
		var name_text := str(node.name)
		if not (name_text == "DistantLandscape" or name_text == "Ground" or name_text.begins_with("Lower")):
			continue
		var material := ShaderMaterial.new()
		material.shader = PARALLAX
		var atlas := node.texture as AtlasTexture
		if atlas != null:
			var total := atlas.atlas.get_size()
			material.set_shader_parameter("region_uv",Vector4(atlas.region.position.x/total.x,atlas.region.position.y/total.y,atlas.region.size.x/total.x,atlas.region.size.y/total.y))
			material.set_shader_parameter("region_width",atlas.region.size.x)
		material.set_shader_parameter("depth_far",0.12 if name_text == "DistantLandscape" else (1.0 if name_text == "Ground" else 0.65))
		# Each authored layer translates rigidly; varying speed within the castle shears it.
		material.set_shader_parameter("depth_near",0.12 if name_text == "DistantLandscape" else (1.0 if name_text == "Ground" else 0.65))
		node.material = material
		_scenery_materials[node] = material
	_apply_parallax()

func _apply_parallax() -> void:
	for material: ShaderMaterial in _scenery_materials.values():
		material.set_shader_parameter("travel_pixels",travel_pixels)

func refresh_spawns() -> void:
	for unit: CombatUnit in _units:
		unit.spawn_global_position = to_global(_home[unit.unit_data.unit_id] + Vector2(world_offset,0))
	_last_page = null
	_bind_scenery()
