extends "res://enemies/enemy.gd"
## Chef (the file is still plate.gd): a ranged enemy. Keeps its distance, sidesteps, always faces the
## hero, and tosses a fan of three-colour beans (pea, corn, carrot) from its frying pan (%Muzzle)
## with a squash-and-hop.

@export var bean_scenes: Array[PackedScene] = []
@export var throw_interval: float = 2.4
@export var fan_degrees: float = 16.0
@export var bean_speed: float = 470.0
@export var bean_damage: int = 55
@export var near_distance: float = 380.0
@export var far_distance: float = 700.0
## How high the chef hops (px) when it throws.
@export var hop_height: float = 28.0

var _throw_timer: float = 1.2
var _strafe_sign: float = 1.0
var _strafe_timer: float = 0.0
var _rest_position: Vector2 = Vector2.ZERO
var _rest_scale: Vector2 = Vector2.ONE

@onready var _sprite: Sprite2D = %Sprite

func _ready() -> void:
	super._ready()
	_rest_position = _sprite.position
	_rest_scale = _sprite.scale

func think(delta: float) -> void:
	var to_hero: Vector2 = to_target()
	var distance: float = to_hero.length()
	face_toward(to_hero)
	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_timer = randf_range(1.0, 2.0)
		_strafe_sign = -_strafe_sign
	if distance < near_distance:
		drive(-to_hero.normalized(), delta)
	elif distance > far_distance:
		drive(to_hero.normalized(), delta)
	else:
		drive(to_hero.normalized().orthogonal() * _strafe_sign, delta, 0.6)
	_throw_timer -= delta * slow_factor()
	if _throw_timer <= 0.0:
		_throw_timer = throw_interval
		_throw()

## Squash down, toss the beans as it springs up, stretch in the air, land squashed, settle.
## Only %Sprite is animated: it scales around the feet, and %Body keeps the left/right flip.
func _throw() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_sprite, "scale", _rest_scale * Vector2(1.15, 0.8), 0.08)
	tween.tween_callback(_toss_beans)
	tween.tween_property(_sprite, "scale", _rest_scale * Vector2(0.88, 1.18), 0.1)
	tween.parallel().tween_property(_sprite, "position:y", _rest_position.y - hop_height, 0.1).set_ease(Tween.EASE_OUT)
	tween.tween_property(_sprite, "position:y", _rest_position.y, 0.12).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_sprite, "scale", _rest_scale * Vector2(1.12, 0.86), 0.12)
	tween.tween_property(_sprite, "scale", _rest_scale, 0.08)

func _toss_beans() -> void:
	if dead:
		return
	for i: int in bean_scenes.size():
		var t: float = 0.5 if bean_scenes.size() == 1 else float(i) / float(bean_scenes.size() - 1)
		throw_projectile(bean_scenes[i], deg_to_rad(lerpf(-fan_degrees, fan_degrees, t)), bean_speed, bean_damage)
	game.sfx.play(&"toss")
