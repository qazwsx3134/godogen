extends Node2D
## Gameplay smoke owns both its readable damage footprint and translucent pixel wisps.
## It cannot be dropped by a cosmetic renderer budget; Street advances its simulation clock.
@export var lifetime: float = 3.8
@export var radius: float = 42.0
@export var damage: float = 4.0
var age: float = 0.0
@onready var footprint: Node2D = %Footprint
@onready var cloud: ColorRect = %Cloud

func _ready() -> void:
	footprint.scale = Vector2.ONE * radius / 42.0
	# A local material keeps overlapping hazards on independent clocks.
	cloud.material = cloud.material.duplicate()
	(cloud.material as ShaderMaterial).set_shader_parameter(&"seed", float(hash(position) % 1000) * 0.1)
	(cloud.material as ShaderMaterial).set_shader_parameter(&"progress", 0.0)

func step(delta: float) -> void:
	age += delta
	(cloud.material as ShaderMaterial).set_shader_parameter(&"progress", clampf(age / lifetime, 0.0, 1.0))
	# The boundary remains visible until the exact frame the damaging hazard expires.
	if age >= lifetime:
		queue_free()
