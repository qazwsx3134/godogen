extends SceneTree
## One-time authored terrain tool. Existing scenes are skipped; never runs during gameplay.
const B = preload("res://addons/proto_kit/scene_builder.gd")
var rng := RandomNumberGenerator.new()
var concrete: StandardMaterial3D
var rust: StandardMaterial3D
var dark: StandardMaterial3D

func _initialize() -> void:
	build.call_deferred()

func mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.95
	return m

func height_at(x: float, z: float) -> float:
	var ridge := 5.0 * exp(-pow((x + 64.0) / 25.0, 2.0))
	var road := exp(-pow((x - 7.0 * sin(z * 0.025)) / 10.0, 2.0))
	var edge := 13.0 * smoothstep(94.0, 120.0, absf(x)) + 12.0 * smoothstep(86.0, 110.0, absf(z))
	var crater := -2.2 * exp(-(pow((x - 27.0) / 13.0, 2.0) + pow((z + 22.0) / 12.0, 2.0)))
	return 0.7 * sin(x * 0.055) * cos(z * 0.043) + ridge - 1.0 * road + edge + crater

func box(parent: Node, label: String, size: Vector3, pos: Vector3, material: Material, angles := Vector3.ZERO) -> Node3D:
	var body := StaticBody3D.new()
	B.add(parent, body, label)
	body.position = pos
	body.rotation_degrees = angles
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material
	B.add(body, mesh, "Surface")
	var col := CollisionShape3D.new()
	var collision := BoxShape3D.new()
	collision.size = size
	col.shape = collision
	B.add(body, col, "Collision")
	return body

func terrain() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Terrain"
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz: int in 55:
		for ix: int in 60:
			var x := -120.0 + ix * 4.0
			var z := -110.0 + iz * 4.0
			for offset: Vector2 in [Vector2(0,0),Vector2(4,0),Vector2(0,4),Vector2(4,0),Vector2(4,4),Vector2(0,4)]:
				var p := Vector3(x + offset.x, height_at(x + offset.x,z + offset.y),z + offset.y)
				var road := absf(p.x - 7.0 * sin(p.z * 0.025)) < 6.0
				var c := Color(0.22,0.245,0.14).lerp(Color(0.38,0.35,0.25),0.5+0.5*sin(p.x*0.045+p.z*0.06))
				if road: c = Color(0.23,0.215,0.18)
				s.set_color(c)
				s.add_vertex(p)
	s.generate_normals()
	var mesh := s.commit()
	var m := mat(Color.WHITE)
	m.vertex_color_use_as_albedo = true
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	B.add(body,mi,"GroundSurface")
	var col := CollisionShape3D.new()
	col.shape = mesh.create_trimesh_shape()
	B.add(body,col,"GroundCollision")
	return body

func grass_mesh() -> ArrayMesh:
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in 5:
		var angle := i * 2.4
		var base := Vector3(cos(angle)*0.28,0,sin(angle)*0.28)
		var side := Vector3(cos(angle+1.2),0,sin(angle+1.2))*0.1
		for p: Vector3 in [base-side,base+Vector3(0.17,0.65+i*0.07,0.1),base+side]:
			s.set_color(Color(0.3,0.36,0.15) if p.y > 0.3 else Color(0.16,0.21,0.09))
			s.add_vertex(p)
	s.generate_normals()
	var mesh := s.commit()
	var m := mat(Color.WHITE)
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0,m)
	return mesh

func grass_chunk(blade: ArrayMesh, poses: Array[Transform3D]) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	for pose: Transform3D in poses:
		surface.append_from(blade, 0, pose)
	var mi := MeshInstance3D.new()
	mi.mesh = surface.commit()
	mi.material_override = blade.surface_get_material(0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func build() -> void:
	rng.seed = 86314
	concrete = mat(Color(0.38,0.38,0.32))
	rust = mat(Color(0.29,0.155,0.085))
	dark = mat(Color(0.12,0.15,0.12))
	# Reusable ruined wall and stripped armored wreck: editable child scenes.
	var wall := Node3D.new()
	wall.name = "RuinedWall"
	box(wall,"Main",Vector3(9,3.6,1.2),Vector3(0,1.8,0),concrete)
	box(wall,"BrokenTop",Vector3(3,1.2,1.2),Vector3(-2.8,4.2,0),concrete,Vector3(0,0,-9))
	box(wall,"FallenSlab",Vector3(4,0.5,2),Vector3(3,0.3,2),concrete,Vector3(8,14,7))
	if not B.save_scene(wall,"res://scenes/ruined_wall.tscn", {"overwrite": "--overwrite" in OS.get_cmdline_user_args()}).ok: quit(1); return
	var wreck := Node3D.new()
	wreck.name = "ArmoredWreck"
	box(wreck,"BurntHull",Vector3(3.4,1.7,5.8),Vector3(0,1.2,0),rust,Vector3(0,0,13))
	box(wreck,"Turret",Vector3(2.2,1.3,2.6),Vector3(0.3,2.4,0),dark,Vector3(0,28,11))
	box(wreck,"BrokenGun",Vector3(0.3,0.3,3.9),Vector3(1.2,2.65,2.5),rust,Vector3(4,28,0))
	for side: float in [-1.0,1.0]:
		box(wreck,"Track",Vector3(0.65,1.0,6.0),Vector3(side*1.7,0.5,0),dark)
	var overgrowth: Array[Transform3D] = []
	for i: int in 22:
		overgrowth.append(Transform3D(Basis.IDENTITY,Vector3(rng.randf_range(-1.1,1.1),2.15,rng.randf_range(-2.5,2.5))))
	B.add(wreck,grass_chunk(grass_mesh(),overgrowth),"HullOvergrowth")
	if not B.save_scene(wreck,"res://scenes/armored_wreck.tscn", {"overwrite": "--overwrite" in OS.get_cmdline_user_args()}).ok: quit(1); return
	var map := Node3D.new()
	map.name = "GreenRust"
	B.add(map,terrain())
	var ruins := B.add(map,Node3D.new(),"Ruins")
	for i: int in 14:
		var x: float = [-1.0,1.0][i%2] * (24.0 + rng.randf_range(0,38))
		var z := -48.0 + (i/2)*17.0
		var w := B.instance("res://scenes/ruined_wall.tscn") as Node3D
		B.add(ruins,w,"Wall%d"%i)
		w.position = Vector3(x,height_at(x,z),z)
		w.rotation.y = rng.randf_range(-0.6,0.6)
	var wrecks := B.add(map,Node3D.new(),"Wrecks")
	for i: int in 10:
		var x: float = [-1.0,1.0][i%2] * rng.randf_range(13,35)
		var z := -52.0 + (i/2)*27.0
		var w := B.instance("res://scenes/armored_wreck.tscn") as Node3D
		B.add(wrecks,w,"Wreck%d"%i)
		w.position = Vector3(x,height_at(x,z),z)
		w.rotation.y = rng.randf_range(-PI,PI)
	var bridge := B.add(map,Node3D.new(),"BrokenViaduct")
	for i: int in 5:
		var x := -90.0+i*21.0
		var y := height_at(x,35)
		box(bridge,"Pier%d"%i,Vector3(3.5,11,4),Vector3(x,y+5.5,35),concrete)
		if i != 2:
			box(bridge,"Deck%d"%i,Vector3(19,1.5,9),Vector3(x+5,y+11,35),concrete,Vector3(0,0,-3 if i==1 else 0))
	var factory := B.add(map,Node3D.new(),"Factory")
	for i: int in 5:
		box(factory,"Frame%d"%i,Vector3(1,9,1),Vector3(65,height_at(65,-5+i*10)+4.5,-5+i*10),rust)
		box(factory,"Beam%d"%i,Vector3(18,0.7,0.7),Vector3(57,height_at(65,-5+i*10)+9,-5+i*10),rust)
	box(factory,"Chimney",Vector3(5,27,5),Vector3(74,height_at(74,48)+13.5,48),concrete)
	var dressing := B.add(map,Node3D.new(),"Vegetation")
	var blade := grass_mesh()
	for cz: int in 5:
		for cx: int in 6:
			var poses: Array[Transform3D] = []
			for i: int in 260:
				var x := -112.0+cx*38+rng.randf_range(0,34)
				var z := -100.0+cz*40+rng.randf_range(0,36)
				if absf(x-7*sin(z*0.025)) < 7: continue
				var scale := rng.randf_range(0.65,1.8)
				poses.append(Transform3D(Basis(Vector3.UP,rng.randf_range(-PI,PI)).scaled(Vector3(scale,scale,scale)),Vector3(x,height_at(x,z)-0.04,z)))
			B.add(dressing,grass_chunk(blade,poses),"Grass_%d_%d"%[cx,cz])

	var markers := B.add(map,Node3D.new(),"RouteMarkers")
	for entry: Array in [["PlayerSpawn",0,-78],["WestRoute",-55,-50],["EastRoute",85,-50],["Relay",0,20]]:
		var marker := Marker3D.new()
		marker.position = Vector3(entry[1],height_at(entry[1],entry[2])+0.1,entry[2])
		B.add(markers,marker,entry[0])
	if not B.save_scene(map,"res://scenes/map_01_green_rust.tscn",{"overwrite": "--overwrite" in OS.get_cmdline_user_args(), "expected_refs":["res://scenes/ruined_wall.tscn","res://scenes/armored_wreck.tscn"]}).ok: quit(1); return
	var opened := B.open_scene("res://scenes/main.tscn")
	var main: Node = opened.root
	main.name = "Battlefield"
	main.set_script(load("res://scripts/battlefield.gd"))
	main.get_node("Arena").free()
	B.add(main,B.instance("res://scenes/map_01_green_rust.tscn"),"Map")
	main.get_node("Walker").position = Vector3(0,height_at(0,-78)+0.1,-78)
	var env: Environment = main.get_node("WorldEnvironment").environment.duplicate(true)
	env.ambient_light_color = Color(0.65,0.7,0.66)
	env.ambient_light_energy = 0.48
	env.fog_light_color = Color(0.49,0.56,0.51)
	env.fog_density = 0.0025
	main.get_node("WorldEnvironment").environment = env
	main.get_node("Sun").light_color = Color(1,0.93,0.78)
	main.get_node("Sun").directional_shadow_max_distance = 85
	var ok: bool = B.save_scene(main,"res://scenes/battlefield.tscn",{"overwrite": "--overwrite" in OS.get_cmdline_user_args(), "expected_refs":["res://scenes/map_01_green_rust.tscn","res://scenes/walker.tscn","res://scenes/hud.tscn"]}).ok
	quit(0 if ok else 1)
