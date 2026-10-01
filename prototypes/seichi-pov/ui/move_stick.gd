extends Control
## Virtual joystick. Emits a vector with x = right, y = forward (screen up), length <= 1.
## Follows one touch (or a real mouse on desktop); emulated mouse events from touches are
## ignored so a finger is never counted twice.

signal changed(vector: Vector2)

@export var radius := 70.0

const NONE := -2
const MOUSE := -1
var _pointer := NONE

@onready var knob: Control = %Knob


func _ready() -> void:
	_center_knob(Vector2.ZERO)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _pointer == NONE:
			_pointer = event.index
			_update(event.position)
		elif not event.pressed and event.index == _pointer:
			_release()
		accept_event()
	elif event is InputEventScreenDrag:
		if event.index == _pointer:
			_update(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed and _pointer == NONE:
			_pointer = MOUSE
			_update(event.position)
		elif not event.pressed and _pointer == MOUSE:
			_release()
		accept_event()
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		if _pointer == MOUSE:
			_update(event.position)
			accept_event()


func _update(local: Vector2) -> void:
	var v := (local - size * 0.5).limit_length(radius)
	_center_knob(v)
	changed.emit(Vector2(v.x, -v.y) / radius)


func _release() -> void:
	_pointer = NONE
	_center_knob(Vector2.ZERO)
	changed.emit(Vector2.ZERO)


func _center_knob(v: Vector2) -> void:
	knob.position = size * 0.5 + v - knob.size * 0.5
