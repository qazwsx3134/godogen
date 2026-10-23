@tool
extends Control
## Brush-stroke corner brackets around the current 章節選擇 card (scenes/ui/episode_card.tscn): a
## thick stroke on the top-right and bottom-left corners, each tapering at its end like a brush.

@export var color: Color = Color("#a8323e"):
	set(value):
		color = value
		queue_redraw()
## Stroke thickness and arm length in px.
@export var thickness: float = 12.0:
	set(value):
		thickness = value
		queue_redraw()
@export var arm: float = 120.0:
	set(value):
		arm = value
		queue_redraw()
## How far the brackets stand outside the card.
@export var outset: float = 14.0:
	set(value):
		outset = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var top_right: Vector2 = Vector2(size.x + outset, -outset)
	var bottom_left: Vector2 = Vector2(-outset, size.y + outset)
	_stroke(top_right, top_right + Vector2(-arm, 0.0))
	_stroke(top_right, top_right + Vector2(0.0, arm * 0.7))
	_stroke(bottom_left, bottom_left + Vector2(arm, 0.0))
	_stroke(bottom_left, bottom_left + Vector2(0.0, -arm * 0.7))


## A stroke from the corner that thins out towards its end.
func _stroke(from: Vector2, to: Vector2) -> void:
	var direction: Vector2 = (to - from).normalized()
	var normal: Vector2 = Vector2(-direction.y, direction.x)
	var start: Vector2 = from - direction * thickness * 0.5
	draw_colored_polygon(PackedVector2Array([
		start + normal * thickness * 0.5, to + normal * thickness * 0.12,
		to - normal * thickness * 0.12, start - normal * thickness * 0.5]), color)
