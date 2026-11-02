@tool
extends Node2D
## A pile that grows with a count: plates (the rival team) or empty skewer sticks (Yorozuya).

const EMPTY_SKEWER := preload("res://assets/sprites/dango_props_2.png")

@export var count := 0:
	set(v):
		count = v
		queue_redraw()
@export var sticks := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _draw() -> void:
	if sticks:
		for i in count:
			var x := (i % 12) * 3.0
			var y := -(i / 12) * 4.0
			draw_texture_rect(EMPTY_SKEWER, Rect2(x - 14, y - 2, 28, 5), false)
		return
	for i in count:
		var y := -i * 3.0
		draw_rect(Rect2(-14 + (i % 2), y - 3, 28, 3), Color(0.95, 0.95, 0.92))
		draw_rect(Rect2(-14 + (i % 2), y - 3, 28, 3), Color(0.4, 0.35, 0.3), false, 1)
