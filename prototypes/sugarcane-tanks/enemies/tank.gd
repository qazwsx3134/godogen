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
var _windup_total: float = 0.4
var _sprite_home: Vector2 = Vector2.ZERO
var _dust_gap: float = 0.0

@onready var _dash_line: Line2D = %DashLine

func _ready() -> void:
	super._ready()
	_sprite_home = sprite.position

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
			_shudder()
			if _timer <= 0.0:
				_start_dash()
		Phase.DASH:
			var before: Vector2 = global_position
			velocity = _dash_direction * dash_speed * slow_factor()
			move_and_slide()
			var moved: float = global_position.distance_to(before)
			_dash_left -= moved
			_dust_gap -= moved
			if _dust_gap <= 0.0:   # dust kicked up behind it
				_dust_gap = 55.0
				game.juice.dash_dust(global_position + Vector2(0.0, _sprite_home.y) - _dash_direction * 45.0)
			var bumped: bool = get_slide_collision_count() > 0
			if bumped or _dash_left <= 0.0:
				_end_dash(bumped)
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
	_windup_total = duration
	_dash_direction = to_target().normalized()
	_dash_left = distance
	face_toward(_dash_direction)
	_dash_line.points = PackedVector2Array([Vector2.ZERO, _dash_direction * distance])
	_dash_line.visible = true
	game.sfx.play(&"rev")

## The picture (not the body) shudders in place, harder the closer the dash gets, then settles back
## at the start of the dash. Smooth sines, not a random jump every frame.
func _shudder() -> void:
	var build_up: float = 1.0 - clampf(_timer / maxf(_windup_total, 0.001), 0.0, 1.0)
	var t: float = Time.get_ticks_msec() * 0.001
	var amplitude: float = 1.5 + 3.5 * build_up
	sprite.position = _sprite_home + Vector2(sin(t * 83.0) * amplitude, cos(t * 67.0) * amplitude * 0.5)

func _start_dash() -> void:
	phase = Phase.DASH
	sprite.position = _sprite_home
	_dust_gap = 0.0
	_dash_line.visible = false
	collision_mask &= ~HERO_LAYER
	game.sfx.play(&"dash")

## `bumped`: the dash stopped against a wall or crate (not because it had run its distance).
func _end_dash(bumped: bool) -> void:
	collision_mask |= HERO_LAYER
	velocity = Vector2.ZERO
	if bumped:
		game.juice.tank_bumped(global_position + Vector2(0.0, _sprite_home.y) + _dash_direction * 50.0)
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

func take_hit(amount: float, crit: bool = false, burn: bool = false, freeze: bool = false, push: Vector2 = Vector2.ZERO, hit_at: Vector2 = Vector2.INF) -> void:
	# A dashing tank does not get pushed off its line.
	super.take_hit(amount, crit, burn, freeze, Vector2.ZERO if phase == Phase.DASH else push, hit_at)
