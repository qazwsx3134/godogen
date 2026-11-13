extends Control
## The ending scroll (scenes/ui/chapter_result_gintama.tscn). A story's `result` step shows the chapter's
## numbers, the grade from the glasses left and a closing line for that grade; an `end` step shows only
## its text and ending. Either way the screen goes dark first, the scroll unrolls, and one tap brings up
## 下一章 (when a next chapter exists), 重玩 and 回標題, with who wrote and drew the chapter above them.

signal next_pressed
signal restart_pressed
signal title_pressed
## The tap brought up the buttons.
signal buttons_revealed

## Seconds: the dark coming in, the scroll unrolling, the buttons fading in.
@export var dim_in: float = 0.6
@export var unroll: float = 0.45
@export var buttons_in: float = 0.3
## No animation (畫面效果：減少): everything arrives at once, still waiting for the tap.
var reduce_motion: bool = false
var _waiting: bool = false
var _tweens: Array[Tween] = []

const GRADE_STAMPS: Dictionary = {
	"S": preload("res://assets/ui/selected/grade_s.png"),
	"A": preload("res://assets/ui/selected/grade_a.png"),
	"B": preload("res://assets/ui/selected/grade_b.png"),
	"C": preload("res://assets/ui/selected/grade_c.png"),
}

@onready var heading: Label = %Heading
@onready var caught: Label = %Caught
@onready var perfect: Label = %Perfect
@onready var combo: Label = %Combo
@onready var fails: Label = %Fails
@onready var hidden_found: Label = %Hidden
@onready var glasses: Label = %GlassesLeft
@onready var game_overs: Label = %GameOvers
@onready var grade: Label = %Grade
@onready var grade_stamp: TextureRect = %GradeStamp
@onready var quote: Label = %Quote
@onready var credit: Label = %Credit
@onready var next_button: Button = %Next
@onready var title_button: Button = %Title
@onready var restart_button: Button = %Restart
@onready var dim: ColorRect = $Dim
@onready var card: Control = $Scroll/Center/Card
@onready var stats: Control = $Scroll/Center/Card/Column/Stats
@onready var grade_row: Control = $Scroll/Center/Card/Column/GradeRow
@onready var buttons: Control = $Scroll/Center/Card/Column/Buttons
@onready var tap_hint: Label = %TapHint


func _ready() -> void:
	visible = false
	next_button.pressed.connect(func() -> void: next_pressed.emit())
	title_button.pressed.connect(func() -> void: title_pressed.emit())
	restart_button.pressed.connect(func() -> void: restart_pressed.emit())
	visibility_changed.connect(func() -> void:
		if not visible:
			_stop())


## summary: StoryRunner.chapter_result(). speaker_name: the closing line's speaker as shown.
## credit_line: the story's credits in one line ("" hides it).
func show_result(summary: Dictionary, speaker_name: String, has_next: bool, credit_line: String = "") -> void:
	credit.text = credit_line
	credit.visible = not credit_line.is_empty()
	var ending: String = str(summary.get("ending_title", ""))
	heading.text = str(summary.get("title", "")) + ("" if ending.is_empty() else "\n結局「%s」" % ending)
	caught.text = "%d / %d" % [int(summary.get("caught", 0)), int(summary.get("tries", 0))]
	perfect.text = str(int(summary.get("perfect", 0)))
	combo.text = str(int(summary.get("max_combo", 0)))
	fails.text = str(int(summary.get("fails", 0)))
	var hidden_total: int = int(summary.get("hidden_total", 0))
	hidden_found.text = str(int(summary.get("hidden", 0))) + (" / %d" % hidden_total if hidden_total > 0 else "")
	glasses.text = "%d / %d" % [int(summary.get("glasses", 0)), int(summary.get("max_glasses", 5))]
	game_overs.text = str(int(summary.get("game_overs", 0)))
	var grade_name: String = str(summary.get("grade", "C"))
	grade.text = "【 %s 】" % grade_name
	grade_stamp.texture = GRADE_STAMPS.get(grade_name, GRADE_STAMPS["C"]) as Texture2D
	var line: Dictionary = summary.get("line", {}) as Dictionary
	var text: String = str(line.get("text", ""))
	quote.text = text if speaker_name.is_empty() or text.is_empty() else "%s：「%s」" % [speaker_name, text]
	quote.visible = not text.is_empty()
	next_button.visible = has_next
	stats.visible = true
	grade_row.visible = true
	_play_in()


## An `end` step's scroll: its text, the ending's name and the credits; no numbers or grade.
func show_ending(text: String, ending_title: String, has_next: bool, credit_line: String = "") -> void:
	heading.text = text + ("" if ending_title.is_empty() else "\n結局「%s」" % ending_title)
	credit.text = credit_line
	credit.visible = not credit_line.is_empty()
	quote.visible = false
	stats.visible = false
	grade_row.visible = false
	next_button.visible = has_next
	_play_in()


## True once the tap has brought up the buttons.
func buttons_shown() -> bool:
	return visible and not _waiting


## The tap that brings up the buttons (any click, touch or accept key on the dark screen).
func reveal_buttons() -> void:
	if not _waiting:
		return
	_waiting = false
	_kill_tweens()
	tap_hint.visible = false
	card.scale = Vector2.ONE
	dim.modulate.a = 1.0
	card.modulate.a = 1.0
	_set_buttons_active(true)
	if reduce_motion:
		buttons.modulate.a = 1.0
	else:
		_tween().tween_property(buttons, "modulate:a", 1.0, buttons_in)
	buttons_revealed.emit()


func _play_in() -> void:
	_kill_tweens()
	visible = true
	_waiting = true
	_set_buttons_active(false)
	buttons.modulate.a = 0.0  # laid out from the start, so the scroll does not grow when they appear
	tap_hint.visible = true
	tap_hint.modulate.a = 0.0
	if reduce_motion:
		dim.modulate.a = 1.0
		card.modulate.a = 1.0
		card.scale = Vector2.ONE
		tap_hint.modulate.a = 1.0
		return
	dim.modulate.a = 0.0
	card.modulate.a = 0.0
	card.scale = Vector2(1.0, 0.04)
	var tween: Tween = _tween()
	tween.tween_property(dim, "modulate:a", 1.0, dim_in).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func() -> void: card.pivot_offset = card.size * 0.5)
	tween.tween_property(card, "modulate:a", 1.0, unroll * 0.4)
	tween.parallel().tween_property(card, "scale", Vector2.ONE, unroll).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(tap_hint, "modulate:a", 1.0, 0.4)
	tween.tween_callback(_breathe_hint)


func _breathe_hint() -> void:
	if not _waiting:
		return
	var loop: Tween = _tween().set_loops()
	loop.tween_property(tap_hint, "modulate:a", 0.35, 0.9).set_trans(Tween.TRANS_SINE)
	loop.tween_property(tap_hint, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)


func _set_buttons_active(active: bool) -> void:
	for button: Button in [next_button, restart_button, title_button]:
		button.disabled = not active
		button.mouse_filter = Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE
		button.focus_mode = Control.FOCUS_ALL if active else Control.FOCUS_NONE


func _input(event: InputEvent) -> void:
	if not visible or not _waiting:
		return
	var tapped: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
		or event.is_action_pressed("ui_accept")
	if tapped:
		get_viewport().set_input_as_handled()
		reveal_buttons()


func _tween() -> Tween:
	var tween: Tween = create_tween()
	_tweens.append(tween)
	return tween


func _kill_tweens() -> void:
	for tween: Tween in _tweens:
		if tween.is_valid():
			tween.kill()
	_tweens.clear()


func _stop() -> void:
	_kill_tweens()
	_waiting = false
