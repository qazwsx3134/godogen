extends Node
## Procedural quadruped walk for the rigid walker model: every foot is planted at a world point and stays there
## (no sliding) until its "home" spot under the body drifts too far; then it and its diagonal partner swing in an
## arc to a new spot (a trot). Two-bone IK bends the hip and knee pivots of the GLB so the ankle reaches the foot.
## Works for strafing, turning in place and slopes, because homes are raycast onto whatever ground is below.
## Faster = shorter steps in time and a lower hull (lower hips reach farther fore and aft). In the air the feet
## follow the body, tucked while rising and reaching down while falling; landing replants all four.
## The hull pitches and rolls with the plane of the four footholds (up to tilt_max_deg) and each planted
## pad lies on its ground. Feet only stand on the terrain layer, never on another walker or a scout.
## While the grapple drags the body faster than any trot (`skid`), the legs brace instead of stepping.
##
## The GLB parts are found by name at runtime (Hull, Leg_FL_Thigh/Shin/Foot ...): the walker model is an imported
## sub-scene, so they cannot be %unique nodes of walker.tscn.

signal stepped(position: Vector3)
## All four feet touched down after being airborne; `impact` is the downward speed (m/s) at touchdown.
signal landed(impact: float)

## A foot steps when its home spot is this far (m) from where it is planted.
@export var step_distance: float = 0.4
## While standing still, feet farther than this from home take one tidy-up step.
@export var settle_distance: float = 0.12
## Swing time at walking pace and at `run_speed`; in between it is interpolated by speed.
@export var step_time: float = 0.28
@export var step_time_run: float = 0.15
@export var run_speed: float = 9.0
@export var step_height: float = 0.4
## Feet land ahead of their home by velocity * step time * lead, so they do not trail behind a moving body.
@export var lead: float = 0.5
## How far (m) the hull rises while a pair is in the air.
@export var bob: float = 0.06
## How far (m) the hull sinks at `run_speed`.
@export var run_crouch: float = 0.3
## How far the hull may tilt with the ground under it, and how quickly it follows.
@export var tilt_max_deg: float = 12.0
@export var tilt_rate: float = 6.0
## How much of the ground's slant a planted pad takes (0 = level with the body, 1 = flat on the ground).
@export var pad_follow: float = 0.8
## Extra hull sink (m) asked for by the player, e.g. the squat before a jump. Eased toward, not snapped.
var squat: float = 0.0
## Set by the player each frame: being dragged by the grapple. The legs brace out and stop stepping.
var skid: bool = false
## Times a planted foot had to lift out of turn because the leg was about to overstretch (the trot broke).
## Stays near zero at every speed the walker can reach on foot; tests read it.
var safety_lifts: int = 0

const SOLE := 0.36  # ankle pivot height above the ground contact (the foot pad)
const LEG_NAMES := ["FL", "BR", "FR", "BL"]  # pairs: FL+BR = group 0, FR+BL = group 1
const AIR_DELAY := 0.08  # seconds off the floor before the legs switch to their airborne pose
const Layers = preload("res://scripts/layers.gd")

class Leg:
	var thigh: Node3D
	var shin: Node3D
	var foot: Node3D
	var group: int
	var hip: Vector3       # thigh pivot in hull space
	var knee_rel: Vector3  # shin pivot in thigh space (rest)
	var ankle_rel: Vector3 # foot pivot in shin space (rest)
	var hinge: Vector3     # knee axis
	var reach: Vector2     # min/max hip-to-ankle distance
	var phi := 0.0         # current knee angle
	var home_local: Vector3  # rest ground contact in model space
	var air_local: Vector3   # contact point (model space) while airborne
	var plant: Vector3     # world ground contact while planted
	var swing_from: Vector3
	var t := -1.0          # swing progress 0..1, -1 = planted
	var target: Vector3    # where the current swing lands (world)
	var normal := Vector3.UP  # ground normal at plant

var legs: Array[Leg] = []
var airborne := false
var _air_time := 0.0
var _body: CharacterBody3D
var _model: Node3D
var _hull: Node3D
var _hull_rest: Vector3
var _sink := 0.0       # current hull sink (m): squat + landing dip, eased
var _fall_speed := 0.0
var _hull_rest_rotation: Vector3
var _tilt := Vector2.ZERO  # current hull pitch (x) and roll (y), radians
var _was_skidding := false

func setup(body: CharacterBody3D, model: Node3D) -> void:
	_body = body
	_model = model
	_hull = model.find_child("Hull") as Node3D
	_hull_rest = _hull.position
	_hull_rest_rotation = _hull.rotation
	for i: int in LEG_NAMES.size():
		var tag: String = LEG_NAMES[i]
		var leg := Leg.new()
		leg.group = i / 2
		leg.thigh = model.find_child("Leg_%s_Thigh" % tag) as Node3D
		leg.shin = model.find_child("Leg_%s_Shin" % tag) as Node3D
		leg.foot = model.find_child("Leg_%s_Foot" % tag) as Node3D
		leg.hip = leg.thigh.position
		leg.knee_rel = leg.shin.position
		leg.ankle_rel = leg.foot.position
		leg.hinge = Vector3(leg.knee_rel.x, 0, leg.knee_rel.z).normalized().cross(Vector3.UP)
		var l1 := leg.knee_rel.length()
		var l2 := leg.ankle_rel.length()
		leg.reach = Vector2(absf(l1 - l2) + 0.05, (l1 + l2) * 0.97)
		var ankle_model: Vector3 = _model.global_transform.affine_inverse() * leg.foot.global_position
		leg.home_local = ankle_model - Vector3.UP * SOLE
		_plant(leg, _model.global_transform * leg.home_local)
		legs.append(leg)

## Puts every foot back under the body, e.g. after the walker was teleported (respawn).
func replant() -> void:
	airborne = false
	_air_time = 0.0
	for leg: Leg in legs:
		leg.t = -1.0
		_plant(leg, _model.global_transform * leg.home_local)

## Ground contact (world) for a leg right now: planted spot or the point in its swing arc.
func contact(leg: Leg) -> Vector3:
	if leg.t < 0.0:
		return leg.plant
	var s := smoothstep(0.0, 1.0, leg.t)
	return leg.swing_from.lerp(leg.target, s) + Vector3.UP * step_height * sin(PI * leg.t)

## Where the sole of the leg's foot actually is (world), for tests and effects.
func sole(leg: Leg) -> Vector3:
	return leg.foot.global_position - _model.global_basis.y * SOLE

## Swing time at the current speed.
func current_step_time() -> float:
	var speed := Vector2(_body.velocity.x, _body.velocity.z).length()
	return lerpf(step_time, step_time_run, clampf(speed / run_speed, 0.0, 1.0))

func _physics_process(delta: float) -> void:
	if _body == null:
		return
	var vel := Vector3(_body.velocity.x, 0, _body.velocity.z)
	var k := clampf(vel.length() / run_speed, 0.0, 1.0)

	_air_time = 0.0 if _body.is_on_floor() else _air_time + delta
	if not _body.is_on_floor():
		_fall_speed = maxf(0.0, -_body.velocity.y)
	if not airborne and not _body.is_on_floor() and (_air_time > AIR_DELAY or _body.velocity.y > 1.0):
		_take_off()
	elif airborne and _body.is_on_floor():
		_land()

	var lifted := 0.0
	if skid and not airborne:
		if not _was_skidding:
			_take_off()  # legs leave their footholds and brace
		_air_pose(delta, true)
	elif airborne:
		_air_pose(delta)
	else:
		if _was_skidding:
			replant()
			_sink = maxf(_sink, 0.2)  # dig in at the end of the drag
		lifted = _walk(delta, vel)
	_was_skidding = skid and not airborne

	var landing := _sink > squat + 0.01  # landing dip springs back faster than a deliberate squat sinks
	_sink = lerpf(_sink, squat, 1.0 - exp(-(9.0 if landing else 14.0) * delta))
	_hull.position = _hull_rest + Vector3.UP * (bob * lifted - run_crouch * k - _sink)
	_tilt_hull(delta)

	for leg: Leg in legs:
		_solve(leg, _hull.global_transform.affine_inverse() * (contact(leg) + _model.global_basis.y * SOLE))
		leg.foot.global_basis = _pad_basis(leg)

## Ground gait; returns how high (0..1) the swinging pair is, for the hull bob.
func _walk(delta: float, vel: Vector3) -> float:
	var st := current_step_time()
	var moving := vel.length() > 0.3
	var homes: Array[Vector3] = []
	for leg: Leg in legs:
		homes.append(_ground(_model.global_transform * leg.home_local + vel * st * lead))

	# Pick a pair to lift: only when the other pair is fully planted.
	var swinging := [false, false]
	for leg: Leg in legs:
		if leg.t >= 0.0:
			swinging[leg.group] = true
	if not swinging[0] and not swinging[1]:
		var limit := step_distance if moving else settle_distance
		var worst := [0.0, 0.0]
		for i: int in legs.size():
			worst[legs[i].group] = maxf(worst[legs[i].group], _flat(homes[i] - legs[i].plant))
		var g: int = 0 if worst[0] >= worst[1] else 1
		if worst[g] > limit:
			_lift(g)

	# Safety: a planted foot about to be stretched past what the leg can reach lifts now, even out of turn
	# (hard starts and sharp turns); otherwise IK clamps and the foot visibly slides. The whole diagonal pair
	# lifts together so the trot rhythm survives.
	var to_hull := _hull.global_transform.affine_inverse()
	for leg: Leg in legs:
		if leg.t < 0.0 and (to_hull * (leg.plant + _model.global_basis.y * SOLE) - leg.hip).length() > leg.reach.y * 0.97:
			safety_lifts += 1
			_lift(leg.group)

	var lifted := 0.0
	for i: int in legs.size():
		var leg := legs[i]
		if leg.t < 0.0:
			continue
		leg.target = homes[i]
		leg.t += delta / st
		lifted = maxf(lifted, sin(PI * minf(leg.t, 1.0)))
		if leg.t >= 1.0:
			leg.t = -1.0
			_plant(leg, leg.target)
			stepped.emit(leg.plant)
	return lifted

func _lift(group: int) -> void:
	for leg: Leg in legs:
		if leg.group == group and leg.t < 0.0:
			leg.t = 0.0
			leg.swing_from = leg.plant

func _take_off() -> void:
	airborne = true
	var to_model := _model.global_transform.affine_inverse()
	for leg: Leg in legs:
		leg.air_local = to_model * contact(leg)
		leg.t = -1.0

## Feet hang under the body: pulled in and up while rising, reaching down while falling. Braced (the
## grapple drag): spread wide and just off the ground.
func _air_pose(delta: float, braced: bool = false) -> void:
	var tuck := clampf(0.15 + _body.velocity.y * 0.07, -0.05, 0.55)
	var blend := 1.0 - exp(-12.0 * delta)
	for leg: Leg in legs:
		var goal := Vector3(leg.home_local.x * 0.85, leg.home_local.y + tuck, leg.home_local.z * 0.85)
		if braced:
			goal = Vector3(leg.home_local.x * 1.1, leg.home_local.y + 0.05, leg.home_local.z * 1.2)
		leg.air_local = leg.air_local.lerp(goal, blend)
		leg.plant = _model.global_transform * leg.air_local

func _land() -> void:
	airborne = false
	for leg: Leg in legs:
		_plant(leg, _model.global_transform * leg.home_local)
	_sink = minf(0.45, squat + _fall_speed * 0.06)
	landed.emit(_fall_speed)
	_fall_speed = 0.0

## Two-bone IK in hull space: knee angle first (so hip->ankle has the right length), then the shortest
## rotation of the thigh that points hip->ankle at the target.
func _solve(leg: Leg, ankle_target: Vector3) -> void:
	var to := ankle_target - leg.hip
	var d := clampf(to.length(), leg.reach.x, leg.reach.y)
	var phi := leg.phi
	for _i: int in 4:  # Newton on |knee + R(phi) ankle| = d, started from last frame's angle
		var f := _span(leg, phi) - d
		var df := (_span(leg, phi + 0.001) - _span(leg, phi)) / 0.001
		if absf(df) < 0.0001:
			break
		phi = clampf(phi - f / df, -1.4, 1.4)
	leg.phi = phi
	var reach_dir := (leg.knee_rel + leg.ankle_rel.rotated(leg.hinge, phi)).normalized()
	leg.thigh.quaternion = Quaternion(reach_dir, to.normalized())
	leg.shin.quaternion = Quaternion(leg.hinge, phi)

func _span(leg: Leg, phi: float) -> float:
	return (leg.knee_rel + leg.ankle_rel.rotated(leg.hinge, phi)).length()

func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()

func _ground(p: Vector3) -> Vector3:
	var hit := _ground_hit(p)
	return hit.position if hit else Vector3(p.x, _body.global_position.y, p.z)

## The terrain straight under p (within 3 m up or down); {} when there is none.
func _ground_hit(p: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p + Vector3.DOWN * 3.0, Layers.TERRAIN)
	query.exclude = [_body.get_rid()]
	return _body.get_world_3d().direct_space_state.intersect_ray(query)

## Puts the leg's foot down at the ground under `p` and remembers that ground's slant.
func _plant(leg: Leg, p: Vector3) -> void:
	var hit := _ground_hit(p)
	leg.plant = hit.position if hit else Vector3(p.x, _body.global_position.y, p.z)
	leg.normal = hit.normal if hit else Vector3.UP

## Hull pitch and roll toward the plane through the four footholds (planted, or where a swing lands).
func _tilt_hull(delta: float) -> void:
	var want := Vector2.ZERO
	if not airborne and not skid:
		var at: Array[Vector3] = []
		for leg: Leg in legs:
			at.append(leg.plant if leg.t < 0.0 else leg.target)
		# LEG_NAMES order: FL, BR, FR, BL
		var fore := (at[0] + at[2]) * 0.5 - (at[1] + at[3]) * 0.5
		var right := (at[2] + at[1]) * 0.5 - (at[0] + at[3]) * 0.5
		var n := right.cross(fore).normalized()
		if n.y < 0.0:
			n = -n
		n = _model.global_basis.inverse() * n
		var limit := deg_to_rad(tilt_max_deg)
		want = Vector2(clampf(atan2(n.z, n.y), -limit, limit), clampf(atan2(-n.x, n.y), -limit, limit))
	_tilt = _tilt.lerp(want, 1.0 - exp(-tilt_rate * delta))
	_hull.rotation = _hull_rest_rotation + Vector3(_tilt.x, 0.0, _tilt.y)

## A planted pad lies on its ground (by pad_follow); a swinging or hanging one stays level with the body.
func _pad_basis(leg: Leg) -> Basis:
	var body_up := _model.global_basis.y
	if leg.t >= 0.0 or airborne or skid or leg.normal.dot(body_up) < 0.5:
		return _model.global_basis
	var up := body_up.slerp(leg.normal, pad_follow).normalized()
	var right := up.cross(_model.global_basis.z).normalized()
	return Basis(right, up, right.cross(up)).orthonormalized()
