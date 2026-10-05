@tool
extends Control
## A bar of slanted stripes in two colours: the caution tape along the director's choice sheet and the
## clapper stick on each of its rows. Draws in the editor too, so the scene shows what the game does.
## The stripes are `stripe_width` wide (measured along the bar) and lean by the bar's height times
## `lean`; the control clips them to its own rectangle.

@export var color_a: Color = Color("#ffd400"):
	set(value):
		color_a = value
		queue_redraw()
@export var color_b: Color = Color("#101010"):
	set(value):
		color_b = value
		queue_redraw()
@export_range(4.0, 400.0, 1.0, "or_greater") var stripe_width: float = 36.0:
	set(value):
		stripe_width = value
		queue_redraw()
## Horizontal shift of a stripe from the top of the bar to its bottom, as a share of the bar's height.
@export_range(-2.0, 2.0, 0.05) var lean: float = 1.0:
	set(value):
		lean = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), color_b)
	var shift: float = size.y * lean
	var step: float = stripe_width * 2.0
	var x: float = -absf(shift) - step
	while x < size.x + absf(shift):
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, 0.0), Vector2(x + stripe_width, 0.0),
			Vector2(x + stripe_width + shift, size.y), Vector2(x + shift, size.y)]), color_a)
		x += step
