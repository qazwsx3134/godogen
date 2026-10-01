@tool
extends Control
## A jagged explosion balloon filling the node's rectangle, with a hard shadow and a thick edge.
## Drawn in the editor too. Put the text in a child Label/RichTextLabel laid out inside it.

@export var spikes: int = 16:
	set(value):
		spikes = value
		queue_redraw()
## How far the notches between spikes cut in (1 = no notch).
@export_range(0.3, 0.98) var inner_ratio: float = 0.8:
	set(value):
		inner_ratio = value
		queue_redraw()
@export var fill: Color = Color("#fff6c8"):
	set(value):
		fill = value
		queue_redraw()
@export var edge: Color = Color("#101010"):
	set(value):
		edge = value
		queue_redraw()
@export var edge_width: float = 14.0:
	set(value):
		edge_width = value
		queue_redraw()
@export var shadow_offset: Vector2 = Vector2(14, 16):
	set(value):
		shadow_offset = value
		queue_redraw()
@export var seed_value: int = 3:
	set(value):
		seed_value = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: Vector2 = size * 0.5 - Vector2.ONE * (edge_width * 0.5 + 2.0) - Vector2(maxf(shadow_offset.x, 0.0), maxf(shadow_offset.y, 0.0)) * 0.5
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(maxi(spikes, 3) * 2):
		var angle: float = TAU * float(index) / float(maxi(spikes, 3) * 2) - PI * 0.5
		var factor: float = rng.randf_range(0.92, 1.0) if index % 2 == 0 else inner_ratio * rng.randf_range(0.96, 1.04)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y) * factor)
	var shadow: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in points:
		shadow.append(point + shadow_offset)
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.45))
	draw_colored_polygon(points, fill)
	var outline: PackedVector2Array = points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, edge, edge_width, true)
