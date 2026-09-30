extends "res://enemies/enemy.gd"
## Plate: a ranged enemy. Keeps its distance, sidesteps, and tosses a fan of
## three-colour beans (pea, corn, carrot) at the hero.

@export var bean_scenes: Array[PackedScene] = []
@export var throw_interval: float = 2.4
@export var fan_degrees: float = 16.0
@export var bean_speed: float = 470.0
@export var bean_damage: int = 55
@export var near_distance: float = 380.0
@export var far_distance: float = 700.0

var _throw_timer: float = 1.2
var _strafe_sign: float = 1.0
var _strafe_timer: float = 0.0

func think(delta: float) -> void:
	var to_hero: Vector2 = to_target()
	var distance: float = to_hero.length()
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

func _throw() -> void:
	for i: int in bean_scenes.size():
		var t: float = 0.5 if bean_scenes.size() == 1 else float(i) / float(bean_scenes.size() - 1)
		throw_projectile(bean_scenes[i], deg_to_rad(lerpf(-fan_degrees, fan_degrees, t)), bean_speed, bean_damage)
	var tween: Tween = create_tween()
	tween.tween_property(body_pivot, "rotation", body_pivot.rotation + TAU, 0.35).set_ease(Tween.EASE_OUT)
	game.sfx.play(&"toss")
