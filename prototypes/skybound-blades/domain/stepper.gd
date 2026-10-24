extends RefCounted
## Turns variable frame deltas into whole fixed simulation steps. Leftover time carries to the
## next frame; a long hitch runs at most max_catch_up steps so the game never spirals.

var step_s: float
var max_catch_up: int
var _carry: float = 0.0


func _init(step_ms: int, max_catch_up_: int = 10) -> void:
	step_s = step_ms / 1000.0
	max_catch_up = max_catch_up_


## Number of steps to run for this frame.
func advance(delta: float) -> int:
	_carry += maxf(delta, 0.0)
	var steps := int(floor((_carry + 1e-9) / step_s))
	_carry -= steps * step_s
	if steps > max_catch_up:
		steps = max_catch_up
		_carry = 0.0
	return steps


## How far the simulation is into the next step (0..1): render positions lerp by it.
func alpha() -> float:
	return clampf(_carry / step_s, 0.0, 1.0)
