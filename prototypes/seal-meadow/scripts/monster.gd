extends Node3D
## One monster: wanders around its home, chases when provoked (or on sight if aggressive), leashes back
## when dragged too far, dies (Combat hands out the XP) and respawns at home. Social aggro: hitting one wakes
## every calm monster of the same kind within pack_radius, so a pack is pulled with one tap.

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
## Key into Items.DROPS.
@export var drop_table: String = "jelly"
## Same-kind monsters this close join the fight when this one is hit. 0 = fights alone.
@export var pack_radius: float = 6.0

@onready var actor: Node3D = $Actor

var hp: int = 30
var combat: Node
## Changes on every respawn, so a target lock taken on the old life never carries over.
var spawn_id: int = 0
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
		combat.attack(self, player, damage, 1.0, false)


func take_damage(amount: int, from: Node3D, crit: bool = false) -> void:
	if hp <= 0:
		return
	hp -= amount
	if not _provoked:
		_alert_pack()
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


func _alert_pack() -> void:
	if pack_radius <= 0.0:
		return
	for m: Node3D in get_tree().get_nodes_in_group("monster"):
		if m != self and m.scene_file_path == scene_file_path and m.is_alive() and not m._returning \
				and m.position.distance_to(position) <= pack_radius:
			m._provoked = true


func _die(from: Node3D) -> void:
	actor.moving = false
	actor.set_dead(true)
	died.emit(self)
	await get_tree().create_timer(respawn_seconds, false).timeout
	position = _home
	_snap()
	spawn_id += 1
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
