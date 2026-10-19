class_name CameraRig
extends Node3D
## Follows the target smoothly. The camera's angle and distance are the child Camera3D's transform in the scene.
## Shake moves Camera3D.h_offset / v_offset only (trauma squared, two sines), so the view direction never changes.
## The narrow side of the screen keeps the field of view: portrait phones see as far sideways as landscape ones do up.

@export var target: Node3D
@export var follow_rate: float = 7.0
@export var trauma_decay: float = 2.0
@export var max_shake: float = 0.3
## The reference shakes its three axes at about 4.6 / 7.0 / 5.4 Hz.
@export var shake_hz: float = 6.0

var trauma: float = 0.0
## Camera distance multiplier (Chibaku Tensei pulls back); eases toward `_zoom_target`.
var zoom: float = 1.0
var _zoom_target: float = 1.0
var _base := Vector3.ZERO
var _clock: float = 0.0

@onready var camera: Camera3D = %Camera


func zoom_to(target: float) -> void:
	_zoom_target = target


func _ready() -> void:
	_base = camera.position
	get_viewport().size_changed.connect(_fit)
	_fit()
	if target:
		global_position = target.global_position


## Re-aims the camera: `pitch_degrees` down from the horizon, `distance` meters from the target (QA tuning).
func set_view(pitch_degrees: float, distance: float) -> void:
	var pitch: float = deg_to_rad(pitch_degrees)
	camera.position = Vector3(0.0, sin(pitch) * distance + 1.0, cos(pitch) * distance)
	camera.rotation = Vector3(-pitch, 0.0, 0.0)
	_base = camera.position


func add_trauma(amount: float, ceiling: float = 1.0) -> void:
	trauma = maxf(trauma, minf(trauma + amount, ceiling))


func step(dt: float, real_dt: float) -> void:
	if target:
		global_position = global_position.lerp(target.global_position, 1.0 - exp(-follow_rate * dt))
	zoom = lerpf(zoom, _zoom_target, 1.0 - exp(-3.0 * real_dt))
	camera.position = _base * zoom
	# Shake runs on real time: a hit stop freezes the game, not the punch.
	trauma = maxf(trauma - trauma_decay * real_dt, 0.0)
	_clock += real_dt
	var a: float = trauma * trauma * max_shake
	var t: float = TAU * shake_hz * _clock
	camera.h_offset = a * (0.62 * sin(t) + 0.38 * sin(t * 1.55 + 2.0))
	camera.v_offset = a * (0.62 * sin(t + 11.0) + 0.38 * sin(t * 1.55 + 22.0))


func _fit() -> void:
	var size: Vector2 = get_viewport().get_visible_rect().size
	camera.keep_aspect = Camera3D.KEEP_HEIGHT if size.x >= size.y else Camera3D.KEEP_WIDTH
