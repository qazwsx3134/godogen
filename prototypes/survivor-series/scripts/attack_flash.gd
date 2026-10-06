extends Node2D
@export var lifetime: float = 0.24
var age: float = 0.0

func setup(mode: String, radius: float, direction: Vector2) -> void:
	%Arc.visible = mode != "kick"
	%Ring.visible = mode == "kick"
	rotation = direction.angle() if mode != "kick" else 0.0
	%Arc.scale = Vector2.ONE * (radius / 100.0)
	%Ring.scale = Vector2.ONE * (radius / 100.0)
	if mode == "heavy":
		%Arc.default_color = Color("ffc56b")
		%Arc.width = 12.0
	if mode == "kick":
		lifetime = 0.32

func _process(delta: float) -> void:
	age += delta
	modulate.a = clampf((lifetime - age) / lifetime, 0.0, 1.0)
	if age >= lifetime:
		queue_free()
