extends Control
## Two-finger touch controls. A finger that lands on the left half drives a floating stick (%StickBase appears
## under it); a finger on the right half turns the camera. Fingers are tracked by index from ScreenTouch /
## ScreenDrag, so either can land first (mouse emulation only follows the first finger, which is why this does
## not reuse proto_kit's floating_stick). Shows nothing until touched, so it can stay in the scene on desktop.

@export var radius: float = 110.0      # px of finger travel for full speed
@export var knob_travel: float = 70.0  # px the knob moves at full deflection
@export var dead_zone: float = 0.15

var move: Vector2 = Vector2.ZERO  # x right, y forward, length 0..1

var _stick_finger := -1
var _look_finger := -1
var _origin := Vector2.ZERO
var _look := Vector2.ZERO

@onready var _base: Control = %StickBase
@onready var _knob: Control = %StickKnob
@onready var _buttons: Control = get_node_or_null("%Buttons")  # JUMP / BOOST corner, not a look area

func _ready() -> void:
	_base.visible = false  # the "touch_input" group is saved in hud.tscn so it exists before any _ready

## Pixels the look finger moved since the last call.
func take_look() -> Vector2:
	var d := _look
	_look = Vector2.ZERO
	return d

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			for area: Node in get_tree().get_nodes_in_group("combat_touch"):
				if area.is_visible_in_tree() and area.get_global_rect().has_point(event.position): return
			if _buttons and _buttons.get_global_rect().has_point(event.position):
				return  # a TouchScreenButton handles it
			if event.position.x < size.x * 0.5 and _stick_finger < 0:
				_stick_finger = event.index
				_origin = event.position
				_base.position = _origin - _base.size * 0.5
				_set_knob(Vector2.ZERO)
				_base.visible = true
			elif event.position.x >= size.x * 0.5 and _look_finger < 0:
				_look_finger = event.index
		elif event.index == _stick_finger:
			_stick_finger = -1
			_base.visible = false
			_set_knob(Vector2.ZERO)
		elif event.index == _look_finger:
			_look_finger = -1
	elif event is InputEventScreenDrag:
		if event.index == _stick_finger:
			_set_knob(event.position - _origin)
		elif event.index == _look_finger:
			_look += event.relative

func _set_knob(offset: Vector2) -> void:
	var clamped := offset.limit_length(radius)
	_knob.position = _base.size * 0.5 + clamped * (knob_travel / radius) - _knob.size * 0.5
	var v := clamped / radius
	move = Vector2(v.x, -v.y) if v.length() > dead_zone else Vector2.ZERO

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		_stick_finger=-1
		_look_finger=-1
		move=Vector2.ZERO
		_look=Vector2.ZERO
		if is_instance_valid(_base): _base.visible=false
