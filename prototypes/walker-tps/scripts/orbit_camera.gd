extends Node3D
## Third-person orbit rig: top_level, follows its parent (the walker) with a little lag, yaw on this node,
## pitch on %Pitch, distance on %Arm (SpringArm3D pulls in when terrain is in the way, never the walker itself).

@export var height: float = 3.3
@export var follow_rate: float = 10.0
## Slower vertical follow, so a jump visibly lifts the walker in the frame.
@export var follow_rate_vertical: float = 3.5
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
var _base_fov: float

func _ready() -> void:
	var body := get_parent() as CollisionObject3D
	_arm.add_excluded_object(body.get_rid())
	global_position = body.global_position + Vector3.UP * height
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

func _physics_process(delta: float) -> void:
	var target := (get_parent() as Node3D).global_position + Vector3.UP * height
	var p := global_position.lerp(target, 1.0 - exp(-follow_rate * delta))
	p.y = lerpf(global_position.y, target.y, 1.0 - exp(-follow_rate_vertical * delta))
	global_position = p
	rotation = Vector3(0.0, yaw, 0.0)
	_pitch.rotation.x = pitch
	_camera.v_offset = -_kick
	_kick = lerpf(_kick, 0.0, 1.0 - exp(-14.0 * delta))
	_camera.fov = lerpf(_camera.fov, _base_fov + fov_add, 1.0 - exp(-4.0 * delta))
