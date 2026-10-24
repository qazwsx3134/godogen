@tool
extends Node3D
## The camp: a safe circle (monsters stay out, quests are claimed here, the shop and warehouse
## open here). The ring under it is part of the game, so players see where safety ends.

@export_range(1.0, 6.0, 0.1) var radius: float = 3.0:
	set(value):
		radius = value
		var ring := get_node_or_null(^"SafeRing") as Node3D
		if ring != null:
			ring.scale = Vector3(radius, 1.0, radius)


func _ready() -> void:
	radius = radius
