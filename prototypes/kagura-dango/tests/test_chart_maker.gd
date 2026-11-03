extends "res://addons/proto_kit/test_kit.gd"
## Chart maker: a round loads and saves back unchanged (round 3's quick / big kept), notes are added, moved and
## deleted on the timeline grid (with undo), recorded keys snap to the grid, moving the start shifts beat 0 by whole
## beats, the length sets end_beat, notes outside the round are dropped on save, and the Conductor plays from the
## cursor. Saves into the temp dir, never data/songs/.

const MAKER := preload("res://scenes/chart_maker.tscn")

var _t := 0.0


func _init() -> void:
	_run.call_deferred()


func _press_tl(tl: Control, pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	tl._gui_input(e)


func _move_tl(tl: Control, pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	tl._gui_input(e)


func _saved(m: Node) -> Dictionary:
	m.save()
	return JSON.parse_string(FileAccess.get_file_as_string(m.save_to))


func _run() -> void:
	Settings.path = OS.get_temp_dir().path_join("kagura-dango-test-settings.cfg")
	DirAccess.remove_absolute(Settings.path)
	var m := MAKER.instantiate()
	m.save_to = OS.get_temp_dir().path_join("kagura-dango-test-chart.json")
	root.add_child(m)
	await process_frame
	m.calib = 0.0
	var tl: Control = m.get_node("%Timeline")

	# Round 1: rows by lane, notes at the tap beat; an untouched save keeps the cues.
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(m.ROUNDS[0]))
	_expect(m.rows == ["anko", "soy", "tri"], "round 1 rows left → right (got %s)" % [m.rows])
	_expect(m.notes.size() == original.cues.size() and m.notes[0].beat == original.cues[0].beat + 2.0, "notes sit at cue + land_after")
	var saved := _saved(m)
	_expect(saved.cues == original.cues, "an untouched round 1 saves the same cues")

	# Editing starts from an empty chart, so the checks below do not depend on what the round's chart holds.
	m.notes.clear()
	# Add, move (across rows), delete, undo.
	var n0: int = m.notes.size()
	var i: int = m.add_note(0, 9.5)
	_expect(m.add_note(0, 9.5) == i and m.notes.size() == n0 + 1, "one note per row and beat")
	m.begin_drag()
	m.move_note(i, 2, 9.75)
	_expect(m.notes[i] == {beat = 9.75, type = "tri"}, "drag moves the note to another row and beat")
	m.undo()
	_expect(m.notes[i] == {beat = 9.5, type = "anko"}, "undo returns the whole drag in one step")
	m.remove_note(i)
	_expect(m.notes.size() == n0, "right click deletes")
	m.undo()
	_expect(m.notes.size() == n0 + 1, "undo brings the deleted note back")
	saved = _saved(m)
	_expect({beat = 7.5, type = "anko"} in saved.cues, "a note at tap beat 9.5 saves as a cue at 7.5")

	# Timeline mouse: a click on empty grid adds a note; dragging a note moves it; dragging empty timeline pans.
	tl.view_start = m.conductor.beat_time(8.0) - 0.5
	var at := Vector2(tl.x_at(m.conductor.beat_time(12.6)), tl.RULER + 1.5 * tl.row_height())
	_press_tl(tl, at, true)
	_press_tl(tl, at, false)
	_expect(m.notes[-1] == {beat = 12.5, type = "soy"}, "clicking row 2 near beat 12.6 adds soy at 12.5 (got %s)" % [m.notes[-1]])
	var count: int = m.notes.size()
	var grab := Vector2(tl.x_at(m.conductor.beat_time(12.5)) + 5.0, at.y - 9.0)  # beside the circle, still on its grid point
	_press_tl(tl, grab, true)
	_move_tl(tl, Vector2(tl.x_at(m.conductor.beat_time(14.0)), tl.RULER + 2.5 * tl.row_height()))
	_press_tl(tl, grab, false)
	_expect(m.notes.size() == count and m.notes[-1] == {beat = 14.0, type = "tri"}, "dragging the note moves it to row 3, beat 14 (got %s)" % [m.notes[-1]])
	var view0: float = tl.view_start
	var empty := Vector2(tl.x_at(m.conductor.beat_time(30.25)), tl.RULER + 0.5 * tl.row_height())
	_press_tl(tl, empty, true)
	_move_tl(tl, empty + Vector2(-100, 0))
	_press_tl(tl, empty + Vector2(-100, 0), false)
	_expect(m.notes.size() == count and is_equal_approx(tl.view_start, view0 + 100.0 / tl.px_per_sec),
		"dragging empty timeline 100 px left pans the view, adds nothing (view %.2f → %.2f)" % [view0, tl.view_start])
	var pan := InputEventPanGesture.new()
	pan.delta = Vector2(2, 0)
	tl._gui_input(pan)
	_expect(tl.view_start > view0 + 100.0 / tl.px_per_sec, "a trackpad two-finger swipe scrolls")

	# Recording: a key while playing lands on the nearest grid point.
	m.conductor.clock = func(): return _t
	_t = m.conductor.beat_time(20.2)
	m.record(1)
	_expect(m.notes[-1] == {beat = 20.0, type = "soy"}, "a recorded key snaps to the half beat (got %s)" % [m.notes[-1]])
	m.conductor.clock = Callable()

	# Timing: start moves beat 0 by whole beats; length sets end_beat; outside notes are dropped.
	var beat_len: float = 60.0 / float(m.chart.bpm)
	var offset0: float = m.chart.offset
	var start: float = float(m.chart.music_start) + 2.1
	m.set_start(start)
	var moved: float = (float(m.chart.offset) - offset0) / beat_len
	_expect(is_equal_approx(m.chart.music_start, start) and absf(moved - roundf(moved)) < 0.01 and roundi(moved) == 3,
		"start +2.1 s shifts beat 0 by 3 whole beats (got %.3f)" % moved)
	m.set_length(30.0)
	var want := roundi((start + 30.0 - float(m.chart.offset)) / beat_len)
	m.add_note(0, want + 4.0)  # past the new end
	_expect(int(m.chart.end_beat) == want, "length 30 s → end_beat %d (got %d)" % [want, int(m.chart.end_beat)])
	var inside: int = m.notes.filter(m.in_range).size()
	_expect(inside < m.notes.size(), "a shorter round leaves some notes outside")
	saved = _saved(m)
	_expect(saved.cues.size() == inside and int(saved.end_beat) == want and is_equal_approx(saved.music_start, start),
		"save keeps only notes inside and writes the new start and length")

	# Round 3: quick and big survive a load → save.
	m.get_node("%Round").select(2)
	m._load_round()
	original = JSON.parse_string(FileAccess.get_file_as_string(m.ROUNDS[2]))
	saved = _saved(m)
	_expect(saved.cues == original.cues, "round 3 saves back unchanged (quick / big kept)")
	# Round 2: rice and dango are their own rows.
	m.get_node("%Round").select(1)
	m._load_round()
	_expect(m.rows == ["rival", "bento", "rice", "dango"], "round 2 rows (got %s)" % [m.rows])

	# The Conductor plays from the cursor: its wall clock starts there.
	m.conductor.play(42.0)
	_expect(absf(m.conductor.wall_time() - 42.0) < 0.2, "play(from) counts from the cursor (got %.2f)" % m.conductor.wall_time())
	m.stop()
	# 從頭 plays from the round's start wherever the cursor was; a cursor at the song's end starts over too.
	m.cursor = 30.0
	m.play_from_start()
	_expect(m.cursor == m.seg_start() and absf(m.conductor.wall_time() - m.seg_start()) < 0.2,
		"從頭 plays from the round's start (got %.2f)" % m.conductor.wall_time())
	m.stop()
	if m.conductor.song_length() > 0.0:  # only with the song file present (it is not in git)
		m.cursor = m.conductor.song_length()
		m.play()
		_expect(m.cursor == m.seg_start(), "play at the song's end starts over from the round's start")
		m.stop()
	m.free()
	_finish("CHART MAKER")
