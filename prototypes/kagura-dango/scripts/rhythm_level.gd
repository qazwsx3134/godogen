class_name RhythmLevel
extends Node2D
## Base of every minigame. Reads a chart (data/songs/<id>.json), turns each cue into the beat the player must hit
## (cue beat + land_after[type]), judges taps against the Conductor and reports the result. Also runs what every
## round shares: the stage (crowd, lanterns, rival team, referee) pulsing on the beat at the chart's intensity, the
## scoreboard, the referee's calls, and MatchState.
## A minigame scene extends this and only presents: override _on_cue, _on_judged, _on_whiff, _on_beat.

signal judged(index: int, grade: StringName, offset: float)
signal finished(result: Dictionary)

const JUDGE_TEXT := {&"ace": "完美！", &"good": "不錯", &"barely": "勉強", &"miss": "漏掉了…", &"wrong": "餵錯人！"}

@export_file("*.json") var chart_path := ""

var chart := {}
## One entry per cue, in cue order: {cue_beat, beat, time, type, lane, grade}. grade is &"" until judged.
## lane is -1 when any tap answers the cue, otherwise 0 left, 1 middle, 2 right.
var hits: Array[Dictionary] = []
## Seconds the player's taps arrive late (from calibration); subtracted from every tap.
var calib := 0.0
var intensity := 1

var _next_cue := 0
var _running := false
var _last_beat := -999
var _rival_beats: Array[int] = []
var _counted_in := false

@onready var conductor: Conductor = %Conductor
@onready var stage: Node2D = %Stage
@onready var hud: CanvasLayer = %HUD
@onready var camera: Camera2D = %Camera


func _ready() -> void:
	chart = JSON.parse_string(FileAccess.get_file_as_string(chart_path))
	conductor.load_song(chart)
	calib = Settings.calib_ms / 1000.0
	intensity = int(chart.get("intensity", 1))
	var lanes: Dictionary = chart.get("lanes", {})
	for cue in chart.cues:
		var beat: float = cue.beat + float(chart.land_after[cue.type])
		hits.append({cue_beat = float(cue.beat), beat = beat, time = conductor.beat_time(beat),
			type = StringName(cue.type), lane = int(lanes.get(cue.type, -1)), grade = &""})
	hits.sort_custom(func(a, b): return a.cue_beat < b.cue_beat)
	# The rival team eats `rival` skewers spread evenly over the round.
	var first: int = int(chart.count_in_beats)
	var span := int(chart.end_beat) - first
	for k in int(chart.get("rival", 0)):
		_rival_beats.append(first + 1 + floori(span * k / float(chart.rival)))
	stage.set_intensity(intensity)
	hud.set_round(chart.title)
	_update_scoreboard()


func start() -> void:
	_next_cue = 0
	_running = true
	MatchState.begin_round()
	hud.call_out("預備……")
	conductor.play()


func end_time() -> float:
	return conductor.beat_time(float(chart.end_beat)) + 1.0


func _process(_delta: float) -> void:
	if not _running:
		return
	var t := conductor.time()
	var beat := floori(conductor.beat_at(t))
	if t > 0.0 and beat != _last_beat:
		for b in range(maxi(_last_beat + 1, beat), beat + 1):
			_beat(b)
		_last_beat = beat
	while _next_cue < hits.size() and t >= conductor.beat_time(hits[_next_cue].cue_beat):
		_on_cue(_next_cue)
		_next_cue += 1
	for i in hits.size():
		var hit := hits[i]
		if hit.grade == &"" and t - calib > hit.time + Judge.BARELY:
			_judge(i, &"miss", t - calib - hit.time)
	if t >= end_time():
		_finish()


func _beat(b: int) -> void:
	var count_in := int(chart.count_in_beats)
	if b == count_in:
		hud.call_out("開始！")
		stage.referee_call()
	elif b == int(chart.end_beat):
		hud.call_out("停！")
		stage.referee_call()
	if b >= count_in and b < int(chart.end_beat):
		stage.pulse()
		if b in _rival_beats:
			MatchState.rival += 1
			stage.rival_eat(MatchState.rival)
			_update_scoreboard()
	_on_beat(b)


func _unhandled_input(event: InputEvent) -> void:
	if not _running:
		return
	var lane := -2
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var width := get_viewport().get_visible_rect().size.x
		lane = clampi(int(event.position.x / (width / 3.0)), 0, 2)
	elif event.is_action_pressed("lane_left") and not event.is_echo():
		lane = 0
	elif event.is_action_pressed("lane_mid") and not event.is_echo():
		lane = 1
	elif event.is_action_pressed("lane_right") and not event.is_echo():
		lane = 2
	elif event.is_action_pressed("tap") and not event.is_echo():
		lane = 1
	if lane >= 0:
		get_viewport().set_input_as_handled()
		tap(lane)


## A tap now, on a lane (0 left, 1 middle, 2 right). It answers the earliest unjudged cue whose window holds the
## tap (earliest, not nearest: two half-beat cues have overlapping windows, and a late first tap must not steal the
## second). A cue on another lane is a wrong feed (counts as a miss); no cue at all is a harmless whiff.
func tap(lane := 1) -> void:
	var t := conductor.time() - calib
	var open: Array[int] = []
	for i in hits.size():
		if hits[i].grade == &"" and Judge.grade(t - hits[i].time) != &"":
			open.append(i)
	open.sort_custom(func(a, b): return hits[a].time < hits[b].time)
	for i in open:
		if hits[i].lane < 0 or hits[i].lane == lane:
			_judge(i, Judge.grade(t - hits[i].time), t - hits[i].time)
			return
	if not open.is_empty():
		_judge(open[0], &"miss", t - hits[open[0]].time, lane)
		return
	_on_whiff(lane)


func result() -> Dictionary:
	var grades := hits.map(func(h): return h.grade if h.grade != &"" else &"miss")  # unjudged at the end = missed
	var points := Judge.score(grades)
	var counts := {&"ace": 0, &"good": 0, &"barely": 0, &"miss": 0}
	for g in grades:
		counts[g] += 1
	return {id = chart.id, title = chart.title, score = points, rank = Judge.rank(points), counts = counts}


## wrong_lane >= 0 marks a miss caused by feeding the wrong person.
func _judge(index: int, grade: StringName, offset: float, wrong_lane := -1) -> void:
	hits[index].grade = grade
	if grade != &"miss":
		var who := eater(index)
		MatchState.eaten[who] += 1
		_update_scoreboard()
		if grade == &"ace" and intensity >= 2:
			shake(2.0 + intensity, 0.12)
	hud.show_judge(JUDGE_TEXT[&"wrong" if wrong_lane >= 0 else grade])
	_on_judged(index, grade, offset, wrong_lane)
	judged.emit(index, grade, offset)


## Who eats this cue's skewer: by lane in round 1, Kagura otherwise.
func eater(index: int) -> StringName:
	return [&"gintoki", &"shinpachi", &"kagura"][hits[index].lane] if hits[index].lane >= 0 else &"kagura"


func shake(strength: float, time: float) -> void:
	var tw := create_tween()
	for k in 4:
		tw.tween_property(camera, "offset", Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength, time / 5.0)
	tw.tween_property(camera, "offset", Vector2.ZERO, time / 5.0)


func _update_scoreboard() -> void:
	hud.set_score(MatchState.team_total(), MatchState.rival)


func _finish() -> void:
	_running = false
	conductor.stop()
	var r := result()
	MatchState.results.append(r)
	finished.emit(r)


func _on_cue(_index: int) -> void:
	pass


func _on_judged(_index: int, _grade: StringName, _offset: float, _wrong_lane: int) -> void:
	pass


func _on_whiff(_lane: int) -> void:
	pass


func _on_beat(_b: int) -> void:
	pass
