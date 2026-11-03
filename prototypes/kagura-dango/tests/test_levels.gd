extends "res://addons/proto_kit/test_kit.gd"
## Every round played by a bot on an injected clock (song seconds advanced by the test, not the audio), so the run
## is the same at any frame rate. Checks grading, the three lanes of round 1, the overlapping windows of half-beat
## doubles, calibration, MatchState (who ate what, the match score, Kagura's girth and body stage) and the stage's
## intensity.

const STEP := 1.0 / 60.0
## [scene, chart, number of cues]; the counts are read from the charts (the author edits them in the chart maker).
var ROUNDS := [["res://scenes/three_eat.tscn", "res://data/songs/eat3.json", 0],
	["res://scenes/feast.tscn", "res://data/songs/feast2.json", 0],
	["res://scenes/toss_game.tscn", "res://data/songs/toss3.json", 0]]

var _t := 0.0


func _init() -> void:
	_run.call_deferred()


func _chart(r: Array) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(r[1]))


## Cues of these types in a round's chart.
func _count(r: Array, types: Array) -> int:
	return _chart(r).cues.filter(func(c): return c.type in types).size()


## Who eats how many skewers when every cue of every round is hit (lane owner in rounds 1–2, Kagura otherwise).
func _expected_eaten() -> Dictionary:
	var eaten := {&"gintoki": 0, &"shinpachi": 0, &"kagura": 0}
	for r in ROUNDS:
		var c := _chart(r)
		for cue in c.cues:
			if c.has("skewers") and cue.type not in c.skewers:
				continue
			var lane := int(c.get("lanes", {}).get(cue.type, -1))
			eaten[[&"gintoki", &"shinpachi", &"kagura"][lane] if lane >= 0 else &"kagura"] += 1
	return eaten


func _run() -> void:
	# Play a snapshot of each chart: the author may be saving charts in the chart maker while this runs.
	for r in ROUNDS:
		var copy := OS.get_temp_dir().path_join("kagura-dango-test-" + String(r[1]).get_file())
		DirAccess.copy_absolute(ProjectSettings.globalize_path(r[1]), copy)
		r[1] = copy
		r[2] = _chart(r).cues.size()
	_check_arc()
	for r in ROUNDS:
		_check_chart(r)
	await _check_round_one_serving()
	await _check_voice()
	await _check_hype()
	# A whole match with exact taps on the right lanes: every round all ace, Kagura grows, the team wins.
	MatchState.reset()
	var girth := []
	var tiers := []
	for r in ROUNDS:
		var res := await _play(r, {})
		_expect(res.score == 100 and res.counts.ace == r[2], "%s exact taps: all %d ace (got %s)" % [r[1], r[2], res])
		_expect(res.max_combo == r[2] and res.full_combo, "%s exact taps: a full combo of %d (got %d)" % [r[1], r[2], res.max_combo])
		_expect(res.points == r[2] * Judge.SCORE[&"ace"], "%s: every ace adds %d points (got %d)" % [r[1], Judge.SCORE[&"ace"], res.points])
		_expect(_last_score_text == Judge.format_points(MatchState.score), "the HUD shows the match score %d (got %s)" % [MatchState.score, _last_score_text])
		girth.append(_last_girth)
		tiers.append([_first_tier, _last_tier])
	_expect(_title_seen == ["第一回合　三人齊吃", "", "最終回合　全力餵食"], "round 2 shows no round title (got %s)" % [_title_seen])
	_expect(_rivals_seen == [[true, false], [false, false], [true, true]], "one rival in round 1, none at the table in round 2, two in round 3 (got %s)" % [_rivals_seen])
	_expect(MatchState.score == (ROUNDS[0][2] + ROUNDS[1][2] + ROUNDS[2][2]) * Judge.SCORE[&"ace"], "the score adds up over all three rounds (got %d)" % MatchState.score)
	_expect(MatchState.won(), "a perfect match is won")
	_expect(tiers[2] == [2, 3], "round 3 opens with Kagura's round 2 body and grows into the roundest (got %s)" % [tiers])
	_expect(MatchState.eaten == _expected_eaten(), "each skewer went to its lane's eater (got %s, want %s)" % [MatchState.eaten, _expected_eaten()])
	_expect(girth[1] < 1.14 and girth[2] > 1.7, "Kagura stays slim through round 2 and is roundest after round 3 (%s)" % [girth])
	_expect(_intensity_seen == [1, 2, 3], "the stage gets livelier each round (%s)" % [_intensity_seen])
	# Grades.
	MatchState.reset()
	var res := await _play(ROUNDS[2], {offset = 0.05})
	_expect(res.counts.good == ROUNDS[2][2] and res.score == 85, "taps 50 ms late are all good (got %s)" % [res])
	res = await _play(ROUNDS[2], {offset = -0.1})
	_expect(res.counts.barely == ROUNDS[2][2] and res.rank == &"again", "taps 100 ms early are all barely (got %s)" % [res])
	res = await _play(ROUNDS[2], {stray = true})
	_expect(res.score == 100, "stray taps between cues cost nothing (got %s)" % [res])
	res = await _play(ROUNDS[2], {offset = 0.08, calib = 0.08})
	_expect(res.score == 100, "with 80 ms calibration, taps 80 ms late are ace (got %s)" % [res])
	MatchState.reset()
	res = await _play(ROUNDS[2], {never = true, no_lives = true})
	_expect(res.counts.miss == ROUNDS[2][2] and res.score == 0, "no taps: every cue missed (got %s)" % [res])
	_expect(MatchState.team_total() == 0 and MatchState.score == 0, "missed skewers are not eaten and score nothing")
	# Lives: only the final round has them. Running out knocks Kagura flat, but no round is ever lost: it plays to the end.
	MatchState.reset()
	res = await _play(ROUNDS[2], {never = true})
	_expect(res.knocked_down and res.counts.miss == ROUNDS[2][2], "final round, no taps: out of lives, knocked down (got %s)" % [res])
	_expect(_ended_at > _miss_time_of(ROUNDS[2], ROUNDS[2][2]) - 0.2, "the round still plays to its end")
	_expect(_max_rotation > 1.0, "Kagura lies on the ground (rotation %.2f)" % _max_rotation)
	_expect(_downs >= 2, "she gets back up (lives refilled) and can be knocked down again (went down %d times)" % _downs)
	for k in 2:
		res = await _play(ROUNDS[k], {never = true})
		_expect(not res.knocked_down and res.counts.miss == ROUNDS[k][2], "%s, no taps: missed, nobody knocked down (got %s)" % [ROUNDS[k][1], res])
	var every: int = ROUNDS[2][2] / 3 + 1  # skips cues every, 2 × every: exactly 2 misses
	res = await _play(ROUNDS[2], {skip_every = every})
	_expect(not res.knocked_down and res.counts.miss == 2, "final round, 2 misses: still standing at the end (got %s)" % [res])
	_expect(not res.full_combo and res.max_combo < ROUNDS[2][2] and res.max_combo >= every - 1, "a miss breaks the combo: best run %d" % res.max_combo)
	# Round 2: kicks and rice score but are not skewers; a missed kick scores nothing.
	MatchState.reset()
	res = await _play(ROUNDS[1], {})
	var r2_skewers := _count(ROUNDS[1], ["dango", "bento"])
	_expect(res.score == 100 and MatchState.team_total() == r2_skewers and MatchState.score == ROUNDS[1][2] * Judge.SCORE[&"ace"],
		"round 2 exact: only dango and bento are eaten, every hit scores (team %d score %d)" % [MatchState.team_total(), MatchState.score])
	MatchState.reset()
	res = await _play(ROUNDS[1], {only_skip = &"rival"})
	_expect(MatchState.score == (ROUNDS[1][2] - _count(ROUNDS[1], ["rival"])) * Judge.SCORE[&"ace"] and MatchState.team_total() == r2_skewers,
		"round 2: missed kicks score nothing (score %d)" % MatchState.score)
	# Half-beat doubles at 136 BPM (0.22 s apart): the first tapped 115 ms late is nearer the second cue, yet it
	# must answer the first (still inside its window) and leave the second for the next tap.
	res = await _play(ROUNDS[2], {late_first_of_double = 0.115})
	_expect(res.counts.miss == 0 and res.counts.ace + res.counts.barely == ROUNDS[2][2],
		"a late first tap of a double does not steal the second (got %s)" % [res])
	# Round 1 lanes: feeding the wrong person is a miss; any lane is fine in the toss rounds.
	MatchState.reset()
	res = await _play(ROUNDS[0], {wrong_lane = true})
	_expect(res.counts.miss == ROUNDS[0][2] and MatchState.team_total() == 0, "wrong lane on every cue: all missed (got %s)" % [res])
	res = await _play(ROUNDS[2], {lane = 0})
	_expect(res.score == 100, "the toss rounds take a tap on any side (got %s)" % [res])
	# Replaying a round does not count its skewers twice.
	MatchState.reset()
	await _play(ROUNDS[0], {})
	var before := MatchState.team_total()
	MatchState.restore_round()
	_expect(MatchState.team_total() == 0 and before == ROUNDS[0][2] and MatchState.score == 0, "restore_round undoes the round's skewers and points (%d → %d)" % [before, MatchState.team_total()])
	_finish("LEVELS")


## Spoken lines: one at a time (a second waits its turn unless it interrupts) and the song ducks under them.
## The clips are local only (not in git), so this checks only what it can.
func _check_voice() -> void:
	var level: Node = load(ROUNDS[1][0]).instantiate()
	level.chart_path = ROUNDS[1][1]
	level.get_node("Conductor").clock = func(): return _t
	root.add_child(level)
	await process_frame
	_expect(not level.play_clip("no_such_clip"), "a missing clip is skipped")
	# Hit sounds: a barely tap plays HitBad, a good or ace tap plays Hit.
	level._judge(0, &"barely", 0.1)
	_expect(level.hud.get_node("%HitBad").playing and not level.hud.get_node("%Hit").playing, "a barely hit plays hit-bad")
	level._judge(1, &"ace", 0.0)
	_expect(level.hud.get_node("%Hit").playing, "an ace hit plays hit")
	MatchState.reset()
	if not ResourceLoader.exists(level.VOICE_DIR + "kagura_rice.wav"):
		print("voice clips not present: run tools/convert_voice.sh to check them")
		level.free()
		return
	level.conductor.play()
	level.say("kagura_rice")
	var first: AudioStreamPlayer = level._line
	level.say("gintoki_kick")
	_expect(level._line == first and first.playing, "a line does not talk over another")
	level.say("kagura_eye", true)
	_expect(level._line != first and not first.playing, "an interrupting line cuts the current one")
	level._running = true
	level._process(0.0)
	_expect(level.conductor._ducked, "the song ducks under a line")
	level.free()


## Combo hype: nothing below 10 in a row, full from 50; on a hyped beat the camera punches in and the background
## figures hop.
func _check_hype() -> void:
	var level: Node = load(ROUNDS[2][0]).instantiate()
	level.chart_path = ROUNDS[2][1]
	root.add_child(level)
	await process_frame
	level.combo = 9
	_expect(level.hype() == 0.0, "no hype below 10 in a row")
	level.combo = 30
	_expect(is_equal_approx(level.hype(), 0.5), "30 in a row is half hype")
	level.combo = 80
	_expect(level.hype() == 1.0, "full hype from 50")
	var referee: Node2D = level.stage.get_node("%Referee")
	var rest: float = referee.position.y
	level._beat(int(level.chart.count_in_beats) + 1)
	_expect(level.camera.zoom.x > 1.0, "a hyped beat punches the camera in")
	await create_timer(0.08).timeout
	_expect(referee.position.y < rest - 5.0, "the referee hops on a hyped beat (%.1f → %.1f)" % [rest, referee.position.y])
	level.free()


func _check_round_one_serving() -> void:
	var level: Node = load("res://scenes/three_eat.tscn").instantiate()
	level.chart_path = ROUNDS[0][1]
	root.add_child(level)
	await process_frame
	var serve_origin: Marker2D = level.get_node("%ServeOrigin")
	var shopkeeper: Node2D = level.get_node("%Shopkeeper")
	var shopkeeper_sprite: Sprite2D = shopkeeper.get_node("%Sprite")
	_expect(shopkeeper.visible and shopkeeper_sprite.texture != null, "round 1 shows the tray-carrying shopkeeper")
	var plate_names := [&"PlateLeft", &"PlateMiddle", &"PlateRight"]
	var checked_lanes: Array[bool] = [false, false, false]
	for index in level.hits.size():
		var hit: Dictionary = level.hits[index]
		var lane: int = hit.lane
		if lane < 0 or checked_lanes[lane]:
			continue
		level.call("_on_cue", index)
		var skewers: Node2D = level.get_node("%Skewers")
		var skewer: Node = skewers.get_child(skewers.get_child_count() - 1)
		var plate: Marker2D = level.get_node("%" + String(plate_names[lane]))
		var expected_from: Vector2 = skewers.to_local(serve_origin.global_position)
		var expected_to: Vector2 = skewers.to_local(plate.global_position)
		_expect((skewer.get("from") as Vector2).is_equal_approx(expected_from)
			and (skewer.get("to") as Vector2).is_equal_approx(expected_to),
			"round 1 %s skewer is served from the owner to its lane's table plate" % [hit.type])
		_expect(float(skewer.get("t1")) < hit.time, "round 1 %s skewer lands on the table before its eating beat" % [hit.type])
		checked_lanes[lane] = true
	_expect(checked_lanes.all(func(value): return value), "round 1 serves to all three table lanes")
	level.free()


func _check_chart(r: Array) -> void:
	var level: Node = load(r[0]).instantiate()
	level.chart_path = r[1]
	root.add_child(level)
	# Same-lane hits need room for a second tap; two lanes on one beat are a chord (two fingers / keys).
	var ok := true
	var last := {}
	var by_time: Array = level.hits.duplicate()
	by_time.sort_custom(func(a, b): return a.time < b.time)  # a quick toss thrown later can land before a slow one
	for h in by_time:
		ok = ok and (not last.has(h.lane) or h.time - last[h.lane] >= 0.2)
		last[h.lane] = h.time
	_expect(level.hits.size() == r[2] and ok, "%s: %d hits, same-lane ones at least 0.2 s apart" % [r[1], r[2]])
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
var _first_tier := 0
var _last_tier := 0
var _last_score_text := ""
var _title_seen: Array = []
var _rivals_seen: Array = []
var _ended_at := 0.0
var _max_rotation := 0.0
var _downs := 0


## When the n-th cue of a round is judged missed with no taps (its window closes).
func _miss_time_of(r: Array, n: int) -> float:
	var level: Node = load(r[0]).instantiate()
	level.chart_path = r[1]
	root.add_child(level)
	var t: float = level.hits[n - 1].time + Judge.BARELY
	level.free()
	return t
var _intensity_seen: Array = []


## Plays one round. opts: offset (s), calib (s), never, stray, lane (force a lane), wrong_lane,
## late_first_of_double (s late for the first of each half-beat pair).
func _play(r: Array, opts: Dictionary, lives_out := []) -> Dictionary:
	if opts.is_empty():
		_intensity_seen.append(0)
	Settings.calib_ms = opts.get("calib", 0.0) * 1000.0
	var level: Node = load(r[0]).instantiate()
	level.chart_path = r[1]
	level.get_node("Conductor").clock = func(): return _t
	root.add_child(level)
	if opts.get("no_lives", false):
		level.max_lives = 0
	if opts.is_empty():
		_first_tier = level.get_node("%Kagura").tier()
		_title_seen.append(level.hud.get_node("%RoundLabel").text)
		_rivals_seen.append([level.stage.get_node("%RivalA").visible, level.stage.get_node("%RivalB").visible])
	var start: float = level.conductor.music_start
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
			if opts.has("skip_every") and i % int(opts.skip_every) == 0 and i > 0:
				continue
			if opts.has("only_skip") and h.type == opts.only_skip:
				continue
			var lane: int = opts.get("lane", h.lane if h.lane >= 0 else 1)
			if opts.get("wrong_lane", false):  # a lane no cue on this beat uses (a chord's other note would answer it)
				var taken: Array = level.hits.filter(func(o): return is_equal_approx(o.time, h.time)).map(func(o): return o.lane)
				lane = [(h.lane + 1) % 3, (h.lane + 2) % 3].filter(func(l): return l not in taken)[0]
			taps.append([at, lane])
	if opts.get("stray", false):
		var times: Array = level.hits.map(func(h): return h.time)
		times.sort()
		for i in range(1, times.size()):
			var a: float = times[i - 1]
			var b: float = times[i]
			if b - a >= 0.9:
				taps.append([(a + b) / 2.0, 1])
	taps.sort_custom(func(x, y): return x[0] < y[0])
	_t = start - 0.2
	level.start()
	_max_rotation = 0.0
	_downs = 0
	var was_down := false
	var k := 0
	while result.is_empty() and _t < level.end_time() + 2.0:
		_t += STEP
		while k < taps.size() and _t >= taps[k][0]:
			var now := _t
			_t = taps[k][0]  # tap at the exact planned time, not the frame's
			level.tap(taps[k][1])
			_t = now
			k += 1
		await process_frame
		if "down" in level:
			_downs += int(level.down and not was_down)
			was_down = level.down
			_max_rotation = maxf(_max_rotation, absf(level.get_node("%Kagura").rotation))
	_ended_at = _t
	lives_out.append(level.lives)
	if opts.is_empty():
		_intensity_seen[-1] = level.stage.intensity
		_last_girth = level.get_node("%Kagura").girth
		_last_tier = level.get_node("%Kagura").tier()
		await create_timer(0.4).timeout  # the score finishes counting up
		_last_score_text = level.hud.get_node("%Score").text
	level.queue_free()
	await process_frame
	Settings.calib_ms = 0.0
	return result
