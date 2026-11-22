@tool
extends Control
## Armored walker silhouette, drawn as a slanted diagnostic view.

@export var accent := Color(0.48, 0.98, 1.0)
var fraction := 1.0:
	set(value):
		value = clampf(value, 0.0, 1.0)
		if not is_equal_approx(fraction, value):
			fraction = value
			queue_redraw()


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var tint := accent if fraction > 0.25 else Color(1.0, 0.45, 0.26)
	draw_set_transform(Vector2(size.x * 0.5, 26), 0.0, Vector2.ONE * minf(1.0, size.x / 150.0))
	var steel := Color(0.04, 0.22, 0.28, 0.95)
	var shadow := Color(0.018, 0.07, 0.11, 0.97)
	var rim := tint.darkened(0.34)
	for side: float in [-1.0, 1.0]:
		for row: float in [-1.0, 1.0]:
			var hip := Vector2(side * 13, row * 7)
			var knee := Vector2(side * (30 + row * 3), row * 12 - 2)
			var foot := Vector2(side * (39 + row * 5), row * 18 + 3)
			draw_polyline(PackedVector2Array([hip, knee, foot]), shadow, 10, true)
			draw_line(hip, knee, steel, 6, true)
			draw_line(knee, foot, steel, 4.5, true)
			draw_polyline(PackedVector2Array([hip, knee, foot]), rim, 1.1, true)
			draw_circle(knee, 3.0, tint, false, 1.3, true)
			draw_line(foot - Vector2(4, 0), foot + Vector2(4, 0), tint, 2.0, true)

	_plate([Vector2(-20, -4), Vector2(-12, -16), Vector2(12, -16), Vector2(20, -4),
		Vector2(17, 13), Vector2(8, 20), Vector2(-8, 20), Vector2(-17, 13)], shadow, rim)
	_plate([Vector2(-11, -16), Vector2(11, -16), Vector2(17, -2), Vector2(10, 11),
		Vector2(-10, 11), Vector2(-17, -2)], steel, tint)
	_plate([Vector2(-7, -6), Vector2(7, -6), Vector2(10, 2), Vector2(6, 8),
		Vector2(-6, 8), Vector2(-10, 2)], shadow, rim)
	draw_line(Vector2(0, 1), Vector2(0, -23), shadow, 7, true)
	draw_line(Vector2(0, 1), Vector2(0, -23), tint, 3, true)
	draw_line(Vector2(-4, -23), Vector2(4, -23), tint, 2, true)
	for side: float in [-1.0, 1.0]:
		for row: int in range(3):
			draw_line(Vector2(11 * side, row * 3 - 3), Vector2(14 * side, row * 3 - 4), tint, 1, true)

	for index in 12:
		var x := -67.0 + 11.0 * index
		var filled := clampf(fraction * 12.0 - index, 0.0, 1.0)
		_plate([Vector2(x + 2, 30), Vector2(x + 9, 30), Vector2(x + 7, 36), Vector2(x, 36)], shadow, steel)
		if filled > 0.0:
			draw_colored_polygon(PackedVector2Array([Vector2(x + 2, 30), Vector2(x + 2 + filled * 7, 30),
				Vector2(x + filled * 7, 36), Vector2(x, 36)]), tint)


func _plate(points: Array[Vector2], fill: Color, line: Color) -> void:
	var polygon := PackedVector2Array(points)
	draw_colored_polygon(polygon, fill)
	polygon.append(points[0])
	draw_polyline(polygon, line, 1.0, true)
