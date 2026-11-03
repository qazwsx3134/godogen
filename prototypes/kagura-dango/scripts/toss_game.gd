extends RhythmLevel
## Round 3: Gintoki and Shinpachi, now fat, take turns throwing skewers like darts at Kagura; each lands in her
## mouth land_after beats later (toss 2, quick 1, big 2). Tap anywhere on the landing beat. A miss hits her in the
## eye and costs a life (the chart's "lives"); when they run out she is knocked flat on the ground (skewers still land
## at her mouth, hits still score) and gets back up down_seconds later with her lives refilled. Kagura keeps growing
## rounder.

const SKEWER := preload("res://scenes/skewer.tscn")

## Kagura's angle once knocked down (rotating about her feet; negative tips her head left, towards the middle, since she
## stands at the right edge).
@export var down_angle_deg := -90.0
## Song seconds she stays on the ground before getting back up.
@export var down_seconds := 4.0

var _up_at := -1.0
## Kagura's eating sound: a clip id in assets/voice/ (empty or missing = the Chomp sound).
@export var eat_clip := "shinpachi_eat"

var _skewers := {}

@onready var _gintoki: Node2D = %Gintoki
@onready var _kagura: Node2D = %Kagura
@onready var _shinpachi: Node2D = %Shinpachi
@onready var _flying: Node2D = %Skewers
@onready var _sticks: Node2D = %SkewerPile


func _ready() -> void:
	super()
	stage.focus(_kagura.get_node("Mouth").global_position)
	_refresh_bodies()


func _process(delta: float) -> void:
	super(delta)
	var t := conductor.time()
	if down and _up_at >= 0.0 and t >= _up_at:
		_stand_up()
	for s in _skewers.values():
		if is_instance_valid(s):
			s.place(t)


func _on_cue(index: int) -> void:
	var hit := hits[index]
	var thrower: Node2D = _gintoki if index % 2 == 0 else _shinpachi
	var s := SKEWER.instantiate()
	var hand: Node = thrower.get_node_or_null("Hand")
	s.from = _flying.to_local((hand if hand else thrower).global_position)
	s.to = _flying.to_local(_kagura.get_node("Mouth").global_position)
	s.t0 = conductor.beat_time(hit.cue_beat)
	s.t1 = hit.time
	s.big = hit.type == &"big"
	s.height = 60.0 if hit.type == &"quick" else 82.0
	_flying.add_child(s)
	_skewers[index] = s
	thrower.call("play_pose", &"dart", 0.3)
	thrower.bump(0.06 + 0.04 * intensity, 0.15)


func _on_judged(index: int, grade: StringName, _offset: float, _wrong_lane: int) -> void:
	var s = _skewers.get(index)
	if grade == &"miss":
		%Miss.play()
		if is_instance_valid(s):
			s.drop()
	else:
		if not play_clip(eat_clip, eat_volume_db):
			%Chomp.play()
		if not down:  # lying on the ground: she keeps her knocked-out pose
			_kagura.call("play_pose", &"eat", 0.3)
			_kagura.bump(0.18 if grade == &"ace" else 0.1, 0.14)
		if is_instance_valid(s):
			s.eat()
		if grade == &"ace":
			_shinpachi.bump(0.08, 0.2)
		if hits[index].type == &"big" and intensity >= 3:
			shake(9.0, 0.3)
		_refresh_bodies()
	_skewers.erase(index)


func _on_hurt() -> void:
	_kagura.call("play_pose", &"eye", 0.6)
	shake(6.0, 0.25)


## Out of lives: the full 「痛苦倒地」 line, and she falls over backwards onto the ground (rotating about her feet).
func _on_knocked_down() -> void:
	say("kagura_eye", true)
	shake(10.0, 0.4)
	_kagura.call("play_pose", &"eye", 9999.0)
	var tw := create_tween()
	tw.tween_property(_kagura, "rotation", deg_to_rad(down_angle_deg), 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_up_at = conductor.time() + down_seconds


func _stand_up() -> void:
	_up_at = -1.0
	get_up()
	var tw := create_tween()
	tw.tween_property(_kagura, "rotation", 0.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_kagura.call("play_pose", &"idle", 0.05)  # ends the knocked-out pose
	_kagura.bump(0.2, 0.3)


func _on_whiff(_lane: int) -> void:
	%Whiff.play()
	_kagura.bump(0.05, 0.1)


func _refresh_bodies() -> void:
	var tier_before: int = _kagura.tier()
	_kagura.fullness = MatchState.kagura_fullness()
	_kagura.girth = kagura_girth_now()
	if _running and not down and _kagura.tier() > tier_before:  # she just grew into her roundest body mid-round: make it land
		_kagura.bump(0.3, 0.4)
		shake(5.0, 0.25)
		say("kagura_now")
	_sticks.count = MatchState.team_total()
