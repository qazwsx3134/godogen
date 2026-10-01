extends Node2D
## EXP gem, heart or coin. Drops with a small hop, then waits until the room is clear
## and flies to the hero (Archero collects everything at once).

enum Kind { EXP, HEART, COIN }

@export var kind: Kind = Kind.EXP
@export var value: int = 1

var game: Node
var _target: Node2D
var _speed: float = 0.0
var _bob: float = 0.0

@onready var _visual: Node2D = %Visual

func _ready() -> void:
	_visual.set_meta(&"rest_scale", _visual.scale)   # the pop-in (game/juice.gd) settles on this

func drop(from: Vector2) -> void:
	game.juice.pickup_dropped(_visual)
	global_position = from
	var land: Vector2 = from + Vector2.from_angle(randf() * TAU) * randf_range(20.0, 70.0)
	var tween: Tween = create_tween()
	tween.tween_property(self, "global_position", land, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_bob = randf() * TAU

func magnet(target: Node2D) -> void:
	_target = target
	_speed = randf_range(250.0, 450.0)

func _process(delta: float) -> void:
	_bob += delta * 4.0
	_visual.position.y = sin(_bob) * 4.0
	if _target == null or not is_instance_valid(_target):
		return
	_speed += 2600.0 * delta
	var to_target: Vector2 = _target.global_position - global_position
	if to_target.length() < 30.0:
		game.collect_pickup(self)
		queue_free()
		return
	global_position += to_target.normalized() * minf(_speed * delta, to_target.length())
