@tool
extends Node3D
## A field prop. block_radius > 0 makes it a circular obstacle (cells, before node scale) that
## the battle walks around; 0 is decoration. The ring is an editor-only gizmo.

@export_range(0.0, 4.0, 0.05) var block_radius: float = 0.0:
	set(value):
		block_radius = value
		_update_gizmo()


func _ready() -> void:
	_update_gizmo()


func _update_gizmo() -> void:
	var ring := get_node_or_null(^"BlockGizmo") as MeshInstance3D
	if ring == null:
		return
	ring.visible = Engine.is_editor_hint() and block_radius > 0.0
	ring.scale = Vector3.ONE * maxf(block_radius, 0.01)
