extends CharacterBody3D
## Placeholder wander AI for the scout crowd: walk to a random spot near home, pause, repeat. It exists so the
## crowd moves and shows its baked walk cycle; real behaviour (spotting the player, attacking) is still to do.
## Each scout has its own RNG seeded from its node name, so runs are repeatable and the global randf is untouched.

signal destroyed(scout: Node)
@export var combat_enabled := false
@export var max_health: float = 80.0
@export var mass: float = 3.0
@export var sight_range: float = 65.0
@export var attack_range: float = 38.0
var team := "enemy"
var health: float
var dead := false
var state := "patrol"
var player: CharacterBody3D
var last_seen := Vector3.ZERO
var memory := 0.0
var charge := 0.0
var fire_wait := 1.8
var hit_flash := 0.0
var pull_left := 0.0
var pull_velocity := Vector3.ZERO
var path_wait := 0.0
var age := 0.0
var _gun_next := 0
var _radio_wait := 2.0
const GUN_CLIPS = [preload("res://assets/sound/runtime/scout_gun_a.ogg"),preload("res://assets/sound/runtime/scout_gun_b.ogg"),preload("res://assets/sound/runtime/scout_gun_c.ogg")]
var ai_enabled := true
@onready var agent: NavigationAgent3D = $NavigationAgent
const Projectile = preload("res://scenes/combat_projectile.tscn")
const Impact = preload("res://scenes/combat_impact.tscn")

@export var speed: float = 1.6
@export var turn_speed_deg: float = 110.0
@export var wander_radius: float = 10.0
@export var pause_min: float = 0.8
@export var pause_max: float = 2.5

## m/s the feet of the baked `walk` cycle travel at (docs/86/enemy/scout/README.md): playback speed = speed / this.
const WALK_ANIM_SPEED := 1.6

var _home: Vector3
var _target: Vector3
var _wait := 0.0
var _rng := RandomNumberGenerator.new()
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _anim: AnimationPlayer

func _ready() -> void:
	health=max_health
	player=get_tree().get_first_node_in_group("combat_player")
	_rng.seed = hash(String(name))
	_home = global_position
	_anim = find_child("AnimationPlayer") as AnimationPlayer
	_anim.play("idle")
	_anim.advance(_rng.randf() * 2.0)  # out of step with its neighbours
	_wait = _rng.randf_range(0.0, pause_max)
	_pick_target()

func _physics_process(delta: float) -> void:
	if combat_enabled:
		combat_step(delta)
		return
	velocity.y -= _gravity * delta
	var flat := Vector3.ZERO
	if _wait > 0.0:
		_wait -= delta
	else:
		var to := _target - global_position
		to.y = 0.0
		if to.length() < 0.6:
			_wait = _rng.randf_range(pause_min, pause_max)
			_pick_target()
		else:
			var dir := to.normalized()
			rotation.y = rotate_toward(rotation.y, atan2(dir.x, dir.z), deg_to_rad(turn_speed_deg) * delta)
			var fwd := global_basis.z  # model front is +Z
			flat = fwd * speed * clampf(fwd.dot(dir), 0.0, 1.0)  # turn on the spot, then walk
	velocity.x = flat.x
	velocity.z = flat.z
	move_and_slide()
	if is_on_wall():
		_pick_target()  # blocked: try somewhere else

	var moving := flat.length() > 0.1
	var want := "walk" if moving else "idle"
	if _anim.current_animation != want:
		_anim.play(want, 0.2)
	_anim.speed_scale = maxf(flat.length() / WALK_ANIM_SPEED, 0.3) if moving else 1.0

func _pick_target() -> void:
	var a := _rng.randf() * TAU
	_target = _home + Vector3(cos(a), 0.0, sin(a)) * _rng.randf_range(2.0, wander_radius)

func apply_damage(amount: float) -> void:
	if dead: return
	health=maxf(0,health-amount)
	hit_flash=0.15
	if health<=0:
		dead=true
		state="dead"
		collision_layer=0
		collision_mask=0
		_anim.stop()
		$Model.rotation.z=0.8
		$Model.position.y=-0.35
		var effect := Impact.instantiate() as Node3D
		effect.radius=3.0
		var session := get_tree().get_first_node_in_group("battle_session")
		(session.get_node("Projectiles") if session else get_parent()).add_child(effect)
		effect.global_position=global_position+Vector3.UP
		destroyed.emit(self)

func grapple_pull(force: Vector3) -> void:
	if dead: return
	pull_left=0.15
	pull_velocity=force
	charge=0.0

func sees_player() -> bool:
	if not is_instance_valid(player) or not player.controls_enabled: return false
	var from := global_position+Vector3.UP*1.6
	var target := player.global_position+Vector3.UP*1.3
	if from.distance_to(target)>sight_range: return false
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,target,7,[get_rid()]))
	return not hit.is_empty() and hit.collider==player

func combat_step(delta: float) -> void:
	age+=delta
	hit_flash=maxf(0,hit_flash-delta)
	$HitFlash.visible=hit_flash>0
	$Warning.visible=false
	$Status.visible=not dead
	if dead:
		$Status.visible=false
		return
	if pull_left>0:
		pull_left-=delta
		velocity=pull_velocity
		move_and_slide()
		state="reeled"
		$Status.text="REELED"
		return
	if not ai_enabled:
		$Status.visible=false
		return
	fire_wait=maxf(0,fire_wait-delta)
	var visible_target := sees_player()
	_radio_wait-=delta
	if visible_target and _radio_wait<=0:
		var session := get_tree().get_first_node_in_group("battle_session")
		if session: session.play_radio()
		_radio_wait=7.0+float(abs(hash(name))%3)
	var goal := _target
	if visible_target:
		last_seen=player.global_position
		memory=4.0
		goal=last_seen
		state="chase"
		if global_position.distance_to(goal)<attack_range: state="aim"
	elif memory>0:
		memory-=delta
		goal=last_seen
		state="search"
	else:
		state="patrol"
		if global_position.distance_to(_target)<2.5: _pick_target()
		goal=_target
	var flat := Vector3.ZERO
	if state=="aim":
		var to := player.global_position-global_position
		rotation.y=rotate_toward(rotation.y,atan2(to.x,to.z),deg_to_rad(turn_speed_deg)*delta)
		if fire_wait<=0 and global_basis.z.dot(to.normalized())>0.92:
			charge+=delta
			$Warning.visible=true
			if charge>=0.8:
				shoot()
				fire_wait=2.5
				charge=0
	else:
		charge=0
		path_wait-=delta
		if path_wait<=0:
			agent.target_position=goal
			path_wait=0.45
		if age>0.25 and NavigationServer3D.map_get_iteration_id(get_world_3d().navigation_map)>0 and not agent.is_navigation_finished():
			var direction := agent.get_next_path_position()-global_position
			direction.y=0
			if direction.length()>0.1:
				flat=direction.normalized()*(2.7 if state=="chase" else speed)
				rotation.y=rotate_toward(rotation.y,atan2(flat.x,flat.z),deg_to_rad(turn_speed_deg)*delta)
	if age>0.3 and state=="patrol" and agent.is_navigation_finished(): _pick_target()
	velocity=Vector3(flat.x,velocity.y-_gravity*delta,flat.z)
	move_and_slide()
	var want := "walk" if flat.length()>0.1 else "idle"
	if _anim.current_animation!=want: _anim.play(want,0.2)
	_anim.speed_scale=maxf(flat.length()/WALK_ANIM_SPEED,0.3) if want=="walk" else 1.0
	$Status.text=("HEAVY" if mass>=8 else "SCOUT")+" %d / %d\n%s"%[health,max_health,state.to_upper()]

func shoot() -> void:
	if not sees_player(): return
	var bullet := Projectile.instantiate() as Node3D
	var session := get_tree().get_first_node_in_group("battle_session")
	if not session:
		bullet.free()
		return
	session.get_node("Projectiles").add_child(bullet)
	bullet.global_position=global_position+Vector3.UP*1.65+global_basis.z*0.6
	bullet.direction=(player.global_position+Vector3.UP*1.1-bullet.global_position).normalized()
	bullet.damage=8.0
	bullet.speed=36.0
	bullet.team="enemy"
	bullet.excluded.assign([get_rid()])
	$GunSound.stream=GUN_CLIPS[_gun_next]
	_gun_next=(_gun_next+1)%GUN_CLIPS.size()
	$GunSound.play()
