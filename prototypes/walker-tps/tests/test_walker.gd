extends "res://addons/proto_kit/test_kit.gd"
## godot --headless --fixed-fps 60 --path . --script res://tests/test_walker.gd

var main: Node
var walker: CharacterBody3D
var rig: Node3D
var gait: Node
var touch: Control
var steps := [0]

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	walker = main.get_node("Walker")
	rig = walker.get_node("CameraRig")
	gait = walker.get_node("Gait")
	touch = main.get_node("HUD/TouchInput")
	gait.stepped.connect(func(_p: Vector3) -> void: steps[0] += 1)
	await _frames(30)

	_expect(gait.legs.size() == 4, "four legs found in the GLB")
	_expect(walker.is_on_floor(), "walker stands on the ground")
	for leg in gait.legs:
		_expect(absf(leg.plant.y) < 0.05, "planted feet on the ground (y=%.3f)" % leg.plant.y)
		_expect(gait.sole(leg).distance_to(leg.plant) < 0.03, "rest pose: IK puts the sole on its spot")

	await _test_forward()
	await _test_strafe()
	await _test_touch_two_fingers()
	await _test_ramp()
	await _test_sprint()
	await _test_jump()
	_finish("WALKER")

## Hold `action` for `frames`; returns the worst distance between a planted foot's sole and its planted spot.
func _hold(action: String, frames: int) -> float:
	var worst := 0.0
	Input.action_press(action)
	for _i: int in frames:
		await _frames(1)
		for leg in gait.legs:
			if leg.t < 0.0:
				worst = maxf(worst, gait.sole(leg).distance_to(leg.plant))
	Input.action_release(action)
	await _frames(60)  # let it stop and settle
	return worst

func _test_forward() -> void:
	var fwd: Vector3 = rig.forward_flat()
	var start := walker.global_position
	steps[0] = 0
	var drift := await _hold("move_forward", 150)
	var d := walker.global_position - start
	_expect(d.dot(fwd) > 5.0, "forward moves along the camera's forward (%.2f m)" % d.dot(fwd))
	_expect(absf(d.dot(fwd.cross(Vector3.UP))) < 0.5, "forward does not drift sideways")
	_expect(walker.global_basis.z.dot(fwd) > 0.95, "model front (+Z) faces the camera's forward")
	_expect(drift < 0.03, "planted feet do not slide while walking (worst %.3f m)" % drift)
	_expect(steps[0] >= 6, "feet take steps while walking (%d)" % steps[0])

func _test_strafe() -> void:
	rig.look(Vector2(PI * 0.5, 0.0))  # camera turns 90 degrees right
	var fwd: Vector3 = rig.forward_flat()
	var left := -fwd.cross(Vector3.UP)
	var start := walker.global_position
	var drift := await _hold("move_left", 90)
	var d := walker.global_position - start
	_expect(d.dot(left) > 2.5, "left strafes to the camera's left (%.2f m)" % d.dot(left))
	_expect(drift < 0.03, "planted feet do not slide while strafing/turning (worst %.3f m)" % drift)
	_expect(walker.global_basis.z.dot(fwd) > 0.9, "hull turned toward the new camera forward")

func _touch(index: int, at: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = at
	e.pressed = pressed
	root.push_input(e, true)  # viewport coordinates, like test_kit

func _finger_drag(index: int, at: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = at
	e.relative = rel
	root.push_input(e, true)  # viewport coordinates, like test_kit

func _test_touch_two_fingers() -> void:
	var w := touch.size.x
	var h := touch.size.y
	var look_at := Vector2(w * 0.75, h * 0.5)
	var stick_at := Vector2(w * 0.2, h * 0.7)
	_touch(0, look_at, true)    # camera finger lands first
	_touch(1, stick_at, true)   # stick finger second: index 1, which mouse emulation would never see
	_finger_drag(1, stick_at + Vector2(0, -100), Vector2(0, -100))
	await _frames(1)
	_expect(touch.move.y > 0.8, "second finger on the left half drives the stick (%.2f)" % touch.move.y)
	var yaw0: float = rig.yaw
	_finger_drag(0, look_at + Vector2(60, 0), Vector2(60, 0))
	await _frames(1)
	_expect(rig.yaw < yaw0 - 0.2, "finger on the right half turns the camera right")
	var fwd: Vector3 = rig.forward_flat()
	var start := walker.global_position
	await _frames(60)
	_expect((walker.global_position - start).dot(fwd) > 1.5, "touch stick walks the walker forward")
	_touch(1, stick_at, false)
	_touch(0, look_at, false)
	await _frames(2)
	_expect(touch.move == Vector2.ZERO, "lifting the stick finger stops")
	var corner: Vector2 = (main.get_node("HUD/Buttons") as Control).get_global_rect().get_center()
	_touch(2, corner, true)
	_finger_drag(2, corner + Vector2(-40, 0), Vector2(-40, 0))
	await _frames(1)
	_expect(touch._look_finger == -1 and touch._stick_finger == -1, "a touch on the JUMP/BOOST corner does not turn the camera")
	_touch(2, corner, false)

func _test_ramp() -> void:
	walker.global_position = Vector3(14, 0.05, 3)  # in front of the cyan ramp, facing up it (+Z)
	walker.rotation.y = 0.0
	walker.velocity = Vector3.ZERO
	rig.yaw = PI
	await _frames(2)
	gait.replant()
	await _frames(20)
	var both_up := [0]
	var count := func() -> void:
		var up := [false, false]
		for leg in gait.legs:
			if leg.t >= 0.0:
				up[leg.group] = true
		if up[0] and up[1]:
			both_up[0] += 1
	get_root().get_tree().process_frame.connect(count)
	var drift := await _hold("move_forward", 330)
	get_root().get_tree().process_frame.disconnect(count)
	_expect(walker.global_position.y > 2.5, "walks up the ramp onto the platform (y=%.2f)" % walker.global_position.y)
	_expect(drift < 0.03, "planted feet do not slide on the ramp (worst %.3f m)" % drift)
	print("ramp: worst drift %.3f m, frames with both pairs up %d / 390" % [drift, both_up[0]])

func _teleport(at: Vector3) -> void:
	walker.global_position = at
	walker.rotation.y = 0.0
	walker.velocity = Vector3.ZERO
	rig.yaw = PI  # camera forward = +Z = model front
	await _frames(2)
	gait.replant()
	await _frames(20)

func _test_sprint() -> void:
	await _teleport(Vector3(-35, 0.05, -50))  # open ground, nothing ahead for 20 m
	var top := [0.0]
	var both_up := [0]
	var probe := func() -> void:
		top[0] = maxf(top[0], Vector2(walker.velocity.x, walker.velocity.z).length())
		var up := [false, false]
		for leg in gait.legs:
			if leg.t >= 0.0:
				up[leg.group] = true
		if up[0] and up[1]:
			both_up[0] += 1
	process_frame.connect(probe)
	Input.action_press("sprint")
	var drift := await _hold("move_forward", 180)
	Input.action_release("sprint")
	process_frame.disconnect(probe)
	_expect(top[0] > 6.2, "sprint reaches sprint speed (%.2f m/s)" % top[0])
	_expect(drift < 0.03, "planted feet do not slide while sprinting (worst %.3f m)" % drift)
	print("sprint: top %.2f m/s, worst drift %.3f m, frames with both pairs up %d / 240" % [top[0], drift, both_up[0]])

func _test_jump() -> void:
	await _teleport(Vector3(-35, 0.05, -50))
	var landings := []
	var on_land := func(impact: float) -> void: landings.append(impact)
	gait.landed.connect(on_land)
	var y0 := walker.global_position.y
	var peak := y0
	var apex_sole := -1.0  # lowest foot height at the top of the jump
	var was_air := false
	Input.action_press("jump")
	await _frames(1)
	Input.action_release("jump")
	for _i: int in 150:
		await _frames(1)
		peak = maxf(peak, walker.global_position.y)
		if gait.airborne:
			was_air = true
			if walker.velocity.y <= 0.0 and apex_sole < 0.0:
				apex_sole = 99.0
				for leg in gait.legs:
					apex_sole = minf(apex_sole, gait.sole(leg).y)
		elif was_air and walker.is_on_floor():
			break
	await _frames(30)
	gait.landed.disconnect(on_land)
	_expect(was_air, "jump leaves the ground")
	_expect(peak - y0 > 2.0, "jump rises over 2 m (%.2f m)" % (peak - y0))
	_expect(apex_sole > 1.5, "feet are tucked up off the ground at the apex (lowest sole %.2f m)" % apex_sole)
	_expect(landings.size() == 1 and landings[0] > 4.0, "lands once, hard (%s)" % str(landings))
	_expect(walker.is_on_floor() and not gait.airborne, "back on the ground after the jump")
	for leg in gait.legs:
		_expect(absf(leg.plant.y) < 0.05 and gait.sole(leg).distance_to(leg.plant) < 0.03,
				"after landing every foot is planted on the ground")
	print("jump: apex %.2f m, lowest foot at apex %.2f m, impact %s" % [peak - y0, apex_sole, str(landings)])
