extends Node2D
@export var lifetime: float = 3.8
@export var radius: float = 42.0
var age: float = 0.0
func step(delta: float) -> void:
	age += delta
	modulate.a = minf(1.0, (lifetime - age) / 0.6)
	if age >= lifetime:
		queue_free()
