extends Node3D
## The stage boss: one sprite3d quad (frames: idle, winding up a telegraph, knocked down by a broken part, the slam
## landing), its shadow, and the anchors of his parts (PartLegs, PartArm, PartHorns) that the HUD's part buttons
## follow. Shows the sim's state; owns no rules. `lighting` (stage.gd sprite_light) tints the
## sprite by the lights around it.

const PushSim = preload("res://domain/push_sim.gd")
const TELEGRAPH_RED := Color(1.0, 0.25, 0.2)
const IDLE := 0
const WINDUP := 1
const STUNNED := 2
const SLAM := 3
## Seconds the slam frame shows after a telegraph lands, and after a 普通攻擊.
const SLAM_TIME := 0.4
const SWING_SLAM_TIME := 0.18
## Hits weaker than this only shake: a crowd of small skill hits would keep the detailed art washed out. Strong hits
## flash up to full white, which the hit stop holds as an impact frame.
const FLASH_FROM := 0.5

@onready var _sprite: MeshInstance3D = %BossSprite
## Anchors of the parts, in PushSim.Part order.
@onready var _parts: Array[Marker3D] = [%PartLegs, %PartArm, %PartHorns]

var _material: ShaderMaterial
## The stage's colour for this boss (stages.gd REGIONS "boss_tint"), on top of the stage lighting.
var body_tint := Color.WHITE
var _flash: float = 0.0
var _shake: float = 0.0
var _time: float = 0.0
var _dissolve: float = 0.0
var _swing: float = 0.0
var _slam: float = 0.0
## (world point) -> Color multiplier; empty = unlit.
var lighting: Callable


func _ready() -> void:
	# Each run gets its own copy, so runtime flashes never touch the saved material.
	_material = _sprite.material_override.duplicate()
	_sprite.material_override = _material


func reset() -> void:
	_flash = 0.0
	_shake = 0.0
	_dissolve = 0.0
	_slam = 0.0


## Shakes the sprite; strong hits (>= FLASH_FROM) also flash it white.
func hit(strength: float) -> void:
	if strength >= FLASH_FROM:
		_flash = maxf(_flash, strength)
	_shake = maxf(_shake, strength)


## 普通攻擊: a quick lunge toward the heroes.
func swing() -> void:
	_swing = 1.0
	_slam = maxf(_slam, SWING_SLAM_TIME)


## A telegraphed attack lands.
func slam() -> void:
	_slam = SLAM_TIME


func part_point(p: int) -> Vector3:
	return _parts[p].global_position


func step(sim: PushSim, dt: float) -> void:
	_time += dt
	var frame: int = IDLE
	var flash_color := Color.WHITE
	var flash: float = _flash
	_slam = maxf(_slam - dt, 0.0)
	if sim.tele_t > 0.0:
		frame = WINDUP
		var pulse: float = 0.1 + 0.06 * sin(_time * 24.0)
		if pulse > flash:
			flash_color = TELEGRAPH_RED
			flash = pulse
	elif _slam > 0.0:
		frame = SLAM
	elif sim.stagger_t > 0.0:
		frame = STUNNED
	if sim.phase == PushSim.Phase.WON:
		frame = STUNNED
		_dissolve = minf(_dissolve + dt * 0.6, 1.0)
	_material.set_shader_parameter(&"frame", float(frame))
	_material.set_shader_parameter(&"flash", clampf(flash, 0.0, 1.0))
	_material.set_shader_parameter(&"flash_color", flash_color)
	_material.set_shader_parameter(&"dissolve", _dissolve)
	var lit: Color = lighting.call(global_position + Vector3(0.0, 2.4, 0.0)) if lighting.is_valid() else Color.WHITE
	_material.set_shader_parameter(&"tint", lit * body_tint)
	_sprite.position.x = sin(_time * 70.0) * 0.12 * _shake - sin(_swing * PI) * 0.35
	_swing = maxf(_swing - dt * 4.0, 0.0)
	_flash = maxf(_flash - dt * 10.0, 0.0)
	_shake = maxf(_shake - dt * 4.0, 0.0)
