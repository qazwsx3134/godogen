extends Node2D
## Taiko-style note track: every cue of the round scrolls from the right into the judge circle and reaches it
## exactly on the beat the player must tap (minus their calibration, so what they see matches what they hear).
## Lives in the HUD (a CanvasLayer), so camera shake never moves it.

const NOTE := preload("res://scenes/note.tscn")

## How far ahead notes appear, in beats.
@export var lead_beats := 4.0

var _level: Node
var _notes := {}  # hit index → note node


func setup(level: Node) -> void:
	_level = level
	level.judged.connect(_on_judged)


func _process(_delta: float) -> void:
	if _level == null or not _level.conductor.playing():
		return
	var now: float = _level.conductor.time() - _level.calib
	var lead: float = lead_beats * 60.0 / _level.conductor.bpm
	var judge_x: float = %JudgeCircle.position.x
	var span: float = %TrackEnd.position.x - judge_x
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
	if note:
		note.finish(grade != &"miss")
		_notes.erase(index)
	if grade != &"miss":
		var tw := create_tween()
		tw.tween_property(%JudgeCircle, "scale", Vector2(1.25, 1.25), 0.05)
		tw.tween_property(%JudgeCircle, "scale", Vector2.ONE, 0.1)
