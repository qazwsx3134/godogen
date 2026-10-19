class_name TouchStick
extends Control
## Floating joystick for one finger of several: a touch that starts on the left `zone` of the screen owns the stick
## (by finger index) until it lifts, so a second finger can press the dash button at the same time. Reads
## InputEventScreenTouch / ScreenDrag in _input; with emulate_touch_from_mouse on, a desktop mouse drives it too.
## `vector` is a screen vector: x right, y down, length 0..1 (0 inside the dead zone).
##
## Children with unique names: %Base (shown under the finger while held) and %Knob inside it. The look is authored
## in the scene; _ready hides %Base. Set `enabled` false while a menu is open (that also lets go).

## Fraction of the screen width, from the left, where a touch grabs the stick (the reference uses 42%).
@export_range(0.1, 1.0) var zone: float = 0.42
@export var radius: float = 110.0
@export var knob_travel: float = 70.0
@export var dead_zone: float = 0.12

var vector := Vector2.ZERO
var enabled: bool = true:
	set(value):
		enabled = value
		if not value:
			release()

var _finger: int = -1
var _origin := Vector2.ZERO

@onready var _base: Control = %Base
@onready var _knob: Control = %Knob


func _ready() -> void:
	_base.visible = false


func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		var at: Vector2 = touch.position - global_position
		if touch.pressed and _finger < 0 and at.x < size.x * zone and at.y > 0.0:
			_finger = touch.index
			_origin = at
			_base.position = _origin - _base.size * 0.5
			_set_knob(Vector2.ZERO)
			_base.visible = true
		elif not touch.pressed and touch.index == _finger:
			release()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _finger:
			_set_knob(drag.position - global_position - _origin)


func held() -> bool:
	return _finger >= 0


func release() -> void:
	_finger = -1
	vector = Vector2.ZERO
	if is_node_ready():
		_base.visible = false
		_set_knob(Vector2.ZERO)


func _set_knob(offset: Vector2) -> void:
	var clamped: Vector2 = offset.limit_length(radius)
	_knob.position = _base.size * 0.5 + clamped * (knob_travel / radius) - _knob.size * 0.5
	var raw: Vector2 = clamped / radius
	vector = raw if raw.length() > dead_zone else Vector2.ZERO
