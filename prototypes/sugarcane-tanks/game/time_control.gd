extends Node
## The one place that touches Engine.time_scale. Hit stops are throttled so a room
## full of kills does not freeze the game every frame. Menu pauses use tree.paused instead.

@export var hit_stop_scale: float = 0.05
@export var hit_stop_cooldown: float = 0.25

var _resume_at_ms: int = 0
var _next_allowed_ms: int = 0

func hit_stop(duration: float) -> void:
	var now: int = Time.get_ticks_msec()
	if now < _next_allowed_ms:
		return
	Engine.time_scale = hit_stop_scale
	_resume_at_ms = now + int(duration * 1000.0)
	_next_allowed_ms = _resume_at_ms + int(hit_stop_cooldown * 1000.0)

func _process(_delta: float) -> void:
	if Engine.time_scale < 1.0 and Time.get_ticks_msec() >= _resume_at_ms:
		Engine.time_scale = 1.0

func reset() -> void:
	Engine.time_scale = 1.0
	_next_allowed_ms = 0

func _exit_tree() -> void:
	Engine.time_scale = 1.0
