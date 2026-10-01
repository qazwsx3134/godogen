extends Node3D
## First-person rig standing on a viewing platform. Put it where the platform deck's centre
## is; its local -Z is the direction the platform faces. Walking is clamped to a rectangle,
## looking to a yaw/pitch cone and zoom to a FOV range, so a spot only has to dress what
## the cone can see.

@export var half_extents := Vector2(3.6, 2.6)
@export var eye_height := 1.6
@export var move_speed := 2.4
@export var look_deg_per_px := 0.12
@export_range(0.0, 180.0) var yaw_limit_deg := 60.0
@export var pitch_min_deg := -35.0
@export var pitch_max_deg := 45.0
@export var start_pitch_deg := 14.0
@export var fov_default := 55.0
@export var fov_min := 18.0
@export var fov_max := 65.0

## On-screen stick: x = strafe right, y = forward. Length <= 1.
var move_input := Vector2.ZERO
var offset := Vector2.ZERO   ## walked distance from the deck centre (x, z) in local space
var yaw := 0.0               ## degrees, + turns left
var pitch := 0.0             ## degrees, + looks up

@onready var camera: Camera3D = %Camera


func _ready() -> void:
	reset_view()


func _process(delta: float) -> void:
	var input := move_input
	if input == Vector2.ZERO:
		input = Vector2(
			float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
			float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S)))
		input = input.limit_length(1.0)
	if input != Vector2.ZERO:
		walk(input * move_speed * delta)


func walk(step: Vector2) -> void:
	## step.x right, step.y forward, metres, relative to where the camera looks.
	var a := deg_to_rad(yaw)
	var forward := Vector2(-sin(a), -cos(a))
	var right := Vector2(cos(a), -sin(a))
	set_offset(offset + right * step.x + forward * step.y)


func set_offset(value: Vector2) -> void:
	offset = value.clamp(-half_extents, half_extents)
	camera.position = Vector3(offset.x, eye_height, offset.y)


func look(drag_px: Vector2) -> void:
	## Swipe right turns right, swipe up looks up. Slower when zoomed in.
	var k := look_deg_per_px * camera.fov / fov_default
	set_angles(yaw - drag_px.x * k, pitch - drag_px.y * k)


func set_angles(new_yaw: float, new_pitch: float) -> void:
	yaw = clampf(new_yaw, -yaw_limit_deg, yaw_limit_deg)
	pitch = clampf(new_pitch, pitch_min_deg, pitch_max_deg)
	camera.rotation = Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0.0)


func zoom(factor: float) -> void:
	## factor > 1 zooms in (pinch spread, wheel up).
	set_fov(camera.fov / factor)


func set_fov(value: float) -> void:
	camera.fov = clampf(value, fov_min, fov_max)


func is_zoomed() -> bool:
	return camera.fov < fov_default - 1.0


func reset_view() -> void:
	set_offset(Vector2.ZERO)
	set_angles(0.0, start_pitch_deg)
	set_fov(fov_default)
