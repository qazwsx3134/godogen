extends CharacterBody3D

@export var speed := 4.0
@export var run_speed := 7.2
@export var jump_speed := 5.6
@export var mouse_sensitivity := 0.0026
@export var touch_sensitivity := 0.005
@export_range(0.03, 0.25, 0.005) var swing_raise_time := 0.11
@export_range(0.035, 0.25, 0.005) var swing_strike_time := 0.10
@export_range(0.0, 0.15, 0.005) var swing_contact_time := 0.055
@export_range(0.06, 0.35, 0.005) var swing_recover_time := 0.21
@export_range(0.1, 0.6, 0.01) var swing_width := 0.32
@export_range(0.5, 3.0, 0.05) var mining_reach := 2.5
@export_range(0.0, 2.0, 0.05) var camera_kick_scale := 1.0

@onready var eyes: Camera3D = %Eyes
@onready var pickaxe: Node3D = %Pickaxe
@onready var pickaxe_tip: Marker3D = %PickaxeTip
@onready var pickaxe_home := pickaxe.transform
@onready var hand: MeshInstance3D = %Hand
@onready var forearm: MeshInstance3D = %Forearm
@onready var elbow_anchor: Marker3D = %ElbowAnchor
@onready var pack_socket: Marker3D = %PackSocket
@onready var swing_sound: AudioStreamPlayer = %SwingSound
@onready var drill_view: Node3D = %Drill
@onready var drill_tip: Marker3D = drill_view.get_node("DrillTip")
@onready var drill_bit: Node3D = drill_view.get_node("Chuck")
@onready var drill_sound: AudioStreamPlayer = %DrillSound
@onready var footstep_sound: AudioStreamPlayer = %FootstepSound

var walking := true
var touch_move := Vector2.ZERO
var touch_running := false
var jump_requested := false
var mining_power := 1
var using_drill := false
var swing: Tween
var swinging := false
var drilling := false
var drill_clock := 0.0
var step_distance := 0.0
var swing_side := 1.0
var kick_tween: Tween
var swing_hit: Dictionary = {}


func _ready() -> void:
	var motor := drill_sound.stream as AudioStreamWAV
	motor.loop_mode = AudioStreamWAV.LOOP_FORWARD
	motor.loop_end = roundi(motor.get_length() * motor.mix_rate)


func _process(_delta: float) -> void:
	var wrist := pickaxe.transform * hand.position
	var elbow := elbow_anchor.position
	var extension := wrist - elbow
	if extension.length_squared() > 0.81:
		elbow = wrist - extension.normalized() * 0.9
	var arm := wrist - elbow
	var arm_length := maxf(0.001, arm.length())
	forearm.position = elbow + arm * 0.5
	forearm.basis = Basis(Quaternion(Vector3.UP, arm / arm_length)).scaled_local(Vector3(1, arm_length, 1))


func _physics_process(delta: float) -> void:
	var direction := Vector2.ZERO
	var vertical := velocity.y - 14.0 * delta
	if walking:
		direction = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		direction = (direction + touch_move).limit_length()
		if jump_requested and is_on_floor():
			vertical = jump_speed
	jump_requested = false
	var running := touch_running or Input.is_action_pressed("run")
	var pace := run_speed if running else speed
	var horizontal := basis * Vector3(direction.x, 0.0, direction.y) * pace
	velocity = Vector3(horizontal.x, vertical, horizontal.z)
	move_and_slide()
	_update_footsteps(running)


func _update_footsteps(running: bool) -> void:
	if not walking or not is_on_floor():
		step_distance = 0.0
		return
	var traveled := get_position_delta()
	var planar_distance := Vector2(traveled.x, traveled.z).length()
	if is_zero_approx(planar_distance):
		return
	step_distance += planar_distance
	var stride := 1.95 if running else 1.47
	if step_distance >= stride:
		step_distance = fmod(step_distance, stride)
		footstep_sound.pitch_scale = randf_range(0.93, 1.08)
		footstep_sound.play()


func request_jump() -> void:
	if walking:
		jump_requested = true


func look(relative: Vector2, touch: bool) -> void:
	var sensitivity := touch_sensitivity if touch else mouse_sensitivity
	rotate_y(-relative.x * sensitivity)
	eyes.rotation.x = clampf(eyes.rotation.x - relative.y * sensitivity, -1.25, 1.25)


func hit_at(point: Vector2) -> Dictionary:
	var from := eyes.project_ray_origin(point)
	var to := from + eyes.project_ray_normal(point) * 2.5
	var ray := PhysicsRayQueryParameters3D.create(from, to, 6)
	return get_world_3d().direct_space_state.intersect_ray(ray)


func mining_hit() -> Dictionary:
	var from := eyes.global_position
	var to := from - eyes.global_basis.z * (mining_reach * 0.70 if using_drill else mining_reach)
	var ray := PhysicsRayQueryParameters3D.create(from, to, 6)
	return get_world_3d().direct_space_state.intersect_ray(ray)


func settle_pickaxe(clearance: float, delta: float) -> void:
	if swinging or drilling:
		return
	pickaxe.transform = pickaxe.transform.interpolate_with(_rest_pose(clearance), 1.0 - exp(-16.0 * delta))


func _rest_pose(clearance: float) -> Transform3D:
	var tuck := clampf((1.45 - clearance) / 0.90, 0.0, 1.0)
	var rest := pickaxe_home
	if using_drill:
		rest = Transform3D(_drill_basis(), Vector3(0.48, -0.59, -0.83))
	rest.origin += Vector3(-0.13, -0.67, 0.31) * tuck
	return rest


func swing_pickaxe(aim: Callable, on_impact: Callable, clearance: float, heavy := false) -> void:
	if swinging:
		return
	swinging = true
	swing_side = -swing_side
	swing_hit.clear()
	var wrist := Vector3(0.55, -0.42, -0.85)
	var raised := Transform3D(_strike_basis(Vector3(0.69, -0.32, 0.65)), wrist)
	var raised_tip := raised * pickaxe_tip.position
	var rest := _rest_pose(clearance)
	swing = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	swing.tween_property(pickaxe, "transform", raised, swing_raise_time + (0.19 if heavy else 0.0)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	swing.tween_callback(_play_swing)
	swing.tween_method(_move_pickaxe.bind(aim, raised_tip, raised.basis), 0.0, 1.0, swing_strike_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	swing.tween_callback(func():
		if not swing_hit.is_empty():
			on_impact.call(swing_hit)
	)
	swing.tween_method(_hold_pickaxe, 0.0, 1.0, swing_contact_time)
	swing.tween_property(pickaxe, "transform", rest, swing_recover_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	swing.tween_callback(func():
		swing_hit.clear()
		swinging = false
	)


func _play_swing() -> void:
	swing_sound.pitch_scale = randf_range(0.94, 1.12)
	swing_sound.play()


func _move_pickaxe(weight: float, aim: Callable, raised_tip: Vector3, raised_basis: Basis) -> void:
	swing_hit = aim.call()
	var target := Vector3(-0.14, -0.25, -1.06)
	var axis := Vector3(0.24, 0, 0.97)
	if not swing_hit.is_empty():
		target = eyes.to_local(swing_hit.position)
		axis = eyes.global_basis.inverse() * Vector3(swing_hit.normal)
	var tip := raised_tip.lerp(target, weight)
	tip += Vector3(0.10 + swing_side * swing_width * 0.13, 0.10, 0.0) * sin(weight * PI)
	pickaxe.transform = _pose_at_tip(tip, raised_basis.slerp(_strike_basis(axis), weight))


func _strike_basis(axis: Vector3) -> Basis:
	var normal := axis.normalized()
	var handle := Vector3(-0.65, 0.76, 0).slide(normal)
	if handle.length_squared() < 0.06:
		handle = Vector3.UP.slide(normal)
	handle = handle.normalized()
	return Basis(normal, handle, normal.cross(handle))


func _hold_pickaxe(weight: float) -> void:
	if swing_hit.is_empty():
		return
	var position: Vector3 = swing_hit.position
	var normal: Vector3 = swing_hit.normal
	var tip := eyes.to_local(position - normal * 0.022 * weight)
	pickaxe.transform = _pose_at_tip(tip, _strike_basis(eyes.global_basis.inverse() * normal))


func drive_drill(hit: Dictionary, delta: float) -> void:
	drill_clock += delta
	if not drilling:
		drilling = true
		drill_sound.play()
	var loaded := not hit.is_empty()
	var target := _rest_pose(2.5)
	target.origin += Vector3(-0.12, 0.05, -0.12)
	if loaded:
		var nose := eyes.to_local(hit.position)
		var size := clampf((-nose.z - 0.37) / 0.63, 0.40, 1.0)
		target.basis = _drill_basis().scaled_local(Vector3.ONE * size)
		target.origin = nose - target.basis * drill_tip.position
	target.origin.x += sin(drill_clock * 165.0) * (0.014 if loaded else 0.004)
	target.origin.z += cos(drill_clock * 120.0) * (0.018 if loaded else 0.004)
	drill_sound.pitch_scale = 0.87 if loaded else 1.12
	drill_bit.rotate_z(delta * (45.0 if loaded else 70.0))
	pickaxe.transform = pickaxe.transform.interpolate_with(target, 1.0 - exp(-23.0 * delta))


func _drill_basis() -> Basis:
	return Basis.looking_at(Vector3(-0.52, 0.23, -0.82))


func stop_drill() -> void:
	if drilling:
		drilling = false
		drill_sound.stop()


func _pose_at_tip(tip: Vector3, orientation: Basis) -> Transform3D:
	return Transform3D(orientation, tip - orientation * pickaxe_tip.position)


## Jolt the view on impact. Offsets shift the projection only, so aim and the look angle stay put.
func kick(strength: float) -> void:
	if kick_tween:
		kick_tween.kill()
	eyes.v_offset = -0.035 * strength * camera_kick_scale
	eyes.h_offset = randf_range(-0.022, 0.022) * strength * camera_kick_scale
	kick_tween = create_tween().set_parallel()
	kick_tween.tween_property(eyes, "v_offset", 0.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	kick_tween.tween_property(eyes, "h_offset", 0.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func cancel_swing() -> void:
	if swing:
		swing.kill()
	swinging = false
	swing_hit.clear()
	stop_drill()


func equip_mining_tool(drill: bool) -> void:
	cancel_swing()
	using_drill = drill
	mining_power = 1 if drill else 2
	drill_view.visible = drill
	for part in [$Eyes/Pickaxe/WoodenHaft, $Eyes/Pickaxe/Grip, %PickaxeHead]:
		part.visible = not drill
	var head := %PickaxeHead as MeshInstance3D
	var steel := head.material_override.duplicate() as StandardMaterial3D
	steel.albedo_color = Color("b2c9d3")
	steel.metallic = 0.55
	head.material_override = steel
	pickaxe.transform = _rest_pose(2.5)
