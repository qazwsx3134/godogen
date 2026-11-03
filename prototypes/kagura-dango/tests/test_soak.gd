extends "res://addons/proto_kit/test_kit.gd"
## Hardening: a whole final round of random mashing (any lane, several taps a frame, taps long before the first cue and
## after the last), every guard on the round's lifecycle (taps before start, start twice, finish twice), replaying a round
## many times without leaking nodes, and the phone's haptics. Run on an injected clock, like levels.
## The charts are the author's own (edited in the chart maker); the test plays a snapshot.

const STEP := 1.0 / 60.0

var _t := 0.0
var _chart := ""


func _init() -> void:
	_run.call_deferred()


func _level() -> Node:
	var level: Node = load("res://scenes/toss_game.tscn").instantiate()
	level.chart_path = _chart
	level.get_node("Conductor").clock = func(): return _t
	root.add_child(level)
	return level


func _run() -> void:
	Settings.path = OS.get_temp_dir().path_join("kagura-dango-test-soak.cfg")
	DirAccess.remove_absolute(Settings.path)
	_chart = OS.get_temp_dir().path_join("kagura-dango-test-soak-toss3.json")
	DirAccess.copy_absolute(ProjectSettings.globalize_path("res://data/songs/toss3.json"), _chart)
	MatchState.reset()

	# Lifecycle guards.
	var level := _level()
	await process_frame
	var start: float = level.conductor.music_start
	_t = start - 0.2
	level.tap(1)  # before start()
	_expect(level.hits.all(func(h): return h.grade == &""), "a tap before the round starts judges nothing")
	level.start()
	level.start()  # a double start must not double anything
	level._finish()
	level._finish()
	_expect(MatchState.results.size() == 1, "finishing twice records one result (got %d)" % MatchState.results.size())
	level.free()

	# Haptics: a tick for a hit, a bump for a miss, a thump for Kagura going down.
	MatchState.reset()
	level = _level()
	await process_frame
	var ms := 0
	level.haptics.clock = func(): return ms
	var buzzes: Array = []
	level.haptics.vibrated.connect(func(d, _a): buzzes.append(d))
	_t = level.conductor.music_start - 0.2
	level.start()
	level._judge(0, &"ace", 0.0)
	ms += 500
	level._judge(1, &"miss", 0.2)
	ms += 500
	level.lives = 1
	level._judge(2, &"miss", 0.2)
	_expect(buzzes == [14, 38, 90], "haptics: tick, bump, thump (got %s)" % [buzzes])
	level.free()

	# Replaying a round does not leak nodes or tweens.
	var counts := []
	for k in 6:
		MatchState.reset()
		level = _level()
		await process_frame
		_t = level.conductor.music_start - 0.2
		level.start()
		for f in 90:
			_t += STEP
			await process_frame
		level.free()
		await process_frame
		await process_frame
		counts.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	_expect(counts[-1] <= counts[0] + 2, "six replays leave no nodes behind (node counts %s)" % [counts])

	# A whole round of mashing.
	MatchState.reset()
	level = _level()
	await process_frame
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var done := []
	level.finished.connect(func(r): done.append(r))
	_t = level.conductor.music_start - 3.0  # taps in the count-in: harmless whiffs
	level.start()
	var frames := 0
	while done.is_empty() and frames < 60 * 200:
		_t += STEP
		frames += 1
		for k in rng.randi_range(0, 3):
			level.tap(rng.randi_range(0, 2))
		await process_frame
	_expect(done.size() == 1, "the mashed round ends exactly once (got %d after %d frames)" % [done.size(), frames])
	var r: Dictionary = done[0]
	var graded: int = r.counts.ace + r.counts.good + r.counts.barely + r.counts.miss
	_expect(graded == level.hits.size(), "every note is graded once (%d of %d)" % [graded, level.hits.size()])
	_expect(r.max_combo <= level.hits.size() and level.lives >= 0 and level.lives <= level.max_lives, "combo and lives stay in range")
	level.tap(1)
	level.tap(0)
	_expect(done.size() == 1, "taps after the round ended do nothing")
	level.free()
	_finish("SOAK")
