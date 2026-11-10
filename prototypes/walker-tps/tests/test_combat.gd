extends "res://addons/proto_kit/test_kit.gd"
var main: Node
var walker: CharacterBody3D
var combat: Node
var enemy: CharacterBody3D

func _init() -> void: _run.call_deferred()
func _run() -> void:
	main=load("res://scenes/battlefield.tscn").instantiate()
	root.add_child(main)
	current_scene=main
	walker=main.get_node("Walker")
	combat=walker.get_node("Combat")
	enemy=main.get_node("Enemies/Scout0")
	await _frames(30)
	_expect(main.match_state=="briefing" and not walker.controls_enabled,"briefing prevents combat input")
	main.start_match()
	for scout: Node in main.get_node("Enemies").get_children(): scout.ai_enabled=false
	await _frames(30)
	_expect(main.match_state=="playing" and walker.controls_enabled,"deploy enables controls")
	_expect(main.get_node("Navigation").navigation_mesh.get_polygon_count()>0,"saved navigation mesh exists")
	await _test_projectiles()
	await _test_hooks()
	await _test_ai()
	# Defeat must freeze enemies and clear shots; use fresh instance for victory.
	walker.apply_damage(1000)
	await _frames(2)
	_expect(main.match_state=="defeat" and not walker.controls_enabled,"player destruction ends round")
	await _stop_audio(main)
	main.queue_free()
	await _frames(3)
	main=load("res://scenes/battlefield.tscn").instantiate()
	root.add_child(main)
	current_scene=main
	await _frames(3)
	_expect(main.kills==0 and main.get_node("Projectiles").get_child_count()==0,"fresh round clears kills and projectiles")
	main.start_match()
	for scout: Node in main.get_node("Enemies").get_children(): scout.apply_damage(1000)
	await _frames(2)
	_expect(main.match_state=="victory" and main.kills==3,"all scouts destroyed wins round")
	await _stop_audio(main)
	main.queue_free()
	await _frames(3)
	main=load("res://scenes/battlefield.tscn").instantiate()
	root.add_child(main)
	current_scene=main
	await _frames(3)
	main.start_match()
	main.time_left=0.01
	await _frames(3)
	_expect(main.match_state=="timeout","time limit ends round")
	await _stop_audio(main)
	main.retry()
	await _frames(12)
	_expect(current_scene.match_state=="briefing" and current_scene.kills==0,"actual retry reloads briefing")
	_expect(current_scene.get_node("Walker/Combat").health==100,"retry restores player health")
	for player: Node in current_scene.find_children("*", "AudioStreamPlayer3D", true, false): player.stop()
	current_scene.get_node("Radio").stop()
	current_scene.queue_free()
	current_scene=null
	main=null
	walker=null
	combat=null
	enemy=null
	await _frames(8)
	OS.delay_msec(50)
	await _frames(2)
	_finish("COMBAT")

func _test_projectiles() -> void:
	# Isolate the real swept projectile collision from turret input.
	enemy.global_position=walker.global_position+Vector3(0,0,12)
	enemy.velocity=Vector3.ZERO
	await _frames(3)
	var hp: float = enemy.health
	var shot := load("res://scenes/combat_projectile.tscn").instantiate() as Node3D
	main.get_node("Projectiles").add_child(shot)
	shot.global_position=enemy.global_position+Vector3(0,1.1,-6)
	shot.direction=Vector3.BACK
	shot.speed=900
	shot.excluded.assign([walker.get_rid()])
	await _frames(3)
	_expect(enemy.health==hp-40,"swept fast projectile damages scout once")
	_expect(not is_instance_valid(shot),"projectile removed after hit")
	_expect(combat.try_fire(),"cannon fires from actual muzzle")
	_expect(not combat.try_fire(),"reload prevents double fire")
	for node: Node in main.get_node("Projectiles").get_children(): node.queue_free()
	await _frames(3)
	walker.set_physics_process(false)
	var wall := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size=Vector3(8,8,0.12)
	col.shape=shape
	wall.add_child(col)
	main.add_child(wall)
	wall.global_position=(combat.turret.global_position+combat.muzzle.global_position)*0.5
	await _frames(3)
	_expect(not combat.ray(combat.turret.global_position,combat.muzzle.global_position).is_empty(),"barrel overlaps the near-wall test fixture")
	combat.reload_left=0
	combat.try_fire()
	var near_shot: Node = main.get_node("Projectiles").get_child(0)
	await _frames(4)
	_expect(not is_instance_valid(near_shot),"barrel-through-wall shot impacts wall instead of escaping")
	wall.queue_free()
	walker.set_physics_process(true)
	await _frames(2)


func _test_hooks() -> void:
	for node: Node in main.get_node("Projectiles").get_children(): node.queue_free()
	enemy.health=enemy.max_health
	enemy.global_position=walker.global_position+Vector3(0,0,16)
	enemy.velocity=Vector3.ZERO
	walker.rotation.y=0
	combat.cooldown_left=0
	var start: Vector3 = enemy.global_position
	var stationary_player := walker.global_position
	_expect(combat.launch_hooks(enemy.global_position+Vector3.UP*1.1),"two hooks launch toward light scout")
	await _frames(45)
	_expect(enemy.global_position.distance_to(walker.global_position)<start.distance_to(walker.global_position)-3,"light scout reels toward player")
	_expect(walker.global_position.distance_to(stationary_player)<1.0,"light-target mode does not dash player")
	_expect(combat.hook_message=="REELING ENEMY","both pins anchor to the light enemy")
	for side: int in 2:
		var cable: Node3D = combat.get_node("Cable%d"%side)
		_expect(cable.visible and absf(cable.global_basis.x.length()-1.0)<0.01 and absf(cable.global_basis.z.length()-1.0)<0.01,"cable keeps constant thickness along its rotated local axis")

	combat.cancel_hook()
	_expect(combat.pins.is_empty() and combat.cooldown_left>0,"cancel releases both hooks and starts cooldown")
	_expect(not combat.launch_hooks(enemy.global_position),"cooldown blocks repeated grapple")
	# Heavy target pulls the player instead.
	enemy.mass=12
	enemy.global_position=walker.global_position+Vector3(0,0,18)
	enemy.velocity=Vector3.ZERO
	await _frames(3)
	combat.cooldown_left=0
	var player_start := walker.global_position
	combat.launch_hooks(enemy.global_position+Vector3.UP*1.2)
	await _frames(35)
	_expect(walker.global_position.z>player_start.z+3,"heavy target causes player dash")
	combat.cancel_hook()
	walker.velocity=Vector3.ZERO
	# Fixed terrain anchor: a ray aimed down the open road.
	combat.cooldown_left=0
	player_start=walker.global_position
	combat.launch_hooks(walker.global_position+Vector3(0,-1,14))
	await _frames(35)
	_expect(walker.global_position.distance_to(player_start)>2,"fixed terrain pulls player")
	combat.cancel_hook()
	combat.cooldown_left=0
	combat.launch_hooks(walker.global_position+Vector3(0,100,100))
	await _frames(80)
	_expect(combat.hook_state not in ["flying","pulling"],"sky miss releases without permanent tether")

func _test_ai() -> void:
	combat.cancel_hook()
	enemy.mass=3
	enemy.ai_enabled=true
	enemy.global_position=walker.global_position+Vector3(0,0,50)
	enemy.velocity=Vector3.ZERO
	enemy.path_wait=0
	var distance_before := walker.global_position.distance_to(enemy.global_position)
	await _frames(120)
	_expect(walker.global_position.distance_to(enemy.global_position)<distance_before-2,"AI follows baked path toward distant player")
	enemy.global_position=walker.global_position+Vector3(0,0,15)
	enemy.velocity=Vector3.ZERO
	await _frames(3)
	_expect(enemy.sees_player(),"scout sees player in clear line of sight")
	var hp: float = combat.health
	enemy.fire_wait=0
	await _frames(150)
	_expect(combat.health<hp,"AI telegraphs and shoots damaging rounds")
	enemy.ai_enabled=false
	# Place an explicit blocking wall between the actual two bodies.
	var wall := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size=Vector3(10,8,1)
	col.shape=box
	wall.add_child(col)
	main.add_child(wall)
	wall.global_position=(walker.global_position+enemy.global_position)*0.5+Vector3.UP*2
	await _frames(3)
	_expect(not enemy.sees_player(),"opaque wall blocks scout vision")
	var safe_health: float = combat.health
	var blocked_shot := load("res://scenes/combat_projectile.tscn").instantiate() as Node3D
	main.get_node("Projectiles").add_child(blocked_shot)
	blocked_shot.global_position=enemy.global_position+Vector3.UP*1.3
	blocked_shot.direction=(walker.global_position+Vector3.UP*1.3-blocked_shot.global_position).normalized()
	blocked_shot.speed=900
	blocked_shot.team="enemy"
	blocked_shot.excluded.assign([enemy.get_rid()])
	await _frames(4)
	_expect(combat.health==safe_health and not is_instance_valid(blocked_shot),"wall blocks real fast enemy projectile")
	wall.queue_free()

func _stop_audio(scene: Node) -> void:
	for player: Node in scene.find_children("*", "AudioStreamPlayer3D", true, false): player.stop()
	scene.get_node("Radio").stop()
	# Drain playbacks before replacing short-lived fixtures with the dummy driver.
	await _frames(2)
	OS.delay_msec(50)
