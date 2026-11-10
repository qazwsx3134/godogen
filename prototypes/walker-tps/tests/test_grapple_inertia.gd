extends "res://addons/proto_kit/test_kit.gd"
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
	_expect(combat.launch_hooks(Vector3(0,0,18)),"terrain grapple launches")
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
		if combat.hook_state=="pulling" and combat.pins.size()==2:
			anchor_z=(combat.pins[0].position.z+combat.pins[1].position.z)*0.5
			acceleration_speeds.append(speed)
		if combat.hook_state=="coasting":
			coast=true
			_expect(combat.pins.is_empty(),"coasting releases rope anchors")
		if combat.hook_state=="braking" and not braking:
			braking=true
			brake_speed=speed
			_expect(walker.position.z>anchor_z+1.5,"braking begins beyond the anchor")
		if braking and combat.hook_state=="cooldown": break
	_expect(coast and braking,"pull transitions through coasting and braking")
	_expect(acceleration_speeds.size()>3 and acceleration_speeds[0]<acceleration_speeds[3],"dash accelerates instead of snapping to top speed")
	_expect(top>15 and top<=combat.pull_speed+0.1,"dash retains capped high speed")
	_expect(walker.position.z>anchor_z+3,"inertia carries walker past anchor")
	_expect(Vector2(walker.velocity.x,walker.velocity.z).length()<0.2,"automatic brake brings walker to rest")
	print("INERTIA anchor_z=%.2f stop_z=%.2f overshoot=%.2f peak=%.2f brake_start=%.2f"%[anchor_z,walker.position.z,walker.position.z-anchor_z,top,brake_speed])
	# Manual release must preserve motion and progressively brake, not zero the speed.
	await reset_walker()
	combat.launch_hooks(Vector3(0,0,28))
	await _frames(50)
	var before := walker.velocity.length()
	Input.action_press("hook")
	await _frames(1)
	Input.action_release("hook")
	_expect(combat.hook_state=="braking" and walker.velocity.length()>before*0.7,"G starts progressive early braking")
	var start := walker.position
	await _frames(60)
	_expect(walker.position.distance_to(start)>1,"early brake still has stopping distance")
	_expect(not combat.has_dash_momentum(),"early brake eventually hands back movement")
	# Hard safety cancellation remains immediate for deaths, focus loss, and map recovery.
	await reset_walker()
	combat.launch_hooks(Vector3(0,0,28))
	await _frames(50)
	combat.cancel_hook("OUT OF BOUNDS")
	_expect(walker.velocity==Vector3.ZERO and not combat.has_dash_momentum(),"safety cancellation clears momentum")
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
	combat.launch_hooks(Vector3(0,0,18))
	await _frames(150)
	_expect(walker.position.z<21 and walker.position.z>18,"overshoot is stopped by wall collision")
	_expect(not combat.has_dash_momentum(),"collision does not leave dash permanently active")
	_finish("GRAPPLE_INERTIA")

func reset_walker() -> void:
	combat.cancel_hook()
	combat.cooldown_left=0
	combat.hook_state="ready"
	walker.position=Vector3(0,0.1,0)
	walker.velocity=Vector3.ZERO
	walker.rotation.y=0
	walker.get_node("Gait").replant()
	await _frames(15)
