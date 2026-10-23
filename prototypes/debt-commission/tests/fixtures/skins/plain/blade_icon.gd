@tool
extends Control
## A test skin's life icon: a blade (a long diamond). Same properties as glasses_icon.gd.

@export var charged: bool = false:
	set(value):
		charged = value
		queue_redraw()
@export var broken: bool = false:
	set(value):
		broken = value
		queue_redraw()
@export var color: Color = Color.WHITE:
	set(value):
		color = value
		queue_redraw()
@export var crack_color: Color = Color.RED:
	set(value):
		crack_color = value
		queue_redraw()


func _draw() -> void:
	var c: Vector2 = size * 0.5
	var ink: Color = Color(color, 0.3) if broken else (Color("#f2c14e") if charged else color)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-size.x * 0.4, 0), c + Vector2(0, -size.y * 0.3),
		c + Vector2(size.x * 0.4, 0), c + Vector2(0, size.y * 0.3)]), ink)
	if broken:
		draw_line(c + Vector2(-6, -8), c + Vector2(6, 8), crack_color, 3.0)
