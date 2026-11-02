extends Node2D
## The ring notes must reach on the beat.

@export var radius := 15.0


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius + 3.0, Color(1, 0.97, 0.9, 0.9), false, 2.0)
	draw_circle(Vector2.ZERO, radius, Color(0.16, 0.15, 0.24, 0.55))
