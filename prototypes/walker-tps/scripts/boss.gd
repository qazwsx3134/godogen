extends CharacterBody3D
## Ground-crawling Boss on knee legs with a charged head-cannon beam, pillar rain and tail sweep.
## Below phase2_health_ratio it unfolds optical-fibre wings (second form) and adds fibre
## stabs (three strands thrust at locked points) and a slam with one of the articulated wings.
signal destroyed(enemy: Node)
enum State { CHASE, BEAM_CHARGE, BEAM, PILLAR_CHARGE, TAIL_CHARGE, TAIL_SWEEP, PHASE_SHIFT, STAB_CHARGE, STAB, SLAM_CHARGE, SLAM, DEAD }
const AudioMix := preload("res://addons/audio_tuner/mix.gd")

@export var max_health := 600.0
@export var crawl_speed := 2.2
@export var turn_speed_deg := 24.0
@export var attack_interval := 4.0
## Beam: the head cannon tracks the player while energy gathers, freezes its aim for the
## last beam_lock_time (red sight line: dodge now), then fires along the barrel.
@export var beam_charge_time := 2.6
@export var beam_lock_time := 0.55
@export var beam_fire_time := 1.0
@export var cannon_turn_deg := 70.0
## Ground speed of walk-loop at speed_scale 1 (printed by knee_legs.py).
@export var walk_anim_speed := 1.035
@export_range(0.1, 0.9) var phase2_health_ratio := 0.5
@export var phase_shift_time := 1.8
@export var stab_telegraph_time := 0.8
@export var stab_damage := 18.0
@export var slam_telegraph_time := 1.65
@export var slam_radius := 7.0
@export var slam_damage := 30.0
@export_range(0.35, 0.9) var slam_fold_ratio := 0.6
## Death: the hull shudders through a chain of explosions while the legs give way, then one
## last blast; `destroyed` (mission complete) is sent after it.
## Pillar rain: how many fall per attack, the gap between them (s), how far from the player
## they land (m), and how many may stand at once.
@export var pillar_count := 16
@export var pillar_stagger := 0.1
@export var pillar_spread := 14.0
@export var max_pillars := 40
@export var death_time := 3.2
@export var death_blast_interval := 0.22
## The distances below (chase stop, tail reach, slam radius, beam range, blast sizes) were tuned
## with the Boss at this root scale; _k stretches them to the scale it has in the scene.
const TUNED_SCALE := 1.35
const CANNON_PIVOT := Vector3(0.0, 5.91, 0.05)  # model is lowered 1.14 m in boss.tscn
## Strand roots on the wings, in Boss space.
const WING_ROOTS := [Vector3(-6.0, 13.0, -4.0), Vector3(0.0, 15.0, -4.5), Vector3(6.0, 13.0, -4.0)]
# Authored middle-feather tips in their MultiMesh node's local space.
const WING_TIPS := [Vector3(27.63, 16.38, -3.15), Vector3(-22.67, 14.18, -6.72)]
const SLAM_TIME := 1.28
const SLAM_SWING := 0.32
const SLAM_HOLD := 0.28
const SLAM_LOCK := 0.48
const CANNON_LENGTH := 2.62  # distance from the imported Cannon bone to the bore
var health: float
var mass := 100.0
var team := "enemy"
var dead := false
var active := false
var state := State.CHASE
var tail_angle := 0.0
var attacks_fired := 0
var _attack_pitch := 1.0
var _attack_timer := 3.0
var _state_left := 0.0
var _beam_tick := 0.0
var _attack_index := 0
var _tail_hit := false
var _beam_impact := 0.0
## World-space barrel direction, read by boss_tail_modifier.gd.
var cannon_dir := Vector3.FORWARD
var phase := 1
var _step_left := 0.0
var _stab_targets: Array[Vector3] = []
var _stab_hit := false
var _slam_target := Vector3.ZERO
var _slam_side := 1.0
var _slam_hit := false
var _slam_wing: MultiMeshInstance3D
var _slam_rest := Basis.IDENTITY
var _slam_original_material: Material
var _slam_material: ShaderMaterial
var _player: CharacterBody3D
var _anim: AnimationPlayer
var _skeleton: Skeleton3D
var _cannon_bone := -1
var _death_left := 0.0
var _k := 1.0
var _greeted := false
var _voice_wait := 0.0  # s until the Boss may talk again
var _death_blast := 0.0
var _death_tilt := Vector3.ZERO
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
@onready var _model: Node3D = %Model
@onready var _beam: MeshInstance3D = $Beam
@onready var _status: Label3D = $Status
@onready var _charge: Node3D = $Charge
@onready var _wings: Node3D = $Wings
@onready var _strands: Node3D = $Wings/Strands
const Pillar = preload("res://scenes/boss_pillar.tscn")
const Impact = preload("res://scenes/combat_impact.tscn")
const Layers = preload("res://scripts/layers.gd")
const TailModifier = preload("res://scripts/boss_tail_modifier.gd")

func _ready() -> void:
	_k = scale.x / TUNED_SCALE
	health = max_health
	_player = get_tree().get_first_node_in_group("combat_player") as CharacterBody3D
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim:
		# Imported flight clips move the hull up and down; remove only that track.
		var library := AnimationLibrary.new()
		for pair: Array in [["idle", "idle"], ["walk", "crawl"], ["fire", "fire"]]:
			var animation := _anim.get_animation(pair[0]).duplicate(true) as Animation
			for index in range(animation.get_track_count() - 1, -1, -1):
				if animation.track_get_type(index) == Animation.TYPE_POSITION_3D and String(animation.track_get_path(index)).ends_with(":Hull"):
					animation.remove_track(index)
			library.add_animation(pair[1], animation)
		_anim.add_animation_library("ground", library)
		_anim.play("ground/idle")
	_skeleton = _model.find_child("Skeleton3D", true, false) as Skeleton3D
	if _skeleton:
		_cannon_bone = _skeleton.find_bone("Cannon")
		var modifier := TailModifier.new()
		modifier.boss = self
		_skeleton.add_child(modifier)
	_beam.visible = false
	cannon_dir = _facing().z
	_update_status()

func _physics_process(delta: float) -> void:
	if dead:
		if _death_left > 0.0: _death_step(delta)
		return
	velocity.y -= _gravity * delta
	_voice_wait -= delta
	if active and not _greeted:
		_greeted = true
		_say(preload("res://assets/sound/runtime/boss_talk.ogg"))
	if not active: cannon_dir = _facing().z
	elif state == State.CHASE: cannon_dir = _turn_dir(cannon_dir, _facing().z, cannon_turn_deg * delta)
	if not active or not is_instance_valid(_player) or not _player.controls_enabled:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		_crush_cover(delta)
		return
	if state == State.CHASE:
		_chase(delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		_attack_step(delta)
	move_and_slide()
	_crush_cover(delta)
	if _anim and state == State.CHASE:
		var speed := Vector2(velocity.x, velocity.z).length()
		var animation := "ground/crawl" if speed > 0.2 else "ground/idle"
		if _anim.current_animation != animation: _anim.play(animation, 0.15)
		_anim.speed_scale = speed / walk_anim_speed if animation == "ground/crawl" else 1.0
		if animation == "ground/crawl":
			# walk-loop plants a wave of feet twice per cycle: a low, slow thud each time.
			_step_left -= delta * _anim.speed_scale
			if _step_left <= 0.0:
				_step_left = _anim.get_animation("ground/crawl").length * 0.5
				AudioMix.play_varied($StepSound, 0.55, INF, 0.08)

## The hull can sweep through props without standing on top of them.
func _crush_cover(delta: float) -> void:
	var hull: CollisionShape3D = $Body
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = hull.shape
	query.transform = hull.global_transform.translated(velocity * delta + Vector3.DOWN)
	query.collision_mask = Layers.BREAKABLE_COVER
	for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(query, 32):
		var cover: Node3D = hit.collider
		cover.break_cover(cover.global_position)


func _chase(delta: float) -> void:
	var to := _player.global_position - global_position
	to.y = 0.0
	if to.length() > 0.1:
		rotation.y = rotate_toward(rotation.y, atan2(to.x, to.z), deg_to_rad(turn_speed_deg) * delta)
	if to.length() > 30.0 * _k:
		var forward := _facing().z
		var speed := crawl_speed * maxf(0.0, forward.dot(to.normalized()))
		velocity.x = forward.x * speed
		velocity.z = forward.z * speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	_attack_timer -= delta
	if _attack_timer <= 0.0:
		var local := to_local(_player.global_position)
		if local.z < -1.0 and to.length() < 18.0 * _k:
			try_attack("tail")
		else:
			var rotation_list: Array = ["beam", "pillars"] if phase == 1 else ["stab", "beam", "slam", "pillars"]
			try_attack(rotation_list[_attack_index % rotation_list.size()])
			_attack_index += 1

func try_attack(kind: String) -> bool:
	if not active or dead or state != State.CHASE or not is_instance_valid(_player): return false
	if _voice_wait <= 0.0: _say(preload("res://assets/sound/runtime/boss_talk.ogg"), randf_range(0.85, 1.0))
	match kind:
		"beam":
			state = State.BEAM_CHARGE
			_state_left = beam_charge_time
			_charge.visible = true
			_charge.get_node("Gather").emitting = true
			$AttackSound.stream = preload("res://assets/sound/runtime/mech_servo.ogg")
			AudioMix.play($AttackSound, _attack_pitch)
		"pillars":
			state = State.PILLAR_CHARGE
			_state_left = 0.9
			$AttackSound.stream = preload("res://assets/sound/runtime/mech_servo.ogg")
			AudioMix.play($AttackSound, _attack_pitch)
		"tail":
			state = State.TAIL_CHARGE
			_state_left = 0.75
			_tail_hit = false
			$AttackSound.stream = preload("res://assets/sound/runtime/mech_servo.ogg")
			AudioMix.play($AttackSound, _attack_pitch)
		"stab":
			if phase < 2: return false
			state = State.STAB_CHARGE
			_state_left = stab_telegraph_time
			_stab_hit = false
			var side := _player.global_basis.x
			_stab_targets.assign([_player.global_position - side * 3.5, _player.global_position, _player.global_position + side * 3.5])
			$AttackSound.stream = preload("res://assets/sound/runtime/mech_servo.ogg")
			AudioMix.play($AttackSound, _attack_pitch)
		"slam":
			if phase < 2: return false
			state = State.SLAM_CHARGE
			_state_left = slam_telegraph_time
			_slam_hit = false
			_slam_target = _slam_ground_target()
			_slam_side = 1.0 if to_local(_player.global_position).x > 0.0 else -1.0
			_slam_wing = _wings.get_node("Left" if _slam_side > 0 else "Right")
			_slam_rest = _slam_wing.basis
			_slam_original_material = _slam_wing.material_override
			var material := _slam_original_material
			if material == null:
				material = _slam_wing.multimesh.mesh.surface_get_material(0)
			_slam_material = material.duplicate() as ShaderMaterial
			_slam_wing.material_override = _slam_material
			$AttackSound.stream = preload("res://assets/sound/runtime/mech_servo.ogg")
			AudioMix.play($AttackSound, _attack_pitch)
		_:
			return false
	return true

func _attack_step(delta: float) -> void:
	_state_left -= delta
	match state:
		State.BEAM_CHARGE:
			var t := clampf(1.0 - _state_left / beam_charge_time, 0.0, 1.0)
			var locked := _state_left <= beam_lock_time
			if not locked:
				var to := _player.global_position - global_position
				rotation.y = rotate_toward(rotation.y, atan2(to.x, to.z), deg_to_rad(turn_speed_deg) * 0.5 * delta)
				var aim := _player.global_position + Vector3.UP * 1.2 - _cannon_pivot()
				cannon_dir = _turn_dir(cannon_dir, _clamp_aim(aim), cannon_turn_deg * delta)
			_charge.global_position = _muzzle() + cannon_dir * 2.5
			_charge.get_node("Core").scale = Vector3.ONE * lerpf(1.5, 10.0, pow(t, 1.5))
			_charge.get_node("Light").light_energy = 8.0 * t
			if locked: _draw_beam(_beam_end(), 0.07, Color(1.0, 0.1, 0.05))
			else: _beam.visible = false
			if _state_left <= 0.0:
				state = State.BEAM
				_state_left = beam_fire_time
				_beam_tick = 0.0
				_beam_impact = 0.0
				attacks_fired += 1
				_charge.get_node("Gather").emitting = false
				_spawn_impact(_muzzle(), 2.4)
				if _anim:
					_anim.speed_scale = 1.0
					_anim.play("ground/fire", 0.05)
				$AttackSound.stream = preload("res://assets/sound/runtime/explosion.ogg")
				AudioMix.play($AttackSound, _attack_pitch)
		State.BEAM:
			var from := _muzzle()
			var hit := _ray(from, from + cannon_dir * 160.0 * _k)
			var end: Vector3 = hit.position if not hit.is_empty() else from + cannon_dir * 160.0 * _k
			var fade := clampf(_state_left / beam_fire_time, 0.0, 1.0)
			_draw_beam(end, (0.45 + 0.25 * sin(_state_left * 60.0)) * (0.4 + 0.6 * fade), Color(1.0, 0.35, 0.08))
			_charge.global_position = from + cannon_dir * 2.5
			_charge.get_node("Core").scale = Vector3.ONE * 10.0 * fade
			_charge.get_node("Light").light_energy = 8.0 * fade
			_beam_tick -= delta
			if _beam_tick <= 0.0:
				_beam_tick = 0.22
				if not hit.is_empty() and (hit.collider == _player or hit.collider.has_method("break_cover")):
					hit.collider.apply_damage(9.0, hit.position, cannon_dir)
			_beam_impact -= delta
			if _beam_impact <= 0.0 and not hit.is_empty():
				_beam_impact = 0.12
				_spawn_impact(end, 1.0)
			if _state_left <= 0.0: _end_attack()
		State.PILLAR_CHARGE:
			if _state_left <= 0.0:
				_launch_pillars()
				_end_attack()
		State.PHASE_SHIFT:
			var unfold := clampf(1.0 - _state_left / phase_shift_time, 0.0, 1.0)
			_wings.visible = true
			_wings.scale = Vector3.ONE * maxf(0.02, ease(unfold, 0.4))
			if _state_left <= 0.0:
				_wings.scale = Vector3.ONE
				_end_attack()
		State.STAB_CHARGE:
			# Faint sight strands show where the fibres will land; the points are locked.
			for i in 3: _place_strand(_strands.get_node("Stab%d" % i), to_global(WING_ROOTS[i]), _stab_targets[i], 0.35, 0.35)
			if _state_left <= 0.0:
				state = State.STAB
				_state_left = 0.55
				attacks_fired += 1
				$AttackSound.stream = preload("res://assets/sound/runtime/hit_heavy.ogg")
				AudioMix.play($AttackSound, _attack_pitch)
		State.STAB:
			var thrust := clampf((0.55 - _state_left) / 0.1, 0.0, 1.0)
			var retract := clampf(_state_left / 0.3, 0.0, 1.0)
			for i in 3:
				var root: Vector3 = to_global(WING_ROOTS[i])
				var tip := root.lerp(_stab_targets[i] + (_stab_targets[i] - root).normalized() * 3.0, thrust * retract)
				_place_strand(_strands.get_node("Stab%d" % i), root, tip, 1.6, 1.0)
			if thrust >= 1.0 and not _stab_hit:
				_stab_hit = true
				for i in 3:
					_spawn_impact(_stab_targets[i], 1.4)
					var root: Vector3 = to_global(WING_ROOTS[i])
					var p := Geometry3D.get_closest_point_to_segment(_player.global_position + Vector3.UP, root, _stab_targets[i] + (_stab_targets[i] - root).normalized() * 3.0)
					if p.distance_to(_player.global_position + Vector3.UP) < 2.2:
						_player.apply_damage(stab_damage, p, (_stab_targets[i] - root).normalized())
						break
			if _state_left <= 0.0: _end_attack()
		State.SLAM_CHARGE:
			if _state_left > SLAM_LOCK:
				_slam_target = _slam_ground_target()
			var ring: MeshInstance3D = _strands.get_node("SlamRing")
			ring.visible = true
			ring.global_position = _slam_target + Vector3.UP * 0.15
			ring.scale = Vector3.ONE * slam_radius * _k * 2.0
			var preparation := clampf(1.0 - _state_left / maxf(slam_telegraph_time, 0.01), 0.0, 1.0)
			var rise := smoothstep(0.0, 0.48, preparation)
			var windup := smoothstep(0.4, 0.84, preparation)
			var direction := _raised_wing_direction().slerp(_loaded_wing_direction(), windup)
			_pose_slam_wing(direction, rise, lerpf(slam_fold_ratio, _loaded_wing_fold(), windup))
			_slam_material.set_shader_parameter("charge", smoothstep(0.3, 0.89, preparation))
			if _state_left <= 0.0:
				state = State.SLAM
				_state_left = SLAM_TIME
				attacks_fired += 1
		State.SLAM:
			var elapsed := SLAM_TIME - _state_left
			var progress := clampf(elapsed / SLAM_SWING, 0.0, 1.0)
			var down := (_wings.to_local(_slam_target) - _slam_wing.position).normalized()
			var direction := _loaded_wing_direction().slerp(down, progress * progress * progress)
			var retract := smoothstep(SLAM_SWING + SLAM_HOLD, SLAM_TIME, elapsed)
			var flare := 1.0 + smoothstep(0.18, 0.85, progress) * (1.0 - retract) * 0.4
			_pose_slam_wing(direction, 1.0 - retract, lerpf(_loaded_wing_fold(), 1.0, progress), flare)
			_slam_material.set_shader_parameter("charge", 1.0 - smoothstep(0.35, 1.0, progress))
			if progress >= 1.0 and not _slam_hit:
				_hit_slam()
			if _state_left <= 0.0: _end_attack()
		State.TAIL_CHARGE:
			tail_angle = -0.65 * (1.0 - maxf(0.0, _state_left) / 0.75)
			if _state_left <= 0.0:
				state = State.TAIL_SWEEP
				_state_left = 0.75
				attacks_fired += 1
				$AttackSound.stream = preload("res://assets/sound/runtime/mech_land.ogg")
				AudioMix.play($AttackSound, _attack_pitch)
		State.TAIL_SWEEP:
			var progress := clampf(1.0 - _state_left / 0.75, 0.0, 1.0)
			tail_angle = lerpf(-0.65, 0.85, progress)
			if progress >= 0.45 and not _tail_hit:
				_tail_hit = true
				var local := to_local(_player.global_position)
				if local.z < 1.0 and absf(local.y) < 6.0 and Vector2(local.x, local.z).length() < 20.0:
					_player.apply_damage(25.0, _player.global_position, (global_position - _player.global_position).normalized())
			if _state_left <= 0.0: _end_attack()

## Rotation only: the Boss root is scaled up in the scenes (`scale`), so its basis is not unit length.
func _facing() -> Basis:
	return global_basis.orthonormalized()

func _cannon_pivot() -> Vector3:
	if _cannon_bone >= 0:
		return _skeleton.to_global(_skeleton.get_bone_global_pose(_cannon_bone).origin)
	return to_global(CANNON_PIVOT)

func _muzzle() -> Vector3:
	return _cannon_pivot() + cannon_dir * CANNON_LENGTH * global_basis.z.length()

func _beam_end() -> Vector3:
	var from := _muzzle()
	var hit := _ray(from, from + cannon_dir * 160.0 * _k)
	return hit.position if not hit.is_empty() else from + cannon_dir * 160.0 * _k

## Keeps the barrel within the head mount: yaw +-60 deg, pitch -35..+20 deg off the hull.
func _clamp_aim(direction: Vector3) -> Vector3:
	var local := _facing().inverse() * direction.normalized()
	var yaw := clampf(atan2(local.x, local.z), deg_to_rad(-60.0), deg_to_rad(60.0))
	var pitch := clampf(atan2(local.y, Vector2(local.x, local.z).length()), deg_to_rad(-35.0), deg_to_rad(20.0))
	return _facing() * Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))

func _turn_dir(from: Vector3, to: Vector3, max_deg: float) -> Vector3:
	var angle := from.angle_to(to)
	if angle < 0.0001: return to.normalized()
	return from.slerp(to.normalized(), minf(1.0, deg_to_rad(max_deg) / angle)).normalized()

func _hit_slam() -> void:
	_slam_hit = true
	_strands.get_node("SlamRing").visible = false
	var radius := slam_radius * _k
	_spawn_impact(_slam_target + Vector3.UP * 0.18, radius * 0.65, radius)
	$AttackSound.stream = preload("res://assets/sound/runtime/mech_land.ogg")
	AudioMix.play($AttackSound, 0.62 * _attack_pitch, 4.0)
	var offset := _player.global_position - _slam_target
	var distance := Vector2(offset.x, offset.z).length()
	var rig := _player.get_node_or_null("CameraRig")
	var impact_strength := 1.0 - smoothstep(radius * 0.55, radius * 3.5, offset.length())
	if rig and impact_strength > 0.0:
		rig.kick(0.48 * impact_strength * rig.shake_scale)
		rig.shake(0.83 * impact_strength)
	if distance < radius and absf(offset.y) < 4.0 * _k:
		_player.apply_damage(slam_damage, _player.global_position, Vector3(offset.x, 0.4, offset.z).normalized())


func _slam_ground_target() -> Vector3:
	var at := _player.global_position
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 2.0,
		at + Vector3.DOWN * 50.0, Layers.MAP_GROUND)
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		query.collision_mask = Layers.TERRAIN
		hit = space.intersect_ray(query)
	return hit.position if not hit.is_empty() else at


func _raised_wing_direction() -> Vector3:
	return Vector3(_slam_side * 0.6, 0.92, 0.20).normalized()


func _loaded_wing_direction() -> Vector3:
	return Vector3(_slam_side * 0.25, 0.94, -0.62).normalized()


func _loaded_wing_fold() -> float:
	return slam_fold_ratio * 0.8


## Swing the authored fan around its mount and stretch along the middle feather.
func _pose_slam_wing(direction: Vector3, weight: float, extension: float, width: float = 1.0) -> void:
	var rest_tip: Vector3 = _slam_rest * WING_TIPS[0 if _slam_side > 0 else 1]
	var axis := rest_tip.normalized()
	var target_offset := _wings.to_local(_slam_target) - _slam_wing.position
	var span_ratio := target_offset.length() / rest_tip.length() * extension
	var twist := Quaternion.IDENTITY.slerp(Quaternion(axis, direction), weight)
	var scale_frame := Basis(Quaternion(Vector3.UP, axis))
	var stretch := scale_frame * Basis.from_scale(Vector3(width, lerpf(1.0, span_ratio, weight), width)) * scale_frame.inverse()
	_slam_wing.basis = Basis(twist) * stretch * _slam_rest


## Stretches a crossed-plane fibre strand from root to tip (mesh runs 0..1 along +Y).
func _place_strand(strand: MeshInstance3D, root: Vector3, tip: Vector3, width: float, opacity: float) -> void:
	var axis := tip - root
	strand.visible = axis.length() > 0.05 and opacity > 0.01
	if not strand.visible: return
	var y := axis
	var x := y.cross(Vector3.UP if absf(y.normalized().y) < 0.95 else Vector3.RIGHT).normalized() * width
	var z := x.cross(y).normalized() * width
	strand.global_transform = Transform3D(Basis(x, y, z), root)
	(strand.mesh.surface_get_material(0) as ShaderMaterial).set_shader_parameter("opacity", opacity)

func _spawn_impact(at: Vector3, radius: float, ground_wave_radius: float = 0.0) -> void:
	var effect := Impact.instantiate() as Node3D
	effect.radius = radius
	effect.ground_wave_radius = ground_wave_radius
	var session := get_tree().get_first_node_in_group("battle_session")
	(session.get_node("Projectiles") if session else get_parent()).add_child(effect)
	effect.global_position = at

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, Layers.SOLID, [get_rid()]))

func _draw_beam(end: Vector3, radius: float, color: Color) -> void:
	var start := _muzzle()
	var direction := end - start
	if direction.length_squared() < 0.01:
		_beam.visible = false
		return
	var basis := Basis(Quaternion(Vector3.UP, direction.normalized()))
	basis.x *= radius
	basis.y *= direction.length()
	basis.z *= radius
	_beam.global_transform = Transform3D(basis, (start + end) * 0.5)
	var material := _beam.get_active_material(0) as StandardMaterial3D
	material.albedo_color = color
	material.emission = color
	_beam.visible = true

## Pillar rain: pillar_count spikes go up from the back; each lands on a red ring around the
## player (one right on them), staggered so the player has to keep moving. Old pillars past
## max_pillars shatter so the field never fills up.
func _launch_pillars() -> void:
	var session := get_tree().get_first_node_in_group("battle_session")
	if not session: return
	var aim := _player.global_position + _player.velocity * Vector3(1, 0, 1) * 0.8  # where they are heading
	for i in pillar_count:
		var spot := aim if i == 0 else aim + Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * randf_range(3.5, pillar_spread)
		var pillar := Pillar.instantiate() as Node3D
		session.get_node("Projectiles").add_child(pillar)
		pillar.drop(spot, 0.7 + i * pillar_stagger + randf_range(0.0, 0.15))
	var standing := get_tree().get_nodes_in_group("boss_pillars")
	for i in maxi(0, standing.size() - max_pillars): standing[i].shatter()
	_spawn_impact(to_global(Vector3(0.0, 7.0, -3.0)), 2.0)
	attacks_fired += 1
	$AttackSound.stream = preload("res://assets/sound/runtime/scout_gun_burst.ogg")
	_attack_pitch = 0.6
	AudioMix.play($AttackSound, _attack_pitch)

func _end_attack() -> void:
	if is_instance_valid(_slam_wing):
		_slam_wing.basis = _slam_rest
		_slam_wing.material_override = _slam_original_material
		_slam_wing = null
		_slam_material = null
		_slam_original_material = null
	state = State.CHASE
	_attack_timer = attack_interval
	tail_angle = 0.0
	_beam.visible = false
	_charge.visible = false
	_charge.get_node("Gather").emitting = false
	for strand: Node in _strands.get_children(): (strand as Node3D).visible = false

func apply_damage(amount: float, _position: Vector3 = Vector3.ZERO, _direction: Vector3 = Vector3.ZERO) -> void:
	if dead: return
	health = maxf(0.0, health - amount)
	_update_status()
	if health > 0.0: $HitReact.react(_direction, 1.0)
	if phase == 1 and health > 0.0 and health <= max_health * phase2_health_ratio:
		_enter_phase_two()
	if health <= 0.0:
		_begin_death(_direction)

func _begin_death(direction: Vector3) -> void:
	dead = true
	active = false
	_end_attack()  # beam, charge, sight strands and the slam ring all go out with it
	state = State.DEAD
	_status.visible = false
	collision_mask = 0  # the wreck stays solid (shots still spark on it) but no longer moves
	velocity = Vector3.ZERO
	if _anim: _anim.stop()
	get_tree().call_group("combat_feedback", "kill_feedback", 1.5)
	$HitReact.react(direction, 2.0)
	_death_left = death_time
	_death_blast = 0.0
	_death_tilt = Vector3(randf_range(0.12, 0.2), 0.0, randf_range(0.18, 0.28) * (1.0 if randf() < 0.5 else -1.0))
	add_to_group("death_show")
	_say(preload("res://assets/sound/runtime/boss_angry.ogg"), 0.75, true)  # the HUD hides the player's sights while this plays

## One frame of the death show: explosions pop across the hull, the legs buckle (the hull sinks
## and lists), the wings sag; the last frame is the biggest blast of the fight.
func _death_step(delta: float) -> void:
	var before := _death_left
	_death_left = maxf(0.0, _death_left - delta)
	var t := 1.0 - _death_left / death_time
	var sink := delta / death_time  # fraction of the slump this frame
	global_position.y -= 2.4 * sink * scale.y
	rotation += _death_tilt * sink
	_wings.scale = Vector3.ONE * lerpf(1.0, 0.55, t) if _wings.visible else _wings.scale
	_death_blast -= delta
	if _death_blast <= 0.0 and _death_left > 0.3:
		_death_blast = death_blast_interval * randf_range(0.6, 1.3)
		var at := to_global(Vector3(randf_range(-5.0, 5.0), randf_range(3.0, 7.5), randf_range(-7.0, 5.0)))
		_spawn_impact(at, randf_range(3.2, 4.6) * _k)
		$HitReact.react(Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)), 0.6)
		var parts := get_tree().get_first_node_in_group("debris_parts")
		if parts:
			for i in 3: parts.spawn(at, Vector3(randf_range(-8, 8), randf_range(6, 12), randf_range(-8, 8)), randf_range(1.0, 2.0))
		var rig := get_tree().get_first_node_in_group("combat_feedback")
		if rig: rig.rig.shake(0.25, 0.6)
	if before > 0.0 and _death_left <= 0.0: _final_blast()

func _final_blast() -> void:
	get_tree().call_group("combat_feedback", "kill_feedback", 3.0)  # the biggest freeze and shake of the fight
	_wings.visible = false
	remove_from_group("death_show")
	var parts := get_tree().get_first_node_in_group("debris_parts")
	if parts:
		for i in 24: parts.spawn(global_position + Vector3(randf_range(-5, 5), 4.0, randf_range(-6, 6)) * _k, Vector3(randf_range(-12, 12), randf_range(8, 16), randf_range(-12, 12)), randf_range(1.5, 3.0))
	var stains := get_tree().get_first_node_in_group("debris_stains")
	if stains: stains.stamp(global_position, 9.0 * _k)
	_spawn_impact(global_position + Vector3.UP * 4.0 * _k, 6.0 * _k)
	destroyed.emit(self)

func _enter_phase_two() -> void:
	phase = 2
	_end_attack()
	_beam.visible = false
	state = State.PHASE_SHIFT
	_state_left = phase_shift_time
	_attack_index = 0
	_wings.visible = true
	_wings.scale = Vector3.ONE * 0.02
	$AttackSound.stream = preload("res://assets/sound/runtime/explosion.ogg")
	AudioMix.play($AttackSound, _attack_pitch)
	_say(preload("res://assets/sound/runtime/boss_angry.ogg"), 0.9, true)

## Boss voice: talk when it starts an attack (at most every 6 s), roar on the phase shift and death.
func _say(clip: AudioStream, pitch: float = 0.9, force: bool = false) -> void:
	if _voice_wait > 0.0 and not force: return
	$Voice.stream = clip
	AudioMix.play($Voice, pitch)
	_voice_wait = maxf(6.0, clip.get_length() + 1.0)

func _update_status() -> void:
	_status.text = ("BOSS %d / %d" if phase == 1 else "BOSS II %d / %d") % [health, max_health]
