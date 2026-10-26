extends Node3D
## The player's warrior: click-to-move or WASD, auto-attacks a locked target, levels up from monster XP.
## Stands on TerrainHeight; trees, rocks and the pond push it out (Meadow.blockers()).

signal stats_changed
signal message(text: String, color: Color)

const TerrainHeight = preload("res://scripts/terrain_height.gd")
const Fx = preload("res://scripts/fx.gd")

@export var player_name: String = "你"
@export var move_speed: float = 5.0
@export var base_hp: int = 120
@export var base_attack: int = 12
@export var attack_range: float = 1.8
@export var attack_interval: float = 0.8
@export var bounds_radius: float = 60.0
@export var respawn_seconds: float = 3.0

@onready var actor: Node3D = $Actor

var level: int = 1
var max_hp: int = 120
var hp: float = 120.0
var attack_power: int = 12
var xp: int = 0
var target: Node3D = null
var dead: bool = false
## Camera yaw (radians), so WASD moves relative to the screen.
var cam_yaw: float = 0.0
## Vector3(x, z, radius) circles the player cannot enter.
var blockers: Array[Vector3] = []

var _goal: Vector3
var _has_goal: bool = false
var _cooldown: float = 0.0
var _since_hit: float = 99.0
var _spawn: Vector3


func _ready() -> void:
	add_to_group("player")
	_spawn = position
	_recalc()
	hp = max_hp
	actor.display_name = player_name
	_snap()


func xp_to_next() -> int:
	return 20 + (level - 1) * 18


func _recalc() -> void:
	max_hp = base_hp + (level - 1) * 18
	attack_power = base_attack + (level - 1) * 4


func _process(delta: float) -> void:
	if dead:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	_since_hit += delta
	if _since_hit > 5.0 and hp < max_hp:
		hp = minf(max_hp, hp + max_hp * 0.04 * delta)
		actor.hp_ratio = hp / max_hp
		stats_changed.emit()

	var dir := Vector3.ZERO
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input.length() > 0.1:
		_has_goal = false
		target = null
		dir = Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, cam_yaw).normalized()
	elif is_instance_valid(target) and target.is_alive():
		var to := target.position - position
		to.y = 0.0
		if to.length() > attack_range:
			dir = to.normalized()
		else:
			actor.face(to)
			_try_attack()
	elif _has_goal:
		var to := _goal - position
		to.y = 0.0
		if to.length() < 0.25:
			_has_goal = false
		else:
			dir = to.normalized()
	if target != null and not (is_instance_valid(target) and target.is_alive()):
		target = null

	if dir != Vector3.ZERO:
		position += dir * move_speed * delta
		_push_out()
		actor.face(dir)
	_snap()
	actor.moving = dir != Vector3.ZERO


func move_to(point: Vector3) -> void:
	if dead:
		return
	_goal = point
	_has_goal = true
	target = null


func set_target(monster: Node3D) -> void:
	if dead or not monster.is_alive():
		return
	target = monster
	_has_goal = false


func attack_nearest(max_distance: float = 9.0) -> void:
	var best: Node3D = null
	var best_d := max_distance
	for m: Node3D in get_tree().get_nodes_in_group("monster"):
		var d := m.position.distance_to(position)
		if m.is_alive() and d < best_d:
			best = m
			best_d = d
	if best != null:
		set_target(best)


func _try_attack() -> void:
	if _cooldown > 0.0:
		return
	_cooldown = attack_interval
	actor.attack()
	var victim := target
	await get_tree().create_timer(0.18, false).timeout
	if dead or not is_instance_valid(victim) or not victim.is_alive():
		return
	var crit := randf() < 0.12
	var amount := attack_power + randi_range(-2, 3)
	if crit:
		amount *= 2
	victim.take_damage(amount, self, crit)


func take_damage(amount: int) -> void:
	if dead:
		return
	hp -= amount
	_since_hit = 0.0
	actor.hurt()
	actor.hp_ratio = clampf(hp / max_hp, 0.0, 1.0)
	Fx.popup(get_parent(), position + Vector3.UP * 1.9, str(amount), Color("ff6b6b"))
	if hp <= 0.0:
		hp = 0.0
		_die()
	stats_changed.emit()


func gain_xp(amount: int, from_name: String) -> void:
	xp += amount
	message.emit("打倒了 %s，獲得 %d 點經驗值。" % [from_name, amount], Color("e6edf7"))
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		_recalc()
		hp = max_hp
		message.emit("等級提升！現在是 Lv %d（生命 %d、攻擊 %d）" % [level, max_hp, attack_power], Color("ffd75e"))
		Fx.popup(get_parent(), position + Vector3.UP * 2.3, "LEVEL UP!", Color("ffd75e"), 64)
	actor.hp_ratio = hp / max_hp
	stats_changed.emit()


func _die() -> void:
	dead = true
	target = null
	_has_goal = false
	actor.moving = false
	actor.set_dead(true)
	message.emit("你倒下了……%d 秒後在路牌旁復活。" % int(respawn_seconds), Color("ff8a8a"))
	await get_tree().create_timer(respawn_seconds, false).timeout
	position = _spawn
	_snap()
	hp = max_hp
	actor.hp_ratio = 1.0
	actor.set_dead(false)
	dead = false
	stats_changed.emit()


func _push_out() -> void:
	var p := Vector2(position.x, position.z)
	for b in blockers:
		var c := Vector2(b.x, b.y)
		var d := p.distance_to(c)
		if d < b.z:
			p = c + (p - c).normalized() * b.z if d > 0.001 else c + Vector2(b.z, 0.0)
	p = p.limit_length(bounds_radius)
	position.x = p.x
	position.z = p.y


func _snap() -> void:
	position.y = TerrainHeight.height(position.x, position.z)
