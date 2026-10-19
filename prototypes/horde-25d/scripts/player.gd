class_name Player
extends Node3D
## The player: a billboard sprite with a blob shadow. Movement, health and the hurt flash; the weapons live in Arsenal.

signal died

@export var base_speed: float = 6.5
@export var base_max_hp: float = 100.0
@export var radius: float = 0.55
## Seconds of invulnerability after a hit.
@export var invuln_time: float = 0.6
@export var steps_per_meter: float = 1.4

var hp: float = 0.0
var max_hp: float = 0.0
var facing: float = 1.0
var dead: bool = false

var _invuln: float = 0.0
var _phase: float = 0.0
var _flash: float = 0.0
var _material: ShaderMaterial

@onready var _body: MeshInstance3D = %Body
@onready var _xray: MeshInstance3D = %Xray


func _ready() -> void:
	max_hp = base_max_hp
	hp = max_hp
	_material = _body.material_override as ShaderMaterial


func ground() -> Vector2:
	return Vector2(position.x, position.z)


## `input` is a ground direction (x right, y toward the camera), length 0..1.
func move(dt: float, input: Vector2, speed_scale: float) -> void:
	var v: Vector2 = input.limit_length(1.0) * base_speed * speed_scale
	position += Vector3(v.x, 0.0, v.y) * dt
	if absf(input.x) > 0.1:
		facing = signf(input.x)
	_phase += v.length() * dt * steps_per_meter * TAU
	_invuln = maxf(_invuln - dt, 0.0)
	_flash = maxf(_flash - dt * 6.0, 0.0)
	_material.set_shader_parameter(&"facing", facing)
	(_xray.material_override as ShaderMaterial).set_shader_parameter(&"facing", facing)
	_material.set_shader_parameter(&"phase", _phase)
	# Blinks while invulnerable, white for the first instant of a hit.
	_body.visible = _invuln <= 0.0 or fmod(_invuln, 0.12) > 0.04
	_material.set_shader_parameter(&"flash", _flash)


## Returns true when the hit landed (not inside the invulnerability window).
func take_hit(amount: float) -> bool:
	if dead or _invuln > 0.0 or amount <= 0.0:
		return false
	hp = maxf(hp - amount, 0.0)
	_invuln = invuln_time
	_flash = 1.0
	if hp <= 0.0:
		dead = true
		died.emit()
	return true


func heal(amount: float) -> void:
	if not dead:
		hp = minf(hp + amount, max_hp)


func set_max_hp(value: float) -> void:
	hp += value - max_hp
	max_hp = value
