extends Node3D
## A travel point. Tapping it walks the player over; on arrival Main fades out, moves the player to `arrival`
## in zone `zone` and fades back in.

const TerrainHeight = preload("res://scripts/terrain_height.gd")

@export var label: String = "往蓬蓬村"
## Zone the portal leads to: "meadow" or "town".
@export var zone: String = "town"
@export var arrival: Vector3 = Vector3.ZERO

@onready var ring: MeshInstance3D = %Ring
@onready var title: Label3D = %Title
@onready var selection: MeshInstance3D = %Selection

var highlighted: bool = false:
	set(value):
		highlighted = value
		if is_node_ready():
			selection.visible = value

var _t: float = 0.0


func _ready() -> void:
	add_to_group("portal")
	title.text = label
	selection.visible = highlighted
	global_position.y = TerrainHeight.height(global_position.x, global_position.z)


func _process(delta: float) -> void:
	_t += delta
	ring.rotate_y(delta * 0.8)
	ring.scale = Vector3.ONE * (1.0 + sin(_t * 2.5) * 0.06)
