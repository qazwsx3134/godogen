@tool
extends Control
## Shinpachi's glasses, cracked through (drawn, so the Game Over scene needs no image).

@export var frame_color: Color = Color("#e6e5dc")
@export var crack_color: Color = Color("#ffffff")


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var unit: float = size.y / 100.0
	var radius: float = 34.0 * unit
	var left: Vector2 = Vector2(size.x * 0.5 - 46.0 * unit, size.y * 0.5)
	var right: Vector2 = Vector2(size.x * 0.5 + 46.0 * unit, size.y * 0.5)
	for lens: Vector2 in [left, right]:
		draw_circle(lens, radius, Color(1, 1, 1, 0.06))
		draw_arc(lens, radius, 0.0, TAU, 64, frame_color, 5.0 * unit, true)
	draw_arc(size * 0.5 - Vector2(0, 2 * unit), 12.0 * unit, PI * 1.1, PI * 1.9, 16, frame_color, 4.0 * unit, true)
	draw_line(left - Vector2(radius, 6 * unit), left - Vector2(radius + 18 * unit, 12 * unit), frame_color, 4.0 * unit)
	draw_line(right + Vector2(radius, -6 * unit), right + Vector2(radius + 18 * unit, -12 * unit), frame_color, 4.0 * unit)
	# The right lens is shattered: a star of cracks and a missing shard.
	var hit: Vector2 = right + Vector2(6, -4) * unit
	for angle: float in [0.3, 1.2, 2.1, 2.9, 3.8, 4.9, 5.7]:
		var bend: Vector2 = hit + Vector2.from_angle(angle) * radius * 0.45 + Vector2.from_angle(angle + 1.4) * 4.0 * unit
		draw_polyline(PackedVector2Array([hit, bend, hit + Vector2.from_angle(angle + 0.12) * radius * 0.95]), crack_color, 1.5 * unit, true)
	draw_colored_polygon(PackedVector2Array([hit + Vector2(4, 10) * unit, right + Vector2(22, 22) * unit,
		right + Vector2(4, 32) * unit]), Color(0.05, 0.05, 0.06))
	draw_polyline(PackedVector2Array([left + Vector2(-14, -20) * unit, left + Vector2(-2, -6) * unit,
		left + Vector2(-8, 8) * unit]), crack_color, 1.2 * unit, true)
