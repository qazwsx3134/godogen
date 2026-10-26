extends Node3D
## Fixed follow camera: yaw, pitch and distance are set in the scene and never change from input (D04).
## The rig sits on the player; the camera is its child at (0, 0, distance).

@export var target_path: NodePath
@export var pitch_deg: float = -42.0
@export var distance: float = 14.0
@export var follow_sharpness: float = 10.0

@onready var camera: Camera3D = $Camera

var yaw: float = 0.0
var _target: Node3D


func _ready() -> void:
	_target = get_node_or_null(target_path) as Node3D
	yaw = rotation.y
	if _target:
		global_position = _target.global_position + Vector3.UP


func _process(delta: float) -> void:
	if _target:
		var goal := _target.global_position + Vector3.UP
		global_position = global_position.lerp(goal, 1.0 - exp(-follow_sharpness * delta))
	rotation = Vector3(deg_to_rad(pitch_deg), yaw, 0.0)
	camera.position = camera.position.lerp(Vector3(0.0, 0.0, distance), 1.0 - exp(-8.0 * delta))
