extends RefCounted
## The director of one timed survivor run: scripted events at fixed times (a boss every few minutes, a stampede, the
## final boss), a spawn-rate curve, which enemy kinds appear in which minutes, and how often a spawn is an elite.
## Pure logic: the game calls step() while the run is not paused (level-up cards pause it) and spawns what it returns.
## `const RunTimeline = preload("res://addons/proto_kit/run_timeline.gd")`
##
##   var run := RunTimeline.new({
##       "duration": 960.0,                                          # 16:00, the final boss
##       "events": [{"at": 180, "id": "hogger", "kind": "boss"}, {"at": 75, "id": "stampede", "kind": "event"}],
##       "rate": [[0, 1.5], [300, 4.0], [900, 9.0]],                 # spawns per second, linear in between
##       "roster": [{"kind": "kobold", "from": 0, "to": 240, "weight": 3}, {"kind": "wolf", "from": 60, "weight": 2}],
##       "elite": [[0, 0.0], [120, 0.02], [900, 0.08]],              # chance that a spawn is an elite
##       "max_alive": 300,
##   }, rng)
##   var out := run.step(delta, alive_count)   # {"events": [event dicts], "spawns": [{"kind", "elite"}]}
##
## Spawning is a budget: rate x delta accumulates and whole spawns are taken out, so a low rate still spawns, and a
## long frame spawns its share at once. While alive_count >= max_alive the budget stops growing (no burst later).
## Deterministic for a seeded RNG. `next_event()` feeds a "next boss in 02:52" label.

var time: float = 0.0
var duration: float
var max_alive: int

var _events: Array = []   # sorted by "at"
var _next: int = 0
var _rate: Array = []
var _elite: Array = []
var _roster: Array = []
var _budget: float = 0.0
var _rng: RandomNumberGenerator


func _init(config: Dictionary, rng: RandomNumberGenerator) -> void:
	_rng = rng
	duration = float(config.get("duration", 900.0))
	max_alive = int(config.get("max_alive", 400))
	_events = config.get("events", []).duplicate(true)
	_events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.at) < float(b.at))
	_rate = config.get("rate", [[0.0, 1.0]])
	_elite = config.get("elite", [[0.0, 0.0]])
	_roster = config.get("roster", [])


func step(delta: float, alive_count: int = 0) -> Dictionary:
	var out := {"events": [], "spawns": []}
	if finished():
		return out
	time += delta
	while _next < _events.size() and float(_events[_next].at) <= time:
		out.events.append(_events[_next])
		_next += 1
	if alive_count < max_alive:
		_budget += sample(_rate, time) * delta
	var room := maxi(0, max_alive - alive_count)
	while _budget >= 1.0 and room > 0:
		_budget -= 1.0
		room -= 1
		var kind := _pick_kind()
		if kind == "":
			break
		out.spawns.append({"kind": kind, "elite": _rng.randf() < sample(_elite, time)})
	return out


func finished() -> bool:
	return time >= duration


## The next scripted event (or {}), for a countdown label: event.at - time seconds away.
func next_event(kind: String = "") -> Dictionary:
	for i in range(_next, _events.size()):
		if kind == "" or _events[i].get("kind", "") == kind:
			return _events[i]
	return {}


## Kinds that can spawn at `at` (default now), with their weights.
func roster_at(at: float = -1.0) -> Array:
	var t := time if at < 0.0 else at
	return _roster.filter(func(r: Dictionary) -> bool:
		return t >= float(r.get("from", 0.0)) and t < float(r.get("to", INF)))


func to_dict() -> Dictionary:
	# The RNG state is a 64-bit int: as a JSON number it would lose bits, so it is saved as text.
	return {"time": time, "next": _next, "budget": _budget, "rng_state": str(_rng.state)}


func from_dict(data: Dictionary) -> void:
	time = float(data.get("time", 0.0))
	_next = int(data.get("next", 0))
	_budget = float(data.get("budget", 0.0))
	if data.has("rng_state"):
		_rng.state = String(data.rng_state).to_int()


## Linear interpolation over [[time, value], ...] keys (sorted by time); flat before the first and after the last.
static func sample(keys: Array, at: float) -> float:
	if keys.is_empty():
		return 0.0
	if at <= float(keys[0][0]):
		return float(keys[0][1])
	for i in range(1, keys.size()):
		if at <= float(keys[i][0]):
			var a: Array = keys[i - 1]
			var b: Array = keys[i]
			var span := float(b[0]) - float(a[0])
			var w := 0.0 if span <= 0.0 else (at - float(a[0])) / span
			return lerpf(float(a[1]), float(b[1]), w)
	return float(keys[-1][1])


func _pick_kind() -> String:
	var live := roster_at()
	var total := 0.0
	for r: Dictionary in live:
		total += float(r.get("weight", 1.0))
	if total <= 0.0:
		return ""
	var pick := _rng.randf() * total
	for r: Dictionary in live:
		pick -= float(r.get("weight", 1.0))
		if pick < 0.0:
			return r.kind
	return live[-1].kind
