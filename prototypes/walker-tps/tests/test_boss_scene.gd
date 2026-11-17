extends "res://addons/proto_kit/test_kit.gd"

func _init() -> void: _run.call_deferred()

func _run() -> void:
	await _test_battle_scene()
	await _test_attacks()
	_finish("BOSS_SCENE")

func _test_battle_scene() -> void:
	change_scene_to_file("res://scenes/boss_battlefield.tscn")
	await _frames(35)
	var scene := current_scene
	var boss: CharacterBody3D = scene.get_node("Boss")
	var session: Node = scene.get_node("Battlefield")
	var armor: Node = scene.get_node("Armor")
	_expect(boss.is_on_floor(), "Boss is standing on the terrain")
	_expect(not boss.has_node("Legs"), "the Boss walks on its own model legs, no added limbs")
	_expect(session.total == 4 and session.objective_name == "TARGETS", "Boss and three scouts share the victory objective")
	_expect(armor.get_child_count() == 10, "ten armor instances are saved in the map")
	var start := boss.global_position
	var unit: Node3D = armor.get_node("Melee00")
	var unit_start := unit.global_position
	session.start_match()
	for enemy: Node in session.get_node("Enemies").get_children(): enemy.ai_enabled = false
	await _frames(110)
	_expect(boss.global_position.distance_to(start) > 2.0 and boss.is_on_floor(), "Boss crawls on the ground")
	_expect(unit.global_position.distance_to(unit_start) > 1.0, "the other armors patrol")
	_expect(unit.find_child("AnimationPlayer").current_animation == &"walk", "rigged armor uses its walk animation")
	scene.set_armors_shadows(false)
	scene.set_armor_count(40)
	_expect(scene.get_node("StressUnits").get_child_count() == 30, "40 mode creates 30 additional armors")
	scene.set_armor_count(80)
	_expect(scene.get_node("StressUnits").get_child_count() == 70, "80 mode creates 70 additional armors")
	scene.set_armors_shadows(true)
	_expect(scene.get_node("StressUnits").get_child(0).shadows_enabled, "shadow toggle reaches new armors")
	scene.set_armor_count(10)
	_expect(scene.get_node("StressUnits").get_child_count() == 0, "returning to 10 removes the extras")
	for i in 3: session._enemy_destroyed(null)
	_expect(session.match_state == "playing", "destroying the scouts alone does not finish the Boss fight")
	boss._end_attack()
	boss.try_attack("slam") if boss.phase == 2 else boss.try_attack("beam")
	await _frames(30)
	boss.apply_damage(10000.0)
	_expect(not boss.get_node("Beam").visible and not boss.get_node("Charge").visible and boss.get_node("Wings/Strands").get_children().all(func(n: Node) -> bool: return not (n as Node3D).visible), "death clears the Boss's sights and charge")
	_expect(session.match_state == "playing", "the death show plays before the mission ends")
	_expect(boss.get_node("Voice").playing and boss.get_node("Voice").stream.resource_path.ends_with("boss_angry.ogg"), "the Boss roars as it dies")
	await _frames(2)
	_expect(not session.get_node("CombatHUD/Crosshair").visible, "the player's sights hide during the death show")
	var y0 := boss.global_position.y
	for i in 1200:  # hit stops run on the wall clock: let real time pass with the frames
		if session.match_state != "playing": break
		OS.delay_msec(4)
		await _frames(1)
	_expect(boss.global_position.y < y0 - 0.5, "the legs give way during the death show")
	_expect(session.match_state == "victory", "destroying Boss completes the objective after the death show")
	session.retry()
	await _frames(10)
	_expect(current_scene != null and current_scene.has_node("Boss"), "retry returns to the Boss battlefield")
	if current_scene:
		_stop_audio(current_scene)
		current_scene.queue_free()
		current_scene = null
	await _frames(8)

func _test_attacks() -> void:
	# An open, level arena isolates hit detection from terrain and other enemies.
	var arena := Node3D.new()
	root.add_child(arena)
	var session := Node3D.new()
	session.add_to_group("battle_session")
	arena.add_child(session)
	var projectiles := Node3D.new()
	projectiles.name = "Projectiles"
	session.add_child(projectiles)
	var ground := StaticBody3D.new()
	var ground_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(900, 2, 900)  # the Boss is about 220 m long
	ground_shape.shape = box
	ground.add_child(ground_shape)
	arena.add_child(ground)
	ground.position.y = -1.0
	var walker := (load("res://scenes/walker.tscn") as PackedScene).instantiate() as CharacterBody3D
	# Place both bodies before they enter the tree: a frame spent at the origin overlaps
	# them, and the Boss then rides the walker as a moving floor.
	walker.position = Vector3(0, 0.1, -120)  # in front of the head, inside the beam range
	arena.add_child(walker)
	var boss := (load("res://scenes/boss.tscn") as PackedScene).instantiate() as CharacterBody3D
	boss.position = Vector3(0, 0.1, 0)
	boss.rotation.y = PI
	arena.add_child(boss)
	await _frames(40)
	boss.active = true
	boss._attack_timer = 1000.0
	var combat: Node = walker.get_node("Combat")
	_expect(boss.try_attack("beam"), "beam attack starts")
	await _frames(30)
	_expect(boss.get_node("Charge").visible and not boss.get_node("Beam").visible, "beam charges energy at the head cannon first")
	var to_player: Vector3 = (walker.global_position + Vector3.UP * 1.2 - boss.to_global(boss.CANNON_PIVOT)).normalized()
	var waited := 0
	while boss.state == boss.State.BEAM_CHARGE and waited < 600:
		await _frames(1); waited += 1
	_expect(absf(waited / 60.0 + 0.5 - boss.beam_charge_time) < 0.2, "the charge lasts beam_charge_time")
	_expect(boss.global_position.distance_to(Vector3(0, 0, 0)) < 1.0, "the Boss stays on its own ground spot")
	_expect(boss.cannon_dir.dot(to_player) > 0.97, "the head cannon aims at the player")
	_expect(combat.health == combat.max_health, "no damage before the beam fires")
	await _frames(40)
	_expect(combat.health < combat.max_health, "beam damages a player in its path")
	while boss.state != boss.State.CHASE: await _frames(1)
	combat.health = combat.max_health
	boss._attack_timer = 1000.0
	walker.velocity = Vector3.ZERO
	_expect(boss.try_attack("pillars"), "pillar rain starts")
	await _frames(58)
	var pillars := get_nodes_in_group("boss_pillars")
	_expect(pillars.size() == boss.pillar_count, "pillar rain drops pillar_count pillars")
	_expect(pillars.all(func(p: Node) -> bool: return p.get_node("Marker").visible), "each landing spot is marked first")
	await _frames(150)
	_expect(combat.health < combat.max_health, "a pillar landing on the player hurts")
	await _frames(60)  # the staggered last pillars are still on their way
	_expect(pillars.all(func(p: Node) -> bool: return p.phase == p.Phase.STUCK and p.collision_layer != 0), "pillars stay stuck in the ground as obstacles")
	var target: Node = pillars[1]
	var shot := load("res://scenes/combat_projectile.tscn").instantiate() as Node3D
	projectiles.add_child(shot)
	var middle: Vector3 = target.global_position + target.global_basis.y.normalized() * 4.0
	shot.global_position = middle + Vector3(0, 0.5, -3)
	shot.direction = (middle - shot.global_position).normalized()
	shot.damage = 1000.0
	shot.excluded.assign([walker.get_rid()])
	await _frames(10)
	_expect(not is_instance_valid(target), "a pillar can be shot apart")
	combat.health = combat.max_health
	for pillar: Node in get_nodes_in_group("boss_pillars"): pillar.queue_free()
	walker.global_position = boss.to_global(Vector3(0, 0.1, -12))
	walker.velocity = Vector3.ZERO
	await _frames(4)
	boss._attack_timer = 1000.0
	_expect(boss.try_attack("tail"), "tail attack starts")
	await _frames(55)
	var pose: float = boss.tail_angle
	await _frames(48)
	_expect(absf(pose) > 0.05, "tail attack animates the tail")
	_expect(combat.health < combat.max_health, "tail sweep damages a nearby player behind the Boss")
	# Second form: below half health the fibre wings unfold and the fibre attacks unlock.
	_expect(not boss.try_attack("stab") and boss.state == boss.State.CHASE, "fibre attacks are locked in the first form")
	while boss.state != boss.State.CHASE: await _frames(1)
	boss.apply_damage(boss.max_health * 0.5 + 1.0)
	_expect(boss.phase == 2 and boss.state == boss.State.PHASE_SHIFT, "half health starts the second form")
	while boss.state != boss.State.CHASE: await _frames(1)
	_expect(boss.get_node("Wings").visible and boss.get_node("Wings").scale.is_equal_approx(Vector3.ONE), "the fibre wings unfold")
	walker.global_position = boss.to_global(Vector3(0, 0.1, 24))
	walker.velocity = Vector3.ZERO
	await _frames(4)
	combat.health = combat.max_health
	boss._attack_timer = 1000.0
	_expect(boss.try_attack("stab"), "fibre stab starts")
	await _frames(10)
	_expect(boss.get_node("Wings/Strands/Stab1").visible and combat.health == combat.max_health, "stab shows sight strands before it lands")
	while boss.state != boss.State.CHASE: await _frames(1)
	_expect(combat.health < combat.max_health, "fibre stab hits a player standing still")
	combat.health = combat.max_health
	boss._attack_timer = 1000.0
	_expect(boss.try_attack("slam"), "fibre slam starts")
	await _frames(20)
	_expect(boss.get_node("Wings/Strands/SlamRing").visible, "slam marks its ring on the ground")
	while boss.state != boss.State.CHASE: await _frames(1)
	_expect(combat.health < combat.max_health, "fibre slam hits a player inside the ring")
	_stop_audio(arena)
	arena.queue_free()
	await _frames(12)
	OS.delay_msec(100)
	await _frames(2)

func _stop_audio(node: Node) -> void:
	for sound: Node in node.find_children("*", "AudioStreamPlayer3D", true, false): sound.stop()
	for sound: Node in node.find_children("*", "AudioStreamPlayer", true, false): sound.stop()
