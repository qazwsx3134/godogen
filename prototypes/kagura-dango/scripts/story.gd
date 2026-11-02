extends Control
## Shows lines one at a time; a tap (or tap key) goes to the next one. Emits done after the last.

signal done

var _lines: Array = []
var _at := -1


func play(lines: Array) -> void:
	_lines = lines
	_at = -1
	_next()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_next()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("tap") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_next()


func _next() -> void:
	_at += 1
	if _at >= _lines.size():
		done.emit()
		return
	%Speaker.text = _lines[_at][0]
	%Line.text = _lines[_at][1]
