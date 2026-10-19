class_name Fx
extends Node
## Short-lived effects drawn through two pools: glowing ones (sparks, flashes, rings) add light in `glow`; dust,
## debris and smoke are alpha-blended in `dust` so they read on bright sand. Lifetimes run on game time.

@export var glow: GlowPool
@export var dust_pool: GlowPool
@export var max_effects: int = 384

var _at := PackedVector3Array()
var _vel := PackedVector3Array()
var _age := PackedFloat32Array()
var _life := PackedFloat32Array()
var _size := PackedFloat32Array()
var _shape := PackedFloat32Array()
var _color: Array[Color] = []
var _is_dust := PackedByteArray()


func spark(at: Vector3, color: Color, size: float = 1.1) -> void:
	_add(at, Vector3.ZERO, size, color, GlowPool.SPARK, 0.14, false)


func ring(at: Vector3, size: float, color: Color, life: float = 0.3) -> void:
	_add(at, Vector3.ZERO, size, color, GlowPool.RING, life, false)


func flash(at: Vector3, size: float, color: Color) -> void:
	_add(at, Vector3.ZERO, size, color, GlowPool.DOT, 0.1, false)


## A flame lick that rises and fades (burning ground, burning enemies).
func flame(at: Vector3, size: float, color: Color) -> void:
	_add(at, Vector3(0.0, 2.4, 0.0), size, color, GlowPool.DOT, 0.32, false)


## A dust puff that drifts and grows.
func dust(at: Vector3, size: float, color: Color, velocity: Vector3 = Vector3.ZERO, life: float = 0.5) -> void:
	_add(at, velocity, size, color, GlowPool.PUFF, life, true)


## A ring of dust kicked outward (a body landing, a swing hitting the ground).
func dust_burst(at: Vector3, count: int, speed: float, size: float, color: Color) -> void:
	for i: int in count:
		var a: float = TAU * (i + randf() * 0.5) / count
		dust(at, size * randf_range(0.7, 1.2), color, Vector3(cos(a) * speed, randf_range(0.5, 1.5), sin(a) * speed), randf_range(0.35, 0.6))


func live() -> int:
	return _at.size()


func step(dt: float) -> void:
	var i: int = 0
	while i < _at.size():
		_age[i] += dt
		var t: float = _age[i] / _life[i]
		if t >= 1.0:
			_remove(i)
			continue
		_at[i] += _vel[i] * dt
		_vel[i] *= exp(-4.0 * dt)
		var pool: GlowPool = dust_pool if _is_dust[i] == 1 else glow
		var size: float = _size[i] * (1.0 + t * 0.6 if _is_dust[i] == 1 else 1.0)
		pool.add(_at[i], size, _color[i], _shape[i], t)
		i += 1


func _add(at: Vector3, velocity: Vector3, size: float, color: Color, shape: float, life: float, is_dust: bool) -> void:
	if _at.size() >= max_effects:
		_remove(0)
	_at.append(at)
	_vel.append(velocity)
	_age.append(0.0)
	_life.append(life)
	_size.append(size)
	_shape.append(shape)
	_color.append(color)
	_is_dust.append(1 if is_dust else 0)


func _remove(i: int) -> void:
	var last: int = _at.size() - 1
	_at[i] = _at[last]
	_vel[i] = _vel[last]
	_age[i] = _age[last]
	_life[i] = _life[last]
	_size[i] = _size[last]
	_shape[i] = _shape[last]
	_color[i] = _color[last]
	_is_dust[i] = _is_dust[last]
	_at.resize(last)
	_vel.resize(last)
	_age.resize(last)
	_life.resize(last)
	_size.resize(last)
	_shape.resize(last)
	_color.resize(last)
	_is_dust.resize(last)
