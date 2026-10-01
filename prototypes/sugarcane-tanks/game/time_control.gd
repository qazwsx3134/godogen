extends Node
## The one place that touches Engine.time_scale. Hit stops are throttled so a room
## full of kills does not freeze the game every frame. Menu pauses use tree.paused instead.

@export var hit_stop_scale: float = 0.05
@export var hit_stop_cooldown: float = 0.25

var _resume_at_ms: int = 0
var _next_allowed_ms: int = 0

## Freezes the game (almost) for `duration` real seconds. Inside the cooldown after the last stop it
## is ignored, unless `force` is set (boss death): a forced stop skips the cooldown and only ever
## lengthens a stop that is still running, never shortens it.
func hit_stop(duration: float, force: bool = false) -> void:
	var now: int = Time.get_ticks_msec()
	if now < _next_allowed_ms and not force:
		return
	Engine.time_scale = hit_stop_scale
	_resume_at_ms = maxi(_resume_at_ms, now + int(duration * 1000.0))
	_next_allowed_ms = _resume_at_ms + int(hit_stop_cooldown * 1000.0)

func _process(_delta: float) -> void:
	if Engine.time_scale < 1.0 and Time.get_ticks_msec() >= _resume_at_ms:
		Engine.time_scale = 1.0

func reset() -> void:
	Engine.time_scale = 1.0
	_resume_at_ms = 0
	_next_allowed_ms = 0

func _exit_tree() -> void:
	Engine.time_scale = 1.0
