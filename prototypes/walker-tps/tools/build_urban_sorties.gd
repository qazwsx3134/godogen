extends SceneTree
## One-time authoring tool. Published scenes are editable in Godot.
const B := preload("res://addons/proto_kit/scene_builder.gd")
const Cover := preload("res://scripts/breakable_cover.gd")
const Concrete := preload("res://materials/weathered_concrete.tres")
const Scout := "res://scenes/scout.tscn"
const Base := "res://scenes/battlefield.tscn"
const MapSize := Vector3(224, 1, 308)
var asphalt := ShaderMaterial.new()
var paving := StandardMaterial3D.new()
var rng := RandomNumberGenerator.new()

func _initialize() -> void:
	build.call_deferred()

func build() -> void:
	asphalt.shader = load("res://shaders/asphalt.gdshader")
	paving.albedo_color = Color("#56534e")
	var street := build_map(false)
	var plaza := build_map(true)
	var ok_street := build_sortie(street, false)
	var ok_plaza := build_sortie(plaza, true)
	var ok_ui := build_picker()
	quit(0 if ok_street and ok_plaza and ok_ui else 1)

func block(parent: Node3D, label: String, size: Vector3, center: Vector3, material: Material, layer: int = 0) -> Node3D:
	var part: Node3D = StaticBody3D.new() if layer != 0 else Node3D.new()
	B.add(parent, part, label + str(parent.get_child_count()))
	if label == "Terrain": part.name = label
	part.position = center
	var surface := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	surface.mesh = mesh
	if parent.name in ["Skyline", "Streets"]:
		surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	B.add(part, surface, "Surface")
	if layer != 0:
		part.collision_layer = layer
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		B.add(part, collision, "Collision")
		if layer == 9:
			part.set_script(Cover)
			surface.material_override = material
	return part

func build_map(boss: bool) -> Node3D:
	rng.seed = 631 if boss else 947
	var map := Node3D.new()
	map.name = "Map"
	block(map, "Terrain", MapSize, Vector3(0, -0.5, 22), asphalt, 17)
	var routes := Node3D.new()
	B.add(map, routes, "RouteMarkers")
	var spawn := Marker3D.new()
	B.add(routes, spawn, "PlayerSpawn")
	spawn.position = Vector3(0, 0.15, -99 if boss else -83)
	var ruins := Node3D.new()
	B.add(map, ruins, "Ruins")
	var skyline := Node3D.new()
	B.add(map, skyline, "Skyline")
	var roads := Node3D.new()
	B.add(map, roads, "Streets")
	for side: float in [-1.0, 1.0]:
		var center := 50.0 if boss else 21.0
		for row in 5:
			var z := -83.0 + row * 43.0
			block(roads, "Sidewalk", Vector3(7, 0.25, 31), Vector3(side * center, 0.125, z), paving, 1)
			_street_props(map, side, center, z, row)
			var x := side * (center + (16.0 if boss else 19.0))
			# Ruined blocks (scenes/buildings, from tools/build_ruined_buildings.gd): collapsed corner faces the street.
			var building := B.instance("res://scenes/buildings/ruined_block_%s.tscn" % ["a", "b", "c"][rng.randi_range(0, 2)]) as Node3D
			B.add(ruins, building, "Building%d_%d" % [int(side), row])
			building.position = Vector3(x, 0, z + 5)
			building.rotation.y = 0.0 if side < 0 else PI
			var wall := B.instance("res://scenes/ruined_wall.tscn") as Node3D
			B.add(ruins, wall, "StreetWall%d_%d" % [int(side), row])
			wall.position = Vector3(side * (center - 6.5), 0, z + 8)
			wall.rotation_degrees.y = rng.randf_range(-30, 40)
			var tower := B.instance("res://scenes/buildings/skyline_tower_%s.tscn" % ["a", "b", "c"][rng.randi_range(0, 2)]) as Node3D
			B.add(skyline, tower, "Tower%d_%d" % [int(side), row])
			tower.position = Vector3(side * rng.randf_range(114, 142), 0, z)
			tower.rotation.y = rng.randi_range(0, 3) * PI * 0.5
			var rear := B.instance("res://scenes/buildings/skyline_tower_%s.tscn" % ["a", "b", "c"][rng.randi_range(0, 2)]) as Node3D
			B.add(skyline, rear, "RearTower%d_%d" % [int(side), row])
			rear.position = Vector3((row - 2) * 42 + side * 8, 0, 155.0 + side * 13)
			rear.rotation.y = rng.randi_range(0, 3) * PI * 0.5
		var wreck := B.instance("res://scenes/armored_wreck.tscn") as Node3D
		B.add(ruins, wreck, "RoadWreck%d" % int(side))
		wreck.position = Vector3(side * (42 if boss else 13), 0, -42 if boss else -49)
		wreck.rotation_degrees.y = side * 31.0
	for index in 19:
		block(roads, "LaneMark", Vector3(0.25, 0.025, 3.3), Vector3(0, 0.028, -113 + index * 11), paving)
	if boss:
		for x in [-38.0, 38.0]:
			for z in [5.0, 44.0]:
				block(roads, "PlazaApron", Vector3(11, 0.05, 34), Vector3(x, 0.008, z), paving)
		block(ruins, "MonumentBase", Vector3(14, 2.2, 11), Vector3(71, 1.1, -52), Concrete, 1)
		var monument := block(ruins, "BrokenMonument", Vector3(6, 22, 6), Vector3(70, 12, -52), Concrete)
		monument.rotation_degrees.z = -16.0
		for side: float in [-1.0, 1.0]:
			block(ruins, "DestroyedGate", Vector3(8, 11, 5), Vector3(side * 38, 5.5, -22), Concrete, 9)
	else:
		# The severed elevated line marks the west flank and gives the district its skyline.
		var rail := B.instance("res://scenes/buildings/elevated_rail.tscn") as Node3D
		B.add(ruins, rail, "ElevatedRail")
		rail.position = Vector3(-31, 0, -46)
		for index in 4:
			var side := -1.0 if index % 2 == 0 else 1.0
			var roadblock := B.instance("res://scenes/buildings/t_wall_roadblock.tscn") as Node3D
			B.add(ruins, roadblock, "Roadblock%d" % index)
			roadblock.position = Vector3(side * 9, 0, -27 + index * 23)
			roadblock.rotation.y = rng.randf_range(-0.12, 0.12)
	return map

func build_sortie(map: Node3D, boss: bool) -> bool:
	var id := "shattered_plaza" if boss else "ruined_district"
	var scene_path := "res://scenes/" + id + ".tscn"
	if FileAccess.file_exists(scene_path):
		map.free()
		return true
	var nav := NavigationMesh.new()
	if not boss:
		nav.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
		nav.geometry_collision_mask = 1
		nav.agent_radius = 1.5
		nav.agent_height = 2.5
		nav.agent_max_climb = 0.5
		nav.cell_size = 0.5
		nav.cell_height = 0.25
		root.add_child(map)
		var data := NavigationMeshSourceGeometryData3D.new()
		NavigationServer3D.parse_source_geometry_data(nav, data, map)
		NavigationServer3D.bake_from_source_geometry_data(nav, data)
		root.remove_child(map)
		if nav.get_polygon_count() == 0:
			map.free()
			push_error("Urban navigation bake returned no polygons")
			return false
	var map_path := "res://scenes/map_" + id + ".tscn"
	var spawn_position: Vector3 = map.get_node("RouteMarkers/PlayerSpawn").position
	if not B.save_scene(map, map_path, {"overwrite": true}).ok:
		return false
	var session: Node3D = B.open_scene(Base).root
	session.sortie_title = "SHATTERED PLAZA" if boss else "RUINED DISTRICT"
	session.playable_half_extents = Vector2(106, 127)
	session.get_node("Walker").position = spawn_position
	B.put(session, B.instance(map_path), "Map")
	var environment: WorldEnvironment = session.get_node("WorldEnvironment")
	environment.environment = environment.environment.duplicate()
	environment.environment.fog_light_color = Color("#8a6256") if boss else Color("#546477")
	environment.environment.fog_density = 0.0048 if boss else 0.0034
	var sun: DirectionalLight3D = session.get_node("Sun")
	sun.light_color = Color("#ffc08c") if boss else Color("#b5cafa")
	session.get_node("Navigation").navigation_mesh = nav if not boss else null
	var enemies := Node3D.new()
	B.put(session, enemies, "Enemies")
	if not boss:
		var points := [Vector3(-10, 0.15, -39), Vector3(13, 0.15, -10), Vector3(-28, 0.15, 16), Vector3(29, 0.15, 25), Vector3(2, 0.15, 60)]
		for index in points.size():
			var scout := B.instance(Scout) as Node3D
			B.add(enemies, scout, "Scout%d" % index)
			scout.position = points[index]
			scout.rotation.y = PI
			scout.combat_enabled = true
			if index == points.size() - 1:
				scout.max_health = 120
				scout.mass = 12
				scout.repositions = false
		return B.save_scene(session, scene_path, {"expected_refs": [map_path, Scout]}).ok
	var stage := Node3D.new()
	stage.name = "ShatteredPlaza"
	B.add(stage, session, "Battlefield")
	session.set_script(load("res://scripts/boss_battle_session.gd"))
	session.sortie_title = "SHATTERED PLAZA"
	session.playable_half_extents = Vector2(106, 127)
	var enemy_boss := B.instance("res://scenes/boss.tscn") as CharacterBody3D
	B.add(stage, enemy_boss, "Boss")
	enemy_boss.position = Vector3(0, 1.0, 64)
	enemy_boss.rotation.y = PI
	enemy_boss.scale = Vector3.ONE * 5.45
	enemy_boss.collision_mask = 18
	enemy_boss.floor_snap_length = 2.0
	return B.save_scene(stage, scene_path, {"expected_refs": [map_path, "res://scenes/boss.tscn"]}).ok

func build_picker() -> bool:
	var path := "res://scenes/combat_hud.tscn"
	var opened := B.open_scene(path)
	var hud: Node = opened.root
	var rows := hud.get_node("Modal/Panel/Margin/Rows")
	if rows.has_node("Sorties"):
		hud.free()
		return true
	var picker := HBoxContainer.new()
	picker.add_theme_constant_override("separation", 10)
	B.add(rows, picker, "Sorties")
	for entry: Array in [["GreenRust", "GREEN RUST"], ["RuinedDistrict", "RUINED DISTRICT"], ["ShatteredPlaza", "SHATTERED PLAZA"]]:
		var button := Button.new()
		button.text = entry[1]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 42
		B.add(picker, button, entry[0])
	return B.save_scene(hud, path, {"overwrite": true, "expected_refs": opened.refs}).ok

## Lamps and poles along the kerb, a burnt car at the roadside and the odd billboard: the walker
## needs real-sized objects next to it to read as a 4 m machine.
func _street_props(map: Node3D, side: float, center: float, z: float, row: int) -> void:
	var props: Node3D = map.get_node_or_null("Props")
	if props == null:
		props = Node3D.new()
		B.add(map, props, "Props")
	var kerb := side * (center - 3.0)
	for dz: float in [-10.0, 10.0]:
		var lamp := B.instance("res://scenes/buildings/street_lamp.tscn") as Node3D
		B.add(props, lamp, "Lamp%d_%d_%d" % [int(side), row, int(dz)])
		lamp.position = Vector3(kerb, 0.25, z + dz)
		lamp.rotation = Vector3(0, PI if side > 0 else 0.0, rng.randf_range(-0.12, 0.12) if rng.randf() < 0.4 else 0.0)
	var pole := B.instance("res://scenes/buildings/utility_pole.tscn") as Node3D
	B.add(props, pole, "Pole%d_%d" % [int(side), row])
	pole.position = Vector3(side * (center + 3.0), 0.25, z)
	pole.rotation.y = PI * 0.5
	var car := B.instance("res://scenes/buildings/wrecked_car.tscn") as Node3D
	B.add(props, car, "Car%d_%d" % [int(side), row])
	car.position = Vector3(side * (center - 9.0), 0, z - 12.0)
	car.rotation.y = PI * 0.5 + rng.randf_range(-0.5, 0.5)
	if rng.randf() < 0.4:
		var board := B.instance("res://scenes/buildings/signboard.tscn") as Node3D
		B.add(props, board, "Board%d_%d" % [int(side), row])
		board.position = Vector3(side * (center + 2.0), 0.25, z + 4.0)
		board.rotation.y = PI * 0.5
