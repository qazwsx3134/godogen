extends Button
## The visible frame is smaller than the touch target, matching the reference toolbar.
@export var normal_surface: StyleBoxFlat
@export var hover_surface: StyleBoxFlat
@export var active_surface: StyleBoxFlat
## Only the painted surface moves; the button's touch area and container layout stay fixed.
@export_range(0.9, 1.0, 0.01) var pressed_scale: float = 0.96
@onready var surface: Panel = %Surface
@onready var cutout_art: TextureRect = %CutoutArt
var _hovering: bool = false
var _reduce_motion: bool = false
var _press_tween: Tween

func _ready() -> void:
	mouse_entered.connect(func() -> void:
		_hovering = true
		refresh_state())
	mouse_exited.connect(func() -> void:
		_hovering = false
		refresh_state())
	toggled.connect(func(_pressed: bool) -> void: refresh_state())
	focus_entered.connect(refresh_state)
	focus_exited.connect(refresh_state)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	surface.resized.connect(_center_surface_pivot)
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			_reset_press())
	_center_surface_pivot()
	refresh_state()


func set_reduce_motion(reduced: bool) -> void:
	_reduce_motion = reduced
	if reduced and is_node_ready():
		_reset_press()


func _center_surface_pivot() -> void:
	surface.pivot_offset = surface.size * 0.5


func _on_button_down() -> void:
	if not disabled and not _reduce_motion:
		_animate_press(Vector2.ONE * pressed_scale, 0.06)


func _on_button_up() -> void:
	if _reduce_motion:
		_reset_press()
	else:
		_animate_press(Vector2.ONE, 0.12)


func _animate_press(target: Vector2, duration: float) -> void:
	if _press_tween != null and _press_tween.is_valid():
		_press_tween.kill()
	_press_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_press_tween.tween_property(surface, "scale", target, duration)


func _reset_press() -> void:
	if _press_tween != null and _press_tween.is_valid():
		_press_tween.kill()
	if is_instance_valid(surface):
		surface.scale = Vector2.ONE


func refresh_state() -> void:
	if not is_node_ready():
		return
	if disabled:
		_reset_press()
	var treatment: StyleBoxFlat = active_surface if button_pressed else hover_surface if _hovering or has_focus() else normal_surface
	surface.add_theme_stylebox_override("panel", treatment)
	cutout_art.modulate = Color(1.12, 1.08, 0.9) if button_pressed else Color(1.12, 1.12, 1.12) if _hovering or has_focus() else Color.WHITE
	surface.modulate.a = 0.45 if disabled else 1.0
