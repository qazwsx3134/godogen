extends CharacterBody3D
## Scout walker. Two modes:
## - wander (combat_enabled false, main.tscn's crowd): walk to a random spot near home, pause, repeat.
## - combat (battlefield.tscn): a small state machine, see combat_step.
##     PATROL --sees / hit / ally contact--> CHASE --in range--> AIM --fired--> REPOSITION --> AIM
##     CHASE / AIM --loses sight--> SEARCH (walk to last_seen, look around) --gives up--> PATROL
##   Sight is checked every SENSE_INTERVAL s: a view cone while patrolling or searching (any
##   direction inside close_sense_range), two rays (hull and turret height) so half cover still shows.
##   Shots lead the target (intercept_point) times lead_accuracy, plus aim_spread: the difficulty knobs.
##   Light and heavy scouts are the same script with different exported numbers (battlefield.tscn).
## Each scout has its own RNG seeded from its node name, so runs are repeatable and the global randf is untouched.

signal destroyed(scout: Node)
enum State { PATROL, CHASE, AIM, REPOSITION, SEARCH, REELED, DEAD }
const SENSE_INTERVAL := 0.15
const GUN_CLIPS = [preload("res://assets/sound/runtime/scout_gun_a.ogg"),preload("res://assets/sound/runtime/scout_gun_b.ogg"),preload("res://assets/sound/runtime/scout_gun_c.ogg")]
const Projectile = preload("res://scenes/combat_projectile.tscn")
const Impact = preload("res://scenes/combat_impact.tscn")
## m/s the feet of the baked `walk` cycle travel at (docs/86/enemy/scout/README.md): playback speed = speed / this.
const WALK_ANIM_SPEED := 1.6

@export var combat_enabled := false
@export var max_health: float = 80.0
@export var mass: float = 3.0
@export_group("Senses")
@export var sight_range: float = 65.0
## Half the view cone while patrolling or searching; once engaged the scout tracks all round.
@export var view_half_angle_deg: float = 70.0
## Inside this distance the player is noticed whatever the scout faces (it hears the walker).
@export var close_sense_range: float = 12.0
## Seconds a search spends looking around once it reaches the last sighting.
@export var search_time: float = 5.0
## A patrolling scout answers another scout's sighting this recent (s) and this close (m).
@export var answer_contact_age: float = 3.0
@export var answer_contact_range: float = 80.0
@export_group("Weapon")
@export var attack_range: float = 38.0
## Aiming stops past attack_range + this, so standing on the edge does not flip chase/aim every frame.
@export var aim_exit_margin: float = 6.0
## 0 shoots where the player is, 1 where a steady player will be when the round arrives.
@export var lead_accuracy: float = 0.7
## Random miss (m) around the aim point.
@export var aim_spread: float = 0.6
@export var shot_damage: float = 8.0
@export var shot_speed: float = 36.0
## Telegraph (the red warning) before the first shot of a burst.
@export var windup_time: float = 0.8
@export var burst_count: int = 1
@export var burst_gap: float = 0.12
## After a burst, before the next telegraph.
@export var fire_cooldown: float = 2.5
## Damage multiplier for hits from behind (the round travels the way the scout faces).
@export var rear_multiplier: float = 2.0
@export_group("Movement")
@export var speed: float = 1.6
@export var chase_speed: float = 2.7
@export var turn_speed_deg: float = 110.0
## After a burst, move to its place around the player (or sidestep 6-10 m) instead of standing still.
@export var repositions := true
@export var reposition_time: float = 2.5
@export var wander_radius: float = 10.0
@export var pause_min: float = 0.8
@export var pause_max: float = 2.5

var team := "enemy"
var health: float
var dead := false
var state: State = State.PATROL
var player: CharacterBody3D
var last_seen := Vector3.ZERO
var charge := 0.0
var fire_wait := 1.8
var hit_flash := 0.0
var pull_left := 0.0
var pull_velocity := Vector3.ZERO
var path_wait := 0.0
var age := 0.0
var ai_enabled := true
@onready var agent: NavigationAgent3D = $NavigationAgent

var _gun_next := 0
var _radio_wait := 2.0
var _state_time := 0.0
var _sees := false
var _sense_wait := 0.0
var _search_left := 0.0
var _search_route_left := 0.0
var _search_arrived := false
var _look_wait := 0.0
var _look_yaw := 0.0
var _burst_left := 0
var _burst_wait := 0.0
var _reposition_point := Vector3.ZERO
var _reposition_limit := 0.0
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
	_sense_wait = _rng.randf() * SENSE_INTERVAL  # neighbours look on different frames
	agent.velocity_computed.connect(_on_safe_velocity)
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
	_play_walk(flat)

func _pick_target() -> void:
	var a := _rng.randf() * TAU
	_target = _home + Vector3(cos(a), 0.0, sin(a)) * _rng.randf_range(2.0, wander_radius)
	if combat_enabled and is_inside_tree() and NavigationServer3D.map_get_iteration_id(get_world_3d().navigation_map) > 0:
		_target = NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, _target)

## from_direction: the way the hit travelled (a round's direction), so the scout knows where it came from.
func apply_damage(amount: float, _hit_position: Vector3 = Vector3.ZERO, from_direction: Vector3 = Vector3.ZERO) -> void:
	if dead: return
	if from_direction != Vector3.ZERO and from_direction.normalized().dot(global_basis.z) > 0.5:
		amount *= rear_multiplier
	health=maxf(0,health-amount)
	hit_flash=0.15
	if health<=0:
		_die()
		return
	if combat_enabled and state in [State.PATROL, State.SEARCH]:
		# Shot from somewhere it cannot see: search back along the round's path.
		last_seen = global_position - from_direction.normalized() * 25.0 if from_direction != Vector3.ZERO \
			else (player.global_position if is_instance_valid(player) else global_position)
		_begin_search()

func _die() -> void:
	dead=true
	_enter(State.DEAD)
	collision_layer=0
	collision_mask=0
	_anim.stop()
	$Model.rotation.z=0.8
	$Model.position.y=-0.35
	$Status.visible=false
	$Warning.visible=false
	$HitFlash.visible=false
	var effect := Impact.instantiate() as Node3D
	effect.radius=3.0
	var session := get_tree().get_first_node_in_group("battle_session")
	(session.get_node("Projectiles") if session else get_parent()).add_child(effect)
	effect.global_position=global_position+Vector3.UP
	destroyed.emit(self)
	set_physics_process(false)

func grapple_pull(force: Vector3) -> void:
	if dead: return
	pull_left=0.15
	pull_velocity=force
	charge=0.0
	_burst_left=0
	if is_instance_valid(player): last_seen=player.global_position  # it knows who hooked it

## Clear line of sight to the player's hull or turret (no view cone): also what shoot() checks.
func sees_player() -> bool:
	if not is_instance_valid(player) or not player.controls_enabled: return false
	var from := global_position+Vector3.UP*1.6
	if from.distance_to(player.global_position)>sight_range: return false
	var space := get_world_3d().direct_space_state
	for height: float in [1.3, 2.6]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from,player.global_position+Vector3.UP*height,7,[get_rid()]))
		if not hit.is_empty() and hit.collider==player: return true
	return false

## sees_player plus the view cone, which only applies while not engaged.
func _check_sight() -> bool:
	if not is_instance_valid(player): return false
	var to := player.global_position-global_position
	to.y=0
	if state in [State.PATROL, State.SEARCH] and to.length()>close_sense_range \
			and global_basis.z.dot(to.normalized())<cos(deg_to_rad(view_half_angle_deg)):
		return false
	return sees_player()

## Where to aim so a round fired now at shot_speed meets a target moving at target_velocity;
## the target's own position when no such point exists (it is faster than the round and moving away).
static func intercept_point(shooter: Vector3, target: Vector3, target_velocity: Vector3, shot_speed_value: float) -> Vector3:
	var d := target-shooter
	var a := target_velocity.length_squared()-shot_speed_value*shot_speed_value
	var b := 2.0*d.dot(target_velocity)
	var c := d.length_squared()
	var t := -1.0
	if absf(a)<0.0001:
		if absf(b)>0.0001: t=-c/b
	else:
		var disc := b*b-4.0*a*c
		if disc>=0.0:
			var root := sqrt(disc)
			var t1 := (-b-root)/(2.0*a)
			var t2 := (-b+root)/(2.0*a)
			t = minf(t1,t2) if minf(t1,t2)>0.0 else maxf(t1,t2)
	return target+target_velocity*t if t>0.0 else target

func combat_step(delta: float) -> void:
	age+=delta
	hit_flash=maxf(0,hit_flash-delta)
	$HitFlash.visible=hit_flash>0
	$Warning.visible=false
	if pull_left>0:
		pull_left-=delta
		velocity=pull_velocity
		move_and_slide()
		_enter(State.REELED)
		$Status.text="REELED"
		return
	if not ai_enabled:
		$Status.visible=false
		return
	$Status.visible=true
	_state_time+=delta
	fire_wait=maxf(0,fire_wait-delta)
	_sense_wait-=delta
	if _sense_wait<=0:
		_sense_wait=SENSE_INTERVAL
		_sees=_check_sight()
	var session := get_tree().get_first_node_in_group("battle_session")
	if _sees:
		last_seen=player.global_position
		if session: session.report_contact(last_seen)
		_radio_wait-=delta
		if _radio_wait<=0:
			if session: session.play_radio()
			_radio_wait=7.0+float(abs(hash(name))%3)
	elif state==State.PATROL and session and session.has_method("report_contact") \
			and session.match_time()-session.contact_time<=answer_contact_age \
			and global_position.distance_to(session.contact_position)<=answer_contact_range:
		last_seen=session.contact_position  # a teammate saw the player: go and look
		_begin_search()
	_transition()
	var flat := _act(delta)
	if agent.avoidance_enabled:
		agent.velocity=flat  # moves in _on_safe_velocity once the agent has steered around the others
	else:
		_move(flat, delta)
	$Status.text=("HEAVY" if mass>=8 else "SCOUT")+" %d / %d\n%s"%[health,max_health,State.keys()[state]]

func _move(flat: Vector3, delta: float) -> void:
	velocity=Vector3(flat.x,velocity.y-_gravity*delta,flat.z)
	move_and_slide()
	_play_walk(flat)

## NavigationAgent3D avoidance (scout.tscn): the wanted velocity adjusted so scouts walk around each other.
func _on_safe_velocity(safe: Vector3) -> void:
	if not combat_enabled or dead or pull_left>0 or not ai_enabled: return
	_move(Vector3(safe.x,0,safe.z), get_physics_process_delta_time())


func _enter(next: State) -> void:
	if next==state: return
	state=next
	_state_time=0.0
	path_wait=0.0  # a new goal: ask for a path now
	if next!=State.AIM:
		charge=0.0
		_burst_left=0

func _begin_search() -> void:
	_search_left=search_time
	_search_route_left=12.0
	_search_arrived=false
	_look_wait=0.0
	_enter(State.SEARCH)

func _transition() -> void:
	var d := global_position.distance_to(player.global_position) if is_instance_valid(player) else INF
	match state:
		State.PATROL:
			if _sees: _enter(State.CHASE)
		State.SEARCH:
			if _sees: _enter(State.CHASE)
			elif (_search_arrived and _search_left<=0) or _search_route_left<=0: _enter(State.PATROL)
		State.CHASE:
			if not _sees: _begin_search()
			elif d<attack_range: _enter(State.AIM)
		State.AIM:
			if _burst_left>0: return  # finish the burst
			if not _sees: _begin_search()
			elif d>attack_range+aim_exit_margin: _enter(State.CHASE)
		State.REPOSITION:
			if _state_time>_reposition_limit or (_state_time>0.3 and agent.is_navigation_finished()):
				if _sees: _enter(State.AIM)
				else: _begin_search()
		State.REELED:
			if _sees: _enter(State.CHASE)
			else: _begin_search()

## What the current state does this frame; returns the flat velocity to move with.
func _act(delta: float) -> Vector3:
	match state:
		State.AIM:
			_aim_and_fire(delta)
			return Vector3.ZERO
		State.CHASE:
			return _nav_toward(_chase_goal(),chase_speed,delta)
		State.REPOSITION:
			return _nav_toward(_reposition_point,chase_speed,delta)
		State.SEARCH:
			if not _search_arrived:
				_search_route_left-=delta
				if global_position.distance_to(last_seen)<2.5 or (_state_time>0.5 and agent.is_navigation_finished()):
					_search_arrived=true
				return _nav_toward(last_seen,chase_speed,delta)
			_search_left-=delta
			_look_wait-=delta
			if _look_wait<=0:
				_look_wait=1.5
				_look_yaw=rotation.y+_rng.randf_range(deg_to_rad(60),deg_to_rad(120))*(1.0 if _rng.randf()<0.5 else -1.0)
			rotation.y=rotate_toward(rotation.y,_look_yaw,deg_to_rad(turn_speed_deg)*delta)
			return Vector3.ZERO
		State.PATROL:
			if global_position.distance_to(_target)<2.5 or (age>0.3 and _state_time>0.3 and agent.is_navigation_finished()):
				_pick_target()
				path_wait=0.0
			return _nav_toward(_target,speed,delta)
	return Vector3.ZERO

## Fighting: chasing, aiming or moving between shots (battlefield.gd spreads these around the player).
func is_engaged() -> bool:
	return state in [State.CHASE, State.AIM, State.REPOSITION]

## Chasing heads for this scout's place on a ring around the player, inside its range.
func _chase_goal() -> Vector3:
	var session := get_tree().get_first_node_in_group("battle_session")
	if not session or not session.has_method("slot_for") or not is_instance_valid(player): return last_seen
	var radius := minf(attack_range*0.8, global_position.distance_to(player.global_position))
	return session.slot_for(self, radius)

func _nav_toward(goal: Vector3, move_speed: float, delta: float) -> Vector3:
	path_wait-=delta
	if path_wait<=0:
		agent.target_position=goal
		path_wait=0.45
	if age<=0.25 or NavigationServer3D.map_get_iteration_id(get_world_3d().navigation_map)==0 or agent.is_navigation_finished():
		return Vector3.ZERO
	var direction := agent.get_next_path_position()-global_position
	direction.y=0
	if direction.length()<=0.1:
		return Vector3.ZERO
	var flat := direction.normalized()*move_speed
	rotation.y=rotate_toward(rotation.y,atan2(flat.x,flat.z),deg_to_rad(turn_speed_deg)*delta)
	return flat

func _aim_and_fire(delta: float) -> void:
	var to := player.global_position-global_position
	rotation.y=rotate_toward(rotation.y,atan2(to.x,to.z),deg_to_rad(turn_speed_deg)*delta)
	if _burst_left>0:
		_burst_wait-=delta
		if _burst_wait<=0:
			shoot()
			_burst_left-=1
			_burst_wait=burst_gap
			if _burst_left==0: _after_burst()
		return
	if fire_wait>0 or global_basis.z.dot(to.normalized())<=0.92:
		charge=0
		return
	charge+=delta
	$Warning.visible=true
	if charge>=windup_time:
		charge=0
		shoot()
		_burst_left=burst_count-1
		_burst_wait=burst_gap
		if _burst_left<=0:
			_burst_left=0
			_after_burst()

func _after_burst() -> void:
	fire_wait=fire_cooldown
	if not repositions: return
	# Move toward this scout's place around the player; already there, sidestep instead.
	var session := get_tree().get_first_node_in_group("battle_session")
	var want := global_position
	if session and session.has_method("slot_for"):
		want=session.slot_for(self, global_position.distance_to(player.global_position))
	if want.distance_to(global_position)<4.0:
		var to_player := (player.global_position-global_position).normalized()
		var side := to_player.cross(Vector3.UP)*(1.0 if _rng.randf()<0.5 else -1.0)
		want=global_position+side*_rng.randf_range(6.0,10.0)
	var map := get_world_3d().navigation_map
	_reposition_point = NavigationServer3D.map_get_closest_point(map,want) if NavigationServer3D.map_get_iteration_id(map)>0 else want
	# A sidestep gets reposition_time; walking to a farther place gets the time it needs, up to 8 s.
	_reposition_limit = clampf(global_position.distance_to(_reposition_point)/chase_speed+0.5, reposition_time, 8.0)
	_enter(State.REPOSITION)

func shoot() -> void:
	if not sees_player(): return
	var session := get_tree().get_first_node_in_group("battle_session")
	if not session: return
	var bullet := Projectile.instantiate() as Node3D
	session.get_node("Projectiles").add_child(bullet)
	bullet.global_position=global_position+Vector3.UP*1.65+global_basis.z*0.6
	var target := player.global_position+Vector3.UP*1.1
	var moving := player.velocity
	moving.y*=0.3  # a jump's rise and fall is hard to predict; lead mostly on the ground plane
	var lead := intercept_point(bullet.global_position,target,moving,shot_speed)-target
	var miss := Vector3(_rng.randf_range(-1,1),0,_rng.randf_range(-1,1)).limit_length(1.0)*aim_spread
	miss.y=_rng.randf_range(-0.5,0.5)*aim_spread
	bullet.direction=(target+lead*lead_accuracy+miss-bullet.global_position).normalized()
	bullet.damage=shot_damage
	bullet.speed=shot_speed
	bullet.team="enemy"
	bullet.excluded.assign([get_rid()])
	$GunSound.stream=GUN_CLIPS[_gun_next]
	_gun_next=(_gun_next+1)%GUN_CLIPS.size()
	$GunSound.play()

func _play_walk(flat: Vector3) -> void:
	var moving := flat.length()>0.1
	var want := "walk" if moving else "idle"
	if _anim.current_animation!=want: _anim.play(want,0.2)
	_anim.speed_scale=maxf(flat.length()/WALK_ANIM_SPEED,0.3) if moving else 1.0
