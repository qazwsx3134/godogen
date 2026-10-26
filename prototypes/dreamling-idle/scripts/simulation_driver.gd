extends Node
## The only gameplay clock. Work is bounded per render frame; carry is not discarded.
signal advanced
@export var max_steps_per_frame: int = 80
var model: RefCounted
var carry: float = 0.0
var enabled: bool = true


func _process(delta: float) -> void:
	if enabled: advance(delta)


func advance(delta: float) -> int:
	if model == null or model.paused: return 0
	carry += maxf(delta, 0.0)
	var count: int = mini(int(floor((carry + 0.00000001) / model.STEP)), max_steps_per_frame)
	for i: int in count: model.step()
	carry -= count * model.STEP
	if count > 0: advanced.emit()
	return count
