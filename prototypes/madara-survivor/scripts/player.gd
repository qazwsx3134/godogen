class_name Player
extends Node3D
## Madara: a billboard sprite with a blob shadow and an x-ray silhouette. Movement, the dash (瞬身), health and the hurt
## flash. The Gunbai and upgrades live elsewhere; main moves this node and asks it for its state.

signal died
signal dashed(from: Vector3, direction: Vector2)
## The Sharingan read a hit and Madara slipped aside, leaving an afterimage where he stood.
signal dodged(from: Vector3, to: Vector3)

@export var base_speed: float = 6.0
@export var base_max_hp: float = 120.0
@export var radius: float = 0.55
## Seconds of invulnerability after a hit.
@export var invuln_time: float = 0.5
@export var steps_per_meter: float = 1.2
@export_group("Dash")
@export var dash_speed: float = 26.0
@export var dash_time: float = 0.16
@export var dash_cooldown: float = 1.1
## Invulnerable for the dash and this long after it.
@export var dash_grace: float = 0.12
@export_group("Sharingan dodge")
## How far a dodge slips aside, how long the afterimage lasts, and the invulnerability after a dodge.
@export var dodge_distance: float = 2.6
@export var ghost_life: float = 0.6
@export var dodge_grace: float = 0.4

@export_group("Poses")
## Atlas frames of Madara's key poses (tools/build_atlas.py lays the art into these cells). With `use_poses`
## off, the base frame is shown throughout (squash, bob and flip still animate it).
@export var use_poses: bool = false
@export var frame_base: int = 0
@export var frame_idle: int = 11
@export var frame_run_a: int = 12
@export var frame_run_b: int = 13
@export var frame_punch: int = 14
@export var frame_kick: int = 15
@export var frame_fan: int = 16
@export var frame_seal: int = 17
## How long a strike pose holds.
@export var pose_time: float = 0.2

var hp: float = 0.0
var max_hp: float = 0.0
var facing: float = 1.0
var dead: bool = false
var dash_ready: float = 0.0

var _invuln: float = 0.0
## Blinking time after a real hit (a dash or dodge is invulnerable without blinking).
var _blink: float = 0.0
var _phase: float = 0.0
var _flash: float = 0.0
var _dash_left: float = 0.0
var _dash_dir := Vector2.RIGHT
var _last_dir := Vector2.RIGHT
var _material: ShaderMaterial
var _xray_material: ShaderMaterial

@onready var _body: MeshInstance3D = %Body
@onready var _xray: MeshInstance3D = %Xray
@onready var _ghosts: Node3D = %Ghosts
@onready var _susanoo: MeshInstance3D = %Susanoo

## Susanoo's scale at stage 1 and how much each stage adds.
@export var susanoo_base_scale: float = 7.5
@export var susanoo_stage_scale: float = 1.4
var _sus_fade: float = 0.0
var _sus_target: float = 0.0

var _pose_frame: int = 0
var _pose_left: float = 0.0
var _moving: bool = false
var _slow_left: float = 0.0
var _slow_factor: float = 1.0
var _ghost_age := PackedFloat32Array()
var _next_ghost: int = 0


func _ready() -> void:
	max_hp = base_max_hp
	hp = max_hp
	_material = _body.material_override as ShaderMaterial
	_xray_material = _xray.material_override as ShaderMaterial
	_susanoo.visible = false
	for ghost: Node in _ghosts.get_children():
		(ghost as MeshInstance3D).visible = false
		_ghost_age.append(99.0)


func ground() -> Vector2:
	return Vector2(position.x, position.z)


func is_dashing() -> bool:
	return _dash_left > 0.0


## Dashes toward `direction` (the last move direction when zero). Returns false while on cooldown.
func dash(direction: Vector2) -> bool:
	if dead or dash_ready > 0.0:
		return false
	_dash_dir = direction.normalized() if direction.length() > 0.1 else _last_dir
	_dash_left = dash_time
	dash_ready = dash_cooldown
	_invuln = maxf(_invuln, dash_time + dash_grace)
	dashed.emit(global_position, _dash_dir)
	return true


## `input` is a ground direction (x right, y toward the camera), length 0..1.
func move(dt: float, input: Vector2, speed_scale: float) -> void:
	dash_ready = maxf(dash_ready - dt, 0.0)
	var v: Vector2
	if _dash_left > 0.0:
		_dash_left -= dt
		v = _dash_dir * dash_speed
	else:
		_slow_left = maxf(_slow_left - dt, 0.0)
		v = input.limit_length(1.0) * base_speed * speed_scale * (_slow_factor if _slow_left > 0.0 else 1.0)
		if input.length() > 0.1:
			_last_dir = input.normalized()
	position += Vector3(v.x, 0.0, v.y) * dt
	_moving = v.length() > 0.3
	_pose_left = maxf(_pose_left - dt, 0.0)
	_phase += v.length() * dt * steps_per_meter * TAU
	_invuln = maxf(_invuln - dt, 0.0)
	_blink = maxf(_blink - dt, 0.0)
	_flash = maxf(_flash - dt * 6.0, 0.0)
	_step_ghosts(dt)
	_sus_fade = move_toward(_sus_fade, _sus_target, dt * 3.0)
	_susanoo.visible = _sus_fade > 0.01
	if _susanoo.visible:
		var material := _susanoo.material_override as ShaderMaterial
		material.set_shader_parameter(&"fade", _sus_fade)
		material.set_shader_parameter(&"facing", facing)
	_apply_look()


## Holds a key pose for a moment (&"punch", &"kick", &"fan", &"seal").
func pose(name: StringName) -> void:
	match name:
		&"punch":
			_pose_frame = frame_punch
		&"kick":
			_pose_frame = frame_kick
		&"fan":
			_pose_frame = frame_fan
		_:
			_pose_frame = frame_seal
	_pose_left = pose_time * (1.6 if name == &"kick" else 1.0)


func current_frame() -> int:
	if not use_poses:
		return frame_base
	if _pose_left > 0.0:
		return _pose_frame
	if _moving or _dash_left > 0.0:
		return frame_run_a if sin(_phase * 0.5) >= 0.0 else frame_run_b
	return frame_idle


## Turns to face a ground direction (the Gunbai's aim) for this frame.
func face(direction: Vector2) -> void:
	if absf(direction.x) > 0.15:
		facing = signf(direction.x)


## Slips `dodge_distance` away from `threat` (sideways to it), leaving a fading afterimage where Madara stood.
func dodge(threat: Vector2, grace: float = -1.0) -> void:
	var from: Vector3 = global_position
	var away: Vector2 = (ground() - threat).normalized()
	if away == Vector2.ZERO:
		away = Vector2.RIGHT.rotated(randf() * TAU)
	var side: Vector2 = away.orthogonal() * (1.0 if randf() < 0.5 else -1.0)
	var slip: Vector2 = (away + side * 0.4).normalized() * dodge_distance
	position += Vector3(slip.x, 0.0, slip.y)
	_invuln = maxf(_invuln, grace if grace > 0.0 else dodge_grace)
	_leave_ghost(from)
	dodged.emit(from, global_position)


## Water jutsu: moves at `factor` speed for `seconds`.
func slow(seconds: float, factor: float) -> void:
	_slow_left = maxf(_slow_left, seconds)
	_slow_factor = factor


## Shows (or fades away) the Susanoo giant behind Madara at this stage.
func show_susanoo(active: bool, stage: int) -> void:
	_sus_target = 1.0 if active else 0.0
	if active:
		_susanoo.scale = Vector3.ONE * (susanoo_base_scale + susanoo_stage_scale * (stage - 1))
		_susanoo.visible = true


func is_invulnerable() -> bool:
	return _invuln > 0.0


func _leave_ghost(at: Vector3) -> void:
	if _ghosts.get_child_count() == 0:
		return
	var ghost := _ghosts.get_child(_next_ghost) as MeshInstance3D
	ghost.global_position = at
	ghost.visible = true
	(ghost.material_override as ShaderMaterial).set_shader_parameter(&"facing", facing)
	(ghost.material_override as ShaderMaterial).set_shader_parameter(&"frame", float(current_frame()))
	_ghost_age[_next_ghost] = 0.0
	_next_ghost = (_next_ghost + 1) % _ghosts.get_child_count()


func _step_ghosts(dt: float) -> void:
	for g: int in _ghost_age.size():
		if _ghost_age[g] >= ghost_life:
			continue
		_ghost_age[g] += dt
		var ghost := _ghosts.get_child(g) as MeshInstance3D
		var t: float = _ghost_age[g] / ghost_life
		ghost.visible = t < 1.0
		(ghost.material_override as ShaderMaterial).set_shader_parameter(&"fade", 1.0 - t)


## Returns true when the hit landed (not inside the invulnerability window).
func take_hit(amount: float) -> bool:
	if dead or _invuln > 0.0 or amount <= 0.0:
		return false
	hp = maxf(hp - amount, 0.0)
	_invuln = invuln_time
	_blink = invuln_time
	_flash = 1.0
	if hp <= 0.0:
		dead = true
		died.emit()
	return true


func heal(amount: float) -> void:
	if not dead:
		hp = minf(hp + amount, max_hp)


func set_max_hp(value: float) -> void:
	hp += value - max_hp
	max_hp = value


func _apply_look() -> void:
	var frame: float = float(current_frame())
	_material.set_shader_parameter(&"frame", frame)
	_xray_material.set_shader_parameter(&"frame", frame)
	(_susanoo.material_override as ShaderMaterial).set_shader_parameter(&"frame", frame)
	_material.set_shader_parameter(&"facing", facing)
	_material.set_shader_parameter(&"phase", _phase)
	_material.set_shader_parameter(&"flash", _flash)
	_xray_material.set_shader_parameter(&"facing", facing)
	# Blinks after a hit only; a dash or a Sharingan dodge is invulnerable without blinking.
	_body.visible = _blink <= 0.0 or fmod(_blink, 0.12) > 0.04
