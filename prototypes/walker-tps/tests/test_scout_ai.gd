extends "res://addons/proto_kit/test_kit.gd"
## Scout combat AI: aim prediction, the state machine's hysteresis, alert on being hit, moving
## after firing, the view cone, rear hits; plus the player landing after a round ends mid-jump.
const Scout = preload("res://scripts/scout.gd")
var main: Node
var walker: CharacterBody3D
var scout: CharacterBody3D

func _init() -> void: _run.call_deferred()

func _run() -> void:
	_test_intercept_point()
	main=load("res://scenes/battlefield.tscn").instantiate()
	root.add_child(main)
	current_scene=main
	walker=main.get_node("Walker")
	scout=main.get_node("Enemies/Scout0")
	await _frames(20)
	main.start_match()
	for other: Node in main.get_node("Enemies").get_children(): other.ai_enabled=false
	await _frames(10)
	await _test_view_cone()
	await _test_aim_hysteresis()
	await _test_reposition_after_firing()
	await _test_alert_when_hit()
	_test_rear_hit()
	await _test_team_contact_and_spread()
	await _test_round_end_mid_jump()
	for player: Node in main.find_children("*", "AudioStreamPlayer3D", true, false): player.stop()
	main.get_node("Radio").stop()
	main.queue_free()
	await _frames(4)
	OS.delay_msec(50)
	await _frames(2)
	_finish("SCOUT_AI")

func _test_intercept_point() -> void:
	var still := Scout.intercept_point(Vector3.ZERO, Vector3(0, 0, 36), Vector3.ZERO, 36.0)
	_expect(still.is_equal_approx(Vector3(0, 0, 36)), "intercept: a still target is aimed at directly")
	# 36 m away, crossing at 4 m/s, 36 m/s rounds: t solves 36^2 + 16t^2 = 1296t^2, t ~ 1.0062 s.
	var crossing := Scout.intercept_point(Vector3.ZERO, Vector3(0, 0, 36), Vector3(4, 0, 0), 36.0)
	_expect(absf(crossing.x - 4.0 * 1.0062) < 0.01 and absf(crossing.z - 36.0) < 0.001,
		"intercept: a crossing target is led by speed x flight time (x=%.3f)" % crossing.x)
	var crossing_time: float = crossing.length() / 36.0
	_expect(absf(crossing_time - 1.0062) < 0.001, "intercept: the round and the target arrive together")
	var escaping := Scout.intercept_point(Vector3.ZERO, Vector3(0, 0, 36), Vector3(0, 0, 50), 36.0)
	_expect(escaping.is_equal_approx(Vector3(0, 0, 36)), "intercept: a target outrunning the round falls back to its position")

## Puts the scout `distance` m in front of the walker, facing it (or facing away), with a fresh state.
func _place(distance: float, facing_player: bool = true) -> void:
	scout.ai_enabled=false
	scout.global_position=walker.global_position+walker.global_basis.z*distance
	scout.velocity=Vector3.ZERO
	var to := walker.global_position-scout.global_position
	scout.rotation.y=atan2(to.x, to.z)+(0.0 if facing_player else PI)
	scout.state=Scout.State.PATROL
	scout._sees=false  # forget the last placement's sighting
	scout._sense_wait=0
	scout.fire_wait=0
	scout.charge=0
	await _frames(2)

func _test_view_cone() -> void:
	await _place(30, false)
	scout.ai_enabled=true
	await _frames(30)
	_expect(scout.sees_player() and scout.state==Scout.State.PATROL, "patrolling scout does not notice a player behind it (clear line of sight)")
	await _place(9, false)
	scout.ai_enabled=true
	await _frames(30)
	_expect(scout.state!=Scout.State.PATROL, "a player close behind is noticed anyway")
	await _place(30, true)
	scout.ai_enabled=true
	await _frames(30)
	_expect(scout.state in [Scout.State.CHASE, Scout.State.AIM], "a player in the view cone is noticed")

func _test_aim_hysteresis() -> void:
	await _place(30)
	scout.repositions=false
	scout.ai_enabled=true
	await _until(func() -> bool: return scout.state==Scout.State.AIM, "scout starts aiming in range", 3.0)
	scout.fire_wait=10.0  # hold fire: only the state is under test
	scout.global_position=walker.global_position+walker.global_basis.z*(scout.attack_range+3.0)
	var flips := 0
	var last: int = scout.state
	for i: int in 60:
		await _frames(1)
		if scout.state!=last: flips+=1
		last=scout.state
	_expect(scout.state==Scout.State.AIM and flips==0, "inside the exit margin the scout keeps aiming (flips %d)" % flips)
	scout.global_position=walker.global_position+walker.global_basis.z*(scout.attack_range+scout.aim_exit_margin+4.0)
	await _frames(30)
	_expect(scout.state==Scout.State.CHASE, "past the exit margin the scout chases again")
	scout.repositions=true

func _test_reposition_after_firing() -> void:
	await _place(20)
	scout.ai_enabled=true
	await _until(func() -> bool: return scout.state==Scout.State.REPOSITION, "scout moves on after a burst", 4.0)
	var fired_at: Vector3 = scout.global_position
	await _frames(150)
	var moved := Vector2(scout.global_position.x-fired_at.x, scout.global_position.z-fired_at.z).length()
	_expect(moved>3.0, "scout sidesteps after firing (%.1f m)" % moved)

func _test_alert_when_hit() -> void:
	await _place(30, false)
	scout.ai_enabled=true
	await _frames(10)
	var shot_direction: Vector3 = (scout.global_position-walker.global_position).normalized()
	scout.apply_damage(5, scout.global_position+Vector3.UP, shot_direction)
	await _frames(2)
	_expect(scout.state==Scout.State.SEARCH or scout.state==Scout.State.CHASE, "a scout shot from behind stops patrolling")
	_expect(scout.last_seen.distance_to(walker.global_position)<scout.global_position.distance_to(walker.global_position),
		"it searches back toward where the round came from")
	var yaw_before: float = scout.rotation.y
	await _frames(120)
	_expect(absf(angle_difference(scout.rotation.y, yaw_before))>deg_to_rad(60), "it turns around to look")

func _test_rear_hit() -> void:
	scout.ai_enabled=false
	scout.health=scout.max_health
	scout.apply_damage(10, Vector3.ZERO, -scout.global_basis.z)
	_expect(is_equal_approx(scout.health, scout.max_health-10), "a frontal hit does normal damage")
	scout.apply_damage(10, Vector3.ZERO, scout.global_basis.z)
	_expect(is_equal_approx(scout.health, scout.max_health-10-10*scout.rear_multiplier), "a hit from behind does rear_multiplier damage")
	scout.health=scout.max_health

## One scout sees the player: a patrolling teammate comes to look; engaged scouts spread around the player.
func _test_team_contact_and_spread() -> void:
	walker.get_node("Combat").health=10000  # three scouts shoot during this; the round must not end
	var scouts: Array[Node] = main.get_node("Enemies").get_children()
	var forward: Vector3 = walker.global_basis.z
	var side: Vector3 = forward.cross(Vector3.UP)
	for i: int in scouts.size():
		var other: CharacterBody3D = scouts[i]
		other.ai_enabled=false
		other.health=other.max_health
		other.velocity=Vector3.ZERO
		other.state=Scout.State.PATROL
		other._sees=false
	# Scout0 in front, facing the player; Scout1 and Scout2 to the side and facing away, out of sight.
	scouts[0].global_position=walker.global_position+forward*25
	scouts[0].rotation.y=atan2(-forward.x,-forward.z)
	scouts[1].global_position=walker.global_position+forward*26+side*4
	scouts[2].global_position=walker.global_position+forward*24-side*4
	for i: int in [1, 2]:
		scouts[i].rotation.y=atan2(forward.x,forward.z)
	await _frames(2)
	for other: Node in scouts: other.ai_enabled=true
	await _frames(30)
	_expect(scouts[0].state!=Scout.State.PATROL, "the scout facing the player sees it")
	_expect(scouts[1].state!=Scout.State.PATROL and scouts[2].state!=Scout.State.PATROL,
		"teammates that could not see the player answer the sighting")
	await _frames(420)
	var closest := INF
	for i: int in scouts.size():
		for j: int in range(i+1, scouts.size()):
			var a: Vector3 = (scouts[i] as Node3D).global_position
			var b: Vector3 = (scouts[j] as Node3D).global_position
			closest=minf(closest, Vector2(a.x-b.x, a.z-b.z).length())
	_expect(closest>5.0, "engaged scouts spread out instead of bunching (closest pair %.1f m)" % closest)
	for other: Node in scouts: other.ai_enabled=false

func _test_round_end_mid_jump() -> void:
	walker.global_position+=Vector3.UP*3.0
	walker.velocity=Vector3.ZERO
	await _frames(2)
	main.finish("victory")
	await _frames(120)
	_expect(walker.is_on_floor(), "a round ending mid-air still lets the walker land")
