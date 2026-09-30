extends Control
## Floating joystick: press anywhere in this area, the base appears under the finger,
## drag to steer. Reads mouse events so it works with touch (emulate_mouse_from_touch),
## a desktop mouse, and test_kit's _drag.

@export var radius: float = 120.0
@export var dead_zone: float = 0.18

var vector: Vector2 = Vector2.ZERO

var _origin: Vector2 = Vector2.ZERO
var _held: bool = false

@onready var _base: Control = %Base
@onready var _knob: Control = %Knob

func _ready() -> void:
	_base.visible = false

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_held = true
			_origin = event.position
			_base.position = _origin - _base.size * 0.5
			_base.visible = true
			_set_knob(Vector2.ZERO)
		else:
			release()
		accept_event()
	elif event is InputEventMouseMotion and _held:
		_set_knob(event.position - _origin)
		accept_event()

func release() -> void:
	_held = false
	vector = Vector2.ZERO
	_base.visible = false

func _set_knob(offset: Vector2) -> void:
	var clamped: Vector2 = offset.limit_length(radius)
	_knob.position = _base.size * 0.5 + clamped - _knob.size * 0.5
	var raw: Vector2 = clamped / radius
	vector = raw if raw.length() > dead_zone else Vector2.ZERO
