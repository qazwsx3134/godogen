extends RhythmLevel
## Round 1: the owner serves a skewer onto the shared table on the cue beat. Its flavour identifies who eats it
## (red bean → Gintoki on the left, soy → Shinpachi in the middle, tricolour → Kagura on the right). Tap that
## person's third of the screen on the eating beat.

const SKEWER := preload("res://scenes/skewer.tscn")

## Eating sound per lane (left, middle, right): a clip id in assets/voice/, or empty for the Chomp sound.
@export var eat_clips: Array[String] = ["gintoki_eat", "shinpachi_eat", "shinpachi_eat"]

var _skewers := {}

@onready var _cast: Array[Node2D] = [%Gintoki, %Shinpachi, %Kagura]
@onready var _serve_origin: Marker2D = %ServeOrigin
@onready var _plates: Array[Marker2D] = [%PlateLeft, %PlateMiddle, %PlateRight]
@onready var _shopkeeper: Node2D = %Shopkeeper
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
	var lane: int = hit.lane
	var s := SKEWER.instantiate()
	s.flavor = hit.type
	s.from = _flying.to_local(_serve_origin.global_position)
	s.to = _flying.to_local(_plates[lane].global_position)
	s.t0 = conductor.beat_time(hit.cue_beat)
	s.t1 = conductor.beat_time(hit.cue_beat + 0.25)
	s.height = 5.0
	_flying.add_child(s)
	_skewers[index] = s
	_shopkeeper.call("serve")
	_cast[lane].call("play_pose", &"wait", maxf(0.2, hit.time - conductor.time() + 0.15))
	hud.call_out("店主上菜！")


func _on_judged(index: int, grade: StringName, _offset: float, wrong_lane: int) -> void:
	var s = _skewers.get(index)
	if grade == &"miss":
		%Miss.play()
		if wrong_lane >= 0:
			_cast[wrong_lane].call("play_pose", &"miss", 0.55)
			_cast[wrong_lane].bump(0.12, 0.2)
		else:
			_cast[hits[index].lane].call("play_pose", &"miss", 0.55)
		if is_instance_valid(s):
			s.drop()
	else:
		var lane: int = hits[index].lane
		if not play_clip(eat_clips[lane]):
			%Chomp.play()
		_cast[lane].call("play_pose", &"eat", 0.28)
		_cast[lane].bump(0.16 if grade == &"ace" else 0.1, 0.14)
		if is_instance_valid(s):
			s.serve_eat(_flying.to_local(_cast[lane].get_node("Mouth").global_position))
		_sticks.count = MatchState.team_total()
		_refresh_bodies()
	_skewers.erase(index)


func _on_whiff(lane: int) -> void:
	%Whiff.play()
	_cast[lane].bump(0.05, 0.1)


func _refresh_bodies() -> void:
	%Gintoki.fullness = MatchState.fullness(&"gintoki")
	%Shinpachi.fullness = MatchState.fullness(&"shinpachi")
	%Kagura.fullness = MatchState.kagura_fullness()
	%Kagura.girth = kagura_girth_now()
	_sticks.count = MatchState.team_total()
