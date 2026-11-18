@tool
extends Control
## The center matches the viewport point used by the weapons ray.

@export var accent := Color(0.51, 0.99, 1.0, 0.98)
@export var frame_color := Color(0.42, 0.94, 0.98, 0.72)
@export_range(0.5, 2.0) var sight_scale := 1.0

var heading_degrees := 180:
	set(value):
		if heading_degrees != value:
			heading_degrees = value
			queue_redraw()


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var center := size * 0.5
	var half_frame := size / (6.0 * sight_scale) + Vector2(4.0, 4.0)
	draw_set_transform(center, 0.0, Vector2.ONE * sight_scale)
	for side: float in [-1.0, 1.0]:
		_stroke(Vector2(17.0 * side, 0), Vector2(46.0 * side, 0), accent, 3.0)
		_stroke(Vector2(0, 19.0 * side), Vector2(0, 42.0 * side), accent, 3.0)
		var x := half_frame.x * side
		_stroke(Vector2(x, -half_frame.y), Vector2(x, half_frame.y), frame_color)
		for y: float in [-half_frame.y, half_frame.y]:
			_stroke(Vector2(x, y), Vector2(x - 48.0 * side, y), accent, 3.0)
		for tick: int in range(-2, 3):
			var length := 18.0 if tick == 0 else 9.0
			_stroke(Vector2(x, tick * half_frame.y / 3.0), Vector2(x + length * side, tick * half_frame.y / 3.0), frame_color)
	draw_circle(Vector2.ZERO, 2.0, accent, true, -1.0, true)

	# Moving heading tape. Each short tick is 5 degrees and each long tick is 15.
	draw_set_transform(Vector2(center.x, 92))
	var nearest_tick := heading_degrees - posmod(heading_degrees, 5)
	for offset: int in range(-5, 7):
		var degrees := nearest_tick + offset * 5
		var x := float(degrees - heading_degrees) * 4.4
		if absf(x) > 121.0:
			continue
		var length := 13.0 if posmod(degrees, 15) == 0 else 6.0
		_stroke(Vector2(x, 0), Vector2(x, length), frame_color)
	_stroke(Vector2(0, -6), Vector2(0, 17), accent, 3.0)


func _stroke(from: Vector2, to: Vector2, color: Color, width: float = 2.0) -> void:
	draw_line(from, to, Color(0.0, 0.08, 0.12, 0.7), width + 2.0, true)
	draw_line(from, to, color, width, true)
