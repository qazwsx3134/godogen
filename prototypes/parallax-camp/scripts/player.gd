extends CharacterBody2D

signal sound_requested(sound: StringName)
signal landed(impact_speed: float)

const RUN_DISTANCE_PER_CEL := 2.0

@export var run_speed := 162.0
@export var jump_speed := 232.0
@export var air_jump_speed := 220.0
@export var gravity := 680.0
@export var run_acceleration := 0.0
@export var run_brake := 0.0
@export var fall_gravity_multiplier := 1.0
@export var coyote_time := 0.0
@export var jump_buffer_time := 0.0
@export_range(0.1, 1.0) var jump_release_multiplier := 1.0

@onready var _art: AnimatedSprite2D = %Art
@onready var _art_origin := _art.position
@onready var _run_cycle_distance := float(_art.sprite_frames.get_frame_count(&"run")) * RUN_DISTANCE_PER_CEL
@onready var _ground_ray: RayCast2D = %GroundRay
@onready var _shadow: Polygon2D = %Shadow
@onready var _shadow_size := _shadow.scale
@onready var _shadow_alpha := _shadow.color.a

var _was_airborne := false
var _air_jump_available := false
var _coyote_remaining := 0.0
var _jump_buffer_remaining := 0.0
var _run_distance := 0.0


func _physics_process(delta: float) -> void:
	var was_grounded := is_on_floor()
	if was_grounded:
		_air_jump_available = true
		_coyote_remaining = coyote_time
	else:
		_coyote_remaining = maxf(0.0, _coyote_remaining - delta)

	var direction := Input.get_axis(&"walk_left", &"walk_right")
	var target_speed := direction * run_speed
	var acceleration := run_brake if is_zero_approx(direction) else run_acceleration
	velocity.x = move_toward(velocity.x, target_speed, acceleration * delta) if acceleration > 0.0 else target_speed
	velocity.y += gravity * delta * (fall_gravity_multiplier if velocity.y > 0.0 else 1.0)
	_update_jump(was_grounded, delta)
	var impact_speed := velocity.y
	move_and_slide()

	if is_on_floor() and _was_airborne:
		sound_requested.emit(&"land")
		landed.emit(impact_speed)
	_was_airborne = not is_on_floor()

	_update_animation(direction)
	_update_shadow()


func _update_jump(was_grounded: bool, delta: float) -> void:
	_jump_buffer_remaining = maxf(0.0, _jump_buffer_remaining - delta)
	if Input.is_action_just_pressed(&"jump"):
		_jump_buffer_remaining = maxf(jump_buffer_time, delta)
	if Input.is_action_just_released(&"jump") and velocity.y < 0.0:
		velocity.y *= jump_release_multiplier

	var ground_jump := was_grounded or _coyote_remaining > 0.0
	if _jump_buffer_remaining <= 0.0 or not (ground_jump or _air_jump_available):
		return
	velocity.y = -jump_speed if ground_jump else -air_jump_speed
	_coyote_remaining = 0.0
	_jump_buffer_remaining = 0.0
	if not ground_jump:
		_air_jump_available = false
	sound_requested.emit(&"jump")


func _update_animation(direction: float) -> void:
	var motion := get_position_delta().x
	if not _was_airborne and absf(get_real_velocity().x) >= 8.0:
		_update_run_cel(motion)
		return

	_art.position = _art_origin
	if not is_zero_approx(motion):
		_art.flip_h = motion < 0.0
	elif not is_zero_approx(direction):
		_art.flip_h = direction < 0.0
	if _was_airborne:
		if velocity.y < -45.0:
			_art.play(&"rise")
		elif velocity.y > 45.0:
			_art.play(&"fall")
		else:
			_art.play(&"apex")
	else:
		_art.play(&"idle")


func _update_run_cel(motion: float) -> void:
	var facing_left := motion < 0.0
	if _art.animation != &"run" or facing_left != _art.flip_h:
		_run_distance = 0.0
		_art.pause()
		_art.animation = &"run"
		_art.flip_h = facing_left
	else:
		_run_distance = fposmod(_run_distance + absf(motion), _run_cycle_distance)
	_art.frame = floori(_run_distance / RUN_DISTANCE_PER_CEL)
	# Cancel motion between cels on the art only, so the planted foot stays put.
	var remainder := fmod(_run_distance, RUN_DISTANCE_PER_CEL)
	_art.position = _art_origin - Vector2(signf(motion) * remainder, 0.0)


func respawn_at(at: Vector2) -> void:
	global_position = at
	velocity = Vector2.ZERO
	_was_airborne = false
	_air_jump_available = false
	_coyote_remaining = 0.0
	_jump_buffer_remaining = 0.0
	_run_distance = 0.0
	_art.position = _art_origin
	_art.play(&"idle")


func _update_shadow() -> void:
	_ground_ray.force_raycast_update()
	_shadow.visible = _ground_ray.is_colliding()
	if not _shadow.visible:
		return

	var hit := _ground_ray.get_collision_point()
	var height_ratio := 0.0
	if _was_airborne:
		height_ratio = clampf((hit.y - global_position.y) / _ground_ray.target_position.y, 0.0, 1.0)
	_shadow.global_position = hit
	_shadow.scale = _shadow_size * lerpf(1.0, 0.32, height_ratio)
	_shadow.color.a = _shadow_alpha * (1.0 - height_ratio)
