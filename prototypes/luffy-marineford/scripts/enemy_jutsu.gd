class_name EnemyJutsu
extends Node3D
## The ninja army's ranged jutsu: casters (horde `cast` signal) throw one of three elements at Madara.
##   FIRE   a fireball that bursts on him
##   WATER  a fast water bullet that also slows him
##   EARTH  a warning ring at his feet, then rock spikes erupt a moment later (on the ground: cannot be reflected)
## Fireballs and water bullets can be swatted back with the Gunbai (reflect_cone): a reflected jutsu flies faster
## and blasts the ninjas it hits. Damage to Madara goes out through `hit_player`; main decides whether the
## Sharingan dodges it.

enum Element { NONE, FIRE, WATER, EARTH }

signal hit_player(amount: float, from: Vector2, element: int)
signal reflected(count: int, at: Vector3)

@export var horde: Horde
@export var fx: Fx
@export var glow: GlowPool
@export_group("Fire")
@export var fire_speed: float = 9.0
@export var fire_damage: float = 12.0
@export var fire_color: Color = Color(1.0, 0.45, 0.15)
@export_group("Water")
@export var water_speed: float = 14.0
@export var water_damage: float = 7.0
@export var water_slow: float = 0.45
@export var water_slow_time: float = 1.5
@export var water_color: Color = Color(0.35, 0.7, 1.0)
@export_group("Earth")
@export var earth_warning: float = 1.1
@export var earth_radius: float = 2.0
@export var earth_damage: float = 16.0
@export var earth_color: Color = Color(0.72, 0.5, 0.3)
@export_group("Reflect")
@export var reflect_speed_scale: float = 1.7
@export var reflect_damage: float = 40.0
@export var reflect_blast: float = 1.8
@export var max_projectiles: int = 96

var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _element := PackedInt32Array()
var _life := PackedFloat32Array()
var _reflected := PackedByteArray()
var _warn_pos := PackedVector2Array()
var _warn_left := PackedFloat32Array()
var _next_warning: int = 0

@onready var _warnings: Node3D = %Warnings


func _ready() -> void:
	for ring: Node in _warnings.get_children():
		(ring as Node3D).visible = false
		_warn_pos.append(Vector2.ZERO)
		_warn_left.append(0.0)


## A caster's jutsu leaves `from` toward `target` (horde.cast).
func cast(element: int, from: Vector3, target: Vector2) -> void:
	var start := Vector2(from.x, from.z)
	match element:
		Element.FIRE, Element.WATER:
			if _pos.size() >= max_projectiles:
				return
			var speed: float = fire_speed if element == Element.FIRE else water_speed
			_pos.append(start)
			_vel.append((target - start).normalized() * speed)
			_element.append(element)
			_life.append(2.6)
			_reflected.append(0)
			fx.flash(from, 1.4, fire_color if element == Element.FIRE else water_color)
		Element.EARTH:
			_warn(target)


func projectiles() -> int:
	return _pos.size()


## Turns every hostile projectile inside the cone back the way the fan swings. Returns how many.
func reflect_cone(center: Vector2, dir: Vector2, radius: float, half_angle: float) -> int:
	var count: int = 0
	var cos_limit: float = cos(half_angle)
	for i: int in _pos.size():
		if _reflected[i] == 1:
			continue
		var away: Vector2 = _pos[i] - center
		var d: float = away.length()
		if d > radius + 0.8 or (d > 0.8 and away.dot(dir) / d < cos_limit):
			continue
		_reflected[i] = 1
		_vel[i] = (away.normalized() if d > 0.1 else dir).lerp(dir, 0.5).normalized() * _vel[i].length() * reflect_speed_scale
		_life[i] = 1.6
		count += 1
	if count > 0:
		reflected.emit(count, Vector3(center.x + dir.x * 1.5, 1.0, center.y + dir.y * 1.5))
	return count


func step(dt: float, player: Vector2, player_radius: float) -> void:
	var i: int = 0
	while i < _pos.size():
		var p: Vector2 = _pos[i] + _vel[i] * dt
		_pos[i] = p
		_life[i] -= dt
		var element: int = _element[i]
		var color: Color = fire_color if element == Element.FIRE else water_color
		var at := Vector3(p.x, 1.0, p.y)
		var done: bool = _life[i] <= 0.0
		if _reflected[i] == 1:
			if horde.first_in(p, 0.5) >= 0:
				horde.damage_circle(p, reflect_blast, reflect_damage, 16.0, 3.0 if element == Element.FIRE else 0.0)
				fx.flash(at, reflect_blast * 1.5, color)
				fx.ring(at - Vector3(0, 0.7, 0), reflect_blast * 2.0, color, 0.3)
				done = true
		elif p.distance_to(player) < player_radius + 0.45:
			hit_player.emit(fire_damage if element == Element.FIRE else water_damage, p - _vel[i].normalized(), element)
			fx.flash(at, 1.6, color)
			done = true
		if done:
			_remove(i)
			continue
		var size: float = (1.0 if element == Element.FIRE else 0.7) * (1.4 if _reflected[i] == 1 else 1.0)
		glow.add(at, size * 1.5, color, GlowPool.DOT)
		glow.add(at, size * 0.7, Color(1.0, 0.95, 0.85), GlowPool.DOT)
		if _reflected[i] == 1:
			glow.add(at, size * 2.2, Color(1.0, 0.3, 0.3, 0.6), GlowPool.RING, 0.4)
		i += 1
	_step_warnings(dt, player, player_radius)


func _warn(target: Vector2) -> void:
	var ring := _warnings.get_child(_next_warning) as MeshInstance3D
	_warn_pos[_next_warning] = target
	_warn_left[_next_warning] = earth_warning
	ring.position = Vector3(target.x, 0.07, target.y)
	ring.scale = Vector3(earth_radius * 2.0, 1.0, earth_radius * 2.0)
	ring.visible = true
	_next_warning = (_next_warning + 1) % _warnings.get_child_count()


func _step_warnings(dt: float, player: Vector2, player_radius: float) -> void:
	for w: int in _warn_left.size():
		if _warn_left[w] <= 0.0:
			continue
		_warn_left[w] -= dt
		var ring := _warnings.get_child(w) as MeshInstance3D
		var t: float = 1.0 - _warn_left[w] / earth_warning
		(ring.material_override as ShaderMaterial).set_shader_parameter(&"progress", t)
		if _warn_left[w] > 0.0:
			continue
		ring.visible = false
		var p: Vector2 = _warn_pos[w]
		var at := Vector3(p.x, 0.3, p.y)
		fx.dust_burst(at, 8, 5.0, 1.4, Color(earth_color, 0.85))
		for k: int in 5:
			var o: Vector2 = Vector2.from_angle(TAU * k / 5.0 + randf()) * earth_radius * 0.55
			fx.spark(at + Vector3(o.x, 0.6, o.y), earth_color.lightened(0.3), 1.6)
		if p.distance_to(player) < earth_radius + player_radius:
			hit_player.emit(earth_damage, p, Element.EARTH)


func _remove(i: int) -> void:
	var last: int = _pos.size() - 1
	_pos[i] = _pos[last]
	_vel[i] = _vel[last]
	_element[i] = _element[last]
	_life[i] = _life[last]
	_reflected[i] = _reflected[last]
	_pos.resize(last)
	_vel.resize(last)
	_element.resize(last)
	_life.resize(last)
	_reflected.resize(last)
