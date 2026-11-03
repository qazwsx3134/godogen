extends Control
## Shows lines one at a time; a tap (or tap key) goes to the next one. Emits done after the last.

signal done

## The speaker's picture is one of %Cast's children, the one whose `speaker` metadata is the line's speaker: each
## stands where it is placed in story.tscn (drag and size them in the editor). Speakers without one show none.

const PICTURE_BOX_ALPHA := 0.55

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
	var who: String = _lines[_at][0]
	# An optional third field is a full-screen picture for that line (the birthday picture at the end).
	var picture: String = _lines[_at][2] if _lines[_at].size() > 2 else ""
	if picture != "":
		%Scenery.texture = load(picture)
		%Scenery.modulate.a = 1.0
	$Box.self_modulate.a = PICTURE_BOX_ALPHA if picture != "" else 1.0  # let the picture show through
	%Speaker.text = who
	for c in %Cast.get_children():
		c.visible = c.get_meta("speaker", "") == who
	%Line.text = _lines[_at][1]
