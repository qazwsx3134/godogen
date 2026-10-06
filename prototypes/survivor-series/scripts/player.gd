extends CharacterBody2D
@export var move_speed: float = 210.0
@export var attack_range: float = 100.0
@export var attack_damage: float = 34.0
@export var attack_interval: float = 0.42
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

func _ready() -> void:
	rest_scale = visual.scale
	rest_position = position
	rest_visual_position = visual.position
	rest_motion_position = motion.position
	rest_fist_scale = fist.scale

func reset() -> void:
	if _pose != null and _pose.is_valid():
		_pose.kill()
	position = rest_position
	velocity = Vector2.ZERO
	attack_cooldown = 0.0
	hurt_cooldown = 0.0
	visual.scale = rest_scale
	visual.position = rest_visual_position
	visual.modulate = Color.WHITE
	fist.position = Vector2.ZERO
	fist.scale = rest_fist_scale
	motion.position = rest_motion_position
	walk_phase = 0.0

func step(delta: float, direction: Vector2, bounds: Rect2) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	hurt_cooldown = maxf(0.0, hurt_cooldown - delta)
	velocity = direction.limit_length(1.0) * move_speed
	move_and_slide()
	position = position.clamp(bounds.position, bounds.end)
	if direction.length() > 0.05:
		walk_phase += delta * 13.0
		motion.position.y = rest_motion_position.y - absf(sin(walk_phase)) * 3.0
	else:
		motion.position.y = move_toward(motion.position.y, rest_motion_position.y, delta * 24.0)
	if absf(direction.x) > 0.05 and (_pose == null or not _pose.is_valid() or not _pose.is_running()):
		visual.scale.x = absf(rest_scale.x) * (1.0 if direction.x >= 0.0 else -1.0)

func punch(direction: Vector2, interval: float = -1.0, heavy: bool = false) -> void:
	attack_cooldown = attack_interval if interval < 0.0 else interval
	if _pose != null and _pose.is_valid():
		_pose.kill()
	fist.position = Vector2.ZERO
	visual.position = rest_visual_position
	if absf(direction.x) > 0.05:
		visual.scale.x = absf(rest_scale.x) * signf(direction.x)
	fist.scale = rest_fist_scale * (1.5 if heavy else 1.15)
	_pose = create_tween().set_parallel(true)
	var local_direction := Vector2(direction.x * signf(visual.scale.x), direction.y)
	_pose.tween_property(fist, "position", local_direction * 27.0, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pose.tween_property(visual, "position", rest_visual_position + local_direction * 6.0, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pose.chain().tween_property(fist, "position", Vector2.ZERO, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pose.parallel().tween_property(visual, "position", rest_visual_position, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pose.parallel().tween_property(fist, "scale", rest_fist_scale, 0.16)

func hurt() -> bool:
	if hurt_cooldown > 0.0:
		return false
	hurt_cooldown = 0.7
	visual.modulate = Color(1.0, 0.35, 0.35)
	create_tween().tween_property(visual, "modulate", Color.WHITE, 0.3)
	return true
