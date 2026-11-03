class_name RhythmLevel
extends Node2D
## Base of every minigame. Reads a chart (data/songs/<id>.json), turns each cue into the beat the player must hit
## (cue beat + land_after[type]), judges taps against the Conductor and reports the result. Also runs what every
## round shares: the stage (crowd, lanterns, rival team, referee) pulsing on the beat at the chart's intensity, the
## match score (every hit adds Judge.SCORE points), the referee's calls, and MatchState.
## A minigame scene extends this and only presents: override _on_cue, _on_judged, _on_whiff, _on_beat.

signal judged(index: int, grade: StringName, offset: float)
signal finished(result: Dictionary)

const JUDGE_TEXT := {&"ace": "完美！", &"good": "不錯", &"barely": "勉強", &"miss": "漏掉了…", &"wrong": "餵錯人！"}

@export_file("*.json") var chart_path := ""
## Kagura's girth (actor.gd) as this round opens (x) and once she has eaten all of its food (y): her body follows the
## round's progress, not how many skewers the charts hold. Rounds 1 and 2 keep her slim (below 1.14); round 3 opens
## round (1.5) and crosses into the roundest body (1.73) halfway.
@export var kagura_girth := Vector2(1.0, 1.0)
## Volume of the eating sounds (clips in eat_clips / eat_clip; the Chomp players sit at the same level in the scene).
@export var eat_volume_db := -8.0
## Line said as the round starts (a clip id in assets/voice/, see say()).
@export var start_voice := ""

const Haptics := preload("res://addons/proto_kit/haptics.gd")
const VOICE_DIR := "res://assets/voice/"
## The song fades in over the count-in while the dialogue's BGM fades out (main.gd), so they cross-fade.
const SONG_FADE_IN := 1.2
## Combo hype (hype()): the beat starts to punch from HYPE_FROM hits in a row and is at its biggest from HYPE_FULL.
const HYPE_FROM := 10
const HYPE_FULL := 50

var chart := {}
## One entry per cue, in cue order: {cue_beat, beat, time, type, lane, grade}. grade is &"" until judged.
## lane is -1 when any tap answers the cue, otherwise 0 left, 1 middle, 2 right.
var hits: Array[Dictionary] = []
## Seconds the player's taps arrive late (from calibration); subtracted from every tap.
var calib := 0.0
var intensity := 1
## Round 3: every miss hits Kagura in the eye and costs a life; at 0 she is knocked down (_on_knocked_down: lies on
## the ground, misses cost nothing) until get_up() refills her lives. The round plays on, it is never lost.
## 0 = no lives (rounds 1, 2).
var max_lives := 0
## Hits in a row (a miss resets it) and the round's best run; a round with no miss is a full combo.
var combo := 0
var max_combo := 0
var lives := 0
## She is on the ground now; knocked_down: she went down at least once this round (the result's comment).
var down := false
var knocked_down := false

var _next_cue := 0
var _running := false
var _last_beat := -999
var _rival_beats: Array[int] = []
var _rival_eaten := 0
## The phone's vibration motor (harmless where there is none): a tick for a hit, a bump for a miss, a thump for a
## combo milestone or Kagura going down.
var haptics := Haptics.new()
var _clips := {}  # clip id → its AudioStreamPlayer
var _line: AudioStreamPlayer  # the spoken line playing now
var _counted_in := false

@onready var conductor: Conductor = %Conductor
@onready var stage: Node2D = %Stage
@onready var hud: CanvasLayer = %HUD
@onready var camera: Camera2D = %Camera


func _ready() -> void:
	chart = JSON.parse_string(FileAccess.get_file_as_string(chart_path))
	conductor.load_song(chart)
	calib = Settings.calib_ms / 1000.0
	haptics.enabled = Settings.haptics
	intensity = int(chart.get("intensity", 1))
	max_lives = int(chart.get("lives", 0))
	lives = max_lives
	var lanes: Dictionary = chart.get("lanes", {})
	for cue in chart.cues:
		var beat: float = cue.beat + float(chart.land_after[cue.type])
		hits.append({cue_beat = float(cue.beat), beat = beat, time = conductor.beat_time(beat),
			type = StringName(cue.type), lane = int(lanes.get(cue.type, -1)), grade = &""})
	hits.sort_custom(func(a, b): return a.cue_beat < b.cue_beat)
	# The rival team (background only) eats `rival` times, spread evenly over the round.
	var first: int = int(chart.count_in_beats)
	var span := int(chart.end_beat) - first
	for k in int(chart.get("rival", 0)):
		_rival_beats.append(first + 1 + floori(span * k / float(chart.rival)))
	stage.set_intensity(intensity)
	stage.set_background(chart.get("background", ""))
	stage.set_calm(chart.get("calm", false))
	stage.set_rival_table(chart.get("rival_table", true))
	hud.get_node("%NoteTrack").setup(self)
	hud.set_round(chart.title if chart.get("show_title", true) else "")
	hud.set_score(MatchState.score)


func start() -> void:
	_next_cue = 0
	_rival_eaten = 0
	combo = 0
	max_combo = 0
	_running = true
	knocked_down = false
	down = false
	lives = max_lives
	hud.set_lives(lives, max_lives)
	MatchState.begin_round()
	hud.call_out("預備……")
	conductor.play(-1.0, SONG_FADE_IN)
	say(start_voice)


func end_time() -> float:
	return conductor.beat_time(float(chart.end_beat)) + 1.0


func _process(_delta: float) -> void:
	if not _running:
		return
	conductor.duck(_line != null and _line.playing)
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
		stage.referee_call(&"start")
	elif b == int(chart.end_beat):
		hud.call_out("停！")
		stage.referee_call(&"stop")
	if b >= count_in and b < int(chart.end_beat):
		var h := hype()
		stage.pulse(h)
		if h > 0.0:  # the screen punches in on the beat, harder the longer the combo
			var tw := create_tween()
			camera.zoom = Vector2.ONE * (1.0 + 0.035 * h)
			tw.tween_property(camera, "zoom", Vector2.ONE, 0.18).set_ease(Tween.EASE_OUT)
		if b in _rival_beats:
			_rival_eaten += 1
			stage.rival_eat(_rival_eaten)
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
	return {id = chart.id, title = chart.title, score = points, rank = Judge.rank(points), counts = counts,
		knocked_down = knocked_down, points = MatchState.round_points(), max_combo = max_combo,
		full_combo = counts[&"miss"] == 0}


## wrong_lane >= 0 marks a miss caused by feeding the wrong person.
func _judge(index: int, grade: StringName, offset: float, wrong_lane := -1) -> void:
	hits[index].grade = grade
	combo = 0 if grade == &"miss" else combo + 1
	max_combo = maxi(max_combo, combo)
	hud.set_combo(combo)
	haptics.buzz(1 if grade == &"miss" else (2 if combo > 0 and combo % hud.COMBO_MILESTONE == 0 else 0))
	if grade != &"miss":
		hud.play_hit(grade)
		hud.add_score(MatchState.add_points(grade), MatchState.score, grade == &"ace")
	if grade != &"miss" and counts_as_skewer(index):
		MatchState.eaten[eater(index)] += 1
		if grade == &"ace" and intensity >= 2:
			shake(2.0 + intensity, 0.12)
	hud.show_judge(JUDGE_TEXT[&"wrong" if wrong_lane >= 0 else grade])
	_on_judged(index, grade, offset, wrong_lane)
	judged.emit(index, grade, offset)
	if grade == &"miss" and max_lives > 0 and _running and not down:
		lives -= 1
		hud.set_lives(lives, max_lives)
		if lives > 0:
			_on_hurt()
		else:
			knocked_down = true
			down = true
			haptics.buzz(2)
			_on_knocked_down()


## How hyped the round is from the combo: 0 below HYPE_FROM hits in a row, 1 at HYPE_FULL and beyond.
func hype() -> float:
	return clampf(float(combo - HYPE_FROM) / (HYPE_FULL - HYPE_FROM), 0.0, 1.0)


## Kagura's girth now: kagura_girth.x → .y by the share of this round's food she has eaten.
func kagura_girth_now() -> float:
	var total := 0
	var eaten := 0
	for i in hits.size():
		if eater(i) == &"kagura" and counts_as_skewer(i):
			total += 1
			eaten += int(hits[i].grade not in [&"", &"miss"])
	return lerpf(kagura_girth.x, kagura_girth.y, eaten / float(total) if total > 0 else 0.0)


## Cue types listed in the chart's "skewers" are eaten skewers (counted for the team); all count when it is absent.
## Round 2: kicking a rival or a spoon of rice is not a skewer.
func counts_as_skewer(index: int) -> bool:
	return not chart.has("skewers") or String(hits[index].type) in chart.skewers


## Who eats this cue's skewer: by lane in rounds 1 and 2, Kagura otherwise.
func eater(index: int) -> StringName:
	return [&"gintoki", &"shinpachi", &"kagura"][hits[index].lane] if hits[index].lane >= 0 else &"kagura"


## Plays a clip from assets/voice/<id>.wav (made by tools/convert_voice.sh from the show's recordings, kept local:
## a clone without them skips every clip). Returns false when there is no such clip.
func play_clip(id: String, volume_db := 0.0) -> bool:
	if id.is_empty():
		return false
	if not _clips.has(id):
		var path := VOICE_DIR + id + ".wav"
		if not ResourceLoader.exists(path):
			_clips[id] = null
		else:
			var p := AudioStreamPlayer.new()
			p.stream = load(path)
			p.max_polyphony = 3  # quick chomps may overlap
			p.bus = &"Voice"
			add_child(p)
			_clips[id] = p
	var player: AudioStreamPlayer = _clips[id]
	if player == null:
		return false
	player.volume_db = volume_db
	player.play()
	return true


## A spoken line: one at a time (a line never talks over another; interrupt cuts the current one), and the song
## ducks under it.
func say(id: String, interrupt := false) -> void:
	if _line and _line.playing:
		if not interrupt:
			return
		_line.stop()
	if play_clip(id):
		_line = _clips[id]


func shake(strength: float, time: float) -> void:
	var tw := create_tween()
	for k in 4:
		tw.tween_property(camera, "offset", Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength, time / 5.0)
	tw.tween_property(camera, "offset", Vector2.ZERO, time / 5.0)


func _finish() -> void:
	if not _running:
		return
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


func _on_hurt() -> void:
	pass


func _on_knocked_down() -> void:
	pass


## Back on her feet: lives refill.
func get_up() -> void:
	down = false
	lives = max_lives
	hud.set_lives(lives, max_lives)


func _on_beat(_b: int) -> void:
	pass
