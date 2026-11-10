extends Node3D
## Weapon and two-pin grapple component; called before the parent's move_and_slide.
signal damaged
signal destroyed
@export var max_health: float = 100.0
@export var mass: float = 8.0
@export var reload_time: float = 1.2
@export var turret_speed: float = 80.0
@export var hook_range: float = 45.0
@export var hook_speed: float = 80.0
@export var pull_speed: float = 18.0
@export var hook_cooldown: float = 3.0
@export var pull_acceleration: float = 45.0
@export var release_distance: float = 4.0
@export var overshoot_distance: float = 2.0
@export var brake_deceleration: float = 24.0
const Projectile = preload("res://scenes/combat_projectile.tscn")
const Impact = preload("res://scenes/combat_impact.tscn")
var health: float
var reload_left := 0.0
var cooldown_left := 0.0
var hook_state := "ready"
var hook_message := "READY"
var pins: Array[Dictionary] = []
var elapsed := 0.0
var aiming := false
var aim_toggle := false
var aim_point := Vector3.ZERO
var gun_point := Vector3.ZERO
var shot_count := 0
var _dash_active := false
var _coast_anchor := Vector3.ZERO
var _coast_direction := Vector3.ZERO
var _coast_left := 0.0
@onready var body: CharacterBody3D = get_parent()
@onready var camera: Camera3D = body.get_node("CameraRig/Pitch/Arm/Camera")
@onready var rig: Node3D = body.get_node("CameraRig")
@onready var turret: Node3D = body.get_node("Model").find_child("Turret")
@onready var cannon: Node3D = body.get_node("Model").find_child("Cannon")
@onready var muzzle: Node3D = body.get_node("Model").find_child("Muzzle")
var cannon_rest := Vector3.ZERO

func _ready() -> void:
	health = max_health
	cannon_rest = cannon.position
	_bind("fire",MOUSE_BUTTON_LEFT,-1)
	_bind("aim",MOUSE_BUTTON_RIGHT,-1)
	_bind("hook",0,JOY_BUTTON_LEFT_SHOULDER,KEY_G)
	_bind("aim_toggle",0,JOY_BUTTON_Y,KEY_Q)
	for entry: Array in [["fire",JOY_AXIS_TRIGGER_RIGHT],["aim",JOY_AXIS_TRIGGER_LEFT]]:
		var axis := InputEventJoypadMotion.new()
		axis.axis=entry[1]
		axis.axis_value=1.0
		InputMap.action_add_event(entry[0],axis)
	$ShotSound.stream = preload("res://addons/proto_kit/synth.gd").ramp(150,32,0.3,0.8,0.0,0.6)

func _bind(action: String, mouse: int, joy: int, key: int = 0) -> void:
	if InputMap.has_action(action): return
	InputMap.add_action(action)
	if mouse:
		var e := InputEventMouseButton.new()
		e.button_index=mouse
		InputMap.action_add_event(action,e)
	if joy >= 0:
		var e := InputEventJoypadButton.new()
		e.button_index=joy
		InputMap.action_add_event(action,e)
	if key:
		var e := InputEventKey.new()
		e.physical_keycode=key
		InputMap.action_add_event(action,e)

func ray(from: Vector3, to: Vector3) -> Dictionary:
	return body.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,7,[body.get_rid()]))

func step(delta: float) -> void:
	reload_left=maxf(0,reload_left-delta)
	cooldown_left=maxf(0,cooldown_left-delta)
	if Input.is_action_just_pressed("aim_toggle"): aim_toggle=not aim_toggle
	aiming=Input.is_action_pressed("aim") or aim_toggle
	var center := camera.get_viewport().get_visible_rect().size * 0.5
	var origin := camera.project_ray_origin(center)
	var end := origin + camera.project_ray_normal(center)*160
	var hit := ray(origin,end)
	aim_point=hit.position if not hit.is_empty() else end
	update_aim(delta)
	var gun_end := muzzle.global_position + muzzle.global_basis.z.normalized()*160
	var gun_hit := ray(muzzle.global_position,gun_end)
	gun_point=gun_hit.position if not gun_hit.is_empty() else gun_end
	if Input.is_action_pressed("fire") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or Input.is_action_pressed("fire") and DisplayServer.is_touchscreen_available():
		try_fire()
	if Input.get_joy_axis(0,JOY_AXIS_TRIGGER_RIGHT)>0.6: try_fire()
	if Input.is_action_just_pressed("hook"):
		if hook_state in ["flying","pulling","coasting","braking"]:
			if _dash_active: begin_braking()
			else: cancel_hook("CANCELLED")
		else: launch_hooks(aim_point)
	update_hooks(delta)
	cannon.position = cannon_rest + Vector3(0,0,-0.22 * clampf(reload_left/reload_time,0,1))
	$MuzzleFlash.visible=reload_left > reload_time-0.06
	$MuzzleFlash.global_position=muzzle.global_position

func update_aim(delta: float) -> void:
	var local: Vector3 = turret.get_parent().to_local(aim_point)-turret.position
	var yaw := atan2(local.x,local.z)
	if (aiming or Input.is_action_pressed("fire")) and absf(yaw)>deg_to_rad(28):
		var direction := aim_point-body.global_position
		body.rotation.y=rotate_toward(body.rotation.y,atan2(direction.x,direction.z),deg_to_rad(body.turn_speed_deg)*delta)
	local=turret.get_parent().to_local(aim_point)-turret.position
	turret.rotation.y=rotate_toward(turret.rotation.y,clampf(atan2(local.x,local.z),-PI/6,PI/6),deg_to_rad(turret_speed)*delta)
	var target: Vector3 = cannon.get_parent().to_local(aim_point)-cannon.position
	var pitch := -atan2(target.y,Vector2(target.x,target.z).length())
	cannon.rotation.x=rotate_toward(cannon.rotation.x,clampf(pitch,deg_to_rad(-25),deg_to_rad(15)),deg_to_rad(turret_speed)*delta)

func try_fire() -> bool:
	if health<=0 or reload_left>0 or not body.controls_enabled: return false
	var bullet := Projectile.instantiate() as Node3D
	projectile_parent().add_child(bullet)
	var obstruction := ray(turret.global_position,muzzle.global_position)
	bullet.global_position=muzzle.global_position if obstruction.is_empty() else obstruction.position-muzzle.global_basis.z.normalized()*0.05
	bullet.direction=muzzle.global_basis.z.normalized()
	bullet.team="player"
	bullet.excluded.assign([body.get_rid()])
	reload_left=reload_time
	shot_count+=1
	rig.kick(0.16)
	$ShotSound.global_position=muzzle.global_position
	$ShotSound.play()
	return true

func projectile_parent() -> Node:
	var session := get_tree().get_first_node_in_group("battle_session")
	return session.get_node("Projectiles") if session else body.get_parent()

func apply_damage(amount: float) -> void:
	if health<=0: return
	health=maxf(0,health-amount)
	damaged.emit()
	rig.kick(0.25)
	if health<=0:
		cancel_hook("DISABLED")
		destroyed.emit()

func launch_hooks(target: Vector3) -> bool:
	if cooldown_left>0 or health<=0 or not body.controls_enabled or hook_state in ["flying","pulling","coasting","braking"]: return false
	var toward := target-body.global_position
	if toward.normalized().dot(body.global_basis.z)<0.25:
		hook_message="TARGET IN FRONT"
		return false
	pins.clear()
	for side: int in 2:
		var from: Vector3 = get_node("Launch%d"%side).global_position
		var end := target+camera.global_basis.x*(0.25 if side else -0.25)
		var blocked := ray(body.global_position+Vector3.UP*1.8,from)
		if not blocked.is_empty():
			pins.append({"position":blocked.position,"direction":(end-from).normalized(),"distance":0.0,"anchored":true,"done":true,"target":blocked.collider,"local":(blocked.collider as Node3D).to_local(blocked.position)})
			continue
		pins.append({"position":from,"direction":(end-from).normalized(),"distance":0.0,"anchored":false,"done":false,"target":null,"local":Vector3.ZERO})
	elapsed=0
	hook_state="flying"
	hook_message="LAUNCHING"
	return true

func cancel_hook(message: String = "READY") -> void:
	if _dash_active: body.velocity=Vector3.ZERO
	_dash_active=false
	if hook_state in ["flying","pulling","coasting","braking"]: cooldown_left=hook_cooldown
	hook_state="cooldown" if cooldown_left>0 else "ready"
	hook_message=message
	clear_cables()

func clear_cables() -> void:
	pins.clear()
	for side: int in 2:
		get_node("Cable%d"%side).visible=false
		get_node("Pin%d"%side).visible=false

func has_dash_momentum() -> bool:
	return _dash_active

func begin_coasting(anchor: Vector3) -> void:
	clear_cables()
	_coast_anchor=anchor
	var flat := Vector3(body.velocity.x,0,body.velocity.z)
	_coast_direction=flat.normalized()
	var remaining := maxf(0,(anchor-body.global_position).dot(_coast_direction))
	_coast_left=clampf((remaining+overshoot_distance)/maxf(flat.length(),1.0)+0.25,0.2,1.25)
	hook_state="coasting"
	hook_message="INERTIA / G TO BRAKE"

func begin_braking() -> void:
	clear_cables()
	hook_state="braking"
	hook_message="BRAKING"

func update_inertia(delta: float) -> void:
	if hook_state=="coasting":
		_coast_left-=delta
		var beyond := (body.global_position-_coast_anchor).dot(_coast_direction)
		if beyond>=overshoot_distance or _coast_left<=0 or body.is_on_wall():
			begin_braking()
	if hook_state=="braking":
		var flat := Vector3(body.velocity.x,0,body.velocity.z).move_toward(Vector3.ZERO,brake_deceleration*delta)
		body.velocity.x=flat.x
		body.velocity.z=flat.z
		if flat.length()<0.15: cancel_hook("BRAKED")

func update_hooks(delta: float) -> void:
	if hook_state in ["coasting","braking"]:
		update_inertia(delta)
		return
	if hook_state not in ["flying","pulling"]:
		if cooldown_left<=0:
			hook_state="ready"
			if hook_message not in ["TARGET IN FRONT"]: hook_message="READY"
		return
	elapsed+=delta
	for pin: Dictionary in pins:
		if not pin.done:
			var end: Vector3 = pin.position+pin.direction*hook_speed*delta
			var hit := ray(pin.position,end)
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
				cancel_hook("TARGET LOST")
				return
			pin.position=pin.target.to_global(pin.local)
	if pins[0].done and pins[1].done:
		var anchors: Array[Dictionary] = []
		for pin: Dictionary in pins:
			if pin.anchored: anchors.append(pin)
		if anchors.is_empty():
			cancel_hook("NO ANCHOR")
			return
		hook_state="pulling"
		var pull_target: Node3D = anchors[0].target
		var light: bool = anchors.size()==2 and anchors[1].target==pull_target and pull_target.has_method("grapple_pull") and float(pull_target.mass)<mass
		var destination := Vector3.ZERO
		for pin: Dictionary in anchors: destination+=pin.position
		destination/=anchors.size()
		var to := destination-body.global_position
		if elapsed>2.8:
			if _dash_active: begin_braking()
			else: cancel_hook("RELEASED")
			return
		if to.length()<(3.2 if light else release_distance):
			if _dash_active: begin_coasting(destination)
			else: cancel_hook("RELEASED")
			return
		for pin: Dictionary in anchors:
			var from: Vector3 = get_node("Launch%d"%pins.find(pin)).global_position
			var obstruction := ray(from,pin.position)
			if not obstruction.is_empty() and obstruction.position.distance_to(pin.position)>1.5:
				cancel_hook("ROPE BLOCKED")
				return
		if light:
			hook_message="REELING ENEMY"
			pull_target.grapple_pull((body.global_position-pull_target.global_position).normalized()*pull_speed)
		else:
			hook_message="GRAPPLE DASH"
			_dash_active=true
			body.velocity=body.velocity.move_toward(to.normalized()*pull_speed,pull_acceleration*delta)
			if body.is_on_wall() and elapsed>1.0:
				cancel_hook("BLOCKED")
				return
	for side: int in 2:
		var start: Vector3 = get_node("Launch%d"%side).global_position
		var end: Vector3 = pins[side].position
		var cable: MeshInstance3D = get_node("Cable%d"%side)
		var length := start.distance_to(end)
		cable.visible=length>0.01
		if length>0.01:
			var cable_basis := Basis(Quaternion(Vector3.UP,(end-start).normalized()))
			cable_basis.y*=length # Scale along the rotated cylinder axis, not world Y.
			cable.global_transform=Transform3D(cable_basis,(start+end)*0.5)
		var head: Node3D = get_node("Pin%d"%side)
		head.visible=true
		head.global_position=end
