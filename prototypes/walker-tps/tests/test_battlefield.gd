extends "res://addons/proto_kit/test_kit.gd"

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var main: Node = load("res://scenes/battlefield.tscn").instantiate()
	root.add_child(main)
	main.start_match()
	var walker: CharacterBody3D = main.get_node("Walker")
	await _frames(60)
	_expect(walker.is_on_floor(), "spawn stands on terrain")
	var start := walker.position
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(300)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	_expect(walker.position.z > start.z + 25, "central route supports forward travel")
	_expect(walker.position.y > -5, "terrain collision prevents falling through")
	for label: String in ["WestRoute", "EastRoute", "Relay"]:
		var marker: Marker3D = main.get_node("Map/RouteMarkers/" + label)
		walker.position = marker.position + Vector3.UP
		walker.velocity = Vector3.ZERO
		walker.get_node("Gait").replant()
		await _frames(90)
		_expect(walker.is_on_floor(), label + " is walkable")
		var route_start := walker.position
		Input.action_press("move_forward")
		await _frames(150)
		Input.action_release("move_forward")
		_expect(walker.position.z > route_start.z + 5, label + " allows forward travel")
	walker.position = Vector3(130,10,0)
	await _frames(3)
	_expect(walker.position.distance_to(start) < 2, "outside map recovers to spawn")
	walker.position.y = -30
	await _frames(3)
	_expect(walker.position.distance_to(start) < 2, "falling recovers to spawn")
	_expect(main.get_node("Map/Vegetation").get_child_count() == 30, "authored grass chunks persist")
	var grass: MeshInstance3D = main.get_node("Map/Vegetation/Grass_0_0")
	_expect(grass.mesh.get_surface_count() > 0 and grass.mesh.surface_get_array_len(0) > 0, "grass geometry survives saved scene reload")
	_expect(main.get_node("Map/Wrecks/Wreck0").has_node("HullOvergrowth"), "wreck has authored overgrowth")
	var radar: Control = main.get_node("CombatHUD/Radar")
	_expect(radar.terrain_segments.size() > 0, "radar builds contours from the real terrain")
	var bridge: Node3D = main.get_node("Map/BrokenViaduct")
	var pier: Node3D = bridge.get_node("Pier0")
	var deck_height: float = bridge.get_node("Deck0").global_position.y
	var deck_surface: MeshInstance3D = bridge.get_node("Deck0/Surface")
	var deck_origin := deck_surface.global_position
	var world_material := deck_surface.material_override as ShaderMaterial
	var parts: Node = walker.get_node("Combat/Parts")
	var previous_parts: int = parts.active_count()
	pier.break_cover(pier.global_position)
	await _frames(30)
	var section := bridge.get_node_or_null("Deck0Falling") as RigidBody3D
	_expect(section != null and section.global_position.y < deck_height - 0.3,
		"a destroyed pier releases its bridge deck to gravity")
	var moving_material := (section.get_node("Surface") as MeshInstance3D).material_override as ShaderMaterial if section else null
	_expect(moving_material != null and moving_material != world_material
		and moving_material.get_shader_parameter("local_projection") == true
		and moving_material.get_shader_parameter("projection_origin") == deck_origin,
		"the moving deck keeps the same texture coordinates throughout the fall")
	_expect(world_material.get_shader_parameter("local_projection") != true,
		"shared fixed scenery keeps its world projection")
	_expect(parts.active_count() > previous_parts, "destroyed scenery throws solid-looking debris")
	_expect(bridge.has_node("Deck1"), "an independent bridge deck keeps its support")
	for player: Node in main.find_children("*", "AudioStreamPlayer3D", true, false): player.stop()
	main.get_node("Radio").stop()
	main.queue_free()
	await _frames(8)
	OS.delay_msec(50)
	await _frames(2)
	_finish("BATTLEFIELD")
