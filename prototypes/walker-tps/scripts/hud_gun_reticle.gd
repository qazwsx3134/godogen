@tool
extends Label
## Screen-projected cannon marker. Drawn in geometry so it has no font dependency.

func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var center := size * 0.5
	var orange := Color(1.0, 0.63, 0.21)
	draw_arc(center, 9.0, 0, TAU, 32, Color(0.12, 0.04, 0.01, 0.94), 4.5, true)
	draw_arc(center, 9.0, 0, TAU, 32, orange, 2.0, true)
	for side: float in [-1.0, 1.0]:
		draw_line(center + Vector2(11 * side, 0), center + Vector2(15 * side, 0), orange, 2.0, true)
