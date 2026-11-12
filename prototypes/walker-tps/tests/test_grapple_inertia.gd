extends "res://addons/proto_kit/test_kit.gd"
const Grapple = preload("res://scripts/grapple.gd")
var walker: CharacterBody3D
var combat: Node
func _init() -> void: _run.call_deferred()
func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var ground := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size=Vector3(80,4,120)
	var collision := CollisionShape3D.new()
	collision.shape=shape
	ground.add_child(collision)
	stage.add_child(ground)
	ground.position=Vector3(0,-2,20)
	walker=load("res://scenes/walker.tscn").instantiate()
	stage.add_child(walker)
	combat=walker.get_node("Combat")
	await _frames(30)
	_expect(combat.grapple.launch_hooks(Vector3(0,0,18)),"terrain grapple launches")
	var anchor_z := 18.0
	var coast := false
	var braking := false
	var top := 0.0
	var brake_speed := 0.0
	var acceleration_speeds: Array[float] = []
	for i: int in 240:
		await _frames(1)
		var speed := Vector2(walker.velocity.x,walker.velocity.z).length()
		top=maxf(top,speed)
		if combat.grapple.state_name()=="pulling" and combat.grapple.pins.size()==2:
			anchor_z=(combat.grapple.pins[0].position.z+combat.grapple.pins[1].position.z)*0.5
			acceleration_speeds.append(speed)
		if combat.grapple.state_name()=="coasting":
			coast=true
			_expect(combat.grapple.pins.is_empty(),"coasting releases rope anchors")
		if combat.grapple.state_name()=="braking" and not braking:
			braking=true
			brake_speed=speed
			_expect(walker.position.z>anchor_z+1.5,"braking begins beyond the anchor")
		if braking and combat.grapple.state_name()=="cooldown": break
	_expect(coast and braking,"pull transitions through coasting and braking")
	_expect(acceleration_speeds.size()>3 and acceleration_speeds[0]<acceleration_speeds[3],"dash accelerates instead of snapping to top speed")
	_expect(top>15 and top<=combat.grapple.pull_speed+0.1,"dash retains capped high speed")
	_expect(walker.position.z>anchor_z+3,"inertia carries walker past anchor")
	_expect(Vector2(walker.velocity.x,walker.velocity.z).length()<0.2,"automatic brake brings walker to rest")
	print("INERTIA anchor_z=%.2f stop_z=%.2f overshoot=%.2f peak=%.2f brake_start=%.2f"%[anchor_z,walker.position.z,walker.position.z-anchor_z,top,brake_speed])
	# Manual release must preserve motion and progressively brake, not zero the speed.
	await reset_walker()
	combat.grapple.launch_hooks(Vector3(0,0,28))
	await _frames(50)
	var before := walker.velocity.length()
	Input.action_press("hook")
	await _frames(1)
	Input.action_release("hook")
	_expect(combat.grapple.state_name()=="braking" and walker.velocity.length()>before*0.7,"G starts progressive early braking")
	var start := walker.position
	await _frames(60)
	_expect(walker.position.distance_to(start)>1,"early brake still has stopping distance")
	_expect(not combat.grapple.has_dash_momentum(),"early brake eventually hands back movement")
	# Hard safety cancellation stays immediate for deaths, round end and map recovery (focus loss now brakes).
	await reset_walker()
	combat.grapple.launch_hooks(Vector3(0,0,28))
	await _frames(50)
	combat.grapple.cancel_hook("OUT OF BOUNDS")
	_expect(walker.velocity==Vector3.ZERO and not combat.grapple.has_dash_momentum(),"safety cancellation clears momentum")
	# A wall beyond the floor anchor must stop the coasting body, never teleport through it.
	await reset_walker()
	var wall := StaticBody3D.new()
	var wall_col := CollisionShape3D.new()
	var wall_shape := BoxShape3D.new()
	wall_shape.size=Vector3(16,10,1)
	wall_col.shape=wall_shape
	wall.add_child(wall_col)
	stage.add_child(wall)
	wall.position=Vector3(0,4,22)
	await _frames(3)
	combat.grapple.launch_hooks(Vector3(0,0,18))
	await _frames(150)
	_expect(walker.position.z<21 and walker.position.z>18,"overshoot is stopped by wall collision")
	_expect(not combat.grapple.has_dash_momentum(),"collision does not leave dash permanently active")
	wall.queue_free()
	var free_swing: float = await _test_swing_drift()
	var steered: float = await _test_swing_drift("move_left")
	print("STEER swept free=%.0f deg, holding the opposite strafe=%.0f deg" % [free_swing, steered])
	_expect(absf(free_swing-steered)>15.0, "strafe input during the drag changes the swing (%.0f vs %.0f deg)" % [free_swing, steered])
	_finish("GRAPPLE_INERTIA")

## Running sideways and hooking ground ahead swings the walker round the anchor (a drift) instead of
## pulling it straight in; letting go keeps the speed, then the brake brings it to rest.
## steer_action: a move action held during the drag ("" = none). Returns the degrees swept round the anchor;
## the full set of checks runs only for the free swing.
func _test_swing_drift(steer_action: String = "") -> float:
	await reset_walker()
	walker.position=Vector3(-22,0.1,-10)
	walker.get_node("Gait").replant()
	await _frames(5)
	Input.action_press("move_right")
	Input.action_press("sprint")
	await _frames(70)
	Input.action_release("move_right")
	Input.action_release("sprint")
	var run_velocity := Vector3(walker.velocity.x,0,walker.velocity.z)
	_expect(run_velocity.length()>6.0, "walker runs sideways before hooking (%.1f m/s)" % run_velocity.length())
	_expect(combat.grapple.launch_hooks(walker.global_position+walker.global_basis.z*15), "hooks ground 15 m ahead")
	if not steer_action.is_empty(): Input.action_press(steer_action)
	var steps: Array[int] = [0]
	var count_steps := func(_at: Vector3) -> void: steps[0]+=1
	var gait: Node = walker.get_node("Gait")
	var anchor := Vector3.INF
	var first_bearing := Vector3.ZERO
	var swept := 0.0
	var last_bearing := Vector3.ZERO
	var worst_slack := -INF
	var max_drift := 0.0
	var release_speed := -1.0
	var dragged_frames := 0
	for i: int in 300:
		await _frames(1)
		if combat.grapple.state_name()=="pulling" and combat.grapple.has_dash_momentum():
			if anchor==Vector3.INF:
				anchor=(combat.grapple.pins[0].position+combat.grapple.pins[1].position)*0.5
				gait.stepped.connect(count_steps)
			dragged_frames+=1
			var bearing := Vector3(walker.global_position.x-anchor.x,0,walker.global_position.z-anchor.z).normalized()
			if last_bearing!=Vector3.ZERO: swept+=rad_to_deg(last_bearing.angle_to(bearing))
			last_bearing=bearing
			if combat.grapple.get("rope_length")!=null:
				worst_slack=maxf(worst_slack, Vector3(walker.global_position-anchor).length()-float(combat.grapple.rope_length))
			var flat := Vector3(walker.velocity.x,0,walker.velocity.z)
			var facing := Vector3(walker.global_basis.z.x,0,walker.global_basis.z.z)
			if flat.length()>2.0: max_drift=maxf(max_drift, rad_to_deg(facing.angle_to(flat)))
		elif anchor!=Vector3.INF and release_speed<0.0:
			release_speed=Vector2(walker.velocity.x,walker.velocity.z).length()
			if gait.stepped.is_connected(count_steps): gait.stepped.disconnect(count_steps)
			await _frames(5)
			var after := Vector2(walker.velocity.x,walker.velocity.z).length()
			_expect(after>=release_speed*0.7, "letting go keeps the momentum (%.1f -> %.1f m/s)" % [release_speed, after])
		elif release_speed>=0.0 and combat.grapple.state_name() in ["cooldown","ready"]:
			break
	if gait.stepped.is_connected(count_steps): gait.stepped.disconnect(count_steps)
	if not steer_action.is_empty():
		Input.action_release(steer_action)
		return swept
	print("SWING swept=%.0f deg drift=%.0f deg slack=%.2f m frames=%d release=%.1f m/s" % [swept, max_drift, worst_slack, dragged_frames, release_speed])
	_expect(dragged_frames>10, "the walker is dragged")
	_expect(swept>45.0, "the drag swings round the anchor instead of pulling straight in (%.0f deg)" % swept)
	_expect(worst_slack<=0.3, "the rope keeps the walker within its length (+%.2f m)" % worst_slack)
	_expect(max_drift>20.0, "the hull faces the anchor while sliding sideways: a drift (%.0f deg)" % max_drift)
	_expect(steps[0]==0, "no steps during the drag (%d)" % steps[0])
	_expect(Vector2(walker.velocity.x,walker.velocity.z).length()<0.2, "the brake brings the walker to rest")
	return swept

func reset_walker() -> void:
	combat.grapple.cancel_hook()
	combat.grapple.cooldown_left=0
	combat.grapple.state=Grapple.Hook.READY
	walker.position=Vector3(0,0.1,0)
	walker.velocity=Vector3.ZERO
	walker.rotation.y=0
	walker.get_node("Gait").replant()
	await _frames(15)
