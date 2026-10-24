extends Control
## Floating virtual joystick: nothing is on screen until a finger presses anywhere in this area. The base then
## appears under the finger, dragging steers, and letting go hides it again. Reads mouse events, so it works with
## touch (Godot's emulate_mouse_from_touch, on by default), a desktop mouse, and test_kit's _drag.
## `vector` is a screen vector: x right, y DOWN, length 0..1 (zero inside the dead zone). A 3D game that wants
## "y forward" flips it: `Vector2(stick.vector.x, -stick.vector.y)`.
##
## Put the script on a Control that fills the touch area and give it two children with unique names:
##   %Base   a Control (a round Panel): follows the finger's press position and is shown while held
##   %Knob   a Control inside it: moves with the finger, at most `knob_travel` px from the middle of %Base
## and read `stick.vector` in the game's _physics_process. The scene leaves the base visible so the editor shows
## how it looks; _ready hides it. The look (sizes, StyleBox, alpha) is authored in the game's scene, not here.
## Call `release()` when the touch must end without a mouse-up (the game was paused under the finger).

## Finger travel (px) that counts as full deflection.
@export var radius: float = 120.0
## How far the knob is drawn from the centre at full deflection; keep it inside the base.
@export var knob_travel: float = 82.0
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
			_set_knob(Vector2.ZERO)
			_base.visible = true
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
	_set_knob(Vector2.ZERO)

func _set_knob(offset: Vector2) -> void:
	var clamped: Vector2 = offset.limit_length(radius)
	_knob.position = _base.size * 0.5 + clamped * (knob_travel / radius) - _knob.size * 0.5
	var raw: Vector2 = clamped / radius
	vector = raw if raw.length() > dead_zone else Vector2.ZERO
