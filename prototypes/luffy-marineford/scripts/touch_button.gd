class_name TouchButton
extends Control
## A round on-screen button that works with any finger, so it can be pressed while another finger steers.
## A touch that starts inside this Control's rect presses `action` (Input.action_press) and emits `tapped`.
## `cooldown_ratio` 0..1 draws the remaining cooldown as a dimmed sweep over the button (set it every frame).

signal tapped

@export var action: StringName = &"dash"

var cooldown_ratio: float = 0.0:
	set(value):
		cooldown_ratio = clampf(value, 0.0, 1.0)
		queue_redraw()

@onready var _face: Control = %Face


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventScreenTouch:
		return
	var touch := event as InputEventScreenTouch
	if not touch.pressed:
		return
	if get_global_rect().has_point(touch.position):
		Input.action_press(action)
		Input.action_release.call_deferred(action)
		tapped.emit()
		_face.scale = Vector2.ONE * 0.9
		create_tween().tween_property(_face, "scale", Vector2.ONE, 0.12)


func _draw() -> void:
	if cooldown_ratio <= 0.0:
		return
	var center: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.5
	draw_arc(center, r * 0.5, -PI * 0.5, -PI * 0.5 + TAU * cooldown_ratio, 32, Color(0.05, 0.04, 0.08, 0.55), r)
