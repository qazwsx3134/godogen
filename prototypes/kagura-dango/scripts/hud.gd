extends CanvasLayer
## Round HUD: judge text, referee call-outs, the round title and the team-vs-rival scoreboard.
## A CanvasLayer, so camera shake never moves it.

@export var hint_text := ""

@onready var _judge: Label = %JudgeLabel
@onready var _call: Label = %CallLabel
@onready var _round: Label = %RoundLabel
@onready var _score: Label = %Scoreboard


func _ready() -> void:
	%Hint.text = hint_text


func show_judge(text: String) -> void:
	_judge.text = text
	_judge.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.3)
	tw.tween_property(_judge, "modulate:a", 0.0, 0.25)


## The referee's line. "預備……" stays until the next call; others fade.
func call_out(text: String) -> void:
	_call.text = text
	_call.modulate.a = 1.0
	if text != "預備……":
		var tw := create_tween()
		tw.tween_interval(0.6)
		tw.tween_property(_call, "modulate:a", 0.0, 0.3)


func set_round(title: String) -> void:
	_round.text = title


func set_score(team: int, rival: int) -> void:
	_score.text = "萬事屋 %d 串　vs　對手隊 %d 串" % [team, rival]
