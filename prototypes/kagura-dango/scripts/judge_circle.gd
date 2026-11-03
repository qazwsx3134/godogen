extends Node2D
## The ring notes must reach on the beat. burst() flashes it on a hit: a ring that grows and fades, gold and bigger
## for an ace.

@export var radius := 15.0

var _burst := 1.0  # 0 → 1 over one burst; 1 = none
var _burst_color := Color.WHITE
var _burst_big := false
var _tween: Tween


func burst(color: Color, big: bool) -> void:
	_burst_color = color
	_burst_big = big
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_burst, 0.0, 1.0, 0.3 if big else 0.2).set_ease(Tween.EASE_OUT)


func _set_burst(v: float) -> void:
	_burst = v
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius + 3.0, Color(1, 0.97, 0.9, 0.9), false, 2.0)
	draw_circle(Vector2.ZERO, radius, Color(0.16, 0.15, 0.24, 0.55))
	if _burst < 1.0:
		var fade := 1.0 - _burst
		draw_circle(Vector2.ZERO, radius, Color(_burst_color, 0.6 * fade))
		var grow := radius * (1.7 if _burst_big else 0.9) * _burst
		draw_circle(Vector2.ZERO, radius + 4.0 + grow, Color(_burst_color, fade), false, 1.0 + 3.0 * fade)
