extends RhythmLevel
## Round 3: Gintoki and Shinpachi, now fat, take turns throwing skewers like darts at Kagura; each lands in her
## mouth land_after beats later (toss 2, quick 1, big 2). Tap anywhere on the landing beat. A miss hits her in the
## eye and costs a life (the chart's "lives"); the round is lost at 0. Kagura keeps growing rounder.

const SKEWER := preload("res://scenes/skewer.tscn")

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
		%Chomp.play()
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


func _on_whiff(_lane: int) -> void:
	%Whiff.play()
	_kagura.bump(0.05, 0.1)


func _refresh_bodies() -> void:
	%Gintoki.fat = true  # both ate themselves fat by the final round
	%Shinpachi.fat = true
	_kagura.fullness = MatchState.kagura_fullness()
	_kagura.girth = 1.0 + 0.9 * MatchState.kagura_fullness()
	_sticks.count = MatchState.team_total()
