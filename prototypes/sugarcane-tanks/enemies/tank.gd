extends "res://enemies/enemy.gd"
## Tank: rolls toward the hero, then locks on (red line), dashes and runs the hero over.
## While dashing it drives through the hero instead of stopping at them, and a hit flattens
## the hero. After a dash it sits still for a moment — the window to hit back.

enum Phase { APPROACH, WINDUP, DASH, RECOVER }

const HERO_LAYER: int = 2

@export var crush_damage: int = 130
@export var dash_speed: float = 950.0
@export var dash_distance: float = 750.0
@export var dash_range: float = 800.0
@export var windup_time: float = 0.7
@export var recover_time: float = 0.9
@export var dash_cooldown: float = 1.0

var phase: Phase = Phase.APPROACH
var _timer: float = 0.0
var _cooldown: float = 0.6
var _dash_direction: Vector2 = Vector2.ZERO
var _dash_left: float = 0.0

@onready var _dash_line: Line2D = %DashLine

func think(delta: float) -> void:
	match phase:
		Phase.APPROACH:
			_cooldown -= delta * slow_factor()
			drive(to_target().normalized(), delta)
			if _cooldown <= 0.0 and to_target().length() < dash_range:
				begin_attack()
		Phase.WINDUP:
			_timer -= delta * slow_factor()
			velocity = Vector2.ZERO
			body_pivot.position = Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))
			if _timer <= 0.0:
				_start_dash()
		Phase.DASH:
			var before: Vector2 = global_position
			velocity = _dash_direction * dash_speed * slow_factor()
			move_and_slide()
			_dash_left -= global_position.distance_to(before)
			if get_slide_collision_count() > 0 or _dash_left <= 0.0:
				_end_dash()
		Phase.RECOVER:
			_timer -= delta
			velocity = Vector2.ZERO
			if _timer <= 0.0:
				phase = Phase.APPROACH
				_cooldown = dash_cooldown

## Starts a normal attack. The boss overrides this to pick among its patterns.
func begin_attack() -> void:
	windup(windup_time, dash_distance)

func windup(duration: float, distance: float) -> void:
	phase = Phase.WINDUP
	_timer = duration
	_dash_direction = to_target().normalized()
	_dash_left = distance
	body_pivot.rotation = _dash_direction.angle()
	_dash_line.points = PackedVector2Array([Vector2.ZERO, _dash_direction * distance])
	_dash_line.visible = true
	game.sfx.play(&"rev")

func _start_dash() -> void:
	phase = Phase.DASH
	body_pivot.position = Vector2.ZERO
	_dash_line.visible = false
	collision_mask &= ~HERO_LAYER
	game.sfx.play(&"dash")

func _end_dash() -> void:
	collision_mask |= HERO_LAYER
	velocity = Vector2.ZERO
	game.shake(4.0, 0.1)
	after_dash()

## Called when a dash ends. The boss overrides this to chain dashes.
func after_dash() -> void:
	phase = Phase.RECOVER
	_timer = recover_time

func is_crushing() -> bool:
	return phase == Phase.DASH

func current_contact_damage() -> int:
	return crush_damage if phase == Phase.DASH else contact_damage

## For the demo bot: the line the tank is about to dash along, or empty.
func dash_warning() -> Array:
	if phase != Phase.WINDUP:
		return []
	return [global_position, _dash_direction, _dash_left]

func take_hit(amount: float, crit: bool = false, burn: bool = false, freeze: bool = false, push: Vector2 = Vector2.ZERO) -> void:
	# A dashing tank does not get pushed off its line.
	super.take_hit(amount, crit, burn, freeze, Vector2.ZERO if phase == Phase.DASH else push)
