extends RefCounted
## Rhythm combos on a few keys (Seal Online style A / S / D): attacking fills a combo gauge; once it is ready, a known
## sequence of presses on the beat chains hits that land faster and harder; a wrong key or a missed beat breaks it.
## Two keys pressed together (within `chord_window`) form a chord step such as "AD".
## Pure logic: feed it presses with a clock in seconds; it does not read Input. `const ComboInput = preload("res://addons/proto_kit/combo_input.gd")`
##
##   var combos := ComboInput.new([
##       {"id": "triple", "steps": ["A", "S", "AS"]},
##       {"id": "five", "steps": ["A", "S", "A", "A", "AD"], "finish_bonus": 0.5},
##   ], {"beat": 0.45, "window": 0.15})
##   combos.add_gauge(0.08)                         # on every normal hit
##   for e in combos.press("A", now): ...            # in _unhandled_input
##   for e in combos.update(now): ...                # every frame: commits chords, notices a missed beat
##
## Events (Dictionary): {"type": "start" | "step" | "finish" | "break", "step": n (1-based), "combo": id or "",
## "mult": damage multiplier for this hit, "speed": attack-speed multiplier}. A step names the combo only once one
## candidate is left. "finish" comes with the last step of a combo no longer sequence could still extend, or one beat
## after it when one could. Starting spends the whole gauge, so after a finish or a break it fills again from zero.
##
## Options: beat (s between steps, 0.45), window (± s around the beat, 0.15), chord_window (s, 0.06), ready (gauge
## needed to start, 0.5), step_mult (+damage per step, 0.1), speed (attack speed while comboing, 1.3), finish_bonus
## (default extra damage on a finished combo, 0.3; a combo may set its own).

var gauge: float = 0.0

var _combos: Array[Dictionary] = []
var _beat: float
var _window: float
var _chord_window: float
var _ready: float
var _step_mult: float
var _speed: float
var _finish_bonus: float

var _done: Array[String] = []   # committed steps of the running combo
var _last: float = 0.0          # time of the last committed step
var _chord: Array[String] = []  # keys of the step being pressed
var _chord_time: float = 0.0
var _complete: String = ""      # a combo whose steps all matched but that a longer one may still extend


func _init(combos: Array[Dictionary], options: Dictionary = {}) -> void:
	_combos = combos
	_beat = float(options.get("beat", 0.45))
	_window = float(options.get("window", 0.15))
	_chord_window = float(options.get("chord_window", 0.06))
	_ready = float(options.get("ready", 0.5))
	_step_mult = float(options.get("step_mult", 0.1))
	_speed = float(options.get("speed", 1.3))
	_finish_bonus = float(options.get("finish_bonus", 0.3))


func add_gauge(amount: float) -> void:
	gauge = clampf(gauge + amount, 0.0, 1.0)


func is_ready() -> bool:
	return gauge >= _ready


func running() -> bool:
	return not _done.is_empty()


## Steps committed so far (for a HUD that lights the keys).
func steps() -> Array[String]:
	return _done.duplicate()


## Combos still possible from here: what to show as the next key hints.
func candidates() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c: Dictionary in _combos:
		var s: Array = c.steps
		if s.size() > _done.size() and s.slice(0, _done.size()) == _done:
			out.append(c)
	return out


func press(key: String, now: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if not _chord.is_empty() and now - _chord_time > _chord_window:
		events.append_array(_commit())
	if _chord.is_empty():
		if not running() and not is_ready():
			return events
		_chord_time = now
	var k := key.to_upper()
	if k not in _chord:
		_chord.append(k)
	return events


func update(now: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if not _chord.is_empty() and now - _chord_time > _chord_window:
		events.append_array(_commit())
	if running() and _chord.is_empty() and now > _last + _beat + _window:
		if _complete != "":
			events.append(_event("finish", _complete))
		else:
			events.append(_event("break", ""))
		_end()
	return events


func _commit() -> Array[Dictionary]:
	var keys := _chord.duplicate()
	keys.sort()
	var symbol := "".join(keys)
	var at := _chord_time
	_chord.clear()
	var events: Array[Dictionary] = []
	if running():
		var early := _last + _beat - _window
		var late := _last + _beat + _window
		if at < early or at > late:
			events.append(_event("break", ""))
			_end()
			return events
	var next: Array[Dictionary] = []
	for c: Dictionary in candidates():
		if _norm(c.steps[_done.size()]) == symbol:
			next.append(c)
	if next.is_empty():
		if running():
			events.append(_event("break", ""))
			_end()
		return events  # a wrong opening key just does nothing
	if not running():
		gauge = 0.0
		events.append(_event("start", ""))
	_done.append(symbol)
	_last = at
	var finished := ""
	var longer := false
	for c: Dictionary in next:
		if c.steps.size() == _done.size():
			finished = c.id
		else:
			longer = true
	var named: String = next[0].id if next.size() == 1 else ""
	events.append(_event("step", named))
	_complete = finished
	if finished != "" and not longer:
		events.append(_event("finish", finished))
		_end()
	return events


func _event(type: String, combo: String) -> Dictionary:
	var mult := 1.0 + _step_mult * maxi(0, _done.size() - 1)
	if type == "finish":
		for c: Dictionary in _combos:
			if c.id == combo:
				mult += float(c.get("finish_bonus", _finish_bonus))
	return {"type": type, "step": _done.size(), "combo": combo,
		"mult": mult if type in ["step", "finish"] else 1.0, "speed": _speed if type in ["start", "step"] else 1.0}


func _end() -> void:
	_done.clear()
	_chord.clear()
	_complete = ""


static func _norm(step: String) -> String:
	var keys: Array = Array(step.to_upper().split(""))
	keys.sort()
	return "".join(keys)
