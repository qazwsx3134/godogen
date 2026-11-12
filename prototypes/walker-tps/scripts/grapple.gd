extends Node3D
## Twin grapple of the walker (child of Combat in walker_combat.tscn; Launch0/1, Cable0/1, Pin0/1 are its
## children). Two pins fly from the launchers; when both are done:
##   - both on the same lighter enemy: reel the enemy in (grapple_pull), the walker stays;
##   - otherwise (terrain, heavy enemy, one pin missed): drag the walker toward the anchors.
## A drag is a rope: it starts at the hook distance and only ever shortens to the current distance (it never
## pushes). Speed toward the anchor builds up (pull_acceleration, up to pull_speed); speed across the rope
## is kept, so a walker that was
## moving sideways swings around the anchor, and strafe input (steer) pushes the swing: a drift. The hull
## turns to face the anchor while it slides. The drag lets go release_distance short of the anchor (or after
## max_drag_time / max_swing_deg) and coasts on its momentum (overshoot_distance past the anchor, or along
## the swing), then brakes (brake_deceleration). G during a drag brakes early; G otherwise launches.
## Losing the anchor or the rope mid-drag also brakes; only a round end, death or leaving the map stop dead.
## Combat calls step() before the walker's move_and_slide.

enum Hook { READY, FLYING, PULLING, COASTING, BRAKING, COOLDOWN }

@export var hook_range: float = 45.0
@export var hook_speed: float = 80.0
@export var pull_speed: float = 18.0
@export var hook_cooldown: float = 3.0
@export var pull_acceleration: float = 45.0
@export var release_distance: float = 4.0
@export var overshoot_distance: float = 2.0
@export var brake_deceleration: float = 24.0
@export_group("Swing")
## Strafe input accelerates the swing sideways (m/s^2).
@export var steer_acceleration: float = 16.0
## Horizontal speed cap while swinging (m/s).
@export var swing_max_speed: float = 22.0
## The hull turns toward the anchor this fast during a drag (deg/s); slower = longer drift.
@export var drag_turn_speed_deg: float = 220.0
## A drag ends after this long or after sweeping this far around the anchor.
@export var max_drag_time: float = 4.0
@export var max_swing_deg: float = 200.0

var state: Hook = Hook.READY
var message := "READY"
var cooldown_left := 0.0
var pins: Array[Dictionary] = []
var elapsed := 0.0
var _dash_active := false
var _coast_anchor := Vector3.ZERO
var _coast_direction := Vector3.ZERO
var _coast_left := 0.0
## Current rope length during a drag (m); the walker is kept within it.
var rope_length := 0.0
## Degrees the walker has gone round the anchor during this drag.
var swept_deg := 0.0
## World-space strafe/move wish from the player this frame (set by walker_player.gd).
var steer := Vector3.ZERO
var _last_bearing := Vector3.ZERO
@onready var combat: Node = get_parent()
@onready var body: CharacterBody3D = combat.get_parent()
@onready var camera: Camera3D = body.get_node("CameraRig/Pitch/Arm/Camera")
@onready var _launch: Array[Node3D] = [$Launch0, $Launch1]
@onready var _cable: Array[MeshInstance3D] = [$Cable0, $Cable1]
@onready var _pin: Array[Node3D] = [$Pin0, $Pin1]

## Lower-case name of the state ("pulling", "coasting" ...), for HUD text and tests.
func state_name() -> String:
	return String(Hook.keys()[state]).to_lower()

## Pins out, dragging, or still moving on the drag's momentum.
func is_active() -> bool:
	return state in [Hook.FLYING, Hook.PULLING, Hook.COASTING, Hook.BRAKING]

func has_dash_momentum() -> bool:
	return _dash_active

## Being pulled toward the anchor right now (the grapple turns the hull, not the player).
func is_dragging() -> bool:
	return _dash_active and state==Hook.PULLING

## Ends a grapple but keeps a drag's momentum: brakes instead of stopping dead.
func release(reason: String) -> void:
	if _dash_active:
		begin_braking()
		message=reason
	else:
		cancel_hook(reason)

## Once per physics frame from Combat. `pressed`: G / LB / HOOK this frame, which launches at
## `aim_point`, or brakes / cancels a grapple in progress.
func step(delta: float, pressed: bool, aim_point: Vector3) -> void:
	cooldown_left=maxf(0,cooldown_left-delta)
	if pressed:
		if is_active():
			if _dash_active: begin_braking()
			else: cancel_hook("CANCELLED")
		else:
			launch_hooks(aim_point)
	_update(delta)

func launch_hooks(target: Vector3) -> bool:
	if cooldown_left>0 or combat.health<=0 or not body.controls_enabled or is_active(): return false
	var toward := target-body.global_position
	if toward.normalized().dot(body.global_basis.z)<0.25:
		message="TARGET IN FRONT"
		return false
	pins.clear()
	for side: int in 2:
		var from: Vector3 = _launch[side].global_position
		var end := target+camera.global_basis.x*(0.25 if side else -0.25)
		var blocked: Dictionary = combat.ray(body.global_position+Vector3.UP*1.8,from)
		if not blocked.is_empty():
			pins.append({"position":blocked.position,"direction":(end-from).normalized(),"distance":0.0,"anchored":true,"done":true,"target":blocked.collider,"local":(blocked.collider as Node3D).to_local(blocked.position)})
			continue
		pins.append({"position":from,"direction":(end-from).normalized(),"distance":0.0,"anchored":false,"done":false,"target":null,"local":Vector3.ZERO})
	elapsed=0
	rope_length=0.0
	swept_deg=0.0
	state=Hook.FLYING
	message="LAUNCHING"
	return true

func cancel_hook(reason: String = "READY") -> void:
	if _dash_active: body.velocity=Vector3.ZERO
	_dash_active=false
	if is_active(): cooldown_left=hook_cooldown
	state=Hook.COOLDOWN if cooldown_left>0 else Hook.READY
	message=reason
	clear_cables()

func clear_cables() -> void:
	pins.clear()
	for side: int in 2:
		_cable[side].visible=false
		_pin[side].visible=false

func begin_coasting(anchor: Vector3) -> void:
	clear_cables()
	_coast_anchor=anchor
	var flat := Vector3(body.velocity.x,0,body.velocity.z)
	_coast_direction=flat.normalized()
	var remaining := maxf(0,(anchor-body.global_position).dot(_coast_direction))
	_coast_left=clampf((remaining+overshoot_distance)/maxf(flat.length(),1.0)+0.25,0.2,1.25)
	state=Hook.COASTING
	message="INERTIA / G TO BRAKE"

func begin_braking() -> void:
	clear_cables()
	state=Hook.BRAKING
	message="BRAKING"

func _update_inertia(delta: float) -> void:
	if state==Hook.COASTING:
		_coast_left-=delta
		var beyond := (body.global_position-_coast_anchor).dot(_coast_direction)
		if beyond>=overshoot_distance or _coast_left<=0 or body.is_on_wall():
			begin_braking()
	if state==Hook.BRAKING:
		var flat := Vector3(body.velocity.x,0,body.velocity.z).move_toward(Vector3.ZERO,brake_deceleration*delta)
		body.velocity.x=flat.x
		body.velocity.z=flat.z
		if flat.length()<0.15: cancel_hook("BRAKED")

func _update(delta: float) -> void:
	if state in [Hook.COASTING, Hook.BRAKING]:
		_update_inertia(delta)
		return
	if state not in [Hook.FLYING, Hook.PULLING]:
		if cooldown_left<=0:
			state=Hook.READY
			if message not in ["TARGET IN FRONT"]: message="READY"
		return
	elapsed+=delta
	for pin: Dictionary in pins:
		if not pin.done:
			var end: Vector3 = pin.position+pin.direction*hook_speed*delta
			var hit: Dictionary = combat.ray(pin.position,end)
			pin.distance+=hook_speed*delta
			if not hit.is_empty():
				pin.position=hit.position
				pin.target=hit.collider
				pin.local=(hit.collider as Node3D).to_local(hit.position)
				pin.anchored=true
				pin.done=true
			elif pin.distance>=hook_range:
				pin.done=true
			else: pin.position=end
		elif pin.anchored:
			if not is_instance_valid(pin.target) or pin.target.get("dead")==true:
				release("TARGET LOST")
				return
			pin.position=pin.target.to_global(pin.local)
	if pins[0].done and pins[1].done:
		var anchors: Array[int] = []
		for side: int in 2:
			if pins[side].anchored: anchors.append(side)
		if anchors.is_empty():
			cancel_hook("NO ANCHOR")
			return
		state=Hook.PULLING
		var pull_target: Node3D = pins[anchors[0]].target
		var light: bool = anchors.size()==2 and pins[anchors[1]].target==pull_target and pull_target.has_method("grapple_pull") and float(pull_target.mass)<combat.mass
		var destination := Vector3.ZERO
		for side: int in anchors: destination+=pins[side].position
		destination/=anchors.size()
		var to := destination-body.global_position
		if elapsed>max_drag_time or swept_deg>max_swing_deg:
			release("RELEASED")
			return
		if to.length()<(3.2 if light else release_distance):
			if _dash_active: begin_coasting(destination)
			else: cancel_hook("RELEASED")
			return
		for side: int in anchors:
			var obstruction: Dictionary = combat.ray(_launch[side].global_position,pins[side].position)
			if not obstruction.is_empty() and obstruction.position.distance_to(pins[side].position)>1.5:
				release("ROPE BLOCKED")
				return
		if light:
			message="REELING ENEMY"
			pull_target.grapple_pull((body.global_position-pull_target.global_position).normalized()*pull_speed)
		else:
			message="GRAPPLE DASH"
			if not _dash_active:
				_dash_active=true
				rope_length=to.length()
				_last_bearing=Vector3(-to.x,0,-to.z).normalized()
			_swing(to, delta)
			if body.is_on_wall() and elapsed>1.0:
				release("BLOCKED")
				return
	_draw_cables()

## One frame of the rope drag. The velocity across the rope (horizontal tangent) is kept and steered; the
## rest is pulled toward the anchor as a straight drag would be; the rope then removes any outward speed.
func _swing(to: Vector3, delta: float) -> void:
	var radial := to.normalized()
	var tangent := radial.cross(Vector3.UP)
	tangent = tangent.normalized() if tangent.length()>0.01 else Vector3.ZERO
	var across := body.velocity.dot(tangent)
	var rest := body.velocity-tangent*across
	rest = rest.move_toward(radial*pull_speed, pull_acceleration*delta)
	across += steer.dot(tangent)*steer_acceleration*delta
	var velocity := rest+tangent*across
	var distance := to.length()
	rope_length = minf(rope_length, distance)  # slack is taken in; the rope never pushes
	if distance>rope_length:
		var outward := -velocity.dot(radial)
		if outward>0.0: velocity += radial*outward
		velocity += radial*minf((distance-rope_length)/maxf(delta,0.001), 6.0)
	var flat := Vector2(velocity.x, velocity.z)
	if flat.length()>swing_max_speed:
		flat = flat.limit_length(swing_max_speed)
		velocity = Vector3(flat.x, velocity.y, flat.y)
	body.velocity = velocity
	var bearing := Vector3(-to.x,0,-to.z).normalized()
	if _last_bearing!=Vector3.ZERO and bearing!=Vector3.ZERO:
		swept_deg += rad_to_deg(_last_bearing.angle_to(bearing))
	_last_bearing = bearing
	body.rotation.y = rotate_toward(body.rotation.y, atan2(to.x,to.z), deg_to_rad(drag_turn_speed_deg)*delta)

func _draw_cables() -> void:
	for side: int in 2:
		var start: Vector3 = _launch[side].global_position
		var end: Vector3 = pins[side].position
		var length := start.distance_to(end)
		_cable[side].visible=length>0.01
		if length>0.01:
			var cable_basis := Basis(Quaternion(Vector3.UP,(end-start).normalized()))
			cable_basis.y*=length # Scale along the rotated cylinder axis, not world Y.
			_cable[side].global_transform=Transform3D(cable_basis,(start+end)*0.5)
		_pin[side].visible=true
		_pin[side].global_position=end
