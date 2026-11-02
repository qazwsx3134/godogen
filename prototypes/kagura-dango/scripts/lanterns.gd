@tool
extends Node2D
## Paper lanterns along the curtain; flash() lights them on the beat.

@export var count := 9
@export var width := 900.0

var _glow := 0.0


func flash(strength: float) -> void:
	var tw := create_tween()
	tw.tween_method(_set_glow, strength, 0.0, 0.3)


func _set_glow(v: float) -> void:
	_glow = v
	queue_redraw()


func _draw() -> void:
	var lit := Color(1.0, 0.85, 0.45).lerp(Color(1, 1, 0.9), _glow)
	for i in count:
		var x := -width / 2.0 + (i + 0.5) * width / count
		draw_line(Vector2(x, -12), Vector2(x, 0), Color(0.2, 0.15, 0.1), 2)
		draw_rect(Rect2(x - 9, 0, 18, 24), Color(0.95, 0.4, 0.25).lerp(lit, 0.3 + _glow))
		draw_rect(Rect2(x - 9, 0, 18, 24), Color(0.3, 0.12, 0.08), false, 1.5)
