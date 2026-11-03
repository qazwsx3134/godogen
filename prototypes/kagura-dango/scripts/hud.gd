extends CanvasLayer
## Round HUD: judge text, referee call-outs, the round title and the match score (added up over all three rounds).
## A CanvasLayer, so camera shake never moves it.

@export var hint_text := ""

@onready var _judge: Label = %JudgeLabel
@onready var _call: Label = %CallLabel
@onready var _round: Label = %RoundLabel
@onready var _score: Label = %Score
@onready var _gain: Label = %ScoreGain

var _shown := 0
var _roll: Tween
var _pop: Tween
var _float: Tween


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


## The hit sound for a judged tap: Hit for ace / good, HitBad for barely (the files peak above 0 dBFS, so the
## players sit at -3 dB in hud.tscn).
func play_hit(grade: StringName) -> void:
	if grade in [&"ace", &"good"]:
		%Hit.play()
	elif grade == &"barely":
		%HitBad.play()


## Shows the score at once (a round starting).
func set_score(total: int) -> void:
	_show_score(total)


## A hit: the total counts up to `total` and pops, and "+points" floats up under it (bigger and gold for an ace).
func add_score(points: int, total: int, ace := false) -> void:
	if _roll:
		_roll.kill()
	_roll = create_tween()
	_roll.tween_method(_show_score, _shown, total, 0.3)
	if _pop:
		_pop.kill()
	_score.pivot_offset = Vector2(_score.size.x, _score.size.y * 0.5)
	_score.scale = Vector2.ONE * (1.45 if ace else 1.25)
	_pop = create_tween()
	_pop.tween_property(_score, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _float:
		_float.kill()
	_gain.text = "+%d" % points
	_gain.modulate = Color(1, 0.82, 0.2) if ace else Color(1, 1, 1)
	_gain.pivot_offset = Vector2(_gain.size.x, _gain.size.y * 0.5)
	_gain.scale = Vector2.ONE * (1.3 if ace else 1.0)
	_gain.position.y = 30.0
	_float = create_tween().set_parallel()
	_float.tween_property(_gain, "position:y", 18.0, 0.5).set_ease(Tween.EASE_OUT)
	_float.tween_property(_gain, "modulate:a", 0.0, 0.5).set_delay(0.15)


func _show_score(value: int) -> void:
	_shown = value
	_score.text = Judge.format_points(value)


## Round 3 only: remaining lives as dango icons, lost ones dimmed. max 0 hides it.
func set_lives(left: int, max_lives: int) -> void:
	%Lives.visible = max_lives > 0
	var icon := "[img=18x18 color=%s]res://assets/sprites/life_dango.png[/img]"
	%Lives.text = "命 " + (icon % "#ffffff").repeat(left) + (icon % "#ffffff30").repeat(max_lives - left)
