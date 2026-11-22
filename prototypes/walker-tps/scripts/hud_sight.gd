@tool
extends Control
## The center matches the viewport point used by the weapons ray.

@export var accent := Color(0.51, 0.99, 1.0, 0.98)
@export var frame_color := Color(0.42, 0.94, 0.98, 0.72)
@export_range(0.5, 2.0) var sight_scale := 1.0
@export_range(0.5, 2.0) var reticle_scale := 1.0

var drift := Vector2.ZERO:
	set(value):
		if value.distance_squared_to(drift) > 0.0001:
			drift = value
			queue_redraw()

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
	draw_set_transform(center + drift, 0.0, Vector2.ONE * sight_scale)
	for side: float in [-1.0, 1.0]:
		var x := half_frame.x * side
		_stroke(Vector2(x, -half_frame.y), Vector2(x, half_frame.y), frame_color)
		for y: float in [-half_frame.y, half_frame.y]:
			_stroke(Vector2(x, y), Vector2(x - 48.0 * side, y), accent, 3.0)
		for tick: int in range(-2, 3):
			var length := 18.0 if tick == 0 else 9.0
			_stroke(Vector2(x, tick * half_frame.y / 3.0), Vector2(x + length * side, tick * half_frame.y / 3.0), frame_color)
	# A short split diamond leaves the center clear against silhouettes.
	draw_set_transform(center + drift, 0.0, Vector2.ONE * reticle_scale)
	for quadrant: float in [-1.0, 1.0]:
		for vertical: float in [-1.0, 1.0]:
			_stroke(Vector2(6 * quadrant, 4 * vertical), Vector2(12 * quadrant, 10 * vertical), accent, 2.2)
			_stroke(Vector2(12 * quadrant, 10 * vertical), Vector2(19 * quadrant, 10 * vertical), accent, 2.2)
	draw_circle(Vector2.ZERO, 3.2, Color(0.02, 0.08, 0.12, 0.95), true, -1.0, true)
	draw_circle(Vector2.ZERO, 1.8, accent, true, -1.0, true)
	draw_set_transform(drift * 0.65)
	_draw_canopy()

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


## Project the ribs toward the same vanishing point on both sides of the glass.
func _draw_canopy() -> void:
	var faint := Color(0.23, 0.64, 0.72, 0.32)
	var rim := Color(0.28, 0.79, 0.84, 0.48)
	for side: float in [-1.0, 1.0]:
		var edge := (1.0 + side) * 0.5
		var outer := Vector2((edge - side * 0.010) * size.x, size.y * 0.27)
		var joint := Vector2((edge - side * 0.063) * size.x, size.y * 0.52)
		var lower_joint := Vector2((edge - side * 0.038) * size.x, size.y * 0.80)
		var foot := Vector2((edge - side * 0.12) * size.x, size.y * 0.98)
		var inner := joint.lerp(size * Vector2(0.5, 0.49), 0.09)
		draw_colored_polygon(PackedVector2Array([outer, joint, lower_joint, foot,
			Vector2(edge * size.x, size.y), Vector2(edge * size.x, outer.y)]), Color(0.008, 0.025, 0.04, 0.27))
		_stroke(outer, joint, faint, 2)
		_stroke(joint, lower_joint, rim, 2)
		_stroke(lower_joint, foot, faint, 2)
		_stroke(joint, inner, rim, 2)
		for tick in range(5):
			var amount := float(tick + 1) / 6.0
			var point := joint.lerp(lower_joint, amount)
			_stroke(point, point + Vector2(-side * lerpf(7.0, 15.0, amount), 3), rim, 1)
		_stroke(Vector2((edge - side * 0.12) * size.x, size.y * 0.12), outer, faint, 1)
