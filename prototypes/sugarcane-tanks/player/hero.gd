extends CharacterBody2D
## The sugarcane thrower. Archero rule: moving means no attacking; the moment the
## stick is released the hero turns to the nearest visible tank and throws.

signal died

@export var move_speed: float = 430.0
## After stopping, the first throw comes this fast even if the cooldown was longer.
@export var stop_to_throw_delay: float = 0.12
@export var volley_gap: float = 0.12
@export var hurt_invulnerability: float = 0.5

var game: Node
var stats: RefCounted
var move_input: Vector2 = Vector2.ZERO
var god_mode: bool = false
var last_hit_crushed: bool = false
var dead: bool = false
var active: bool = true

var _cooldown: float = 0.0
var _invulnerable: float = 0.0
var _facing: float = 1.0

@onready var _body: Node2D = %Body
@onready var _held_cane: Node2D = %HeldCane
@onready var _hand: Marker2D = %Hand
@onready var _hp_bar: ProgressBar = %HpBar
@onready var _hp_label: Label = %HpLabel

func setup(game_ref: Node, hero_stats: RefCounted) -> void:
	game = game_ref
	stats = hero_stats
	dead = false
	active = true
	modulate = Color.WHITE
	refresh_hp()

func is_moving() -> bool:
	return move_input.length() > 0.15

func throw_origin() -> Vector2:
	return _hand.global_position

func _physics_process(delta: float) -> void:
	_invulnerable = maxf(0.0, _invulnerable - delta)
	if dead or not active:
		velocity = Vector2.ZERO
		return
	if is_moving():
		velocity = move_input.limit_length(1.0) * move_speed
		_face(velocity.x)
		_cooldown = maxf(_cooldown - delta, stop_to_throw_delay)
		_body.rotation = sin(Time.get_ticks_msec() * 0.02) * 0.08
	else:
		velocity = Vector2.ZERO
		_body.rotation = 0.0
		_cooldown -= delta
		if _cooldown <= 0.0:
			var target: Node2D = game.nearest_enemy(global_position)
			if target != null:
				_throw_at(target)
				_cooldown = stats.attack_interval()
	move_and_slide()

func _throw_at(target: Node2D) -> void:
	var direction: Vector2 = (target.global_position - throw_origin()).normalized()
	_face(direction.x)
	_swing()
	for volley: int in stats.volleys():
		if volley > 0:
			await get_tree().create_timer(volley_gap, false).timeout
			if dead or not is_inside_tree() or is_moving():
				return
		game.throw_volley(self, direction)

func _face(x: float) -> void:
	if absf(x) > 0.05:
		_facing = signf(x)
		_body.scale.x = _facing

func _swing() -> void:
	var tween: Tween = create_tween()
	_held_cane.rotation = -1.4
	tween.tween_property(_held_cane, "rotation", 0.9, 0.1).set_ease(Tween.EASE_OUT)
	tween.tween_property(_held_cane, "rotation", -0.35, 0.18)

## `crushed`: run over by a dashing tank — the hero gets flattened for a moment.
func take_hit(amount: int, crushed: bool = false) -> void:
	if dead or god_mode or _invulnerable > 0.0:
		return
	_invulnerable = hurt_invulnerability
	last_hit_crushed = crushed
	if crushed:
		_squash()
	var taken: int = stats.take_damage(amount)
	game.on_hero_hurt(taken)
	refresh_hp()
	var tween: Tween = create_tween()
	modulate = Color(1.0, 0.35, 0.35)
	tween.tween_property(self, "modulate", Color.WHITE, 0.25)
	if stats.hp <= 0:
		dead = true
		died.emit()

func _squash() -> void:
	var facing: float = _body.scale.x
	_body.scale = Vector2(facing * 1.5, 0.3)
	var tween: Tween = create_tween()
	tween.tween_property(_body, "scale", Vector2(facing, 1.0), 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)

func refresh_hp() -> void:
	_hp_bar.max_value = stats.max_hp
	_hp_bar.value = stats.hp
	_hp_label.text = str(stats.hp)
