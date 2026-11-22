extends Node3D

@export var fish_name := ""
@export var appearance := ""
@export var phase := 0.0
@export var swim_span := Vector3(2.1, 0.41, 2.1)
@export var swim_period := 12.0
@export var start_facing_left := false
@export var tail_speed := 7.0
@export var tail_swing := 0.33
@export var marker_drop := 0.4
@export var mouth_tip := 0.46

@onready var _rig: Node3D = %Rig
@onready var _tail: Node3D = %Tail
@onready var _swim_body: MeshInstance3D = %Body
@onready var _near_fin: Node3D = %NearPectoral
@onready var _far_fin: Node3D = %FarPectoral

var _time := 0.0
var _home: Vector3
var _facing := 0.0
var food_target: Node3D
const SWALLOW_TIME := 0.39
var _peck_left := 0.0
var _mouth_open := 0.0
var _pitch := 0.0
var _tail_home: Vector3
var _wave_angle := 0.0
var _turn_speed := 0.0
var _turn_blend := 0.0
var school_slot := -1
var school_time := 0.0


func mouth_position() -> Vector3:
	return _rig.to_global(Vector3(mouth_tip, 0, 0))


func can_bite_food(point: Vector3) -> bool:
	return _peck_left <= 0.0 and _mouth_open > 0.42 and mouth_position().distance_to(point) <= 0.16


func peck() -> void:
	_peck_left = SWALLOW_TIME


func _ready() -> void:
	_home = position
	_facing = PI if start_facing_left else 0.0
	_rig.rotation.y = _facing
	_tail_home = _tail.position
	_wave_angle = phase
	_swim_body.set_instance_shader_parameter("tail_mount", _tail_home.x)


func display_name() -> String:
	return fish_name


func display_traits() -> String:
	return appearance


func set_in_tank(in_tank: bool) -> void:
	visible = in_tank
	process_mode = Node.PROCESS_MODE_INHERIT if in_tank else Node.PROCESS_MODE_DISABLED
	%BodyPick.set_deferred("collision_layer", int(in_tank))
	%TailPick.set_deferred("collision_layer", int(in_tank))


func _process(delta: float) -> void:
	_time += delta
	var angle := _time * TAU / swim_period + phase
	var direction := -1.0 if start_facing_left else 1.0
	var home := _home
	var span := swim_span
	var depth_offset := phase + 0.8
	if school_slot >= 0:
		# Fish share the route clock. Small individual offsets keep the school
		# recognizable while each fish keeps its own tail rhythm and can feed.
		var row := floori(school_slot / 3.0)
		var column := school_slot % 3
		angle = school_time * TAU / 11.8 + float(column) * 0.095
		direction = 1.0
		home = Vector3((column - 1) * 0.55, 1.32 + float(row) * 0.37 +
			float(column % 2) * 0.28, -0.98 - float(row) * 0.24)
		span = Vector3(2.42, 0.29, 1.04)
		depth_offset = 1.24
	var depth_phase := angle * 0.67 + depth_offset
	var target := home + Vector3(
		sin(angle) * span.x * direction,
		sin(angle * 1.7) * span.y,
		sin(depth_phase) * span.z
	)
	var glide := Vector2(cos(angle) * span.x * direction, cos(depth_phase) * 0.67 * span.z)
	var yaw := _facing if glide.length_squared() < 0.008 else atan2(-glide.y, glide.x)
	var pitch := sin(angle * 1.7) * 0.075
	var mouth_target := 0.0
	var chasing := is_instance_valid(food_target)
	if chasing:
		var path := food_target.global_position - global_position
		var distance := path.length()
		yaw = atan2(-path.z, path.x)
		pitch = atan2(path.y, Vector2(path.x, path.z).length())
		var home_scale := global_basis.x.length()
		mouth_target = 1.0 - smoothstep(0.41, 0.82, distance / (home_scale * mouth_tip / 0.46))
		var cruise := lerpf(0.48, 2.53, smoothstep(0.40, 1.40, distance))
		if absf(angle_difference(_facing, yaw)) < 0.6:
			global_position += path.normalized() * minf(cruise * delta, maxf(0.0, distance - mouth_tip * 0.826 * home_scale))
	elif _peck_left > 0.0:
		_peck_left = maxf(0.0, _peck_left - delta)
		var elapsed := SWALLOW_TIME - _peck_left
		yaw = _facing
		pitch = _pitch * 0.75 - sin(PI * clampf(elapsed / 0.26, 0.0, 1.0)) * 0.16
		mouth_target = 1.0 - smoothstep(0.0, 0.10, elapsed)
	else:
		position = position.lerp(target, 1.0 - exp(-delta * 2.7))
	_mouth_open = lerpf(_mouth_open, mouth_target, 1.0 - exp(-delta * 28.0))
	_pitch = lerp_angle(_pitch, pitch, 1.0 - exp(-delta * 12.0))

	# Gradually accelerate into the turn and settle as the heading catches up.
	var turn_error := angle_difference(_facing, yaw)
	var turn_target := clampf(turn_error * 5.0, -4.8, 4.8)
	_turn_speed = move_toward(_turn_speed, turn_target, delta * (23.0 if chasing else 13.0))
	var turn_step := _turn_speed * delta
	if signf(turn_step) == signf(turn_error) and absf(turn_step) >= absf(turn_error):
		_facing = yaw
		_turn_speed = 0.0
	else:
		_facing = wrapf(_facing + turn_step, -PI, PI)
	var turning := smoothstep(0.22, 2.7, absf(_turn_speed))
	_turn_blend = lerpf(_turn_blend, turning, 1.0 - exp(-delta * 7.0))

	# A short push and glide changes the cadence. The bend reaches the tail
	# after the body has already started moving, with a softer kick in turns.
	var push := 0.5 + 0.5 * sin(_time * 1.63 + phase)
	var cadence := lerpf(0.73, 1.18, push) * (1.30 if chasing else 1.0)
	_wave_angle = fposmod(_wave_angle + delta * tail_speed * cadence, TAU)
	var energy := lerpf(0.65, 1.0, push) * (1.24 if chasing else 1.0)
	if _peck_left > 0.0:
		energy *= 0.38
	var wave := sin(_wave_angle) + 0.17 * sin(_wave_angle * 2.0 + 0.5)
	var turn_curve := -signf(_turn_speed) * _turn_blend
	var curve := tail_swing * (0.18 * wave * energy * (1.0 - _turn_blend * 0.38) + turn_curve * 0.29)
	_swim_body.set_instance_shader_parameter("swim_curve", curve)
	_tail.position = _tail_home + Vector3.BACK * curve
	_tail.rotation.y = tail_swing * (sin(_wave_angle - 1.07) * energy * (1.0 - _turn_blend * 0.44)
		+ turn_curve * 0.69)
	_tail.scale.y = lerpf(0.94, 1.035, push)
	var bank := -_turn_speed * 0.057 + wave * 0.025
	_rig.rotation = Vector3(bank, _facing, _pitch)
	_near_fin.rotation.y = 0.20 + sin(_wave_angle * 1.47) * 0.31 * energy
	_far_fin.rotation.y = -0.20 - sin(_wave_angle * 1.47 + 0.36) * 0.31 * energy
