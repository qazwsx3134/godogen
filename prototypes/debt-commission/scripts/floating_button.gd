extends Control
## Round floating button: tap, long-press, and drag that snaps to the nearest side edge.
## Only mouse events are handled; the project emulates mouse from touch, so a touch
## never fires twice.

signal tapped
signal long_pressed
signal moved

const UI_STYLES_SCRIPT: Script = preload("res://scripts/ui_styles.gd")
const LONG_PRESS_SEC: float = 0.6
const DRAG_THRESHOLD: float = 24.0
const DIAMETER: float = 128.0

var glyph: String = ""
var accent: Color = Color(0.045, 0.06, 0.115, 0.94)
## Allowed area for the button's top-left corner, in parent coordinates. Set by main.
var bounds: Rect2 = Rect2(0.0, 0.0, 1080.0, 1920.0)

var _pressing: bool = false
var _dragging: bool = false
var _long_fired: bool = false
var _press_global: Vector2 = Vector2.ZERO
var _grab_offset: Vector2 = Vector2.ZERO
var _press_token: int = 0
var _hovered: bool = false
var _label: Label = null
var _snap_tween: Tween = null
var _style_id: String = "cinema"


func setup(glyph_text: String, font: Font, style_id: String = "cinema") -> void:
	glyph = glyph_text
	size = Vector2(DIAMETER, DIAMETER)
	custom_minimum_size = size
	pivot_offset = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	_label = Label.new()
	_label.text = glyph
	_label.size = size
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_override("font", font)
	_label.add_theme_font_size_override("font_size", 54)
	add_child(_label)
	set_style(style_id)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	queue_redraw()


func is_dragging() -> bool:
	return _dragging


func set_style(style_id: String) -> void:
	_style_id = UI_STYLES_SCRIPT.normalize_id(style_id)
	var palette: Dictionary = UI_STYLES_SCRIPT.palette(_style_id)
	accent = palette["floating_bg"] as Color
	if _label != null:
		_label.add_theme_color_override("font_color", palette["floating_ink"] as Color)
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = size.x * 0.5
	var palette: Dictionary = UI_STYLES_SCRIPT.palette(_style_id)
	draw_circle(center + Vector2(0.0, 6.0), radius - 2.0, Color(0.0, 0.0, 0.0, 0.24))
	var fill: Color = accent
	var outline: Color = palette["rule"] as Color
	var outline_width: float = 1.0
	if _hovered:
		fill = accent.lightened(0.1)
		outline = palette["focus"] as Color
	if _pressing:
		fill = palette["accent"] as Color
		outline = palette["focus"] as Color
		outline_width = 3.0 if _style_id == "manga" else 2.0
	draw_circle(center, radius - 4.0, fill)
	draw_arc(center, radius - 6.0, 0.0, TAU, 48, outline, outline_width, true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		accept_event()
		if button.pressed:
			_pressing = true
			_dragging = false
			_long_fired = false
			_press_global = button.global_position
			_grab_offset = position - _to_parent(button.global_position)
			_press_token += 1
			_refresh_visual_state()
			_wait_long_press(_press_token)
		elif _pressing:
			_pressing = false
			_press_token += 1
			_refresh_visual_state()
			if _dragging:
				_dragging = false
				snap_to_edge(true)
			elif not _long_fired:
				tapped.emit()
	elif event is InputEventMouseMotion and _pressing:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		accept_event()
		if not _dragging and motion.global_position.distance_to(_press_global) > DRAG_THRESHOLD:
			_dragging = true
			_press_token += 1
			_refresh_visual_state()
		if _dragging:
			position = _clamp(_to_parent(motion.global_position) + _grab_offset)


func snap_to_edge(animated: bool) -> void:
	var clamped: Vector2 = _clamp(position)
	var left: float = bounds.position.x
	var right: float = bounds.end.x
	var target: Vector2 = Vector2(left if clamped.x - left < right - clamped.x else right, clamped.y)
	if _snap_tween != null:
		_snap_tween.kill()
	if not animated:
		position = target
		moved.emit()
		return
	_snap_tween = create_tween()
	_snap_tween.tween_property(self, "position", target, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_snap_tween.finished.connect(func() -> void: moved.emit())


func _clamp(value: Vector2) -> Vector2:
	return Vector2(clampf(value.x, bounds.position.x, max(bounds.position.x, bounds.end.x)),
		clampf(value.y, bounds.position.y, max(bounds.position.y, bounds.end.y)))


func _to_parent(global_point: Vector2) -> Vector2:
	var parent_item: CanvasItem = get_parent() as CanvasItem
	if parent_item == null:
		return global_point
	return parent_item.get_global_transform().affine_inverse() * global_point


func _wait_long_press(token: int) -> void:
	await get_tree().create_timer(LONG_PRESS_SEC).timeout
	if token != _press_token or not _pressing or _dragging:
		return
	_long_fired = true
	_refresh_visual_state()
	long_pressed.emit()


func _on_mouse_entered() -> void:
	_hovered = true
	_refresh_visual_state()


func _on_mouse_exited() -> void:
	_hovered = false
	_refresh_visual_state()


func _refresh_visual_state() -> void:
	if _label != null:
		var palette: Dictionary = UI_STYLES_SCRIPT.palette(_style_id)
		var label_color: Color = palette["floating_ink"] as Color
		if _pressing:
			label_color = palette["accent_ink"] as Color
		_label.add_theme_color_override("font_color", label_color)
	queue_redraw()
