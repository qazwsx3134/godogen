extends CharacterBody2D
## The sugarcane thrower. Archero rule: moving means no attacking; the moment the
## stick is released the hero turns to the nearest visible enemy and throws.
##
## The throw is drawn from hero_throw.png, six frames in %Sprite (frame property): 0 ready, 1 raise,
## 2 pull back, 3 release, 4 follow-through, 5 recover. The frames only follow the throw timing set by
## _cooldown and stats.attack_interval(); they never change it. Only %Sprite.frame and .offset are
## animated here, so %Sprite.scale stays free for squash and stretch.

signal died

const READY: int = 0
const RAISE: int = 1
const PULL_BACK: int = 2
const RELEASE: int = 3   # 3, 4, 5 are the follow-through

@export var move_speed: float = 430.0
## After stopping, the first throw comes this fast even if the cooldown was longer.
@export var stop_to_throw_delay: float = 0.12
@export var volley_gap: float = 0.12
@export var hurt_invulnerability: float = 0.5
## The wind-up (frames 1 then 2) fills the shorter of this and the time left before the next throw.
@export var windup_time: float = 0.15
## From the cane leaving the hand (frame 3) back to the ready pose (frame 0). A new throw inside this
## time (fast attack speed, the volleys of a multishot) starts it again from frame 3.
@export var follow_through_time: float = 0.25
## Per frame, how far (px) to push the picture down so the soles stand on the shadow in every frame:
## the lunge frames of hero_throw.png end above the bottom of their cell (= 140 minus the lowest opaque row).
@export var frame_drop: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 9.0, 9.0, 5.0])
## Walking leaves a puff of dust at the feet every this many px.
@export var step_spacing: float = 95.0

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
var _sprite_offset: Vector2 = Vector2.ZERO
var _foot: float = 0.0   # y of the soles, where dust goes
var _since_throw: float = INF
var _windup_length: float = 0.0   # 0 = no wind-up running
var _was_moving: bool = false
var _step_distance: float = 0.0

@onready var _body: Node2D = %Body
@onready var _sprite: Sprite2D = %Sprite
@onready var _hand: Marker2D = %Hand
@onready var _hp_bar: ProgressBar = %HpBar
@onready var _hp_label: Label = %HpLabel

func _ready() -> void:
	_sprite_offset = _sprite.offset
	_foot = _sprite.position.y
	_sprite.set_meta(&"rest_scale", _sprite.scale)   # squashes (game/juice.gd) always return to this

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

## Where the soles are on the floor.
func feet() -> Vector2:
	return global_position + Vector2(0.0, _foot)

func _physics_process(delta: float) -> void:
	_invulnerable = maxf(0.0, _invulnerable - delta)
	_since_throw += delta
	_blink()
	if dead or not active:
		velocity = Vector2.ZERO
		_windup_length = 0.0
		_was_moving = false
		_show_frame(READY)
		return
	var before: Vector2 = global_position
	var moving: bool = is_moving()
	if _was_moving and not moving:
		game.juice.hero_stopped(self)
	_was_moving = moving
	if moving:
		velocity = move_input.limit_length(1.0) * move_speed
		_face(velocity.x)
		_cooldown = maxf(_cooldown - delta, stop_to_throw_delay)
		_body.rotation = sin(Time.get_ticks_msec() * 0.02) * 0.08
		_windup_length = 0.0
		_show_frame(READY)
	else:
		velocity = Vector2.ZERO
		_body.rotation = 0.0
		_cooldown -= delta
		var target: Node2D = null
		if _cooldown < windup_time:   # the next throw is near (or due): is there anything to throw at?
			target = game.nearest_enemy(global_position)
		if target != null:
			_face(_side_of(target))
			if _cooldown <= 0.0:
				_throw_at(target)
				_cooldown = stats.attack_interval()
		_animate_standing(target != null)
	move_and_slide()
	if moving:
		_step_distance += global_position.distance_to(before)
		if _step_distance >= step_spacing:
			_step_distance = 0.0
			game.juice.hero_stepped(feet())
	else:
		_step_distance = 0.0

## While the hit's invulnerability runs the hero flickers (only the picture's alpha; the red flash on
## the whole body in take_hit is separate).
func _blink() -> void:
	var flicker: bool = _invulnerable > 0.0 and not dead and int(_invulnerable * 24.0) % 2 == 0
	_sprite.modulate.a = 0.35 if flicker else 1.0

## Which frame to show while standing: follow-through after a throw, else the wind-up before the next
## one (only while there is a target, so a hero with nothing to throw at does not hold its arm up).
func _animate_standing(has_target: bool) -> void:
	if _since_throw < follow_through_time:
		_show_frame(RELEASE + mini(2, int(_since_throw / (follow_through_time / 3.0))))
	elif has_target:
		if _windup_length <= 0.0:
			_windup_length = minf(_cooldown, windup_time)
		var progress: float = 1.0 - _cooldown / maxf(_windup_length, 0.001)
		_show_frame(PULL_BACK if progress >= 0.5 else RAISE)
	else:
		_windup_length = 0.0
		_show_frame(READY)

func _throw_at(target: Node2D) -> void:
	_face(_side_of(target))
	var direction: Vector2 = (target.global_position - throw_origin()).normalized()
	for volley: int in stats.volleys():
		if volley > 0:
			await get_tree().create_timer(volley_gap, false).timeout
			if dead or not is_inside_tree() or is_moving():
				return
		_release(direction)
		game.throw_volley(self, direction)

## The cane leaves the hand: frame 3, and the follow-through starts over (also between the volleys of
## a multishot or when the next throw comes before the last one has finished).
func _release(direction: Vector2) -> void:
	_since_throw = 0.0
	_windup_length = 0.0
	_show_frame(RELEASE)
	game.juice.hero_threw(self, _hand.global_position, direction)

func _show_frame(frame: int) -> void:
	if _sprite.frame == frame:
		return
	_sprite.frame = frame
	_sprite.offset = _sprite_offset + Vector2(0.0, frame_drop[frame] if frame < frame_drop.size() else 0.0)

## -1..1: how far to the left or right of the hero the target is (the sign is the side).
func _side_of(target: Node2D) -> float:
	return (target.global_position - global_position).normalized().x

func _face(x: float) -> void:
	if absf(x) > 0.05:
		_facing = signf(x)
		_body.scale.x = _facing

## `crushed`: run over by a dashing tank — the hero gets flattened for a moment.
func take_hit(amount: int, crushed: bool = false) -> void:
	if dead or god_mode or _invulnerable > 0.0:
		return
	_invulnerable = hurt_invulnerability
	last_hit_crushed = crushed
	if crushed:
		_squash()
	var taken: int = stats.take_damage(amount)
	game.on_hero_hurt(taken, crushed)
	refresh_hp()
	var tween: Tween = create_tween()
	modulate = Color(1.0, 0.35, 0.35)
	tween.tween_property(self, "modulate", Color.WHITE, 0.25)
	if stats.hp <= 0:
		dead = true
		died.emit()

## Flattened onto the ground: only the sprite squashes (around the feet); %Body keeps the left/right flip.
func _squash() -> void:
	game.juice.squash(_sprite, Vector2(1.5, 0.3), 0.45, Tween.TRANS_ELASTIC)

func refresh_hp() -> void:
	_hp_bar.max_value = stats.max_hp
	_hp_bar.value = stats.hp
	_hp_label.text = str(stats.hp)
