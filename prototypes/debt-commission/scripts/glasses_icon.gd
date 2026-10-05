@tool
extends Control
## One pair of glasses in the HUD's life row (scenes/ui/glasses_icon.tscn). A lost pair is drawn
## faint with a cracked lens.

@export var charged: bool = false:
	set(value):
		charged = value
		set_process(value and not Engine.is_editor_hint())
		queue_redraw()
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
	set_process(charged and not Engine.is_editor_hint())


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var unit: float = size.y / 36.0
	var radius: float = 10.0 * unit
	if charged and not broken:
		var clock: float = Time.get_ticks_msec() / 1000.0
		for i: int in range(9):
			var x: float = size.x * (float(i) + 0.5) / 9.0
			var height: float = unit * (12.0 + 7.0 * sin(clock * 7.0 + i * 2.1))
			draw_colored_polygon(PackedVector2Array([Vector2(x - unit * 4, size.y * 0.8),
				Vector2(x + unit * sin(clock * 4 + i) * 3, size.y * 0.45 - height),
				Vector2(x + unit * 4, size.y * 0.8)]), Color(1.0, 0.72, 0.1, 0.65))
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
