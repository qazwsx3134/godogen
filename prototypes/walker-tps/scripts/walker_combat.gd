extends Node3D
## Main gun, aim and hull health of the walker; the twin grapple is the Grapple child (grapple.gd) and the
## blades the AutoBlades child. step() is called before the parent's move_and_slide.
signal damaged
signal destroyed
@export var max_health: float = 100.0
@export var mass: float = 8.0
## Autocannon: hold fire. Everything a shot does (flash, barrel kick, camera kick, recoil push,
## shell, sound) happens inside try_fire(), on the trigger frame.
@export var reload_time: float = 0.16
@export var shot_damage: float = 12.0
@export_range(0.0, 5.0) var spread_deg: float = 1.4      # hip fire cone (half angle)
@export_range(0.0, 5.0) var aim_spread_deg: float = 0.5  # while aiming
@export var bullet_speed_min: float = 110.0
@export var bullet_speed_max: float = 135.0
## Magazine: empty (or R / gamepad X) starts reload_magazine_time; firing is locked meanwhile.
@export var magazine_size: int = 30
@export var magazine_reload_time: float = 1.8
@export var barrel_kick: float = 0.32      # m the barrel snaps back
@export var camera_kick_deg: float = 0.7   # view climb per shot, eases back
@export var recoil_push: float = 0.9       # m/s the hull is shoved back per shot
@export var turret_speed: float = 80.0
const Layers = preload("res://scripts/layers.gd")
const Projectile = preload("res://scenes/combat_projectile.tscn")
const Impact = preload("res://scenes/combat_impact.tscn")
var health: float
var reload_left := 0.0
var ammo := 0
var magazine_left := 0.0  # > 0 while swapping magazines
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
var _barrel := 0.0  # current barrel kick (m), decays fast
const Synth = preload("res://addons/proto_kit/synth.gd")
const SHOT_SOUNDS := [preload("res://assets/sound/runtime/cannon_shot.ogg")]

func _ready() -> void:
	health = max_health
	ammo = magazine_size
	assert(turret and cannon and muzzle, "walker model lost Turret/Cannon/Muzzle (renamed in the GLB?)")
	cannon_rest = cannon.position
	_bind("fire",MOUSE_BUTTON_LEFT,-1)
	_bind("aim",MOUSE_BUTTON_RIGHT,-1)
	_bind("hook",0,JOY_BUTTON_LEFT_SHOULDER,KEY_G)
	_bind("aim_toggle",0,JOY_BUTTON_Y,KEY_Q)
	_bind("reload",0,JOY_BUTTON_X,KEY_R)
	for entry: Array in [["fire",JOY_AXIS_TRIGGER_RIGHT],["aim",JOY_AXIS_TRIGGER_LEFT]]:
		var axis := InputEventJoypadMotion.new()
		axis.axis=entry[1]
		axis.axis_value=1.0
		InputMap.action_add_event(entry[0],axis)
	$ShotSound.max_polyphony = 4  # autofire overlaps tails instead of cutting them
	$Shells.landed.connect(_shell_landed)
	add_to_group("combat_feedback")

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
	if magazine_left > 0.0:
		magazine_left -= delta
		if magazine_left <= 0.0:
			magazine_left = 0.0
			ammo = magazine_size
			_reload_sound(0.8)  # magazine seated
	elif Input.is_action_just_pressed("reload") and ammo < magazine_size: start_reload()
	if Input.is_action_just_pressed("aim_toggle"): aim_toggle=not aim_toggle
	aiming=Input.is_action_pressed("aim") or aim_toggle
	var center := camera.get_viewport().get_visible_rect().size * 0.5
	var origin := camera.project_ray_origin(center)
	var end := origin + camera.project_ray_normal(center)*160
	var hit := ray(origin,end)
	aim_point=hit.position if not hit.is_empty() else end
	grapple.step(delta, Input.is_action_just_pressed("hook"), aim_point)
	update_aim(delta)
	var gun_end := muzzle.global_position + muzzle.global_basis.z.normalized()*160
	var gun_hit := ray(muzzle.global_position,gun_end)
	gun_point=gun_hit.position if not gun_hit.is_empty() else gun_end
	if Input.is_action_pressed("fire") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or Input.is_action_pressed("fire") and DisplayServer.is_touchscreen_available():
		try_fire()
	if Input.get_joy_axis(0,JOY_AXIS_TRIGGER_RIGHT)>0.6: try_fire()
	_barrel = lerpf(_barrel, 0.0, 1.0 - exp(-30.0 * delta))
	cannon.position = cannon_rest + Vector3(0, 0, -_barrel)
	$MuzzleFlash.global_transform=muzzle.global_transform.orthonormalized()

func update_aim(delta: float) -> void:
	var local: Vector3 = turret.get_parent().to_local(aim_point)-turret.position
	var yaw := atan2(local.x,local.z)
	if (aiming or Input.is_action_pressed("fire")) and absf(yaw)>deg_to_rad(28) and not grapple.is_dragging():
		var direction := aim_point-body.global_position
		body.rotation.y=rotate_toward(body.rotation.y,atan2(direction.x,direction.z),deg_to_rad(body.turn_speed_deg)*delta)
	local=turret.get_parent().to_local(aim_point)-turret.position
	var yaw_target := atan2(local.x, local.z)
	if grapple.is_dragging():
		# The hull can turn quickly around the tether; keep the gun on the camera target.
		turret.rotation.y = yaw_target
	else:
		turret.rotation.y=rotate_toward(turret.rotation.y,clampf(yaw_target,-PI/6,PI/6),deg_to_rad(turret_speed)*delta)
	var target: Vector3 = cannon.get_parent().to_local(aim_point)-cannon.position
	var pitch := -atan2(target.y,Vector2(target.x,target.z).length())
	cannon.rotation.x=rotate_toward(cannon.rotation.x,clampf(pitch,deg_to_rad(-25),deg_to_rad(15)),deg_to_rad(turret_speed)*delta)

func try_fire() -> bool:
	if health<=0 or reload_left>0 or magazine_left>0 or not body.controls_enabled: return false
	var bullet := Projectile.instantiate() as Node3D
	projectile_parent().add_child(bullet)
	var obstruction := ray(turret.global_position,muzzle.global_position)
	bullet.global_position=muzzle.global_position if obstruction.is_empty() else obstruction.position-muzzle.global_basis.z.normalized()*0.05
	var forward := muzzle.global_basis.z.normalized()
	bullet.direction = _spread(forward, aim_spread_deg if aiming else spread_deg)
	bullet.speed = randf_range(bullet_speed_min, bullet_speed_max)
	bullet.damage = shot_damage
	bullet.team="player"
	bullet.impact_radius=1.0
	bullet.excluded.assign([body.get_rid()])
	reload_left=reload_time
	shot_count+=1
	ammo-=1
	if ammo<=0: start_reload()
	# --- all on the trigger frame: flash, barrel, camera, hull, shell, sound ---
	$MuzzleFlash.global_transform=muzzle.global_transform.orthonormalized()
	$MuzzleFlash.play()
	_barrel = barrel_kick
	cannon.position = cannon_rest + Vector3(0, 0, -_barrel)
	rig.gun_kick(deg_to_rad(camera_kick_deg))
	rig.shake(0.12, 0.3)
	var back := Vector3(-forward.x, 0.0, -forward.z).normalized()
	body.velocity += back * recoil_push
	var shells := get_tree().get_first_node_in_group("debris_shells")
	if shells:
		var side := turret.global_basis.x.normalized()
		shells.spawn(cannon.global_position + Vector3.UP * 0.3, side * randf_range(3.0, 5.0) + Vector3.UP * randf_range(3.0, 4.5) + back * 1.0, 1.0)
	$ShotSound.stream = SHOT_SOUNDS[randi() % SHOT_SOUNDS.size()]
	$ShotSound.pitch_scale = randf_range(0.97, 1.03)  # stays the recording; only a hint of variation
	$ShotSound.volume_db = 3.0 + randf_range(-1.5, 1.5)  # a loud cannon
	$ShotSound.global_position=muzzle.global_position
	$ShotSound.play()
	return true

## A casing hits the floor: a brass clink, quieter for the softer bounces.
func _shell_landed(at: Vector3, speed: float) -> void:
	$ShellSound.global_position = at
	$ShellSound.pitch_scale = randf_range(0.9, 1.25)
	$ShellSound.volume_db = linear_to_db(clampf(speed / 9.0, 0.25, 1.0))
	$ShellSound.play()

func start_reload() -> void:
	if magazine_left > 0.0: return
	magazine_left = magazine_reload_time
	_reload_sound(1.3)  # magazine out

func _reload_sound(pitch: float) -> void:
	$ReloadSound.pitch_scale = pitch
	$ReloadSound.play()

## Random direction inside a cone, uniform over the disc (not clumped at the centre).
func _spread(forward: Vector3, half_angle_deg: float) -> Vector3:
	var r := deg_to_rad(half_angle_deg) * sqrt(randf())
	var a := randf() * TAU
	var side := forward.cross(Vector3.UP if absf(forward.y) < 0.95 else Vector3.RIGHT).normalized()
	var up := side.cross(forward)
	return (forward + (side * cos(a) + up * sin(a)) * tan(r)).normalized()

## Called (via group "combat_feedback") when an enemy dies. strength 1 = a scout, 3 = the Boss:
## the last hit is the biggest: freeze, then shake.
func kill_feedback(strength: float) -> void:
	var time := get_tree().get_first_node_in_group("time_control")
	if time: time.hit_stop(0.08 * strength, true)
	rig.shake(0.35 * strength)

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
