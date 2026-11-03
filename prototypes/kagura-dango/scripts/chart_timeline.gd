extends Control
## The chart maker's timeline: song seconds run left → right, one row per cue type (the maker's `rows`).
## The ruler on top shows bar numbers; clicking it moves the play cursor. The round's part of the song is lit, the
## count-in tinted, and notes outside the round are grey (saving drops them).
## Left click on empty grid adds a note, dragging a note moves it (across rows too), dragging empty timeline pans it,
## dragging the ruler scrubs the cursor, right click deletes; wheel or trackpad scrolls, Ctrl/Cmd + wheel or pinch zooms.

const NOTE := preload("res://scripts/note.gd")
const RULER := 18.0
const LABEL_W := 70.0
const NOTE_R := 6.0
## Pixels a press on empty timeline may move and still count as a click (adds a note).
const PAN_SLOP := 4.0

@export var px_per_sec := 50.0

var maker: Node
## Song seconds at the left edge of the note area.
var view_start := 0.0

var _drag := -1
var _scrubbing := false
var _scrub_to := -1.0
## Where a press on empty timeline started (x < 0: none) and the view then; moving past PAN_SLOP pans instead of adding.
var _press_at := Vector2(-1, -1)
var _press_view := 0.0
var _panning := false
var _icons := {}


func time_at(x: float) -> float:
	return view_start + (x - LABEL_W) / px_per_sec


func x_at(t: float) -> float:
	return LABEL_W + (t - view_start) * px_per_sec


func row_height() -> float:
	return (size.y - RULER) / maxi(1, maker.rows.size())


func row_at(y: float) -> int:
	return clampi(int((y - RULER) / row_height()), 0, maker.rows.size() - 1)


func beat_at_x(x: float) -> float:
	return snappedf(maker.conductor.beat_at(time_at(x)), maker.grid())


func note_pos(note: Dictionary) -> Vector2:
	return Vector2(x_at(maker.note_time(note)), RULER + (maker.rows.find(note.type) + 0.5) * row_height())


## Index of the note under `pos`, or -1.
func note_under(pos: Vector2) -> int:
	var best := -1
	for i in maker.notes.size():
		var d := note_pos(maker.notes[i]).distance_to(pos)
		if d <= NOTE_R + 2.0 and (best < 0 or d < note_pos(maker.notes[best]).distance_to(pos)):
			best = i
	return best


## Keeps the playing cursor in view.
func follow(t: float) -> void:
	var span := (size.x - LABEL_W) / px_per_sec
	if t < view_start or t > view_start + span * 0.8:
		view_start = t - span * 0.2
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if maker == null:
		return
	if event is InputEventMouseButton and event.pressed:
		var cmd: bool = event.ctrl_pressed or event.meta_pressed
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT:
				var dir := -1.0 if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT] else 1.0
				if cmd:
					_zoom(pow(1.15, -dir), event.position.x)
				else:
					view_start += dir * 120.0 / px_per_sec
			MOUSE_BUTTON_LEFT:
				if event.position.y < RULER:
					_scrubbing = true
					_scrub_to = -1.0
					maker.set_cursor(time_at(event.position.x))
				elif event.position.x > LABEL_W:
					_drag = _note_at(event.position)
					if _drag >= 0:
						maker.begin_drag()
					else:  # empty: a click adds a note on release, a drag pans the view
						_press_at = event.position
						_press_view = view_start
						_panning = false
			MOUSE_BUTTON_RIGHT:
				var i := _note_at(event.position)
				if i >= 0:
					maker.remove_note(i)
		accept_event()
		queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if _press_at.x >= 0.0 and not _panning:
			maker.add_note(row_at(_press_at.y), beat_at_x(_press_at.x))
		if _scrubbing and maker.is_playing() and _scrub_to >= 0.0:
			maker.set_cursor(_scrub_to)
		_drag = -1
		_scrubbing = false
		_press_at = Vector2(-1, -1)
		accept_event()
		queue_redraw()
	elif event is InputEventMouseMotion:
		if _drag >= 0:
			maker.move_note(_drag, row_at(event.position.y), beat_at_x(event.position.x))
		elif _scrubbing:
			_scrub_to = time_at(event.position.x)
			if not maker.is_playing():  # while playing, jump once on release instead of restarting every move
				maker.set_cursor(_scrub_to)
		elif _press_at.x >= 0.0:
			_panning = _panning or absf(event.position.x - _press_at.x) > PAN_SLOP
			if _panning:
				view_start = _press_view - (event.position.x - _press_at.x) / px_per_sec
		else:
			return
		accept_event()
		queue_redraw()
	elif event is InputEventPanGesture:  # trackpad two-finger scroll (macOS sends no wheel events for it)
		view_start += (event.delta.x + event.delta.y) * 12.0 / px_per_sec
		accept_event()
		queue_redraw()
	elif event is InputEventMagnifyGesture:  # trackpad pinch
		_zoom(event.factor, event.position.x)
		accept_event()
		queue_redraw()


## The note under the pointer, or else the note on the grid point it is over (same row): easy to grab.
func _note_at(pos: Vector2) -> int:
	var i := note_under(pos)
	if i < 0 and pos.y >= RULER:
		i = maker.find_note(row_at(pos.y), beat_at_x(pos.x))
	return i


func _zoom(factor: float, at_x: float) -> void:
	var anchor := time_at(at_x)
	px_per_sec = clampf(px_per_sec * factor, 15.0, 600.0)
	view_start = anchor - (at_x - LABEL_W) / px_per_sec


func _draw() -> void:
	if maker == null or maker.chart.is_empty():
		return
	var c: Conductor = maker.conductor
	var font := get_theme_default_font()
	var h := size.y
	var w := size.x
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.09, 0.14))
	# The round's part of the song, and its count-in.
	var x0 := x_at(maker.seg_start())
	var x1 := x_at(maker.seg_end())
	draw_rect(Rect2(x0, RULER, x1 - x0, h - RULER), Color(0.2, 0.19, 0.28))
	draw_rect(Rect2(x0, RULER, x_at(maker.count_in_end()) - x0, h - RULER), Color(0.3, 0.22, 0.2))
	# Grid: sub-beats faint, beats medium, bars (4 beats) strong with their bar number.
	var step: float = maker.grid()
	var step_px := step * 60.0 / c.bpm * px_per_sec
	if step_px < 5.0:
		step = 1.0 if 60.0 / c.bpm * px_per_sec >= 5.0 else 4.0
	var b := floorf(c.beat_at(time_at(LABEL_W)) / step) * step
	while b <= c.beat_at(time_at(w)):
		var x := x_at(c.beat_time(b))
		var bar := is_zero_approx(fposmod(b, 4.0))
		var whole := is_zero_approx(fposmod(b, 1.0))
		var col := Color(1, 1, 1, 0.35) if bar else (Color(1, 1, 1, 0.16) if whole else Color(1, 1, 1, 0.06))
		draw_line(Vector2(x, RULER), Vector2(x, h), col)
		if bar:
			draw_string(font, Vector2(x + 2, RULER - 5), str(int(b)), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.98, 0.93, 0.84))
		b += step
	for r in maker.rows.size():
		var y: float = RULER + r * row_height()
		draw_line(Vector2(0, y), Vector2(w, y), Color(1, 1, 1, 0.12))
	draw_line(Vector2(x0, 0), Vector2(x0, h), Color(0.4, 0.85, 0.45), 2.0)
	draw_line(Vector2(x1, 0), Vector2(x1, h), Color(0.9, 0.3, 0.3), 2.0)
	# Notes, in their lane's colour; grey outside the round.
	var lanes: Dictionary = maker.chart.get("lanes", {})
	for n in maker.notes:
		var p := note_pos(n)
		if p.x < LABEL_W - NOTE_R or p.x > w + NOTE_R:
			continue
		var col: Color = NOTE.LANE_COLORS.get(int(lanes.get(n.type, -1)), NOTE.LANE_COLORS[-1])
		if not maker.in_range(n):
			col = Color(0.45, 0.45, 0.5)
		draw_circle(p, NOTE_R + 1.5, Color(0.05, 0.04, 0.07))
		draw_circle(p, NOTE_R, col)
		draw_circle(p, NOTE_R * 0.45, Color(1, 0.97, 0.9))
	# Play cursor.
	var xc := x_at(maker.cursor)
	draw_line(Vector2(xc, 0), Vector2(xc, h), Color(1, 0.85, 0.2), 2.0)
	# Ruler and row labels stay put over the scrolling area.
	draw_rect(Rect2(0, 0, LABEL_W, h), Color(0.16, 0.15, 0.24))
	draw_rect(Rect2(0, 0, w, RULER), Color(0.16, 0.15, 0.24, 0.6))
	draw_string(font, Vector2(4, RULER - 5), "%d:%04.1f" % [floori(maker.cursor / 60.0), fmod(maker.cursor, 60.0)],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.85, 0.2))
	for r in maker.rows.size():
		var type: String = maker.rows[r]
		var cy: float = RULER + (r + 0.5) * row_height()
		var icon := _icon(type)
		var s := minf(row_height() - 4.0, 18.0)
		draw_texture_rect(icon, Rect2(4, cy - s / 2, s, s), false)
		var label := "%s %s" % ["ASDF"[r] if r < 4 else " ", maker.TYPE_NAMES.get(type, type)]
		draw_string(font, Vector2(s + 7, cy + 4), label, HORIZONTAL_ALIGNMENT_LEFT, LABEL_W - s - 8, 11, Color(0.98, 0.93, 0.84))


func _icon(type: String) -> Texture2D:
	if not _icons.has(type):
		var path: String = NOTE.ICONS.get(StringName(type), NOTE.DEFAULT_ICON)
		_icons[type] = load(path if ResourceLoader.exists(path) else NOTE.DEFAULT_ICON)
	return _icons[type]
