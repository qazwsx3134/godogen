@tool
extends Control
## Concentration lines for a manga overlay: thin spikes that start outside a clear area around the
## centre and run past the edge. Drawn in the editor too, so a preset scene shows them unplayed.

@export var line_count: int = 64:
	set(value):
		line_count = value
		queue_redraw()
@export var ink: Color = Color(1, 1, 1, 0.3):
	set(value):
		ink = value
		queue_redraw()
## Share of the shorter side left empty around the centre.
@export_range(0.05, 0.9) var clear_radius: float = 0.32:
	set(value):
		clear_radius = value
		queue_redraw()
@export var center_ratio: Vector2 = Vector2(0.5, 0.5):
	set(value):
		center_ratio = value
		queue_redraw()
## Seeds the spread of the lines, so the same scene always draws the same picture.
@export var seed_value: int = 7:
	set(value):
		seed_value = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var center: Vector2 = size * center_ratio
	var reach: float = size.length()
	var near: float = minf(size.x, size.y) * clear_radius
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	for index: int in range(line_count):
		var angle: float = TAU * (float(index) + rng.randf_range(-0.35, 0.35)) / float(line_count)
		var spread: float = rng.randf_range(0.006, 0.02)
		var start: float = near * rng.randf_range(1.0, 1.35)
		draw_colored_polygon(PackedVector2Array([
			center + Vector2.from_angle(angle) * start,
			center + Vector2.from_angle(angle - spread) * reach,
			center + Vector2.from_angle(angle + spread) * reach]), ink)
