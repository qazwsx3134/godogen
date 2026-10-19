class_name Fx
extends Node
## Short-lived hit sparks and death puffs, drawn through the GlowPool. Lifetimes run on game time.

@export var glow: GlowPool
@export var spark_life: float = 0.14
@export var spark_size: float = 0.9
@export var puff_life: float = 0.32
@export var max_effects: int = 256

var _at := PackedVector3Array()
var _age := PackedFloat32Array()
var _life := PackedFloat32Array()
var _size := PackedFloat32Array()
var _shape := PackedFloat32Array()
var _color: Array[Color] = []


func spark(at: Vector3, color: Color) -> void:
	_add(at, spark_size, color, GlowPool.SPARK, spark_life)


func puff(at: Vector3, size: float, color: Color) -> void:
	_add(at + Vector3(0.0, size * 0.45, 0.0), size * 1.6, color, GlowPool.RING, puff_life)


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
		glow.add(_at[i], _size[i], _color[i], _shape[i], t)
		i += 1


func _add(at: Vector3, size: float, color: Color, shape: float, life: float) -> void:
	if _at.size() >= max_effects:
		_remove(0)
	_at.append(at)
	_age.append(0.0)
	_life.append(life)
	_size.append(size)
	_shape.append(shape)
	_color.append(color)


func _remove(i: int) -> void:
	var last: int = _at.size() - 1
	_at[i] = _at[last]
	_age[i] = _age[last]
	_life[i] = _life[last]
	_size[i] = _size[last]
	_shape[i] = _shape[last]
	_color[i] = _color[last]
	_at.resize(last)
	_age.resize(last)
	_life.resize(last)
	_size.resize(last)
	_shape.resize(last)
	_color.resize(last)
