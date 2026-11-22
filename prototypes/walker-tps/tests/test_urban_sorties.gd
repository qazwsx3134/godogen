extends "res://addons/proto_kit/test_kit.gd"

func _init() -> void:
	run.call_deferred()

func run() -> void:
	await _frames(1)
	change_scene_to_file("res://scenes/battlefield.tscn")
	await _frames(12)
	var buttons := "CombatHUD/Modal/Panel/Margin/Rows/Sorties/"
	current_scene.get_node(buttons + "RuinedDistrict").pressed.emit()
	await _frames(35)
	var district := current_scene
	_expect(district.scene_file_path.ends_with("/ruined_district.tscn"), "briefing opens the district")
	_expect(district.total == 5 and district.walker.is_on_floor(), "district spawns five targets and a grounded walker")
	var nav: NavigationMesh = district.get_node("Navigation").navigation_mesh
	_expect(nav.get_polygon_count() > 0, "district navigation was baked")
	nav = null
	var map: RID = district.get_world_3d().navigation_map
	var path := NavigationServer3D.map_get_path(map, Vector3(0, 0, -83), Vector3(2, 0, 60), true)
	_expect(path.size() >= 2 and path[-1].distance_to(Vector3(2, 0, 60)) < 4, "district has a connected northbound route")
	district.start_match()
	for scout: Node in district.get_node("Enemies").get_children():
		_expect(scout.ai_enabled, "district targets activate")
		district._enemy_destroyed(scout)
	_expect(district.match_state == "victory", "clearing the scouts completes the sortie")
	district.retry()
	await _frames(20)
	_expect(current_scene.scene_file_path.ends_with("/ruined_district.tscn"), "retry keeps the selected district")
	current_scene.get_node(buttons + "ShatteredPlaza").pressed.emit()
	await _frames(35)
	var plaza := current_scene
	var session := plaza.get_node("Battlefield")
	var boss: CharacterBody3D = plaza.get_node("Boss")
	_expect(session.total == 1 and boss.is_on_floor() and session.walker.is_on_floor(), "plaza spawns one grounded boss and player")
	session.start_match()
	_expect(boss.active, "plaza deployment activates the boss")
	boss.destroyed.emit(boss)
	_expect(session.match_state == "victory" and not boss.active, "defeating the boss completes the plaza sortie")
	session.retry()
	await _frames(20)
	_expect(current_scene.scene_file_path.ends_with("/shattered_plaza.tscn"), "retry returns to the plaza")
	current_scene.free()
	await _frames(3)
	_finish("URBAN_SORTIES")
