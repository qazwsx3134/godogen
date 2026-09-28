@tool
extends Control
## One pair of glasses in the HUD's life row (scenes/ui/glasses_icon.tscn). A lost pair is drawn
## faint with a cracked lens.

@export var broken: bool = false:
	set(value):
		broken = value
		queue_redraw()
@export var color: Color = Color("#e6e5dc"):
	set(value):
		color = value
		queue_redraw()
@export var crack_color: Color = Color("#ffb2a1"):
	set(value):
		crack_color = value
		queue_redraw()


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var unit: float = size.y / 36.0
	var radius: float = 10.0 * unit
	var ink: Color = Color(color, 0.35) if broken else color
	var width: float = 3.0 * unit
	var left: Vector2 = Vector2(size.x * 0.5 - 12.5 * unit, size.y * 0.55)
	var right: Vector2 = Vector2(size.x * 0.5 + 12.5 * unit, size.y * 0.55)
	for lens: Vector2 in [left, right]:
		draw_circle(lens, radius, Color(ink, 0.12))
		draw_arc(lens, radius, 0.0, TAU, 32, ink, width, true)
	draw_line(left + Vector2(radius, -2 * unit), right - Vector2(radius, 2 * unit), ink, width * 0.8)
	draw_line(left - Vector2(radius, 2 * unit), left - Vector2(radius + 3 * unit, 5 * unit), ink, width * 0.8)
	draw_line(right + Vector2(radius, -2 * unit), right + Vector2(radius + 3 * unit, -5 * unit), ink, width * 0.8)
	if broken:
		var hit: Vector2 = right + Vector2(2, -2) * unit
		for angle: float in [0.4, 1.9, 3.3, 4.8]:
			draw_line(hit, hit + Vector2.from_angle(angle) * radius * 0.95, crack_color, 1.6 * unit, true)
