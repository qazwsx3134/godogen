extends Button
## One 關卡 on the 關卡 page (scenes/stage_row.tscn): its label (1-1), boss, a note under it (the first-clear reward),
## and whether it is cleared, the one to push next, or still locked (a locked one cannot be tapped).

enum State { LOCKED, NEXT, CLEARED }
const STATE_TEXT := ["未開放", "挑戰", "已通關"]
const STATE_COLOR := [Color("7c776b"), Color("d9b26e"), Color("9fd08f")]

## Stage number (1-based).
var stage: int = 1

@onready var _label: Label = %StageLabel
@onready var _boss: Label = %BossName
@onready var _note: Label = %Note
@onready var _state: Label = %StateLabel


func show_stage(n: int, label: String, boss: String, note: String, state: int) -> void:
	stage = n
	_label.text = label
	_boss.text = boss
	_note.text = note
	_state.text = STATE_TEXT[state]
	_state.add_theme_color_override(&"font_color", STATE_COLOR[state])
	disabled = state == State.LOCKED
	button_pressed = state == State.NEXT
