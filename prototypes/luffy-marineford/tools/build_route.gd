extends SceneTree
## Authors the C6 gray-box route: scenes/route.tscn (terrain, bridge, landmarks, waypoints) and the terrain mesh
## assets/route/terrain.res, both from scripts/route.gd's height function so the mesh matches the walkable bounds.
##   godot --headless --path prototypes/luffy-marineford --script res://tools/build_route.gd [-- --overwrite]
## A one-time authoring tool: once route.tscn is edited in the editor, do not overwrite it. Rerunning rebuilds only
## the terrain mesh, from the saved scene's Route settings (skip it with --keep-mesh).

const SceneBuilder = preload("res://addons/proto_kit/scene_builder.gd")
const RouteScript = preload("res://scripts/route.gd")
const MESH_PATH := "res://assets/route/terrain.res"
const SCENE_PATH := "res://scenes/route.tscn"
const TERRAIN_SHADER := preload("res://shaders/terrain.gdshader")
const SOLID_SHADER := preload("res://shaders/toon_solid.gdshader")


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var route := Node3D.new()
	route.name = "Route"
	route.set_script(RouteScript)
	if ResourceLoader.exists(SCENE_PATH):
		# The saved scene's Route settings win over the script defaults, so a rebuilt mesh matches what blocks.
		var saved: Node = (load(SCENE_PATH) as PackedScene).instantiate()
		for prop: Dictionary in route.get_property_list():
			if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and prop.usage & PROPERTY_USAGE_STORAGE:
				route.set(prop.name, saved.get(prop.name))
		var bridge := saved.get_node_or_null(^"Bridge") as MeshInstance3D
		var want_size := Vector3(route.bridge_half * 2.0, 1.0, route.bridge_from - route.bridge_to)
		var want_at := Vector3(0.0, -0.5, (route.bridge_from + route.bridge_to) * 0.5)
		if bridge and not ((bridge.mesh as BoxMesh).size.is_equal_approx(want_size) and bridge.position.is_equal_approx(want_at)):
			push_warning("route.tscn's Bridge does not match the Route settings: set its size to %s and position to %s in the editor" % [want_size, want_at])
		saved.free()
	if not args.has("--keep-mesh"):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/route"))
		var err: int = ResourceSaver.save(_terrain_mesh(route), MESH_PATH)
		if err != OK:
			push_error("terrain mesh save failed: %d" % err)
			quit(1)
			return
	var terrain := MeshInstance3D.new()
	terrain.mesh = load(MESH_PATH)
	var terrain_material := ShaderMaterial.new()
	terrain_material.shader = TERRAIN_SHADER
	terrain.material_override = terrain_material
	SceneBuilder.add(route, terrain, "Terrain")

	var slab := _solid(Color(0.74, 0.76, 0.8), Vector2(0.5, 2.0))
	var bridge_len: float = route.bridge_from - route.bridge_to
	_box(route, "Bridge", Vector3(route.bridge_half * 2.0, 1.0, bridge_len),
		Vector3(0.0, -0.5, (route.bridge_from + route.bridge_to) * 0.5), slab)

	var landmarks := SceneBuilder.add(route, Node3D.new(), "Landmarks")
	var stone := _solid(Color(0.8, 0.8, 0.83), Vector2(1.0, 3.0))
	var dark_stone := _solid(Color(0.5, 0.52, 0.6), Vector2(1.0, 3.0))
	var marine_white := _solid(Color(0.92, 0.93, 0.95), Vector2(3.0, 4.0))
	var marine_blue := _solid(Color(0.3, 0.42, 0.66))
	var wood := _solid(Color(0.5, 0.38, 0.28))
	var hull := _solid(Color(0.42, 0.33, 0.27), Vector2(0.8, 6.0))
	var sail := _solid(Color(0.95, 0.94, 0.9))
	# Execution platform: two stepped bases, a scaffold tower, the deck on top (about 27 m up).
	var pz: float = route.end_z - 10.0
	_box(landmarks, "PlatformBase", Vector3(44.0, 3.0, 20.0), Vector3(0.0, 1.5, pz), stone)
	_box(landmarks, "PlatformStep", Vector3(28.0, 3.0, 13.0), Vector3(0.0, 4.5, pz - 1.0), stone)
	for side: float in [-1.0, 1.0]:
		_box(landmarks, "TowerLeg" + ("L" if side < 0.0 else "R"), Vector3(2.0, 20.0, 2.0), Vector3(side * 3.2, 16.0, pz - 1.0), wood)
	_box(landmarks, "TowerBrace", Vector3(8.4, 1.0, 1.6), Vector3(0.0, 15.0, pz - 1.0), wood)
	_box(landmarks, "PlatformDeck", Vector3(11.0, 1.4, 8.0), Vector3(0.0, 26.7, pz - 1.0), wood)
	# Marine HQ behind it: the main block, the tower, a blue roof band.
	_box(landmarks, "HeadquartersBlock", Vector3(90.0, 34.0, 26.0), Vector3(0.0, 17.0, pz - 50.0), marine_white)
	_box(landmarks, "HeadquartersTower", Vector3(22.0, 26.0, 20.0), Vector3(0.0, 47.0, pz - 50.0), marine_white)
	_box(landmarks, "HeadquartersRoof", Vector3(26.0, 6.0, 24.0), Vector3(0.0, 63.0, pz - 50.0), marine_blue)
	# Siege walls on the terrace's outer edge, from behind the start to the platform.
	var wall_from: float = route.back_z + 10.0
	var wall_to: float = pz - 20.0
	for side: float in [-1.0, 1.0]:
		_box(landmarks, "SiegeWall" + ("L" if side < 0.0 else "R"), Vector3(3.0, 14.0, wall_from - wall_to),
			Vector3(side * (route.bay_at + 1.0), route.step_height + 7.0, (wall_from + wall_to) * 0.5), dark_stone)
	# Warships on the frozen bay outside the walls; their masts show over the walls.
	var ship_z: Array[float] = [-30.0, -110.0, -190.0, 40.0, -70.0, -150.0]
	for i: int in ship_z.size():
		var side: float = -1.0 if i < 3 else 1.0
		var x: float = side * (route.bay_at + 22.0 + 10.0 * float(i % 2))
		var ship := SceneBuilder.add(landmarks, Node3D.new(), "Warship%d" % (i + 1))
		ship.position = Vector3(x, -route.bay_depth, ship_z[i])
		_box(ship, "Hull", Vector3(9.0, 7.0, 34.0), Vector3(0.0, 3.5, 0.0), hull)
		_box(ship, "Deck", Vector3(8.0, 1.0, 30.0), Vector3(0.0, 7.5, 0.0), wood)
		for m: int in 2:
			var mz: float = -7.0 + 14.0 * m
			_box(ship, "Mast%d" % (m + 1), Vector3(0.8, 22.0, 0.8), Vector3(0.0, 19.0, mz), wood)
			_box(ship, "Sail%d" % (m + 1), Vector3(10.0, 8.0, 0.4), Vector3(0.0, 21.0, mz + 0.6), sail)

	var waypoints := SceneBuilder.add(route, Node3D.new(), "Waypoints")
	for entry: Array in [["Waypoint1", route.bridge_from], ["Garp", route.bridge_to], ["Platform", route.end_z]]:
		var marker: Marker3D = SceneBuilder.add(waypoints, Marker3D.new(), entry[0])
		marker.position = Vector3(0.0, 0.0, entry[1])

	var result: Dictionary = SceneBuilder.save_scene(route, SCENE_PATH, {"overwrite": args.has("--overwrite")})
	print("route: ", result)
	quit(0 if result.ok else 1)


func _solid(color: Color, courses: Vector2 = Vector2.ZERO) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SOLID_SHADER
	m.set_shader_parameter(&"albedo", color)
	m.set_shader_parameter(&"courses", courses)
	return m


func _box(parent: Node, node_name: String, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = box
	mi.material_override = material
	mi.position = at
	SceneBuilder.add(parent, mi, node_name)
	return mi


## Height-field mesh: 1 m columns over the corridor and terrace, 3 m over the bay; 2 m rows, 0.5 m at the crack.
func _terrain_mesh(route: Node) -> ArrayMesh:
	var xs: PackedFloat32Array = []
	var x: float = -130.0
	while x <= 130.0:
		xs.append(x)
		x += 1.0 if absf(x) < 46.0 else 3.0
	var zs: PackedFloat32Array = []
	var z: float = 60.0
	var z_end: float = route.end_z - 90.0
	while z >= z_end:
		zs.append(z)
		var near_crack: bool = absf(z - route.bridge_from) < 3.0 or absf(z - route.bridge_to) < 3.0
		z -= 0.5 if near_crack else 2.0
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	for zz: float in zs:
		for xx: float in xs:
			verts.append(Vector3(xx, route.height(xx, zz), zz))
			var e: float = 0.25
			var dx: float = route.height(xx + e, zz) - route.height(xx - e, zz)
			var dz: float = route.height(xx, zz + e) - route.height(xx, zz - e)
			normals.append(Vector3(-dx, 2.0 * e, -dz).normalized())
	var w: int = xs.size()
	var indices := PackedInt32Array()
	for r: int in zs.size() - 1:
		for c: int in w - 1:
			var a: int = r * w + c
			var b: int = a + 1
			var d: int = a + w
			var e2: int = d + 1
			# Rows run toward -Z, so this winding faces up.
			indices.append_array([a, d, b, b, d, e2])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	print("terrain: %d x %d vertices, %d triangles" % [w, zs.size(), indices.size() / 3])
	return mesh
