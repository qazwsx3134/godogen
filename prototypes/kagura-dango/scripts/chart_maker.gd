extends Node2D
## Chart maker (desktop tool, not part of the match). Pick a round, then edit:
## - the song: which file, where in it the round starts and how long it lasts (music_start, end_beat), its BPM and
##   where beat 0 falls (offset), checked by ear against the metronome;
## - the notes, on a timeline with one row per cue type: click to add, drag to move, right-click to delete, or play
##   with 錄音 on and press A S D F to drop notes into rows 1–4 on the grid;
## and save into the round's chart (the old one is kept as <id>.bak.json).
## A note sits on the beat the player taps; it is saved as a cue at that beat - land_after[type].
## Run: open scenes/chart_maker.tscn in the editor and press F6.

const ROUNDS := ["res://data/songs/eat3.json", "res://data/songs/feast2.json", "res://data/songs/toss3.json"]
const MUSIC_DIR := "res://assets/music/"
const GRIDS := [0.5, 0.25, 1.0]
const TYPE_NAMES := {"anko": "紅豆", "soy": "醬油", "tri": "三色", "rice": "飯", "dango": "丸子", "bento": "便當",
	"rival": "踢人", "toss": "拋", "quick": "快拋", "big": "大串"}
const ROW_KEYS := [KEY_A, KEY_S, KEY_D, KEY_F]

## Tests save somewhere else; empty = the round's own chart file.
var save_to := ""
var chart := {}
## Cue types, one timeline row each, ordered left → middle → right lane.
var rows: Array[String] = []
## {beat, type}; beat is the tap beat. Kept in edit order; sorted when saved.
var notes: Array[Dictionary] = []
## Song seconds where playback starts; follows the music while playing.
var cursor := 0.0
var calib := 0.0

var _undo: Array = []
var _songs: Array[String] = []
var _playing := false
var _last_t := 0.0

@onready var conductor: Conductor = %Conductor
@onready var timeline: Control = %Timeline


func _ready() -> void:
	Settings.load_all()
	calib = Settings.calib_ms / 1000.0
	timeline.maker = self
	%Round.item_selected.connect(func(_i): _load_round())
	%Song.item_selected.connect(func(i): set_song(_songs[i]))
	%Start.value_changed.connect(set_start)
	%Length.value_changed.connect(set_length)
	%Bpm.value_changed.connect(set_bpm)
	%Offset.value_changed.connect(set_offset)
	%Grid.item_selected.connect(func(_i): timeline.queue_redraw())
	%FromStart.pressed.connect(play_from_start)
	%Play.pressed.connect(toggle_play)
	%Undo.pressed.connect(undo)
	%Save.pressed.connect(save)
	_load_round()


func _load_round() -> void:
	stop()
	chart = JSON.parse_string(FileAccess.get_file_as_string(ROUNDS[%Round.selected]))
	var lanes: Dictionary = chart.get("lanes", {})
	var keys: Array = chart.land_after.keys()
	rows.assign(keys)
	rows.sort_custom(func(a, b):
		var la := int(lanes.get(a, -1))
		var lb := int(lanes.get(b, -1))
		return la < lb if la != lb else keys.find(a) < keys.find(b))
	notes.clear()
	for cue in chart.cues:
		notes.append({beat = float(cue.beat) + float(chart.land_after[cue.type]), type = String(cue.type)})
	_undo.clear()
	conductor.load_song(chart)
	_fill_songs()
	cursor = float(chart.get("music_start", 0.0))
	timeline.view_start = cursor - 1.0
	_refresh_fields()
	_status("%s：%d 個音符。" % [chart.title, notes.size()])


func _fill_songs() -> void:
	_songs.clear()
	for f in DirAccess.get_files_at(MUSIC_DIR):
		if f.get_extension() in ["mp3", "ogg", "wav"]:
			_songs.append(MUSIC_DIR + f)
	var music: String = chart.get("music", "")
	if music not in _songs:
		_songs.append(music)
	%Song.clear()
	for s in _songs:
		%Song.add_item(s.get_file() + ("" if ResourceLoader.exists(s) else "（找不到）"))
	%Song.select(_songs.find(music))


# --- song and timing ---------------------------------------------------------------------------------------------

func grid() -> float:
	return GRIDS[%Grid.selected]


func seg_start() -> float:
	return float(chart.get("music_start", 0.0))


func seg_end() -> float:
	return conductor.beat_time(float(chart.end_beat))


func count_in_end() -> float:
	return conductor.beat_time(float(chart.count_in_beats))


func in_range(note: Dictionary) -> bool:
	return note.beat >= float(chart.count_in_beats) and note.beat < float(chart.end_beat)


func set_song(path: String) -> void:
	chart.music = path
	conductor.load_song(chart)
	_refresh_fields()


## Moves where the round starts. Beat 0 moves along by whole beats, so the grid stays on the song's beats and the
## count-in still opens the round; notes keep their beat numbers and travel with it.
func set_start(seconds: float) -> void:
	var beat_len := 60.0 / float(chart.bpm)
	var shift := roundi((seconds - seg_start()) / beat_len)
	chart.offset = snappedf(float(chart.offset) + shift * beat_len, 0.001)
	chart.music_start = snappedf(seconds, 0.001)
	_apply_timing()


## How long the round lasts from its start: rounded to a whole beat (end_beat).
func set_length(seconds: float) -> void:
	var beats := (seg_start() + seconds - float(chart.offset)) * float(chart.bpm) / 60.0
	chart.end_beat = maxi(int(chart.count_in_beats) + 1, roundi(beats))
	_apply_timing()


func set_bpm(bpm: float) -> void:
	chart.bpm = snappedf(bpm, 0.01)
	_apply_timing()


func set_offset(seconds: float) -> void:
	chart.offset = snappedf(seconds, 0.001)
	_apply_timing()


func _apply_timing() -> void:
	conductor.bpm = float(chart.bpm)
	conductor.offset = float(chart.offset)
	conductor.music_start = seg_start()
	_refresh_fields()


func _refresh_fields() -> void:
	var song_len := conductor.song_length()
	%Start.max_value = song_len if song_len > 0.0 else 600.0
	%Start.set_value_no_signal(seg_start())
	%Length.set_value_no_signal(seg_end() - seg_start())
	%Bpm.set_value_no_signal(float(chart.bpm))
	%Offset.set_value_no_signal(float(chart.offset))
	var outside := notes.filter(func(n): return not in_range(n)).size()
	%Info.text = "共 %d 拍・%d 個音符%s" % [int(chart.end_beat), notes.size() - outside,
		"（%d 個在範圍外，儲存時捨棄）" % outside if outside > 0 else ""]
	timeline.queue_redraw()


# --- notes -------------------------------------------------------------------------------------------------------

func note_time(note: Dictionary) -> float:
	return conductor.beat_time(note.beat)


func find_note(row: int, beat: float) -> int:
	for i in notes.size():
		if notes[i].type == rows[row] and is_equal_approx(notes[i].beat, beat):
			return i
	return -1


## Adds a note (no-op if that row already has one on that beat). Returns its index.
func add_note(row: int, beat: float) -> int:
	var found := find_note(row, beat)
	if found >= 0:
		return found
	_push_undo()
	notes.append({beat = beat, type = rows[row]})
	_refresh_fields()
	return notes.size() - 1


func remove_note(index: int) -> void:
	_push_undo()
	notes.remove_at(index)
	_refresh_fields()


## Call once before a drag: the whole drag undoes in one step.
func begin_drag() -> void:
	_push_undo()


func move_note(index: int, row: int, beat: float) -> void:
	notes[index] = {beat = beat, type = rows[row]}
	_refresh_fields()


func undo() -> void:
	if _undo.is_empty():
		return
	notes.assign(_undo.pop_back())
	_refresh_fields()
	_status("已復原。")


func _push_undo() -> void:
	_undo.append(notes.duplicate(true))
	if _undo.size() > 200:
		_undo.pop_front()


# --- playback ----------------------------------------------------------------------------------------------------

func set_cursor(seconds: float) -> void:
	cursor = maxf(0.0, seconds)
	if _playing:
		play()
	timeline.queue_redraw()


func is_playing() -> bool:
	return _playing


func toggle_play() -> void:
	if _playing:
		stop()
	else:
		play()


## Plays from where the round starts (the green line).
func play_from_start() -> void:
	cursor = seg_start()
	timeline.follow(cursor)
	play()


## Plays from the cursor; a cursor left at the song's end starts over from the round's start.
func play() -> void:
	var song_len := conductor.song_length()
	if song_len > 0.0 and cursor >= song_len - 0.5:
		cursor = seg_start()
		timeline.follow(cursor)
	_playing = true
	_last_t = cursor
	conductor.play(cursor)
	%Play.text = "■ 停止"


func stop() -> void:
	if _playing:
		conductor.stop()
	_playing = false
	%Play.text = "▶ 播放"


func _process(_delta: float) -> void:
	if not _playing:
		return
	var t := conductor.time()
	if t < 0.0:
		return
	if %Metronome.button_pressed and floori(conductor.beat_at(t)) > floori(conductor.beat_at(_last_t)):
		%Tick.play()
	for n in notes:
		if note_time(n) > _last_t and note_time(n) <= t:
			%NoteSound.play()
			break
	_last_t = t
	cursor = t
	timeline.follow(t)
	var song_len := conductor.song_length()
	if song_len > 0.0 and t >= song_len:
		stop()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var cmd: bool = event.ctrl_pressed or event.meta_pressed
	if event.keycode == KEY_SPACE:
		toggle_play()
	elif event.keycode == KEY_HOME:
		play_from_start()
	elif cmd and event.keycode == KEY_Z:
		undo()
	elif cmd and event.keycode == KEY_S:
		save()
	elif _playing and %Record.button_pressed and event.keycode in ROW_KEYS:
		record(ROW_KEYS.find(event.keycode))
	else:
		return
	get_viewport().set_input_as_handled()


## A key pressed while playing: a note in that row on the nearest grid point (minus the player's calibration).
func record(row: int) -> void:
	if row >= rows.size():
		return
	var beat := snappedf(conductor.beat_at(conductor.time() - calib), grid())
	add_note(row, beat)
	_status("錄音：%s 第 %.2f 拍" % [TYPE_NAMES.get(rows[row], rows[row]), beat])


# --- save --------------------------------------------------------------------------------------------------------

func save() -> void:
	stop()
	var path: String = save_to if save_to != "" else ROUNDS[%Round.selected]
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path.replace(".json", ".bak.json")))
	var kept := notes.filter(in_range)
	var cues := kept.map(func(n): return {beat = n.beat - float(chart.land_after[n.type]), type = n.type})
	cues.sort_custom(func(a, b): return a.beat < b.beat if a.beat != b.beat else rows.find(a.type) < rows.find(b.type))
	chart.cues = cues
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(chart, "\t", false))
	f.close()
	var dropped := notes.size() - kept.size()
	_status("已儲存 %s（%d 個音符%s），舊譜面備份成 %s。" % [path.get_file(), kept.size(),
		"，捨棄範圍外 %d 個" % dropped if dropped > 0 else "", path.get_file().replace(".json", ".bak.json")])


func _status(text: String) -> void:
	%Status.text = text
