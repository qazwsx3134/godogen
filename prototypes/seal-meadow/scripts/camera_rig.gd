extends Node3D
## RO-style follow camera: fixed pitch looking down at the player, right-drag turns it, the wheel zooms.
## The rig sits on the player; the camera is its child at (0, 0, distance).

@export var target_path: NodePath
@export var pitch_deg: float = -42.0
@export var distance: float = 14.0
@export var min_distance: float = 7.0
@export var max_distance: float = 24.0
@export var turn_speed: float = 0.35
@export var follow_sharpness: float = 10.0

@onready var camera: Camera3D = $Camera

var yaw: float = 0.0
var _dragging: bool = false
var _target: Node3D


func _ready() -> void:
	_target = get_node_or_null(target_path) as Node3D
	yaw = rotation.y
	if _target:
		global_position = _target.global_position + Vector3.UP


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_RIGHT:
				_dragging = event.pressed
			MOUSE_BUTTON_WHEEL_UP:
				distance = maxf(min_distance, distance - 1.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				distance = minf(max_distance, distance + 1.0)
	elif event is InputEventMouseMotion and _dragging:
		yaw -= deg_to_rad(event.relative.x * turn_speed)


func _process(delta: float) -> void:
	if _target:
		var goal := _target.global_position + Vector3.UP
		global_position = global_position.lerp(goal, 1.0 - exp(-follow_sharpness * delta))
	rotation = Vector3(deg_to_rad(pitch_deg), yaw, 0.0)
	camera.position = camera.position.lerp(Vector3(0.0, 0.0, distance), 1.0 - exp(-8.0 * delta))
