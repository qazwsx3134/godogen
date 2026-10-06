extends Button
## The visible frame is smaller than the touch target, matching the reference toolbar.
@export var normal_surface: StyleBoxFlat
@export var hover_surface: StyleBoxFlat
@export var active_surface: StyleBoxFlat
@onready var surface: Panel = %Surface
@onready var cutout_art: TextureRect = %CutoutArt
var _hovering: bool = false

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
	refresh_state()

func refresh_state() -> void:
	if not is_node_ready():
		return
	var treatment: StyleBoxFlat = active_surface if button_pressed else hover_surface if _hovering or has_focus() else normal_surface
	surface.add_theme_stylebox_override("panel", treatment)
	cutout_art.modulate = Color(1.12, 1.08, 0.9) if button_pressed else Color(1.12, 1.12, 1.12) if _hovering or has_focus() else Color.WHITE
	surface.modulate.a = 0.45 if disabled else 1.0
