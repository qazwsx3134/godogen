@tool
extends Control
## Four-legged walker silhouette above a segmented armor gauge.

@export var accent := Color(0.48, 0.98, 1.0)
var fraction := 1.0:
	set(value):
		value = clampf(value, 0.0, 1.0)
		if not is_equal_approx(fraction, value):
			fraction = value
			queue_redraw()


func _draw() -> void:
	var tint := accent if fraction > 0.25 else Color(1.0, 0.45, 0.26)
	draw_set_transform(Vector2(size.x * 0.5, 24.0))
	var hull := PackedVector2Array([Vector2(-10, -13), Vector2(10, -13), Vector2(16, -6),
		Vector2(16, 11), Vector2(7, 17), Vector2(-7, 17), Vector2(-16, 11),
		Vector2(-16, -6), Vector2(-10, -13)])
	draw_colored_polygon(hull, Color(0.01, 0.10, 0.15, 0.85))
	draw_polyline(hull, tint, 2.0, true)
	draw_line(Vector2(0, 4), Vector2(0, -23), tint, 4.0, true)
	for side: float in [-1.0, 1.0]:
		for axle: float in [-1.0, 1.0]:
			draw_polyline(PackedVector2Array([Vector2(side * 13, axle * 8),
				Vector2(side * 25, axle * 14), Vector2(side * 31, axle * 22),
				Vector2(side * 38, axle * 22)]), tint, 2.0, true)
	for index in 12:
		var segment := Rect2(-67 + 11 * index, 31, 9, 5)
		draw_rect(segment, Color(0.01, 0.09, 0.12, 0.9))
		var filled := clampf(fraction * 12.0 - index, 0.0, 1.0)
		draw_rect(Rect2(segment.position, Vector2(segment.size.x * filled, segment.size.y)), tint)
