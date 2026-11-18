extends Node3D
## Third-person orbit rig: top_level, follows its parent (the walker) with a little lag, yaw on this node,
## pitch on %Pitch, distance on %Arm (SpringArm3D pulls in when terrain is in the way, never the walker itself).

@export var height: float = 3.3
@export var follow_rate: float = 10.0
## Slower vertical follow, so a jump visibly lifts the walker in the frame.
@export var follow_rate_vertical: float = 3.5
@export var pitch_start_deg: float = -16.0
@export var pitch_min_deg: float = -55.0
@export var pitch_max_deg: float = 20.0

@onready var _pitch: Node3D = %Pitch
@onready var _arm: SpringArm3D = %Arm
@onready var _camera: Camera3D = %Camera

## Degrees added to the camera's field of view (sprint); eased, so it breathes in and out.
var fov_add: float = 0.0
var yaw: float = PI
var pitch: float = deg_to_rad(-16.0)
var _kick: float = 0.0
var _recoil: float = 0.0   # extra pitch (rad) from gun kick, springs back to the aim
var _trauma: float = 0.0   # 0..1 shake; the camera moves by trauma squared
var _shake_time: float = 0.0
## Accessibility: 0 disables shake and gun kick.
@export_range(0.0, 1.0) var shake_scale: float = 1.0
@export var shake_offset: float = 0.45  # m at full trauma
var _base_fov: float

func _ready() -> void:
	var body := get_parent() as CollisionObject3D
	_arm.add_excluded_object(body.get_rid())
	global_position = body.global_position + Vector3.UP * height
	pitch = deg_to_rad(pitch_start_deg)
	rotation.y = yaw
	_pitch.rotation.x = pitch
	_base_fov = _camera.fov

## d.x turns right, d.y looks down (radians).
func look(d: Vector2) -> void:
	yaw -= d.x
	pitch = clampf(pitch - d.y, deg_to_rad(pitch_min_deg), deg_to_rad(pitch_max_deg))

## Horizontal unit vector the camera looks along.
func forward_flat() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))

## Short downward jolt (m), e.g. a heavy footfall. Jolts do not stack past the biggest one.
func kick(amount: float) -> void:
	_kick = maxf(_kick, amount)

## Gun recoil: the view snaps up by `radians` and eases back over ~0.15 s.
func gun_kick(radians: float) -> void:
	_recoil = minf(_recoil + radians * shake_scale, deg_to_rad(6.0))

## Adds shake (0..1). `ceiling` keeps a stream of small hits from adding up to a big one.
func shake(amount: float, ceiling: float = 1.0) -> void:
	if shake_scale <= 0.0: return
	_trauma = maxf(_trauma, minf(_trauma + amount, ceiling))

func _physics_process(delta: float) -> void:
	var target := (get_parent() as Node3D).global_position + Vector3.UP * height
	var p := global_position.lerp(target, 1.0 - exp(-follow_rate * delta))
	p.y = lerpf(global_position.y, target.y, 1.0 - exp(-follow_rate_vertical * delta))
	global_position = p
	rotation = Vector3(0.0, yaw, 0.0)
	_pitch.rotation.x = pitch + _recoil
	_recoil = lerpf(_recoil, 0.0, 1.0 - exp(-18.0 * delta))
	_shake_time += delta
	var amp := _trauma * _trauma * shake_offset * shake_scale
	# Two sines at unrelated rates, not randf() per frame (that buzzes).
	_camera.h_offset = amp * sin(_shake_time * 47.0) * cos(_shake_time * 13.0)
	_camera.v_offset = -_kick + amp * sin(_shake_time * 53.0 + 1.3)
	_trauma = maxf(0.0, _trauma - 1.6 * delta)
	_kick = lerpf(_kick, 0.0, 1.0 - exp(-14.0 * delta))
	_camera.fov = lerpf(_camera.fov, _base_fov + fov_add, 1.0 - exp(-4.0 * delta))
