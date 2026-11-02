extends Control
## Shows lines one at a time; a tap (or tap key) goes to the next one. Emits done after the last.

signal done

## The speaker's picture shown above the line; speakers without one show none.
const PORTRAITS := {
	"銀時": "res://assets/sprites/gintoki_ref.png",
	"新八": "res://assets/sprites/shinpachi_ref.png",
	"神樂": "res://assets/sprites/kagura_ref.png",
	"裁判": "res://assets/sprites/referee_ref.png",
	"店主": "res://assets/sprites/store_owner_serve.png",
}
## Portrait x (left edge) per speaker: Kagura stands on the right, everyone else on the left.
const RIGHT_SIDE := ["神樂"]

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
	%Speaker.text = who
	var path: String = PORTRAITS.get(who, "")
	%Portrait.texture = load(path) if path != "" and ResourceLoader.exists(path) else null
	var right := who in RIGHT_SIDE
	%Portrait.position.x = size.x - 30.0 - %Portrait.size.x if right else 30.0
	%Portrait.flip_h = right
	%Line.text = _lines[_at][1]
