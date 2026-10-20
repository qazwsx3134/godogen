extends Node3D
## The stage boss: one sprite3d quad (frames: idle, winding up the sweep, broken), its shadow, and the anchor the
## HUD puts the weak point on. Shows the sim's state; owns no rules.

const PushSim = preload("res://domain/push_sim.gd")
const TELEGRAPH_RED := Color(1.0, 0.25, 0.2)

@onready var _sprite: MeshInstance3D = %BossSprite
@onready var _weak: Marker3D = %WeakPointAnchor

var _material: ShaderMaterial
var _flash: float = 0.0
var _shake: float = 0.0
var _time: float = 0.0
var _dissolve: float = 0.0
var _swing: float = 0.0


func _ready() -> void:
	# Each run gets its own copy, so runtime flashes never touch the saved material.
	_material = _sprite.material_override.duplicate()
	_sprite.material_override = _material


func reset() -> void:
	_flash = 0.0
	_shake = 0.0
	_dissolve = 0.0


func hit(strength: float) -> void:
	_flash = maxf(_flash, strength)
	_shake = maxf(_shake, strength)


## 普通攻擊: a quick lunge toward the heroes.
func swing() -> void:
	_swing = 1.0


func weak_point() -> Vector3:
	return _weak.global_position


func step(sim: PushSim, dt: float) -> void:
	_time += dt
	var frame: int = 0
	var flash_color := Color.WHITE
	var flash: float = _flash
	if sim.tele_t > 0.0:
		frame = 1
		flash_color = TELEGRAPH_RED
		flash = maxf(flash, 0.35 + 0.3 * sin(_time * 24.0))
	elif sim.break_t > 0.0:
		frame = 2
	if sim.phase == PushSim.Phase.WON:
		frame = 2
		_dissolve = minf(_dissolve + dt * 0.6, 1.0)
	_material.set_shader_parameter(&"frame", float(frame))
	_material.set_shader_parameter(&"flash", clampf(flash, 0.0, 1.0))
	_material.set_shader_parameter(&"flash_color", flash_color)
	_material.set_shader_parameter(&"dissolve", _dissolve)
	_sprite.position.x = sin(_time * 70.0) * 0.12 * _shake - sin(_swing * PI) * 0.35
	_swing = maxf(_swing - dt * 4.0, 0.0)
	_flash = maxf(_flash - dt * 6.0, 0.0)
	_shake = maxf(_shake - dt * 4.0, 0.0)
