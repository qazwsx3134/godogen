extends Node3D
## The meadow map: sky and sun presets (T toggles day and dusk) and the circles that block walking.

const TerrainHeight = preload("res://scripts/terrain_height.gd")

@export var day_environment: Environment
@export var dusk_environment: Environment
@export var day_sun: Color = Color("fff1d6")
@export var dusk_sun: Color = Color("b7c2ff")
@export var day_energy: float = 0.9
@export var dusk_energy: float = 0.7

@onready var world_environment: WorldEnvironment = %WorldEnvironment
@onready var sun: DirectionalLight3D = %Sun
@onready var props: Node3D = %Props

var dusk: bool = false


func toggle_time() -> void:
	dusk = not dusk
	world_environment.environment = dusk_environment if dusk else day_environment
	sun.light_color = dusk_sun if dusk else day_sun
	sun.light_energy = dusk_energy if dusk else day_energy


## Vector3(x, z, radius) for every prop whose block_radius > 0, and the pond.
func blockers() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for prop: Node3D in props.get_children():
		var r: float = prop.get_meta(&"block_radius", 0.0) * prop.scale.x
		if r > 0.0:
			out.append(Vector3(prop.position.x, prop.position.z, r))
	out.append(Vector3(TerrainHeight.POND.x, TerrainHeight.POND.y, TerrainHeight.POND_BLOCK))
	return out
