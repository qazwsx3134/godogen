@tool
extends Control
## Short-range tactical radar with camera-forward at the top.

@export var detection_range: float = 100.0
@export var grid_color := Color(0.44, 0.94, 0.98, 0.64)
var contacts := PackedVector2Array()


func set_contacts(origin: Vector3, forward: Vector3, targets: Array[Node]) -> void:
	var right := forward.cross(Vector3.UP)
	contacts.clear()
	for target: Node3D in targets:
		if target.get("health") <= 0.0:
			continue
		var delta := target.global_position - origin
		var relative := Vector2(delta.dot(right), -delta.dot(forward)) / detection_range
		if relative.length_squared() <= 1.0:
			contacts.append(relative)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(center.x, center.y) - 4.0
	if radius <= 0.0:
		return
	draw_circle(center, radius, Color(0.01, 0.07, 0.10, 0.30), true, -1.0, true)
	draw_arc(center, radius, 0, TAU, 64, grid_color, 1.4, true)
	draw_arc(center, radius * 0.5, 0, TAU, 48, grid_color * Color(1, 1, 1, 0.55), 1.0, true)
	for axis: Vector2 in [Vector2.RIGHT, Vector2.DOWN]:
		draw_line(center - axis * radius, center + axis * radius, grid_color, 1.0, true)
	var ownship := PackedVector2Array([center + Vector2(-5, 5), center + Vector2(0, -8),
		center + Vector2(5, 5)])
	draw_colored_polygon(ownship, grid_color)
	for contact: Vector2 in contacts:
		var point := center + contact * (radius - 5)
		var diamond := PackedVector2Array([point + Vector2(0, -5), point + Vector2(5, 0),
			point + Vector2(0, 5), point + Vector2(-5, 0), point + Vector2(0, -5)])
		draw_polyline(diamond, Color(1.0, 0.65, 0.43), 2.0, true)
