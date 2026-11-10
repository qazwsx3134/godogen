extends Node
## The one place that touches Engine.time_scale: hit stops, the few frozen frames that make an impact land.
## Menu pauses use tree.paused instead, so the two never fight over the same switch.
## `const TimeControl = preload("res://addons/proto_kit/time_control.gd")`, or put the script on a Node of the game
## scene (process_mode ALWAYS, so it keeps running while the tree is paused) and call:
##
##   time_control.hit_stop(0.06)          # an ordinary impact
##   time_control.hit_stop(0.2, true)     # a boss death: skips the cooldown, only ever lengthens a running stop
##   time_control.reset()                 # a restart, or leaving the scene
##
## Hit stops are throttled: inside `hit_stop_cooldown` after the last one a request is ignored, so a room full of
## kills does not freeze the game every frame. They run on the wall clock, not on game time: how long the freeze
## lasts is what the player feels, and a slowed game clock would stretch it. Do not use this for gameplay timers.
## Leaving the tree puts Engine.time_scale back to 1.

## How slow the game runs during a stop (0.05 = almost frozen; 0 would stop the engine's own timers too).
@export var hit_stop_scale: float = 0.05
## Seconds after a stop ends during which an ordinary request is ignored.
@export var hit_stop_cooldown: float = 0.25

## Milliseconds for the rules. Empty = the wall clock. Tests set one they can move by hand.
var clock: Callable

var _resume_at_ms: int = 0
var _next_allowed_ms: int = 0

func _now_ms() -> int:
	return clock.call() if clock.is_valid() else Time.get_ticks_msec()

## Freezes the game (almost) for `duration` real seconds. Inside the cooldown after the last stop it
## is ignored, unless `force` is set (boss death): a forced stop skips the cooldown and only ever
## lengthens a stop that is still running, never shortens it.
func hit_stop(duration: float, force: bool = false) -> void:
	var now: int = _now_ms()
	if now < _next_allowed_ms and not force:
		return
	Engine.time_scale = hit_stop_scale
	_resume_at_ms = maxi(_resume_at_ms, now + int(duration * 1000.0))
	_next_allowed_ms = _resume_at_ms + int(hit_stop_cooldown * 1000.0)

func _process(_delta: float) -> void:
	if Engine.time_scale < 1.0 and _now_ms() >= _resume_at_ms:
		Engine.time_scale = 1.0

func reset() -> void:
	Engine.time_scale = 1.0
	_resume_at_ms = 0
	_next_allowed_ms = 0

func _exit_tree() -> void:
	Engine.time_scale = 1.0
