extends Node3D
## The pet walking behind the player: a small sprite actor that keeps `follow_distance` and shows its type's name.

const TerrainHeight = preload("res://scripts/terrain_height.gd")
const PetRules = preload("res://scripts/pet_rules.gd")

@export var follow_distance: float = 1.6
@export var speed: float = 6.0

@onready var actor: Node3D = $Actor

var player: Node3D


func _process(delta: float) -> void:
	if player == null:
		return
	var to := player.global_position - global_position
	to.y = 0.0
	if to.length() > 12.0:  # left behind (travel, respawn): appear next to the player
		global_position = player.global_position + Vector3(-1.0, 0.0, 0.6)
	elif to.length() > follow_distance:
		global_position += to.normalized() * minf(speed * delta, to.length() - follow_distance)
		actor.face(to)
	actor.moving = to.length() > follow_distance + 0.05
	global_position.y = TerrainHeight.height(global_position.x, global_position.z)
	var p = player.pet
	actor.display_name = "%s +%d%s" % [PetRules.TYPE_NAMES.get(p.type, p.type), p.level, "（餓）" if p.is_hungry() else ""]
