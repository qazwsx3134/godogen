extends Node2D
class_name CombatUnit

signal attack_performed(source: CombatUnit, target: CombatUnit, amount: int)

@export var unit_data: UnitData
@export_enum("hero", "enemy") var faction: String = "hero"
@export var preview_only: bool = false
@export var appearance: String = ""
@export var automatic_respawn: bool = true
var active: bool = true
var battle_locked: bool = false
var regeneration: float = 0.0
var regeneration_clock: float = 0.0
var crit_chance: float = 0.0
var _rng := RandomNumberGenerator.new()

@onready var knight_visual: Node2D = %KnightVisual
@onready var slime_visual: Node2D = %SlimeVisual
@onready var health_fill: Polygon2D = %HealthFill

var current_health: int = 1
var current_target: CombatUnit
var is_dead: bool = false
var attack_cooldown_remaining: float = 0.0
var respawn_remaining: float = 0.0
var target_scan_remaining: float = 0.0
var arena_token: int = 0
var spawn_global_position: Vector2 = Vector2.ZERO

const DamageRules = preload("res://domain/combat/damage_rules.gd")
@onready var _game_state: Node = get_node("/root/Game")
@onready var _event_bus: Node = get_node("/root/EventBus")

func _ready() -> void:
	if unit_data == null:
		push_error("CombatUnit needs UnitData: %s" % name)
		return
	unit_data = unit_data.duplicate()
	_rng.seed = abs(unit_data.unit_id.hash()) + 42
	spawn_global_position = global_position
	current_health = unit_data.max_health
	faction = unit_data.faction
	if appearance.is_empty():
		knight_visual.visible = unit_data.unit_id == "knight"
		slime_visual.visible = unit_data.unit_id == "slime"
	else:
		set_appearance(appearance)
	_update_health_bar()
	if not preview_only:
		add_to_group("combat_units")
		add_to_group("heroes" if faction == "hero" else "enemies")
		_event_bus.emit_signal("unit_health_changed", unit_data.unit_id, faction, current_health, unit_data.max_health)

func _physics_process(delta: float) -> void:
	simulate_step(delta)

func simulate_step(delta: float) -> void:
	if preview_only or not active or battle_locked or unit_data == null or delta <= 0.0:
		return
	if bool(_game_state.get("combat_paused")):
		return
	if is_dead:
		if not automatic_respawn:
			return
		respawn_remaining -= delta
		if respawn_remaining <= 0.0:
			_revive()
		return

	regeneration_clock += delta
	if regeneration_clock >= 1.0:
		regeneration_clock -= 1.0
		current_health = mini(unit_data.max_health, current_health + int(regeneration))
		_update_health_bar()
	target_scan_remaining -= delta
	if not is_instance_valid(current_target) or not current_target.active or current_target.is_dead or target_scan_remaining <= 0.0:
		current_target = _nearest_opponent()
		target_scan_remaining = 0.12
	if not is_instance_valid(current_target):
		return

	var distance_to_target: float = global_position.distance_to(current_target.global_position)
	if distance_to_target > unit_data.attack_range:
		global_position = global_position.move_toward(
			current_target.global_position,
			unit_data.move_speed * delta
		)
		return

	attack_cooldown_remaining -= delta
	if attack_cooldown_remaining <= 0.0:
		if _attack(current_target):
			attack_cooldown_remaining = DamageRules.attack_interval(unit_data.attack_speed)

func take_damage(amount: int, source: CombatUnit = null) -> void:
	if preview_only or not active or is_dead or amount <= 0:
		return
	current_health = maxi(current_health - amount, 0)
	_update_health_bar()
	_event_bus.emit_signal("unit_health_changed", unit_data.unit_id, faction, current_health, unit_data.max_health)
	if source != null:
		_event_bus.emit_signal(
			"damage_dealt",
			source.unit_data.unit_id,
			unit_data.unit_id,
			amount,
			current_health,
			unit_data.max_health
		)
	if current_health == 0:
		_die()

func _attack(target: CombatUnit) -> bool:
	if not active or is_dead or battle_locked or arena_token == 0 or not is_instance_valid(target) or not target.active or target.is_dead or target.arena_token != arena_token or target.faction == faction:
		return false
	if global_position.distance_to(target.global_position) > unit_data.attack_range:
		return false
	var amount: int = DamageRules.final_damage(unit_data.attack, target.unit_data.defense, 2.0 if _rng.randf()*100.0 < crit_chance else 1.0)
	target.take_damage(amount, self)
	attack_performed.emit(self, target, amount)
	return true

func _nearest_opponent() -> CombatUnit:
	if arena_token == 0:
		return null
	var target_group: String = "enemies" if faction == "hero" else "heroes"
	var closest: CombatUnit
	var closest_distance: float = INF
	for candidate_node: Node in get_tree().get_nodes_in_group(target_group):
		var candidate: CombatUnit = candidate_node as CombatUnit
		if candidate == null or not candidate.active or candidate.is_dead or candidate.preview_only or candidate.arena_token != arena_token:
			continue
		var candidate_distance: float = global_position.distance_squared_to(candidate.global_position)
		var is_stably_closer: bool = is_equal_approx(candidate_distance, closest_distance) \
			and closest != null \
			and str(candidate.get_path()) < str(closest.get_path())
		if candidate_distance < closest_distance or is_stably_closer:
			closest = candidate
			closest_distance = candidate_distance
	return closest

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	visible = false
	respawn_remaining = unit_data.respawn_delay
	current_target = null
	_event_bus.emit_signal("unit_died", unit_data.unit_id, faction)
	if faction == "enemy":
		_event_bus.emit_signal("enemy_killed", unit_data.unit_id, unit_data.gold_reward)

func _revive() -> void:
	is_dead = false
	current_health = unit_data.max_health
	global_position = spawn_global_position
	attack_cooldown_remaining = 0.0
	target_scan_remaining = 0.0
	visible = true
	_update_health_bar()
	_event_bus.emit_signal("unit_respawned", unit_data.unit_id, faction)
	_event_bus.emit_signal("unit_health_changed", unit_data.unit_id, faction, current_health, unit_data.max_health)

func _update_health_bar() -> void:
	if not is_node_ready() or unit_data == null:
		return
	var ratio: float = clampf(float(current_health) / float(unit_data.max_health), 0.0, 1.0)
	var left: float = -24.0
	var right: float = left + 48.0 * ratio
	health_fill.polygon = PackedVector2Array([
		Vector2(left, -49.0), Vector2(right, -49.0),
		Vector2(right, -43.0), Vector2(left, -43.0),
	])

func set_active(value: bool) -> void:
	if active == value:
		return
	active = value
	visible = value and not is_dead
	current_target = null
	if value and is_node_ready():
		_revive()

func set_appearance(value: String) -> void:
	appearance = value
	var visuals := get_node_or_null("Visuals")
	if visuals == null:
		return
	for node: Node in visuals.get_children():
		if node is CanvasItem:
			node.visible = str(node.name) == value

func apply_stats(stats: Dictionary) -> void:
	var previous_max: int = unit_data.max_health
	unit_data.max_health = int(stats.get("health",previous_max))
	unit_data.attack = int(stats.get("attack",unit_data.attack))
	unit_data.defense = int(stats.get("defense",unit_data.defense))
	unit_data.move_speed = 60.0 + float(stats.get("speed",12)) * 2.0
	crit_chance = float(stats.get("crit",0))
	regeneration = float(stats.get("regen",0))
	current_health = clampi(current_health + maxi(unit_data.max_health-previous_max,0),0,unit_data.max_health)
	_update_health_bar()
