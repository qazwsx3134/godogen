extends Node3D
## A town NPC standing on the terrain. Tapping it walks the player over; Main opens the NPC panel on arrival.

const TerrainHeight = preload("res://scripts/terrain_height.gd")

@export var npc_name: String = "村長"

@onready var actor: Node3D = $Actor


func _ready() -> void:
	add_to_group("npc")
	actor.display_name = npc_name
	global_position.y = TerrainHeight.height(global_position.x, global_position.z)
