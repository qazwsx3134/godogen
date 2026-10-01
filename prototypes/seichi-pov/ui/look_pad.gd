extends Control
## Full-screen look surface behind the other controls. One finger drags the view, two
## fingers pinch to zoom; on desktop, mouse drag looks and the wheel zooms.

signal look(drag_px: Vector2)
signal zoom(factor: float)

var _touches := {}   # index -> last position
var _pinch := 0.0
var _mouse_down := false
var _mouse_last := Vector2.ZERO


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		_pinch = _spread()
		accept_event()
	elif event is InputEventScreenDrag:
		if not _touches.has(event.index):
			return
		var last: Vector2 = _touches[event.index]
		_touches[event.index] = event.position
		if _touches.size() >= 2:
			var spread := _spread()
			if _pinch > 0.0 and spread > 0.0:
				zoom.emit(spread / _pinch)
			_pinch = spread
		else:
			look.emit(event.position - last)
		accept_event()
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_mouse_down = event.pressed
				_mouse_last = event.position
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					zoom.emit(1.1)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					zoom.emit(1.0 / 1.1)
		accept_event()
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		if _mouse_down:
			look.emit(event.position - _mouse_last)
			_mouse_last = event.position
			accept_event()


func _spread() -> float:
	if _touches.size() < 2:
		return 0.0
	var pts := _touches.values()
	return (pts[0] as Vector2).distance_to(pts[1])
