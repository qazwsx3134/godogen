extends "res://scripts/three_eat.gd"
## Round 2: Gintoki and Shinpachi can't eat any more, so the team cheats for Kagura.
## Right (high): Kagura eats rice and dango in turn — rice is no skewer, dango is.
## Middle: Shinpachi packs a skewer into his bento (counts for the team).
## Left (low): a rival sneaks up to the table; Gintoki kicks him away on the beat. A missed kick lets him run off with
## a skewer (no points). Score only, no lives.


@onready var _intruder: Node2D = %Intruder
@onready var _intruder_target: Marker2D = %IntruderTarget
var _intruder_home := Vector2.ZERO


func _ready() -> void:
	super()
	_intruder_home = _intruder.position


func _on_cue(index: int) -> void:
	var hit := hits[index]
	if hit.type != &"rival":
		super(index)
		hud.call_out("")
		return
	_intruder.visible = true
	_intruder.position = _intruder_home
	var tw := create_tween()
	tw.tween_property(_intruder, "position", _intruder_target.position, maxf(0.1, hit.time - conductor.time()))
	_cast[0].call("play_pose", &"wait", 0.3)


func _on_judged(index: int, grade: StringName, offset: float, wrong_lane: int) -> void:
	var type: StringName = hits[index].type
	if type != &"rival":
		super(index, grade, offset, wrong_lane)
		if grade != &"miss" and type == &"bento":
			_cast[1].call("play_pose", &"pack", 0.36)
			say("shinpachi_bento")
		elif grade != &"miss" and type == &"rice":
			_cast[2].call("play_pose", &"rice", 0.3)
			say("kagura_rice")
		return
	if grade == &"miss":
		%Miss.play()
		var tw := create_tween()
		tw.tween_interval(0.25)
		tw.tween_property(_intruder, "position", _intruder_home, 0.4)
	else:
		%Chomp.play()
		say("gintoki_kick")
		_cast[0].call("play_pose", &"kick", 0.35)
		_cast[0].bump(0.14, 0.14)
		var tw := create_tween()
		tw.tween_property(_intruder, "position", _intruder_target.position + Vector2(-220, -140), 0.35)
		tw.tween_callback(func(): _intruder.visible = false)
