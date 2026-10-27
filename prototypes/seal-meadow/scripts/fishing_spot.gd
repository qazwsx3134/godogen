extends Node3D
## One editable pond-side fishing point.

const TerrainHeight = preload("res://scripts/terrain_height.gd")


func _ready() -> void:
	add_to_group("fishing_spot")
	global_position.y = TerrainHeight.height(global_position.x, global_position.z)
