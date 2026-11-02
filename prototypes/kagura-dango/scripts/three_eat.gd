extends RhythmLevel
## Round 1: the three of them eat together. A skewer flies out of the serving hatch; its flavour says who eats it
## (red bean → Gintoki on the left, soy → Shinpachi in the middle, tricolour → Kagura on the right), and so does its
## sound (low / middle / high). Tap that person's third of the screen on the landing beat.

const SKEWER := preload("res://scenes/skewer.tscn")

var _skewers := {}

@onready var _cast: Array[Node2D] = [%Gintoki, %Shinpachi, %Kagura]
@onready var _hatch: Marker2D = %Hatch
@onready var _flying: Node2D = %Skewers
@onready var _sticks: Node2D = %SkewerPile


func _ready() -> void:
	super()
	_refresh_bodies()


func _process(delta: float) -> void:
	super(delta)
	var t := conductor.time()
	for s in _skewers.values():
		if is_instance_valid(s):
			s.place(t)


func _on_cue(index: int) -> void:
	var hit := hits[index]
	var s := SKEWER.instantiate()
	s.flavor = hit.type
	s.from = _flying.to_local(_hatch.global_position)
	s.to = _flying.to_local(_cast[hit.lane].get_node("Mouth").global_position)
	s.t0 = conductor.beat_time(hit.cue_beat)
	s.t1 = hit.time
	s.height = 60.0
	_flying.add_child(s)
	_skewers[index] = s


func _on_judged(index: int, grade: StringName, _offset: float, wrong_lane: int) -> void:
	var s = _skewers.get(index)
	if grade == &"miss":
		%Miss.play()
		if wrong_lane >= 0:
			_cast[wrong_lane].bump(0.12, 0.2)
		if is_instance_valid(s):
			s.drop()
	else:
		%Chomp.play()
		_cast[hits[index].lane].bump(0.16 if grade == &"ace" else 0.1, 0.14)
		if is_instance_valid(s):
			s.eat()
		_sticks.count = MatchState.team_total()
		_refresh_bodies()
	_skewers.erase(index)


func _on_whiff(lane: int) -> void:
	%Whiff.play()
	_cast[lane].bump(0.05, 0.1)


func _refresh_bodies() -> void:
	%Gintoki.fullness = MatchState.fullness(&"gintoki")
	%Shinpachi.fullness = MatchState.fullness(&"shinpachi")
	%Kagura.fullness = MatchState.kagura_fullness() * 0.5
	%Kagura.girth = 1.0 + 0.9 * MatchState.kagura_fullness()
	_sticks.count = MatchState.team_total()
