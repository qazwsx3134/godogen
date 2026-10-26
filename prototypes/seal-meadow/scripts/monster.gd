extends Node3D
## One monster: wanders around its home, chases when provoked (or on sight if aggressive), leashes back
## when dragged too far, dies into XP and respawns at home.

signal died(monster: Node3D)

const TerrainHeight = preload("res://scripts/terrain_height.gd")
const Fx = preload("res://scripts/fx.gd")

@export var display_name: String = "怪物"
@export var level: int = 1
@export var max_hp: int = 30
@export var damage: int = 4
@export var move_speed: float = 2.0
@export var aggressive: bool = false
@export var aggro_radius: float = 7.0
@export var leash_radius: float = 15.0
@export var attack_range: float = 1.5
@export var attack_interval: float = 1.6
@export var wander_radius: float = 5.0
@export var xp_reward: int = 6
@export var respawn_seconds: float = 10.0

@onready var actor: Node3D = $Actor

var hp: int = 30
var blockers: Array[Vector3] = []
var _home: Vector3
var _provoked: bool = false
var _returning: bool = false
var _wander_goal: Vector3
var _wandering: bool = false
var _think: float = 0.0
var _cooldown: float = 0.0


func _ready() -> void:
	add_to_group("monster")
	_home = position
	hp = max_hp
	actor.display_name = "%s  Lv%d" % [display_name, level]
	actor.nameplate_color = Color("ff9d8a") if aggressive else Color("f4ead2")
	actor.nameplate.modulate = actor.nameplate_color
	_think = randf_range(0.5, 3.0)
	_snap()


func is_alive() -> bool:
	return hp > 0


func _process(delta: float) -> void:
	if hp <= 0:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var to_player := Vector3.ZERO
	var player_ok: bool = player != null and not player.dead
	if player_ok:
		to_player = player.position - position
		to_player.y = 0.0
		if aggressive and not _returning and to_player.length() < aggro_radius:
			_provoked = true
	else:
		_provoked = false
	if _provoked and position.distance_to(_home) > leash_radius:
		_provoked = false
		_returning = true

	var dir := Vector3.ZERO
	var speed := move_speed
	if _provoked:
		if to_player.length() > attack_range:
			dir = to_player.normalized()
		else:
			actor.face(to_player)
			_try_attack(player)
	elif _returning:
		var to := _home - position
		to.y = 0.0
		speed *= 1.8
		hp = mini(max_hp, hp + int(ceil(max_hp * delta)))
		actor.hp_ratio = float(hp) / max_hp
		if to.length() < 0.4:
			_returning = false
		else:
			dir = to.normalized()
	else:
		_think -= delta
		if _think <= 0.0:
			_think = randf_range(2.0, 5.0)
			_wandering = randf() < 0.6
			var a := randf() * TAU
			_wander_goal = _home + Vector3(cos(a), 0.0, sin(a)) * randf() * wander_radius
		if _wandering:
			var to := _wander_goal - position
			to.y = 0.0
			if to.length() < 0.3:
				_wandering = false
			else:
				dir = to.normalized()
				speed *= 0.5

	if dir != Vector3.ZERO:
		position += dir * speed * delta
		_push_out()
		actor.face(dir)
	_snap()
	actor.moving = dir != Vector3.ZERO


func _try_attack(player: Node3D) -> void:
	if _cooldown > 0.0:
		return
	_cooldown = attack_interval
	actor.attack()
	await get_tree().create_timer(0.22, false).timeout
	if hp <= 0 or player.dead:
		return
	if player.position.distance_to(position) <= attack_range * 1.4:
		player.take_damage(damage + randi_range(0, 2))


func take_damage(amount: int, from: Node3D, crit: bool = false) -> void:
	if hp <= 0:
		return
	hp -= amount
	_provoked = true
	_returning = false
	actor.hurt()
	actor.hp_ratio = clampf(float(hp) / max_hp, 0.0, 1.0)
	var text := ("暴擊 %d!" % amount) if crit else str(amount)
	Fx.popup(get_parent(), position + Vector3.UP * (actor.head_height + 0.2), text,
		Color("ffcf4d") if crit else Color.WHITE, 56 if crit else 44)
	if hp <= 0:
		hp = 0
		_die(from)


func _die(from: Node3D) -> void:
	actor.moving = false
	actor.set_dead(true)
	died.emit(self)
	if from != null and from.has_method("gain_xp"):
		from.gain_xp(xp_reward, display_name)
	await get_tree().create_timer(respawn_seconds, false).timeout
	position = _home
	_snap()
	hp = max_hp
	_provoked = false
	_returning = false
	actor.hp_ratio = 1.0
	actor.set_dead(false)


func _push_out() -> void:
	var p := Vector2(position.x, position.z)
	for b in blockers:
		var c := Vector2(b.x, b.y)
		var d := p.distance_to(c)
		if d < b.z and d > 0.001:
			p = c + (p - c).normalized() * b.z
	position.x = p.x
	position.z = p.y


func _snap() -> void:
	position.y = TerrainHeight.height(position.x, position.z)
