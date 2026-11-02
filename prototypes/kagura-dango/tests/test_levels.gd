extends "res://addons/proto_kit/test_kit.gd"
## Every round played by a bot on an injected clock (song seconds advanced by the test, not the audio), so the run
## is the same at any frame rate. Checks grading, the three lanes of round 1, the overlapping windows of half-beat
## doubles, calibration, MatchState (who ate what, the rival's count, Kagura's girth) and the stage's intensity.

const STEP := 1.0 / 60.0
const ROUNDS := [["res://scenes/three_eat.tscn", "res://data/songs/eat3.json", 30],
	["res://scenes/toss_game.tscn", "res://data/songs/toss2.json", 28],
	["res://scenes/toss_game.tscn", "res://data/songs/toss3.json", 42]]

var _t := 0.0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_arc()
	for r in ROUNDS:
		_check_chart(r)
	# A whole match with exact taps on the right lanes: every round all ace, Kagura grows, the team wins.
	MatchState.reset()
	var girth := []
	for r in ROUNDS:
		var res := await _play(r, {})
		_expect(res.score == 100 and res.counts.ace == r[2], "%s exact taps: all %d ace (got %s)" % [r[1], r[2], res])
		girth.append(_last_girth)
	_expect(MatchState.team_total() == 100, "the team ate all 100 skewers (got %d)" % MatchState.team_total())
	_expect(MatchState.rival == 18 + 22 + 27, "the rival ate 67 (got %d)" % MatchState.rival)
	_expect(MatchState.eaten[&"gintoki"] == 8 and MatchState.eaten[&"shinpachi"] == 9,
		"round 1 fed Gintoki 8 and Shinpachi 9 (got %s)" % [MatchState.eaten])
	_expect(girth[0] < girth[1] and girth[1] < girth[2] and girth[2] > 1.7, "Kagura grows every round (%s)" % [girth])
	_expect(_intensity_seen == [1, 2, 3], "the stage gets livelier each round (%s)" % [_intensity_seen])
	# Grades.
	MatchState.reset()
	var res := await _play(ROUNDS[1], {offset = 0.05})
	_expect(res.counts.good == 28 and res.score == 85, "taps 50 ms late are all good (got %s)" % [res])
	res = await _play(ROUNDS[1], {offset = -0.1})
	_expect(res.counts.barely == 28 and res.rank == &"again", "taps 100 ms early are all barely (got %s)" % [res])
	res = await _play(ROUNDS[1], {stray = true})
	_expect(res.score == 100, "stray taps between cues cost nothing (got %s)" % [res])
	res = await _play(ROUNDS[1], {offset = 0.08, calib = 0.08})
	_expect(res.score == 100, "with 80 ms calibration, taps 80 ms late are ace (got %s)" % [res])
	MatchState.reset()
	res = await _play(ROUNDS[1], {never = true})
	_expect(res.counts.miss == 28 and res.score == 0, "no taps: every cue missed (got %s)" % [res])
	_expect(MatchState.team_total() == 0, "missed skewers are not eaten")
	# Half-beat doubles at 136 BPM (0.22 s apart): the first tapped 115 ms late is nearer the second cue, yet it
	# must answer the first (still inside its window) and leave the second for the next tap.
	res = await _play(ROUNDS[2], {late_first_of_double = 0.115})
	_expect(res.counts.miss == 0 and res.counts.ace + res.counts.barely == 42,
		"a late first tap of a double does not steal the second (got %s)" % [res])
	# Round 1 lanes: feeding the wrong person is a miss; any lane is fine in the toss rounds.
	MatchState.reset()
	res = await _play(ROUNDS[0], {wrong_lane = true})
	_expect(res.counts.miss == 30 and MatchState.team_total() == 0, "wrong lane on every cue: all missed (got %s)" % [res])
	res = await _play(ROUNDS[1], {lane = 0})
	_expect(res.score == 100, "the toss rounds take a tap on any side (got %s)" % [res])
	# Replaying a round does not count its skewers twice.
	MatchState.reset()
	await _play(ROUNDS[0], {})
	var before := MatchState.team_total()
	MatchState.restore_round()
	_expect(MatchState.team_total() == 0 and before == 30, "restore_round undoes the round (%d → %d)" % [before, MatchState.team_total()])
	_finish("LEVELS")


func _check_chart(r: Array) -> void:
	var level: Node = load(r[0]).instantiate()
	level.chart_path = r[1]
	root.add_child(level)
	var times: Array = level.hits.map(func(h): return h.time)
	var ok := true
	for i in range(1, times.size()):
		ok = ok and times[i] - times[i - 1] >= 0.2
	_expect(times.size() == r[2] and ok, "%s: %d hits in order, at least 0.2 s apart" % [r[1], r[2]])
	level.free()


func _check_arc() -> void:
	var s = load("res://scenes/skewer.tscn").instantiate()
	s.from = Vector2(10, 20)
	s.to = Vector2(300, 40)
	s.t0 = 1.0
	s.t1 = 2.0
	s.place(1.0)
	var at_start: Vector2 = s.position
	s.place(2.0)
	_expect(at_start.is_equal_approx(Vector2(10, 20)) and s.position.is_equal_approx(Vector2(300, 40)),
		"a skewer leaves the hand at its cue and is in the mouth exactly on its beat")
	s.free()


var _last_girth := 1.0
var _intensity_seen: Array = []


## Plays one round. opts: offset (s), calib (s), never, stray, lane (force a lane), wrong_lane,
## late_first_of_double (s late for the first of each half-beat pair).
func _play(r: Array, opts: Dictionary) -> Dictionary:
	if opts.is_empty():
		_intensity_seen.append(0)
	Settings.calib_ms = opts.get("calib", 0.0) * 1000.0
	var level: Node = load(r[0]).instantiate()
	level.chart_path = r[1]
	level.get_node("Conductor").clock = func(): return _t
	root.add_child(level)
	var result := {}
	level.finished.connect(func(res): result.merge(res))
	var taps: Array = []  # [time, lane]
	if not opts.get("never", false):
		for i in level.hits.size():
			var h: Dictionary = level.hits[i]
			var at: float = h.time + opts.get("offset", 0.0)
			var late: float = opts.get("late_first_of_double", 0.0)
			if late > 0.0 and i + 1 < level.hits.size() and is_equal_approx(level.hits[i + 1].beat - h.beat, 0.5):
				at += late
			var lane: int = opts.get("lane", h.lane if h.lane >= 0 else 1)
			if opts.get("wrong_lane", false):
				lane = (h.lane + 1) % 3
			taps.append([at, lane])
	if opts.get("stray", false):
		for i in range(1, level.hits.size()):
			var a: float = level.hits[i - 1].time
			var b: float = level.hits[i].time
			if b - a >= 0.9:
				taps.append([(a + b) / 2.0, 1])
	taps.sort_custom(func(x, y): return x[0] < y[0])
	_t = -0.2
	level.start()
	var k := 0
	while result.is_empty() and _t < 90.0:
		_t += STEP
		while k < taps.size() and _t >= taps[k][0]:
			var now := _t
			_t = taps[k][0]  # tap at the exact planned time, not the frame's
			level.tap(taps[k][1])
			_t = now
			k += 1
		await process_frame
	if opts.is_empty():
		_intensity_seen[-1] = level.stage.intensity
		_last_girth = level.get_node("%Kagura").girth
	level.queue_free()
	await process_frame
	Settings.calib_ms = 0.0
	return result
