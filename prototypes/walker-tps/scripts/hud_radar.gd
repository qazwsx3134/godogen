@tool
extends Control
## Short-range tactical radar with camera-forward at the top.

@export_range(20.0, 300.0) var detection_range: float = 100.0
@export var grid_color := Color(0.44, 0.94, 0.98, 0.64)
@export_range(0.5, 10.0) var contour_interval := 2.0
const Layers := preload("res://scripts/layers.gd")
const GRID := 21
const RAYS_PER_TICK := 24
var contacts := PackedVector2Array()
var terrain_segments := PackedVector2Array()
var _heights := PackedFloat32Array()
var _actor: Node3D
var _origin := Vector2.ZERO
var _facing := Vector2(0, -1)
var _scan_center := Vector2(INF, INF)
var _grid_start := Vector2.ZERO
var _grid_step := 1.0
var _sample := GRID * GRID


func track_terrain(actor: Node3D) -> void:
	_actor = actor
	_heights.resize(GRID * GRID)


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_actor) or not is_visible_in_tree():
		return
	if _sample == GRID * GRID:
		var location := Vector2(_actor.global_position.x, _actor.global_position.z)
		if location.distance_to(_scan_center) < detection_range * 0.16:
			return
		_scan_center = location
		_grid_step = detection_range * 2.4 / (GRID - 1)
		_grid_start = location - Vector2.ONE * _grid_step * (GRID - 1) * 0.5
		_sample = 0
	var space := _actor.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.new()
	query.collision_mask = Layers.MAP_GROUND
	var stop := mini(_sample + RAYS_PER_TICK, GRID * GRID)
	while _sample < stop:
		@warning_ignore("integer_division")
		var point := _grid_start + Vector2(_sample % GRID, _sample / GRID) * _grid_step
		query.from = Vector3(point.x, 128, point.y)
		query.to = Vector3(point.x, -40, point.y)
		var ground := space.intersect_ray(query)
		_heights[_sample] = ground.position.y if not ground.is_empty() else NAN
		_sample += 1
	if _sample == GRID * GRID:
		_rebuild_contours()


func _rebuild_contours() -> void:
	terrain_segments.clear()
	for row in range(GRID - 1):
		for column in range(GRID - 1):
			var i := row * GRID + column
			var a := _heights[i]
			var b := _heights[i + 1]
			var c := _heights[i + GRID]
			var d := _heights[i + GRID + 1]
			if is_nan(a) or is_nan(b) or is_nan(c) or is_nan(d):
				continue
			var first := ceili(minf(minf(a, b), minf(c, d)) / contour_interval)
			var last := floori(maxf(maxf(a, b), maxf(c, d)) / contour_interval)
			var top_left := _grid_start + Vector2(column, row) * _grid_step
			var tr := top_left + Vector2.RIGHT * _grid_step
			var bl := top_left + Vector2.DOWN * _grid_step
			var br := top_left + Vector2.ONE * _grid_step
			for level in range(first, last + 1):
				var altitude := level * contour_interval
				_contour_triangle(top_left, tr, bl, Vector3(a, b, c), altitude)
				_contour_triangle(tr, br, bl, Vector3(b, d, c), altitude)
	queue_redraw()


func _contour_triangle(a: Vector2, b: Vector2, c: Vector2, heights: Vector3, level: float) -> void:
	var points := [a, b, c]
	for i in range(3):
		var j := (i + 1) % 3
		if (heights[i] < level) != (heights[j] < level):
			terrain_segments.append(points[i].lerp(points[j], inverse_lerp(heights[i], heights[j], level)))


func _radar_position(world_point: Vector2) -> Vector2:
	var delta := (world_point - _origin) / detection_range
	return Vector2(delta.dot(Vector2(-_facing.y, _facing.x)), -delta.dot(_facing))


func set_contacts(origin: Vector3, forward: Vector3, targets: Array[Node]) -> void:
	_origin = Vector2(origin.x, origin.z)
	_facing = Vector2(forward.x, forward.z)
	contacts.clear()
	for target: Node3D in targets:
		if target.get("health") <= 0.0:
			continue
		var relative := _radar_position(Vector2(target.global_position.x, target.global_position.z))
		if relative.length_squared() <= 1.0:
			contacts.append(relative)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(center.x, center.y) - 4.0
	if radius <= 0.0:
		return
	draw_circle(center, radius, Color(0.01, 0.07, 0.10, 0.52), true, -1.0, true)
	var contours := PackedVector2Array()
	for i in range(0, terrain_segments.size(), 2):
		var a := _radar_position(terrain_segments[i])
		var b := _radar_position(terrain_segments[i + 1])
		if a.length_squared() <= 0.96 and b.length_squared() <= 0.96:
			contours.append(center + a * radius)
			contours.append(center + b * radius)
	if not contours.is_empty():
		draw_multiline(contours, Color(0.31, 0.76, 0.70, 0.57), 1.0, true)
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
