extends "res://enemies/enemy.gd"
## Rat: the first enemy. Scurries straight at the hero with a little zig-zag and bumps into them.

@export var wobble: float = 0.35
@export var tail_wag_speed: float = 18.0

var _time: float = 0.0

@onready var _tail: Node2D = %Tail

func _ready() -> void:
	super._ready()
	_time = randf() * TAU

func think(delta: float) -> void:
	_time += delta
	var direction: Vector2 = to_target().normalized().rotated(sin(_time * 5.0) * wobble)
	drive(direction, delta)
	_tail.rotation = sin(_time * tail_wag_speed) * 0.5
