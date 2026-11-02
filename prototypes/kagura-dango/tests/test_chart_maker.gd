extends "res://addons/proto_kit/test_kit.gd"
## Chart maker: recorded taps snap to the grid (count-in and double presses ignored), A/S/D recolours the note at
## the circle, and saving writes cues at landing beat − land_after (round 2's right lane alternating rice / dango).
## Saves into the temp dir, never data/songs/.

const MAKER := preload("res://scenes/chart_maker.tscn")

var _t := 0.0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	Settings.path = OS.get_temp_dir().path_join("kagura-dango-test-settings.cfg")
	DirAccess.remove_absolute(Settings.path)
	var m := MAKER.instantiate()
	m.get_node("Conductor").clock = func(): return _t
	m.save_to = OS.get_temp_dir().path_join("kagura-dango-test-chart.json")
	root.add_child(m)
	await process_frame
	m.calib = 0.0
	m._start(&"record")
	for beat in [7.0, 8.1, 9.4, 9.45, 11.0]:  # 7 is in the count-in; 9.45 snaps onto 9.5 again
		_t = m.conductor.beat_time(beat)
		m._record_tap()
	_expect(m.hits.map(func(h): return h.beat) == [8.0, 9.5, 11.0], "taps snap to half beats (got %s)" % [m.hits.map(func(h): return h.beat)])
	m._stop()
	m._start(&"assign")
	_t = m.conductor.beat_time(9.55)
	m._assign(0)
	m._save()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(m.save_to))
	_expect(saved.cues == [{beat = 6.0, type = "tri"}, {beat = 7.5, type = "anko"}, {beat = 9.0, type = "tri"}],
		"round 1 saves cue = landing − 2 with the assigned colours (got %s)" % [saved.cues])
	# Round 2: three right-lane notes become rice, dango, rice.
	m.get_node("%Round").select(1)
	m._load_round()
	m._start(&"record")
	for beat in [8.0, 9.0, 10.0]:
		_t = m.conductor.beat_time(beat)
		m._record_tap()
	m._save()
	saved = JSON.parse_string(FileAccess.get_file_as_string(m.save_to))
	_expect(saved.cues.map(func(c): return c.type) == ["rice", "dango", "rice"], "round 2 right lane alternates rice / dango (got %s)" % [saved.cues])
	m.free()
	_finish("CHART MAKER")
