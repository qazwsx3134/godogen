@tool
extends Node2D
## Manga speed lines radiating from a point (the final round). flash() makes them pop on the beat.

@export var lines := 28
@export var inner := 70.0
@export var outer := 520.0

var _alpha := 0.25


func flash() -> void:
	var tw := create_tween()
	tw.tween_method(_set_alpha, 0.55, 0.2, 0.25)


func _set_alpha(v: float) -> void:
	_alpha = v
	queue_redraw()


func _draw() -> void:
	for i in lines:
		var a := TAU * i / lines + (0.05 if i % 2 else 0.0)
		var d := Vector2.from_angle(a)
		var side := d.orthogonal() * (5.0 if i % 3 == 0 else 2.5)
		draw_colored_polygon(PackedVector2Array([d * inner, d * outer + side, d * outer - side]),
			Color(1, 1, 1, _alpha))
