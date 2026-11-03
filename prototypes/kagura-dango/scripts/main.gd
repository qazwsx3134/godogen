extends Node
## Match flow from data/match.json: title → opening (referee) → for each round: its story → the round → its result
## → … → ending (win or lose, then the birthday) → final result. Title → calibration on the side.
## The dialogue (story screens) plays the looping BGM (%Bgm); it fades out when any other screen comes up.
## On the web with ?qa=1 (or `-- --qa` natively) every frame publishes the clock readings as window.__dango,
## which tools/web_clock_probe.mjs reads to check the audio clock in a real browser.

const TITLE := preload("res://scenes/title.tscn")
const STORY := preload("res://scenes/story.tscn")
const RESULT := preload("res://scenes/result.tscn")
const CALIBRATE := preload("res://scenes/calibrate.tscn")

var screen: Node
var match_data := {}
var round_index := 0
var _qa := false
var _bgm_on := false
var _bgm_fade: Tween
## %Bgm volume when fully in (the scene's volume_db).
var _bgm_db := 0.0


func _ready() -> void:
	Settings.load_all()
	_bgm_db = %Bgm.volume_db
	match_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/match.json"))
	_qa = "--qa" in OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		_qa = _qa or str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('qa')")) == "1"
	var jump := _qa_round()
	if jump > 0:
		_jump_to_round(jump)
		return
	show_title()


## QA only (?qa=1&round=N, or `-- --qa --round=N`): straight into round N with the skewers a perfect run would
## have eaten before it, so Kagura's size and the stage match that round.
func _qa_round() -> int:
	if not _qa:
		return 0
	var n := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--round="):
			n = arg.trim_prefix("--round=")
	if OS.has_feature("web"):
		n = str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('round') || ''"))
	return clampi(n.to_int(), 0, match_data.stages.size())


func _jump_to_round(n: int) -> void:
	MatchState.reset()
	var before: Dictionary = [{}, {gintoki = 8, shinpachi = 9, kagura = 13, score = 30000}, {gintoki = 8, shinpachi = 23, kagura = 36, score = 97000}][n - 1]
	for who in [&"gintoki", &"shinpachi", &"kagura"]:
		MatchState.eaten[who] = before.get(String(who), 0)
	MatchState.score = before.get("score", 0)
	round_index = n - 1
	play_round()


func show_title() -> void:
	var s := _swap(TITLE)
	s.start_requested.connect(start_match)
	s.calibrate_requested.connect(show_calibrate)


func start_match() -> void:
	MatchState.reset()
	round_index = 0
	show_story(StoryData.lines(match_data.opening), show_round_intro)


func show_round_intro() -> void:
	var stage: Dictionary = match_data.stages[round_index]
	show_story(StoryData.lines(stage.story), play_round)


func play_round() -> void:
	var stage: Dictionary = match_data.stages[round_index]
	var level: Node = load(stage.scene).instantiate()
	level.chart_path = stage.chart
	_put(level)
	level.finished.connect(show_round_result)
	level.start()


func show_round_result(r: Dictionary) -> void:
	var s := _swap(RESULT)
	var last: bool = round_index == match_data.stages.size() - 1
	s.show_result(r, last)
	s.next_requested.connect(func():
		round_index += 1
		if last:
			var won := MatchState.won()
			show_story(StoryData.lines("ending_win" if won else "ending_lose"), show_final)
		else:
			show_round_intro())
	s.retry_requested.connect(func():
		MatchState.restore_round()
		play_round())
	s.back_requested.connect(show_title)


func show_final() -> void:
	var s := _swap(RESULT)
	s.show_final()
	s.retry_requested.connect(start_match)
	s.back_requested.connect(show_title)


func show_story(lines: Array, then: Callable) -> void:
	var s := _swap(STORY)
	s.done.connect(then)
	s.play(lines)


func show_calibrate() -> void:
	var s := _swap(CALIBRATE)
	s.back_requested.connect(show_title)
	s.start()


func _swap(packed: PackedScene) -> Node:
	return _put(packed.instantiate())


func _put(node: Node) -> Node:
	if screen:
		screen.name = "Leaving"  # frees at the end of the frame; let the new screen keep its own name now
		screen.queue_free()
	screen = node
	%Screen.add_child(screen)
	_set_bgm(node.scene_file_path == STORY.resource_path)
	return screen


## Story screens fade the BGM in (or keep it going between two of them); everything else fades it out.
func _set_bgm(on: bool) -> void:
	if on == _bgm_on:
		return
	_bgm_on = on
	var bgm: AudioStreamPlayer = %Bgm
	if _bgm_fade:
		_bgm_fade.kill()
	_bgm_fade = create_tween()
	if on:
		if not bgm.playing:
			bgm.volume_db = -40.0
			bgm.play()
		_bgm_fade.tween_property(bgm, "volume_db", _bgm_db, 0.8)
	else:
		_bgm_fade.tween_property(bgm, "volume_db", -40.0, 0.6)
		_bgm_fade.tween_callback(bgm.stop)


func _process(_delta: float) -> void:
	if not _qa or not OS.has_feature("web"):
		return
	var c: Conductor = screen.get_node_or_null("%Conductor") if screen else null
	var row := {screen = String(screen.name) if screen else "", usec = Time.get_ticks_usec(), round = round_index}
	if c and c.playing():
		row.merge({wall = c.wall_time(), audio = c.audio_time(), time = c.time(), latency = AudioServer.get_output_latency()})
	if screen and "hits" in screen:
		var judged := 0
		for h in screen.hits:
			judged += int(h.grade != &"")
		row.judged = judged
		row.total = screen.hits.size()
	var js := "window.__dango=%s;" % JSON.stringify(row)
	if row.has("audio"):
		js += "(window.__dangoLog=window.__dangoLog||[]).push([%f,%f,%d]);" % [row.wall, row.audio, round_index]
	JavaScriptBridge.eval(js)
