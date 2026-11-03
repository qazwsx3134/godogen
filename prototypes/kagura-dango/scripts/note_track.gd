extends Node2D
## Taiko-style note track: every cue of the round scrolls from the right into the judge circle and reaches it
## exactly on the beat the player must tap (minus their calibration, so what they see matches what they hear).
## Lives in the HUD (a CanvasLayer), so camera shake never moves it. Bar lines (every 4 beats) scroll with the notes;
## a hit bursts the judge circle, flashes the lane in that note's colour and flies the note to `fly_target` (the
## score), Taiko style.

const NOTE := preload("res://scenes/note.tscn")
const NOTE_SCRIPT := preload("res://scripts/note.gd")

## How far ahead notes appear, in beats.
@export var lead_beats := 4.0
## Where hit notes fly (the HUD's score); empty = they just pop.
@export var fly_target: NodePath

const ACE_COLOR := Color(1, 0.82, 0.2)
## Where the lane ends on a 16:9 canvas (the scene's value).
const LANE_RIGHT := 640.0

var _level: Node
var _notes := {}  # hit index → note node
var _lane_color := Color.BLACK
var _flash: Tween


func _ready() -> void:
	_lane_color = %Lane.color


## A phone wider than 16:9 has a canvas wider than 640: the lane (and where notes appear) reaches its right edge, even
## when the HUD's safe area has moved the track in from the left.
func _fit_lane() -> void:
	var right := get_viewport().get_visible_rect().size.x - global_position.x
	%Lane.offset_right = maxf(LANE_RIGHT, right)
	%TrackEnd.position.x = maxf(LANE_RIGHT + 20.0, right + 20.0)


func setup(level: Node) -> void:
	_level = level
	level.judged.connect(_on_judged)


func _process(_delta: float) -> void:
	_fit_lane()
	if _level == null or not _level.conductor.playing():
		return
	var now: float = _level.conductor.time() - _level.calib
	var lead: float = lead_beats * 60.0 / _level.conductor.bpm
	var judge_x: float = %JudgeCircle.position.x
	var span: float = %TrackEnd.position.x - judge_x
	var c: Conductor = _level.conductor
	var bars := PackedFloat32Array()
	var bar := ceilf(c.beat_at(now - lead * 0.25) / 4.0) * 4.0
	while c.beat_time(bar) - now <= lead:
		bars.append(judge_x + span * (c.beat_time(bar) - now) / lead)
		bar += 4.0
	%BarLines.xs = bars
	for i in _level.hits.size():
		var hit: Dictionary = _level.hits[i]
		var ahead: float = hit.time - now
		if hit.grade != &"" or ahead > lead:
			continue
		var note: Node2D = _notes.get(i)
		if note and (note.lane != hit.lane or note.type != hit.type):  # recoloured (chart maker)
			note.queue_free()
			note = null
		if note == null:
			note = NOTE.instantiate()
			note.lane = hit.lane
			note.type = hit.type
			%Notes.add_child(note)
			_notes[i] = note
		note.position = Vector2(judge_x + span * ahead / lead, 0.0)


## Drop every note (a new round or a restart in the chart maker).
func clear() -> void:
	for n in _notes.values():
		n.queue_free()
	_notes.clear()


func _on_judged(index: int, grade: StringName, _offset: float) -> void:
	var note: Node2D = _notes.get(index)
	var target: Control = get_node_or_null(fly_target) if not fly_target.is_empty() else null
	if note:
		if grade != &"miss" and target:
			note.fly_to(%Notes.to_local(target.global_position + Vector2(target.size.x - 24.0, target.size.y * 0.5)))
		else:
			note.finish(grade != &"miss")
		_notes.erase(index)
	if grade != &"miss":
		var lane_color: Color = NOTE_SCRIPT.LANE_COLORS.get(_level.hits[index].lane, NOTE_SCRIPT.LANE_COLORS[-1])
		%JudgeCircle.burst(ACE_COLOR if grade == &"ace" else lane_color, grade == &"ace")
		if _flash:
			_flash.kill()
		%Lane.color = _lane_color.lerp(lane_color, 0.45)
		_flash = create_tween()
		_flash.tween_property(%Lane, "color", _lane_color, 0.18)
		var tw := create_tween()
		tw.tween_property(%JudgeCircle, "scale", Vector2(1.25, 1.25), 0.05)
		tw.tween_property(%JudgeCircle, "scale", Vector2.ONE, 0.1)
