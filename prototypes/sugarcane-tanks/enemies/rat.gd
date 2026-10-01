extends "res://enemies/enemy.gd"
## Rat: the first enemy. Scurries straight at the hero with a little zig-zag and bumps into them.

@export var wobble: float = 0.35
## Scurrying: the sprite hops this fast (rad/s) and this high (px) on its feet line, with a little sway.
@export var hop_speed: float = 20.0
@export var hop_height: float = 5.0

var _time: float = 0.0
var _rest_y: float = 0.0

@onready var _sprite: Sprite2D = %Sprite

func _ready() -> void:
	super._ready()
	_time = randf() * TAU
	_rest_y = _sprite.position.y

func think(delta: float) -> void:
	_time += delta
	var direction: Vector2 = to_target().normalized().rotated(sin(_time * 5.0) * wobble)
	drive(direction, delta)
	_sprite.position.y = _rest_y - absf(sin(_time * hop_speed)) * hop_height
	_sprite.rotation = sin(_time * hop_speed * 0.5) * 0.06
