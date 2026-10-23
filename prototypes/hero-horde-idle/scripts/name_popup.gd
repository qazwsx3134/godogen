extends Label3D
## A hero's name popping up over their head when they cast a skill (pooled under main.tscn's Popups): rises and fades
## over LIFE seconds, then hides until reused.

const LIFE := 1.0
const RISE := 0.7

var _t: float = -1.0
var _from := Vector3.ZERO


func pop(at: Vector3, text_value: String, color: Color) -> void:
	text = text_value
	modulate = color
	_from = at
	position = at
	_t = 0.0
	visible = true


func busy() -> bool:
	return _t >= 0.0


func step(dt: float) -> void:
	if _t < 0.0:
		return
	_t += dt
	var k: float = _t / LIFE
	if k >= 1.0:
		_t = -1.0
		visible = false
		return
	position = _from + Vector3(0.0, RISE * k, 0.0)
	modulate.a = 1.0 if k < 0.6 else 1.0 - (k - 0.6) / 0.4
	outline_modulate.a = modulate.a
