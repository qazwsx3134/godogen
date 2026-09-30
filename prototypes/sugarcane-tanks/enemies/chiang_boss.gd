extends "res://enemies/enemy.gd"
## Final boss: moves around the upper half of the room and fires bullet patterns to dodge.
## Each pattern is announced by a short flash. Below half HP bullets get faster and rests shorter.
##   aimed  — three 3-way bursts at the hero
##   fan    — two wide fans, the second offset so there are gaps to slip through
##   spiral — two arms rotating for a few seconds
##   ring   — a full circle

enum Pattern { AIMED, FAN, SPIRAL, RING }

@export var bullet_scene: PackedScene
@export var bullet_speed: float = 420.0
@export var bullet_damage: int = 70
@export var rest_time: float = 1.1
@export var telegraph_time: float = 0.45
@export var roam_area: Rect2 = Rect2(200, 380, 680, 280)

var _pattern_index: int = 0
var _busy: bool = false
var _rest: float = 1.2
var _roam_target: Vector2 = Vector2.ZERO

@onready var _gun_arm: Node2D = %GunArm

func enraged() -> bool:
	return hp * 2 < max_hp

func think(delta: float) -> void:
	_gun_arm.rotation = lerp_angle(_gun_arm.rotation, to_target().angle(), clampf(10.0 * delta, 0.0, 1.0))
	if _busy:
		drive(Vector2.ZERO, delta)
		return
	if _roam_target == Vector2.ZERO or global_position.distance_to(_roam_target) < 20.0:
		_roam_target = roam_area.position + Vector2(randf() * roam_area.size.x, randf() * roam_area.size.y)
	drive((_roam_target - global_position).normalized(), delta)
	_rest -= delta * (1.5 if enraged() else 1.0) * slow_factor()
	if _rest <= 0.0:
		_run_pattern(_pattern_index % 4)
		_pattern_index += 1

func _speed() -> float:
	return bullet_speed * (1.2 if enraged() else 1.0)

func _fire(angle: float) -> void:
	game.spawn_projectile(bullet_scene, muzzle.global_position, Vector2.from_angle(angle), _speed(), bullet_damage)

func _wait(seconds: float) -> bool:
	await get_tree().create_timer(seconds, false).timeout
	return not dead and active

func _run_pattern(pattern: int) -> void:
	_busy = true
	var flash: Tween = create_tween()
	flash.tween_property(body_pivot, "modulate", Color(1.8, 1.5, 1.0), telegraph_time * 0.5)
	flash.tween_property(body_pivot, "modulate", Color.WHITE, telegraph_time * 0.5)
	if not await _wait(telegraph_time):
		return
	match pattern:
		Pattern.AIMED:
			for burst: int in 3:
				var aim: float = (target.global_position - muzzle.global_position).angle()
				for offset: float in [-0.17, 0.0, 0.17]:
					_fire(aim + offset)
				game.sfx.play(&"gun")
				if not await _wait(0.28):
					return
		Pattern.FAN:
			var count: int = 13
			for wave: int in 2:
				var aim: float = (target.global_position - muzzle.global_position).angle()
				var half_step: float = deg_to_rad(140.0) / (count - 1) * 0.5 * wave
				for i: int in count:
					_fire(aim - deg_to_rad(70.0) + deg_to_rad(140.0) * i / (count - 1) + half_step)
				game.sfx.play(&"gun")
				if not await _wait(0.5):
					return
		Pattern.SPIRAL:
			var angle: float = randf() * TAU
			for step: int in 28:
				_fire(angle)
				_fire(angle + PI)
				angle += deg_to_rad(17.0)
				if step % 4 == 0:
					game.sfx.play(&"gun")
				if not await _wait(0.085):
					return
		Pattern.RING:
			var count: int = 24 + (8 if enraged() else 0)
			var start: float = randf() * TAU
			for i: int in count:
				_fire(start + TAU * i / count)
			game.sfx.play(&"gun")
			game.shake(5.0, 0.15)
	_rest = rest_time
	_busy = false
