extends Node
## Game time for gameplay rules. Pauses the tree while the app is in the background (tab hidden,
## app switched away) and counts unpaused seconds, so rules never read the wall clock.
## Add one node anywhere; it sets itself to PROCESS_MODE_ALWAYS. Timers made with
## create_timer(t, false) and every pausable _process then stop while the app is away.
##
## Coming back, the first frame's delta covers the whole time away; the tree stays paused for
## `resume_frames` frames so that delta is spent while paused, not as one giant step.
## Hand `now_ms` to modules that take an injectable clock (haptics.gd `clock`).

signal backgrounded(away: bool)

@export var pause_in_background: bool = true
@export var resume_frames: int = 2
## Upper bound on one frame of game time, so a hitch never jumps `now` far ahead.
@export var max_delta: float = 0.1

## Seconds of unpaused game time since this node entered the tree.
var now: float = 0.0
var away: bool = false

var _paused_before: bool = false
var _resume_left: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if _resume_left > 0:
		_resume_left -= 1
		if _resume_left == 0:
			get_tree().paused = _paused_before
		return
	if not get_tree().paused:
		now += minf(delta, max_delta)


func now_ms() -> int:
	return int(now * 1000.0)


## Also callable directly (tests, a web visibilitychange hook).
func set_away(value: bool) -> void:
	if value == away:
		return
	away = value
	if pause_in_background:
		if away:
			if _resume_left == 0:  # a quick away/back/away keeps the pause state from before
				_paused_before = get_tree().paused
			_resume_left = 0
			get_tree().paused = true
		else:
			_resume_left = maxi(1, resume_frames)
	backgrounded.emit(away)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			set_away(true)
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			set_away(false)
