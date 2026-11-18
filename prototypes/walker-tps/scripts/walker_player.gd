extends CharacterBody3D
## Third-person walker: moves relative to the camera (forward/back/strafe), the hull turns toward where the camera
## looks while moving, so the gun ends up pointing where the player looks. One movement model for keyboard,
## gamepad and touch; each look source has its own sensitivity. Sprint while held; jump = dash: a short squat, then a low burst along the stick (camera forward
## without input) that slides back down to running speed.

@export var max_speed: float = 7.5
@export var sprint_speed: float = 12.0
@export var accel: float = 8.0
## Fraction of `accel` available in the air.
@export var air_control: float = 0.3
@export var turn_speed_deg: float = 90.0
## Dash: burst speed (m/s), how long it is held before easing back, and a small hop
## (m/s up; apex = v^2 / 2g, about 1 m at 4.5): a rising diagonal, not a high jump.
@export var dash_speed: float = 20.0
@export var dash_time: float = 0.22
@export var jump_velocity: float = 4.5
@export var dash_cooldown: float = 0.45
## Dashing off a wall or a slope also pushes along its normal.
@export var wall_jump_push: float = 10.0
@export var slope_jump_push: float = 3.0
## Squat before the launch (s) and how deep the hull sinks (m).
@export var jump_squat_time: float = 0.06
@export var jump_squat_depth: float = 0.25
@export var mouse_sensitivity: float = 0.0025   # rad per pixel
@export var touch_sensitivity: float = 0.006    # rad per pixel
@export var pad_look_speed: float = 2.4         # rad per second at full stick
@export var step_kick: float = 0.05             # camera jolt per footfall (m)
@export var sprint_fov_add: float = 10.0        # degrees wider at full sprint speed
## Set to zero to disable the fullscreen speed effect.
@export_range(0.0, 0.05, 0.001) var speed_blur_strength: float = 0.018

const STEP_CLIPS = [
	preload("res://assets/sound/runtime/mech_contact.ogg"),
	preload("res://assets/sound/runtime/mech_step_a.ogg"),
	preload("res://assets/sound/runtime/mech_contact.ogg"),
	preload("res://assets/sound/runtime/mech_step_b.ogg"),
]

@onready var model: Node3D = %Model
@onready var gait: Node = %Gait
@onready var rig: Node3D = %CameraRig
@onready var dust: Node3D = %Dust
@onready var step_sound: AudioStreamPlayer3D = %StepSound

var controls_enabled := true
var team := "player"
@onready var combat: Node = get_node_or_null("Combat")
@onready var speed_blur: ColorRect = get_node_or_null("SpeedBlur/Screen")

func apply_damage(amount: float, hit_position: Vector3 = Vector3.ZERO, from_direction: Vector3 = Vector3.ZERO) -> void:
	if combat: combat.apply_damage(amount, hit_position, from_direction)

var touch: Node  # touch_input.gd, found by group; null on a desktop without a HUD
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _dust_next := 0
var _squat_left := -1.0  # > 0 while squatting before a jump
var _step_next := 0
var _step_sound_wait := 0.0
var _was_moving := false
var _land_stream: AudioStream
var _jump_normal := Vector3.UP
var _wall_jump_ready := true
var _wall_jump_cooldown := 0.0
var _speed_blur_amount := 0.0
var _dash_left := 0.0
var _dash_cooldown_left := 0.0
var _dash_dir := Vector3.ZERO

func _ready() -> void:
	_ensure_actions()
	gait.setup(self, model)
	gait.stepped.connect(_on_stepped)
	gait.landed.connect(_on_landed)
	rig.yaw = rotation.y + PI  # start behind the walker, looking where it faces (+Z)
	_land_stream = preload("res://assets/sound/runtime/mech_land.ogg")
	touch = get_tree().get_first_node_in_group("touch_input")

func _physics_process(delta: float) -> void:
	if not controls_enabled:  # still falls and lands, e.g. a round ending mid-jump
		_update_speed_blur(delta, false, 0.0)
		velocity=Vector3(0.0, velocity.y - _gravity * delta, 0.0)
		move_and_slide()
		return
	_step_sound_wait=maxf(0,_step_sound_wait-delta)
	_wall_jump_cooldown = maxf(0.0, _wall_jump_cooldown - delta)
	_dash_left = maxf(0.0, _dash_left - delta)
	_dash_cooldown_left = maxf(0.0, _dash_cooldown_left - delta)
	if is_on_floor() or (not is_on_wall() and _wall_jump_cooldown <= 0.0):
		_wall_jump_ready = true
	var input := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	if touch:
		input = (input + touch.move).limit_length(1.0)
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down") * pad_look_speed * delta
	if touch:
		look += touch.take_look() * touch_sensitivity
	rig.look(look)

	var fwd: Vector3 = rig.forward_flat()
	var wish: Vector3 = fwd.cross(Vector3.UP) * input.x + fwd * input.y
	var speed := sprint_speed if Input.is_action_pressed("sprint") else max_speed
	var flat := Vector3(velocity.x, 0, velocity.z)
	# Air control is weak, but a dash's extra speed still bleeds off at the ground rate.
	var a := accel if is_on_floor() or flat.length() > sprint_speed else accel * air_control
	if _dash_left > 0.0:
		flat = _dash_dir * dash_speed  # held flat out, then eases back via accel below
	elif not combat or not combat.grapple.has_dash_momentum():
		flat=flat.move_toward(wish * speed, a * delta)
	velocity = Vector3(flat.x, velocity.y - _gravity * delta, flat.z)
	var dragged: bool = combat != null and combat.grapple.is_dragging()  # the grapple turns the hull then
	if wish.length() > 0.05 and not dragged:  # model front is +Z: face the camera's forward
		rotation.y = rotate_toward(rotation.y, atan2(fwd.x, fwd.z), deg_to_rad(turn_speed_deg) * delta)

	if Input.is_action_just_pressed("jump") and _squat_left < 0.0:
		if is_on_wall() and _wall_jump_ready and _wall_jump_cooldown <= 0.0:
			_wall_jump(get_wall_normal())
		elif is_on_floor() and _dash_cooldown_left <= 0.0:
			_jump_normal = get_floor_normal()
			var downhill := Vector3(_jump_normal.x, 0.0, _jump_normal.z)
			# No stick: dash along camera forward, or off the slope when standing on one.
			_dash_dir = (wish if wish.length() > 0.1 else (downhill if downhill.length() > 0.15 else fwd)).normalized()
			_squat_left = jump_squat_time
			gait.squat = jump_squat_depth
	if _squat_left >= 0.0:
		_squat_left -= delta
		if _squat_left < 0.0:
			gait.squat = 0.0
			velocity.y = jump_velocity
			var slope := Vector3(_jump_normal.x, 0.0, _jump_normal.z)
			if slope.length() > 0.15:
				_dash_dir = (_dash_dir * dash_speed + slope.normalized() * slope_jump_push).normalized()
			_dash_left = dash_time
			_dash_cooldown_left = dash_cooldown
			velocity.x = _dash_dir.x * dash_speed
			velocity.z = _dash_dir.z * dash_speed
			rig.shake(0.15, 0.3)
	var moving := flat.length()>0.5
	if moving and not _was_moving: %MovementSound.play()
	_was_moving=moving
	if combat:
		combat.grapple.steer = wish  # strafe pushes a grapple swing sideways
		combat.step(delta)
	gait.skid = combat != null and combat.grapple.has_dash_momentum()
	move_and_slide()
	if flat.length() > max_speed or _dash_left > 0.0:
		preload("res://scripts/breakable_cover.gd").crush_contacts(self)

	rig.fov_add = sprint_fov_add * clampf((flat.length() - max_speed) / (sprint_speed - max_speed), 0.0, 1.0) - (18.0 if combat and combat.aiming else 0.0)
	var speed_effect: bool = (Input.is_action_pressed("sprint") and flat.length() > max_speed) \
		or _dash_left > 0.0 or (combat != null and combat.grapple.has_dash_momentum())
	_update_speed_blur(delta, speed_effect, Vector2(velocity.x, velocity.z).length())

func _wall_jump(normal: Vector3) -> void:
	var away := Vector3(normal.x, 0.0, normal.z).normalized()
	if away.length_squared() < 0.01: return
	var incoming := Vector3(velocity.x, 0.0, velocity.z)
	if combat and combat.grapple.has_dash_momentum():
		combat.grapple.cancel_hook("WALL JUMP")
	var tangent := incoming - away * incoming.dot(away)
	var reflected := maxf(wall_jump_push, -incoming.dot(away) * 0.8)
	velocity = tangent + away * reflected + Vector3.UP * jump_velocity
	_dash_dir = (tangent + away * reflected).normalized()
	_dash_left = dash_time * 0.6
	_wall_jump_ready = false
	_wall_jump_cooldown = 0.22

func _update_speed_blur(delta: float, active: bool, speed: float) -> void:
	if speed_blur == null: return
	var target := speed_blur_strength * clampf((speed - max_speed * 0.6) / maxf(sprint_speed - max_speed * 0.6, 0.01), 0.0, 1.0) if active else 0.0
	_speed_blur_amount = lerpf(_speed_blur_amount, target, 1.0 - exp(-8.0 * delta))
	speed_blur.visible = _speed_blur_amount > 0.0002
	(speed_blur.material as ShaderMaterial).set_shader_parameter("strength", _speed_blur_amount)

func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled: return
	# Click captures the mouse, Esc frees it. Clicks emulated from touch are ignored (touch has its own look).
	if event is InputEventMouseButton and event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rig.look(event.relative * mouse_sensitivity)

func _puff(at: Vector3) -> void:
	var puff: CPUParticles3D = dust.get_child(_dust_next)
	_dust_next = (_dust_next + 1) % dust.get_child_count()
	puff.global_position = at + Vector3.UP * 0.05
	puff.restart()

func _on_stepped(at: Vector3) -> void:
	_puff(at)
	rig.kick(step_kick)
	if _step_sound_wait>0: return
	_step_sound_wait=0.07
	step_sound.stream = STEP_CLIPS[_step_next]
	_step_next=(_step_next+1)%STEP_CLIPS.size()
	step_sound.volume_db=-2
	step_sound.global_position = at
	step_sound.pitch_scale = randf_range(0.85, 1.1)
	step_sound.play()

func _on_landed(impact: float) -> void:
	for leg in gait.legs:
		_puff(leg.plant)
	rig.kick(clampf(impact * 0.04, 0.1, 0.35))
	step_sound.stream = _land_stream
	step_sound.volume_db=2
	step_sound.global_position = global_position
	step_sound.pitch_scale = randf_range(0.9, 1.05)
	step_sound.play()

## Input map lives here rather than in project.godot so the bindings read as code. ponytail: no rebinding UI.
static func _ensure_actions() -> void:
	var keys := {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE], "sprint": [KEY_SHIFT],
	}
	var axes := {  # [axis, direction]
		"move_forward": [JOY_AXIS_LEFT_Y, -1.0], "move_back": [JOY_AXIS_LEFT_Y, 1.0],
		"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
		"look_up": [JOY_AXIS_RIGHT_Y, -1.0], "look_down": [JOY_AXIS_RIGHT_Y, 1.0],
		"look_left": [JOY_AXIS_RIGHT_X, -1.0], "look_right": [JOY_AXIS_RIGHT_X, 1.0],
	}
	var buttons := {"jump": [JOY_BUTTON_A], "sprint": [JOY_BUTTON_LEFT_STICK, JOY_BUTTON_RIGHT_SHOULDER]}
	for action: String in keys.keys() + axes.keys():
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.2)
		for key: int in keys.get(action, []):
			var k := InputEventKey.new()
			k.physical_keycode = key
			InputMap.action_add_event(action, k)
		if axes.has(action):
			var j := InputEventJoypadMotion.new()
			j.axis = axes[action][0]
			j.axis_value = axes[action][1]
			InputMap.action_add_event(action, j)
		for b: int in buttons.get(action, []):
			var jb := InputEventJoypadButton.new()
			jb.button_index = b
			InputMap.action_add_event(action, jb)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		for action: StringName in InputMap.get_actions():
			Input.action_release(action)
		if combat:
			combat.grapple.release("FOCUS LOST")
			combat.aim_toggle=false
