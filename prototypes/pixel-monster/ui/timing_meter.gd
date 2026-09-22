extends Control

var phase: float = 0.0
var running: bool = true
var cursor: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(280, 64)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if running:
		phase += delta * 3.6
		cursor = (sin(phase) + 1.0) * 0.5
	queue_redraw()

func quality() -> int:
	var distance: float = absf(cursor - 0.5)
	return 3 if distance < 0.075 else (2 if distance < 0.20 else 1)

func _draw() -> void:
	var area := Rect2(0, 13, size.x, 32)
	draw_style_box(_style(Color("e1dcc6")), area)
	draw_rect(Rect2(size.x * 0.30, 13, size.x * 0.40, 32), Color("b6c797"))
	draw_rect(Rect2(size.x * 0.425, 13, size.x * 0.15, 32), Color("63876a"))
	draw_rect(Rect2(size.x * cursor - 3, 6, 6, 47), Color("c67856"))
	draw_rect(Rect2(size.x * cursor - 6, 4, 12, 4), Color("c67856"))

func _style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	return style
