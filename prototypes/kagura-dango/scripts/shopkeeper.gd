extends Node2D
## A small forward dip timed with each round-one serving cue.

var _home_position := Vector2.ZERO


func _ready() -> void:
	_home_position = position


func serve() -> void:
	var tween := create_tween()
	tween.tween_property(self, "position", _home_position + Vector2(10, 5), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", _home_position, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
