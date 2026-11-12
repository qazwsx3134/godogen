extends "res://addons/proto_kit/test_kit.gd"
## Gait on terrain, on its own stage (main.tscn's Arena is not needed): feet stand on terrain only,
## the hull and pads follow a slope, and the legs brace instead of stepping during a grapple drag.
var stage: Node3D
var walker: CharacterBody3D
var gait: Node
var slope: StaticBody3D

func _init() -> void: _run.call_deferred()

func _run() -> void:
	stage=Node3D.new()
	root.add_child(stage)
	_box(Vector3(0,-2,20), Vector3(80,4,120), 0.0)  # flat ground, top at y=0
	slope=_box(Vector3(100,-0.5,0), Vector3(40,1,40), deg_to_rad(-12.0))  # rises toward +Z
	walker=load("res://scenes/walker.tscn").instantiate()
	stage.add_child(walker)
	gait=walker.get_node("Gait")
	await _frames(40)
	await _test_flat_is_level()
	await _test_sprint_keeps_the_trot()
	await _test_feet_ignore_scouts()
	await _test_slope_tilts_hull_and_pads()
	await _test_grapple_drag_braces()
	stage.queue_free()
	await _frames(3)
	_finish("GAIT_TERRAIN")

func _box(at: Vector3, size: Vector3, pitch: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size=size
	var collision := CollisionShape3D.new()
	collision.shape=shape
	body.add_child(collision)
	stage.add_child(body)
	body.position=at
	body.rotation.x=pitch
	return body

func _hull() -> Node3D:
	return walker.get_node("Model").find_child("Hull") as Node3D

func _test_flat_is_level() -> void:
	_expect(absf(_hull().global_basis.z.normalized().y)<sin(deg_to_rad(1.0)), "the hull stays level on flat ground")

func _test_sprint_keeps_the_trot() -> void:
	walker.global_position=Vector3(0,0.5,-30)
	walker.velocity=Vector3.ZERO
	await _frames(5)
	gait.replant()
	var player: Node = walker
	var lifts_before: int = gait.safety_lifts
	Input.action_press("move_forward")
	Input.action_press("sprint")
	var top := 0.0
	for i: int in 180:
		await _frames(1)
		top=maxf(top, Vector2(walker.velocity.x, walker.velocity.z).length())
	Input.action_release("move_forward")
	Input.action_release("sprint")
	await _frames(90)
	var lifts: int = gait.safety_lifts-lifts_before
	print("SPRINT top=%.2f safety_lifts=%d" % [top, lifts])
	_expect(top>player.sprint_speed-0.2, "the walker reaches sprint speed (%.2f m/s)" % top)
	_expect(lifts<=2, "at sprint speed the trot holds: legs rarely lift out of turn (%d)" % lifts)
	walker.global_position=Vector3(0,1,0)
	walker.velocity=Vector3.ZERO
	await _frames(5)
	gait.replant()
	await _frames(30)

func _test_feet_ignore_scouts() -> void:
	# A scout beside the walker (not under its body, which would stand on it); ask where the ground is there.
	var scout: CharacterBody3D = load("res://scenes/scout.tscn").instantiate()
	stage.add_child(scout)
	scout.set_physics_process(false)
	scout.global_position=walker.global_position+Vector3(6,0,0)
	await _frames(3)
	var ground: Vector3 = gait._ground(scout.global_position+Vector3(0,0.5,0))
	_expect(absf(ground.y)<0.1, "a foothold over a scout is the ground under it, not the scout (y=%.2f)" % ground.y)
	scout.queue_free()
	await _frames(2)


func _test_slope_tilts_hull_and_pads() -> void:
	walker.global_position=Vector3(100,4,0)
	walker.velocity=Vector3.ZERO
	await _frames(5)
	gait.replant()
	await _frames(120)
	var nose_up: float = _hull().global_basis.z.normalized().y
	_expect(nose_up>sin(deg_to_rad(6.0)), "facing up a 12 degree slope the hull pitches nose-up (%.1f deg)" % rad_to_deg(asin(nose_up)))
	var ground_up: Vector3 = slope.global_basis.y.normalized()
	var flat_pads := 0
	for leg: Object in gait.legs:
		if leg.t<0.0 and (leg.foot as Node3D).global_basis.y.normalized().dot(ground_up)>cos(deg_to_rad(5.0)):
			flat_pads+=1
	_expect(flat_pads==4, "every planted pad lies on the slope (%d of 4)" % flat_pads)
	walker.global_position=Vector3(0,1,0)
	walker.velocity=Vector3.ZERO
	await _frames(5)
	gait.replant()
	await _frames(90)
	_expect(absf(_hull().global_basis.z.normalized().y)<sin(deg_to_rad(1.0)), "back on flat ground the hull levels out again")

func _test_grapple_drag_braces() -> void:
	var combat: Node = walker.get_node("Combat")
	combat.grapple.cooldown_left=0
	var steps: Array[int] = [0]
	var count_steps := func(_at: Vector3) -> void: steps[0]+=1
	_expect(combat.grapple.launch_hooks(walker.global_position+Vector3(0,0,18)), "terrain grapple launches")
	var dragging_frames := 0
	for i: int in 240:
		await _frames(1)
		if combat.grapple.has_dash_momentum():
			if dragging_frames==0: gait.stepped.connect(count_steps)
			dragging_frames+=1
		elif dragging_frames>0:
			break
	if gait.stepped.is_connected(count_steps): gait.stepped.disconnect(count_steps)
	_expect(dragging_frames>10 and steps[0]==0, "no steps while the grapple drags the walker (%d steps over %d frames)" % [steps[0], dragging_frames])
	await _frames(30)
	var planted := 0
	for leg: Object in gait.legs:
		if leg.t<0.0 and absf(leg.plant.y)<0.1: planted+=1
	_expect(planted==4, "after the drag all four feet are down on the ground (%d of 4)" % planted)
