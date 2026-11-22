extends "res://addons/proto_kit/test_kit.gd"
var stage: Node3D
var walker: CharacterBody3D

func _init() -> void: _run.call_deferred()

func _box(at: Vector3, size: Vector3, pitch := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	stage.add_child(body)
	body.position = at
	body.rotation.x = pitch
	return body

func _run() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	_box(Vector3(0, -2, 0), Vector3(100, 4, 200))
	_box(Vector3(0, 4, 50), Vector3(20, 8, 1))
	_box(Vector3(100, -0.5, 0), Vector3(40, 1, 40), deg_to_rad(-12.0))
	walker = (load("res://scenes/walker.tscn") as PackedScene).instantiate() as CharacterBody3D
	stage.add_child(walker)
	await _frames(30)
	var combat: Node = walker.get_node("Combat")
	var cannon: Node3D = walker.get_node("Model").find_child("Cannon")
	_expect(cannon.scale.x > 1.7 and cannon.scale.y > 1.7, "larger cannon is saved in the scene")
	_expect(combat.SHOT_SOUNDS.all(func(st: AudioStream) -> bool: return st.resource_path.begins_with("res://assets/sound/runtime/")), "cannon uses the provided audio (picked per shot)")
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(110)
	var speed := Vector2(walker.velocity.x, walker.velocity.z).length()
	_expect(speed > 11.8, "boost reaches the faster sprint speed")
	var blur: ColorRect = walker.get_node("SpeedBlur/Screen")
	_expect(blur.visible and blur.material.get_shader_parameter("strength") > 0.035, "moving boost enables speed blur")
	Input.action_release("move_forward")
	Input.action_release("sprint")
	await _frames(90)
	_expect(not blur.visible, "speed blur fades away after boosting")
	# Jump is a dash: a low, fast burst along the camera forward, then back to running speed.
	walker.velocity = Vector3.ZERO
	await _frames(10)
	var y0 := walker.global_position.y
	var z0 := walker.global_position.z
	var peak := y0
	var top_speed := 0.0
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	for i in 60:
		await _frames(1)
		peak = maxf(peak, walker.global_position.y)
		top_speed = maxf(top_speed, Vector2(walker.velocity.x, walker.velocity.z).length())
	_expect(top_speed > 18.0, "dash bursts forward (%.1f m/s)" % top_speed)
	_expect(peak - y0 > 0.5 and peak - y0 < 1.6, "dash rises at a low angle (%.2f m)" % (peak - y0))
	_expect(walker.global_position.z - z0 > 4.0, "dash covers ground (%.1f m)" % (walker.global_position.z - z0))
	# Physics: no braking in the air; after landing the feet skid (friction) down to grip speed.
	var skidded := false
	for i in 120:
		await _frames(1)
		skidded = skidded or walker.skidding
	_expect(skidded, "landing above grip speed skids")
	_expect(Vector2(walker.velocity.x, walker.velocity.z).length() < walker.grip_speed, "the skid bleeds the dash back down to grip speed")
	await _frames(60)
	# The wall's near face is at z=49.5; the capsule reaches it from the front.
	walker.global_position = Vector3(0, 0.1, 47.5)
	walker.velocity = Vector3.ZERO
	walker.get_node("Gait").replant()
	Input.action_press("move_forward")
	await _frames(35)
	Input.action_release("move_forward")
	_expect(walker.is_on_wall(), "the walker reaches the wall")
	var before := walker.global_position
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	_expect(walker.velocity.y > 1.5 and walker.velocity.z < -8.0, "wall jump sends the walker up and away")
	await _frames(10)
	_expect(walker.global_position.z < before.z - 0.3, "wall jump moves away from the wall")
	# Jumping from a slope adds an outward component along its normal.
	walker.global_position = Vector3(100, 5, 0)
	walker.velocity = Vector3.ZERO
	walker.get_node("Gait").replant()
	await _frames(100)
	_expect(walker.is_on_floor(), "walker settles on the slope")
	var slope_normal := walker.get_floor_normal()
	Input.action_press("jump")
	await _frames(12)
	Input.action_release("jump")
	var horizontal := Vector3(walker.velocity.x, 0, walker.velocity.z)
	var outward := Vector3(slope_normal.x, 0, slope_normal.z).normalized()
	_expect(horizontal.dot(outward) > 1.0, "slope dash pushes outward")
	# Check the world aim while the hull changes orientation under a tether.
	walker.set_physics_process(false)
	combat.grapple.state = 2 # PULLING
	combat.grapple._dash_active = true
	combat.aim_point = walker.global_position + Vector3(0, 1.5, 100)
	walker.rotation.y = 0.0
	combat.update_aim(0.016)
	var before_aim: Vector3 = combat.turret.global_basis.z.normalized()
	walker.rotation.y = PI / 2.0
	combat.update_aim(0.016)
	var after_aim: Vector3 = combat.turret.global_basis.z.normalized()
	before_aim.y = 0.0
	after_aim.y = 0.0
	_expect(before_aim.normalized().dot(after_aim.normalized()) > 0.999, "grapple hull rotation does not pull the turret away from the camera target")
	combat.grapple._dash_active = false
	for sound: Node in stage.find_children("*", "AudioStreamPlayer3D", true, false): sound.stop()
	stage.queue_free()
	await _frames(10)
	OS.delay_msec(100)
	await _frames(2)
	_finish("MOBILITY")
