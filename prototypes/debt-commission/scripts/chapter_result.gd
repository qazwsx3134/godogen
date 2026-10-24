extends Control
## The chapter result (scenes/ui/chapter_result.tscn), shown by a story's `result` step: the
## chapter's numbers, the grade from the glasses left, a closing line for that grade, and
## 下一章 (when a next chapter exists) or 回標題, with who wrote and drew the chapter under the line.

signal next_pressed
signal title_pressed

@onready var heading: Label = %Heading
@onready var caught: Label = %Caught
@onready var perfect: Label = %Perfect
@onready var combo: Label = %Combo
@onready var fails: Label = %Fails
@onready var hidden_found: Label = %Hidden
@onready var glasses: Label = %GlassesLeft
@onready var game_overs: Label = %GameOvers
@onready var grade: Label = %Grade
@onready var quote: Label = %Quote
@onready var credit: Label = %Credit
@onready var next_button: Button = %Next
@onready var title_button: Button = %Title


func _ready() -> void:
	visible = false
	next_button.pressed.connect(func() -> void: next_pressed.emit())
	title_button.pressed.connect(func() -> void: title_pressed.emit())


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
	grade.text = "【 %s 】" % str(summary.get("grade", "C"))
	var line: Dictionary = summary.get("line", {}) as Dictionary
	var text: String = str(line.get("text", ""))
	quote.text = text if speaker_name.is_empty() or text.is_empty() else "%s：「%s」" % [speaker_name, text]
	quote.visible = not text.is_empty()
	next_button.visible = has_next
