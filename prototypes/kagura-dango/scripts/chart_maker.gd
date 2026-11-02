extends Node2D
## Chart maker (desktop tool, not part of the match): ① play a round's song and tap the rhythm (space / click);
## taps snap to the chosen grid; ② play it again with the notes scrolling and press A S D (left / middle / right) as
## each note reaches the circle to give it a colour; ③ save into that round's chart (the old one is kept as
## <id>.bak.json). Exposes hits / conductor / calib / judged like a RhythmLevel, so the round's NoteTrack shows it.
## Run: open scenes/chart_maker.tscn in the editor and press F6.

signal judged(index: int, grade: StringName, offset: float)

const ROUNDS := ["res://data/songs/eat3.json", "res://data/songs/feast2.json", "res://data/songs/toss3.json"]
## Cue type for each lane per round. Round 2's right lane alternates rice / dango; round 3 has one colour.
const LANE_TYPES := {"eat3": ["anko", "soy", "tri"], "feast2": ["rival", "bento", "dango"], "toss3": ["toss", "toss", "toss"]}
const GRIDS := [0.5, 0.25]

## Tests save somewhere else; empty = the round's own chart file.
var save_to := ""

var hits: Array[Dictionary] = []
var calib := 0.0
var chart := {}
var _mode := &"idle"  # idle, record, assign
var _assign_next := 0

@onready var conductor: Conductor = %Conductor


func _ready() -> void:
	Settings.load_all()
	calib = Settings.calib_ms / 1000.0
	%NoteTrack.setup(self)
	%Round.item_selected.connect(func(_i): _load_round())
	%Record.pressed.connect(_start.bind(&"record"))
	%Assign.pressed.connect(_start.bind(&"assign"))
	%Stop.pressed.connect(_stop)
	%Save.pressed.connect(_save)
	_load_round()


func _load_round() -> void:
	_stop()
	chart = JSON.parse_string(FileAccess.get_file_as_string(ROUNDS[%Round.selected]))
	conductor.load_song(chart)
	hits.clear()
	for cue in chart.cues:  # start from the current chart, so colours can be redone without re-recording
		var beat: float = cue.beat + float(chart.land_after[cue.type])
		hits.append(_hit(beat, _lane_of(String(cue.type))))
	hits.sort_custom(func(a, b): return a.time < b.time)
	_status("%s：%d 個音符。按「錄節奏」重錄，或按「分配顏色」。" % [chart.title, hits.size()])


func _hit(beat: float, lane: int) -> Dictionary:
	var types: Array = LANE_TYPES[chart.id]
	return {beat = beat, time = conductor.beat_time(beat), lane = lane if chart.id != "toss3" else -1,
		type = StringName(types[maxi(lane, 0)]), grade = &""}


func _lane_of(type: String) -> int:
	if type == "rice":
		return 2
	return maxi(0, LANE_TYPES[chart.id].find(type))


func _start(mode: StringName) -> void:
	_stop()
	_mode = mode
	%NoteTrack.clear()
	if mode == &"record":
		hits.clear()
		_status("錄節奏中：跟著音樂按空白鍵或點畫面。按「停止」結束。")
	else:
		for h in hits:
			h.grade = &""
		_assign_next = 0
		_status("分配顏色：音符進圈時按 A（左）S（中）D（右）。沒按的保持原色。")
	conductor.play()


func _stop() -> void:
	if _mode != &"idle":
		conductor.stop()
		_status("已停止：%d 個音符。可以再分配顏色，或按「儲存」。" % hits.size())
	_mode = &"idle"
	%NoteTrack.clear()


func _process(_delta: float) -> void:
	if _mode == &"idle":
		return
	var t := conductor.time() - calib
	if t > conductor.beat_time(float(chart.end_beat)) + 0.5:
		_stop()
		return
	if _mode == &"assign":  # notes leave the track once they pass the circle
		while _assign_next < hits.size() and t > hits[_assign_next].time + Judge.BARELY:
			hits[_assign_next].grade = &"good"
			judged.emit(_assign_next, &"good", 0.0)
			_assign_next += 1


func _unhandled_input(event: InputEvent) -> void:
	if _mode == &"record" and (event.is_action_pressed("tap") or (event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT and event.position.y > 120)):
		_record_tap()
	elif _mode == &"assign":
		for k in 3:
			if event.is_action_pressed(["lane_left", "lane_mid", "lane_right"][k]) and not event.is_echo():
				_assign(k)


func _record_tap() -> void:
	var grid: float = GRIDS[%Grid.selected]
	var beat: float = snappedf(conductor.beat_at(conductor.time() - calib), grid)
	if beat < float(chart.count_in_beats) or beat >= float(chart.end_beat):
		return
	if not hits.is_empty() and is_equal_approx(hits[-1].beat, beat):
		return  # a double press on the same grid point
	var h := _hit(beat, 2)
	hits.append(h)
	h.grade = &"good"  # recorded notes are already behind the circle: keep them off the track
	_status("錄節奏中：%d 個音符（第 %.2f 拍）" % [hits.size(), beat])


## Colours the note nearest the circle (within half a beat).
func _assign(lane: int) -> void:
	var t := conductor.time() - calib
	var best := -1
	for i in hits.size():
		if absf(hits[i].time - t) < 30.0 / conductor.bpm and (best < 0 or absf(hits[i].time - t) < absf(hits[best].time - t)):
			best = i
	if best < 0:
		return
	var old: Dictionary = hits[best]
	var h := _hit(old.beat, lane)
	h.grade = old.grade
	hits[best] = h
	_status("第 %.2f 拍 → %s" % [h.beat, ["左", "中", "右"][lane]])


func _save() -> void:
	_stop()
	var path: String = save_to if save_to != "" else ROUNDS[%Round.selected]
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path.replace(".json", ".bak.json")))
	var cues := []
	var right := 0
	for h in hits:
		var type := String(h.type)
		if chart.id == "feast2" and h.lane == 2:  # Kagura: rice, dango, rice, dango…
			type = ["rice", "dango"][right % 2]
			right += 1
		cues.append({beat = h.beat - float(chart.land_after[type]), type = type})
	chart.cues = cues
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(chart, "\t", false))
	f.close()
	_status("已儲存 %s（%d 個音符），舊譜面備份成 %s。" % [path, cues.size(), path.get_file().replace(".json", ".bak.json")])


func _status(text: String) -> void:
	%Status.text = text
