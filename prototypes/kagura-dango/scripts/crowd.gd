@tool
extends Node2D
## Placeholder spectators: rows of silhouettes behind the table that hop on the beat.

@export var count := 16:
	set(v):
		count = v
		queue_redraw()
@export var width := 900.0
@export var color := Color(0.45, 0.33, 0.3, 0.55)

var _hop := 0.0


func bob(height: float) -> void:
	var tw := create_tween()
	tw.tween_method(_set_hop, height, 0.0, 0.25)


func _set_hop(v: float) -> void:
	_hop = v
	queue_redraw()


func _draw() -> void:
	for i in count:
		var x := -width / 2.0 + (i + 0.5) * width / count
		var row := i % 2
		var y := -row * 14.0 - (_hop if (i + row) % 2 == 0 else _hop * 0.5)
		draw_circle(Vector2(x, y - 30), 9, color)
		draw_rect(Rect2(x - 11, y - 22, 22, 30), color)
