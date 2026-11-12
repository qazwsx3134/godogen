extends Node3D
## Main gun, aim and hull health of the walker; the twin grapple is the Grapple child (grapple.gd) and the
## blades the AutoBlades child. step() is called before the parent's move_and_slide.
signal damaged
signal destroyed
@export var max_health: float = 100.0
@export var mass: float = 8.0
@export var reload_time: float = 1.2
@export var turret_speed: float = 80.0
const Layers = preload("res://scripts/layers.gd")
const Projectile = preload("res://scenes/combat_projectile.tscn")
const Impact = preload("res://scenes/combat_impact.tscn")
var health: float
var reload_left := 0.0
var aiming := false
var aim_toggle := false
var aim_point := Vector3.ZERO
var gun_point := Vector3.ZERO
var shot_count := 0
@onready var body: CharacterBody3D = get_parent()
@onready var camera: Camera3D = body.get_node("CameraRig/Pitch/Arm/Camera")
@onready var rig: Node3D = body.get_node("CameraRig")
@onready var turret: Node3D = body.get_node("Model").find_child("Turret")
@onready var cannon: Node3D = body.get_node("Model").find_child("Cannon")
@onready var muzzle: Node3D = body.get_node("Model").find_child("Muzzle")
@onready var grapple: Node3D = $Grapple
var cannon_rest := Vector3.ZERO

func _ready() -> void:
	health = max_health
	assert(turret and cannon and muzzle, "walker model lost Turret/Cannon/Muzzle (renamed in the GLB?)")
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
	return body.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,Layers.SOLID,[body.get_rid()]))

func step(delta: float) -> void:
	reload_left=maxf(0,reload_left-delta)
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
	grapple.step(delta, Input.is_action_just_pressed("hook"), aim_point)
	cannon.position = cannon_rest + Vector3(0,0,-0.22 * clampf(reload_left/reload_time,0,1))
	$MuzzleFlash.visible=reload_left > reload_time-0.06
	$MuzzleFlash.global_position=muzzle.global_position

func update_aim(delta: float) -> void:
	var local: Vector3 = turret.get_parent().to_local(aim_point)-turret.position
	var yaw := atan2(local.x,local.z)
	if (aiming or Input.is_action_pressed("fire")) and absf(yaw)>deg_to_rad(28) and not grapple.is_dragging():
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

## hit_position / from_direction: where the hit landed and which way it travelled (for later
## part damage and an incoming-fire marker); unused for now.
func apply_damage(amount: float, _hit_position: Vector3 = Vector3.ZERO, _from_direction: Vector3 = Vector3.ZERO) -> void:
	if health<=0: return
	health=maxf(0,health-amount)
	damaged.emit()
	rig.kick(0.25)
	if health<=0:
		grapple.cancel_hook("DISABLED")
		destroyed.emit()
