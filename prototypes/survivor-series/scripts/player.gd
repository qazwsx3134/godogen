extends CharacterBody2D
@export var move_speed: float = 210.0
@export var attack_range: float = 100.0
@export var max_hp: float = 100.0
## Seconds of invulnerability after taking damage.
@export var hurt_interval: float = 0.5
var hp: float = 100.0
var hp_limit: float = 100.0
var armor: float = 0.0
var speed_scale: float = 1.0
## Per-hero multipliers and swing feel, set by set_hero().
var hero_hp: float = 1.0
var hero_speed: float = 1.0
var swing_reach: float = 27.0
var swing_overshoot: bool = true
var facing := Vector2.RIGHT
var attack_cooldown: float = 0.0
var hurt_cooldown: float = 0.0
var rest_scale: Vector2
var rest_position: Vector2
var rest_visual_position: Vector2
var rest_motion_position: Vector2
var rest_fist_scale: Vector2
var walk_phase: float = 0.0
var _pose: Tween
@onready var visual: Node2D = %Visual
@onready var fist: Node2D = %Fist
@onready var motion: Node2D = %Motion
@onready var body_man: Node2D = %BodyMan
@onready var body_woman: Node2D = %BodyWoman
@onready var umbrella: Node2D = %Umbrella
@onready var hp_bar: ProgressBar = %HpBar

func _ready() -> void:
	rest_scale = visual.scale
	rest_position = position
	rest_visual_position = visual.position
	rest_motion_position = motion.position
	rest_fist_scale = fist.scale

## Shows the hero's body and applies their stat multipliers and swing feel (HeroDef).
func set_hero(def: Resource) -> void:
	var woman: bool = def != null and def.id == &"woman"
	body_man.visible = not woman
	body_woman.visible = woman
	if def == null:
		return
	hero_hp = def.hp_scale
	hero_speed = def.speed_scale
	swing_reach = def.swing_reach
	swing_overshoot = def.swing_overshoot

## Shows the umbrella while at least one hit can still be absorbed.
func set_shield(charges: int) -> void:
	umbrella.visible = charges > 0

func reset(limit: float = max_hp, damage_reduction: float = 0.0, speed_bonus: float = 0.0) -> void:
	if _pose != null and _pose.is_valid():
		_pose.kill()
	position = rest_position
	velocity = Vector2.ZERO
	hp_limit = limit
	hp = limit
	armor = damage_reduction
	speed_scale = hero_speed * (1.0 + speed_bonus)
	facing = Vector2.RIGHT
	attack_cooldown = 0.0
	hurt_cooldown = 0.0
	visual.scale = rest_scale
	visual.position = rest_visual_position
	visual.modulate = Color.WHITE
	fist.position = Vector2.ZERO
	fist.scale = rest_fist_scale
	motion.position = rest_motion_position
	walk_phase = 0.0
	_refresh_bar()
	set_shield(0)

func step(delta: float, direction: Vector2, bounds: Rect2, slow: float = 0.0) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	hurt_cooldown = maxf(0.0, hurt_cooldown - delta)
	velocity = direction.limit_length(1.0) * move_speed * speed_scale * (1.0 - slow)
	move_and_slide()
	position = position.clamp(bounds.position, bounds.end)
	if direction.length() > 0.05:
		facing = direction.normalized()
		walk_phase += delta * 13.0
		motion.position.y = rest_motion_position.y - absf(sin(walk_phase)) * 3.0
	else:
		motion.position.y = move_toward(motion.position.y, rest_motion_position.y, delta * 24.0)
	if absf(direction.x) > 0.05 and (_pose == null or not _pose.is_valid() or not _pose.is_running()):
		visual.scale.x = absf(rest_scale.x) * (1.0 if direction.x >= 0.0 else -1.0)

func punch(direction: Vector2, interval: float, heavy: bool = false) -> void:
	attack_cooldown = interval
	if _pose != null and _pose.is_valid():
		_pose.kill()
	fist.position = Vector2.ZERO
	visual.position = rest_visual_position
	if absf(direction.x) > 0.05:
		visual.scale.x = absf(rest_scale.x) * signf(direction.x)
	fist.scale = rest_fist_scale * (1.5 if heavy else 1.15)
	_pose = create_tween().set_parallel(true)
	var local_direction := Vector2(direction.x * signf(visual.scale.x), direction.y)
	_pose.tween_property(fist, "position", local_direction * swing_reach, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pose.tween_property(visual, "position", rest_visual_position + local_direction * 6.0, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pose.chain().tween_property(fist, "position", Vector2.ZERO, 0.16).set_trans(Tween.TRANS_BACK if swing_overshoot else Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pose.parallel().tween_property(visual, "position", rest_visual_position, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pose.parallel().tween_property(fist, "scale", rest_fist_scale, 0.16)

## Takes `amount` minus armor (at least 1). Returns false while invulnerable.
func hurt(amount: float) -> bool:
	if hurt_cooldown > 0.0 or hp <= 0.0:
		return false
	hurt_cooldown = hurt_interval
	hp = maxf(0.0, hp - maxf(1.0, amount - armor))
	_refresh_bar()
	visual.modulate = Color(1.0, 0.35, 0.35)
	create_tween().tween_property(visual, "modulate", Color.WHITE, 0.3)
	return true

func heal(amount: float) -> void:
	if hp <= 0.0:
		return
	hp = minf(hp_limit, hp + amount)
	_refresh_bar()

func revive(fraction: float) -> void:
	hp = hp_limit * fraction
	hurt_cooldown = 2.0
	_refresh_bar()

func _refresh_bar() -> void:
	hp_bar.max_value = hp_limit
	hp_bar.value = hp
