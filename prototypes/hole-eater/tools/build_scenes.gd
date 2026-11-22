extends SceneTree
## 製作工具：只在要重建時手動跑（會覆蓋 scenes/）。之後 scene 就是來源檔。
## godot --headless --path . -s tools/build_scenes.gd

const R := 1.5           # 洞半徑
const LIP := 0.6         # 洞緣碰撞的寬度（圓到方形開口）
const GROUND_HALF := 40.0
const PIT_DEPTH := 4.0
# 帶洞地面比地板低 3cm：物體停在地面時有約 1cm 的接觸穿透，若兩層等高，
# 移動中的洞緣「垂直側面」會碰到物體底部把它推走。
const GROUND_TOP := -0.03
const PROPS := 0b00010
const PROP_MASK := 0b00011


func _own(n: Node, root: Node) -> void:
	for c in n.get_children():
		c.owner = root
		if c.scene_file_path == "":
			_own(c, root)


func _save(root: Node, path: String) -> void:
	_own(root, root)
	var p := PackedScene.new()
	assert(p.pack(root) == OK)
	assert(ResourceSaver.save(p, path) == OK)
	print("saved ", path)


func _box_shape(parent: Node, name: String, size: Vector3, pos: Vector3) -> void:
	var cs := CollisionShape3D.new(); cs.name = name
	var b := BoxShape3D.new(); b.size = size
	cs.shape = b; cs.position = pos
	parent.add_child(cs)


func _prop(name: String, mesh: Mesh, shape: Shape3D, color: Color, mass: float) -> void:
	var rb := RigidBody3D.new(); rb.name = name
	rb.collision_layer = PROPS; rb.collision_mask = PROP_MASK; rb.mass = mass
	var mi := MeshInstance3D.new(); mi.name = "Mesh"; mi.mesh = mesh
	var m := StandardMaterial3D.new(); m.albedo_color = color
	mi.material_override = m
	rb.add_child(mi)
	var cs := CollisionShape3D.new(); cs.name = "Shape"; cs.shape = shape
	rb.add_child(cs)
	_save(rb, "res://scenes/%s.tscn" % name.to_snake_case())


func _init() -> void:
	# --- 材質
	var mask_mat := StandardMaterial3D.new()  # 第一步：洞口，只寫 stencil 不畫顏色
	mask_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mask_mat.albedo_color = Color(0, 0, 0, 0)   # 手機上 transparency 失效時仍不可見
	mask_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mask_mat.no_depth_test = true
	mask_mat.stencil_mode = BaseMaterial3D.STENCIL_MODE_CUSTOM
	mask_mat.stencil_flags = BaseMaterial3D.STENCIL_FLAG_WRITE
	mask_mat.stencil_compare = BaseMaterial3D.STENCIL_COMPARE_ALWAYS
	mask_mat.stencil_reference = 1
	mask_mat.render_priority = -128  # 透明佇列由小到大畫：洞口要比地板先寫 stencil
	ResourceSaver.save(mask_mat, "res://scenes/hole_mask_mat.tres")

	var floor_mat := StandardMaterial3D.new()  # 地板：stencil ≠ 1 才畫
	floor_mat.albedo_color = Color.WHITE
	floor_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	floor_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	floor_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	floor_mat.stencil_mode = BaseMaterial3D.STENCIL_MODE_CUSTOM
	floor_mat.stencil_flags = BaseMaterial3D.STENCIL_FLAG_READ
	floor_mat.stencil_compare = BaseMaterial3D.STENCIL_COMPARE_NOT_EQUAL
	floor_mat.stencil_reference = 1
	floor_mat.render_priority = -127  # 緊接在洞口之後；比其他透明物（含編輯器輔助線）早
	floor_mat.uv1_scale = Vector3(20, 20, 1)
	floor_mat.albedo_texture = _checker()
	ResourceSaver.save(floor_mat, "res://scenes/floor_mat.tres")

	var pit_mat := StandardMaterial3D.new()  # 第二步：洞的內壁，只畫背面
	pit_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	pit_mat.albedo_color = Color("8a7a3a")  # 黃色調，看得清楚洞底
	ResourceSaver.save(pit_mat, "res://scenes/pit_mat.tres")

	# --- 道具
	var bm := BoxMesh.new(); bm.size = Vector3.ONE * 0.5
	var bs := BoxShape3D.new(); bs.size = Vector3.ONE * 0.5
	_prop("PropBox", bm, bs, Color("d9822b"), 1.0)
	var sm := SphereMesh.new(); sm.radius = 0.3; sm.height = 0.6
	var ss := SphereShape3D.new(); ss.radius = 0.3
	_prop("PropBall", sm, ss, Color("3a86c8"), 0.6)
	var big := BoxMesh.new(); big.size = Vector3(3.6, 1.2, 3.6)
	var bigs := BoxShape3D.new(); bigs.size = Vector3(3.6, 1.2, 3.6)
	_prop("PropCrate", big, bigs, Color("8c5a3c"), 8.0)
	var tall := CylinderMesh.new(); tall.top_radius = 0.25; tall.bottom_radius = 0.25; tall.height = 1.2
	var talls := CylinderShape3D.new(); talls.radius = 0.25; talls.height = 1.2
	_prop("PropPillar", tall, talls, Color("c8c3b8"), 1.5)

	# --- hole.tscn
	var hole := RigidBody3D.new(); hole.name = "Hole"
	hole.set_script(load("res://scripts/hole_body.gd"))
	hole.gravity_scale = 0.0
	hole.freeze = true; hole.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	hole.collision_layer = 1 << 4   # 第 5 層 hole
	hole.collision_mask = 0
	var slick := PhysicsMaterial.new(); slick.friction = 0.0  # 洞在移動：有摩擦會把上面的大物體一起拖走
	hole.physics_material_override = slick

	var hm := CSGCylinder3D.new(); hm.name = "HoleMask"
	hm.radius = R; hm.height = 0.1; hm.sides = 24
	hm.position.y = 0.05; hm.material = mask_mat
	hm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hole.add_child(hm)
	var pit := CSGCylinder3D.new(); pit.name = "Pit"
	pit.radius = R; pit.height = PIT_DEPTH; pit.sides = 24
	pit.position.y = -PIT_DEPTH / 2.0; pit.material = pit_mat
	pit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hole.add_child(pit)

	var lip := MeshInstance3D.new(); lip.name = "Lip"  # 洞口光環（shader）
	var tm := TorusMesh.new(); tm.inner_radius = R; tm.outer_radius = R + 0.12; tm.rings = 48
	lip.mesh = tm; lip.position.y = 0.0
	var rim := ShaderMaterial.new(); rim.shader = load("res://shaders/hole_rim.gdshader")
	lip.material_override = rim
	lip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hole.add_child(lip)

	# 第三步：帶洞的第二層地面。洞緣用多個凸形（multiple convex），外面四個 box 補滿。
	var S := R + LIP
	var n := 32
	for i in n:
		var a0 := PI / 4.0 + TAU * i / n
		var a1 := PI / 4.0 + TAU * (i + 1) / n
		var pts := PackedVector3Array()
		for a in [a0, a1]:
			var d := Vector2(cos(a), sin(a))
			var outer := d * (S / maxf(absf(d.x), absf(d.y)))
			for y in [GROUND_TOP - 1.0, GROUND_TOP]:
				pts.append(Vector3(d.x * R, y, d.y * R))
				pts.append(Vector3(outer.x, y, outer.y))
		var cp := ConvexPolygonShape3D.new(); cp.points = pts
		var cs := CollisionShape3D.new(); cs.name = "LipShape%d" % i; cs.shape = cp
		hole.add_child(cs)
	var L := GROUND_HALF
	_box_shape(hole, "GroundN", Vector3(2 * L, 1, L - S), Vector3(0, GROUND_TOP - 0.5, (S + L) / 2))
	_box_shape(hole, "GroundS", Vector3(2 * L, 1, L - S), Vector3(0, GROUND_TOP - 0.5, -(S + L) / 2))
	_box_shape(hole, "GroundE", Vector3(L - S, 1, 2 * S), Vector3((S + L) / 2, GROUND_TOP - 0.5, 0))
	_box_shape(hole, "GroundW", Vector3(L - S, 1, 2 * S), Vector3(-(S + L) / 2, GROUND_TOP - 0.5, 0))

	# 第四步：偵測區與洞底
	var catch := Area3D.new(); catch.name = "Catch"; catch.unique_name_in_owner = true
	catch.collision_layer = 0; catch.collision_mask = PROPS
	var csph := CollisionShape3D.new(); csph.name = "Shape"
	var sph := SphereShape3D.new(); sph.radius = R * 0.9
	csph.shape = sph; catch.add_child(csph)
	hole.add_child(catch)
	var kill := Area3D.new(); kill.name = "Kill"; kill.unique_name_in_owner = true
	kill.collision_layer = 0; kill.collision_mask = PROPS
	kill.position.y = -PIT_DEPTH + 0.3
	_box_shape(kill, "Shape", Vector3(2 * R, 0.6, 2 * R), Vector3.ZERO)
	hole.add_child(kill)
	_save(hole, "res://scenes/hole.tscn")

	# --- main.tscn
	var root := Node3D.new(); root.name = "Main"
	root.set_script(load("res://scripts/main.gd"))
	var env := WorldEnvironment.new(); env.name = "Env"
	var e := Environment.new(); e.background_mode = Environment.BG_COLOR
	e.background_color = Color("9ad0e8"); e.ambient_light_color = Color.WHITE; e.ambient_light_energy = 0.5
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment = e; root.add_child(env)
	var sun := DirectionalLight3D.new(); sun.name = "Sun"; sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-55, 30, 0); root.add_child(sun)
	var cam := Camera3D.new(); cam.name = "Camera"; cam.unique_name_in_owner = true
	cam.fov = 50; cam.position = Vector3(0, 24, 17)
	root.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(0, 0, 2))

	var fl := StaticBody3D.new(); fl.name = "Floor"
	fl.collision_layer = 1; fl.collision_mask = 0
	var fm := MeshInstance3D.new(); fm.name = "Mesh"
	var pm := PlaneMesh.new(); pm.size = Vector2(40, 40); fm.mesh = pm
	fm.material_override = floor_mat
	fl.add_child(fm)
	_box_shape(fl, "Shape", Vector3(40, 1, 40), Vector3(0, -0.5, 0))
	root.add_child(fl)

	var hi := (load("res://scenes/hole.tscn") as PackedScene).instantiate()
	hi.unique_name_in_owner = true
	root.add_child(hi)

	var props := Node3D.new(); props.name = "Props"; root.add_child(props)
	var kinds := ["prop_box", "prop_ball", "prop_pillar"]
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var k := 0
	var crates := [Vector3(-6.3, 0.7, -6.3), Vector3(8.4, 0.7, 4.2), Vector3(-10.5, 0.7, 8.4)]
	for x in range(-8, 9):
		for z in range(-8, 9):
			if abs(x) < 2 and abs(z) < 2:
				continue
			if rng.randf() < 0.45:
				continue
			if crates.any(func(c): return Vector2(c.x - x * 2.1, c.z - z * 2.1).length() < 2.8):
				continue
			var sc: PackedScene = load("res://scenes/%s.tscn" % kinds[rng.randi() % kinds.size()])
			var p := sc.instantiate(); p.name = "Prop%d" % k; k += 1
			p.position = Vector3(x * 2.1 + rng.randf_range(-0.3, 0.3), 0.7, z * 2.1 + rng.randf_range(-0.3, 0.3))
			props.add_child(p)
	for pos in crates:
		var c := (load("res://scenes/prop_crate.tscn") as PackedScene).instantiate()
		c.name = "Crate%d" % k; k += 1; c.position = pos
		props.add_child(c)

	var ui := CanvasLayer.new(); ui.name = "UI"
	var score := Label.new(); score.name = "Score"; score.unique_name_in_owner = true
	score.text = "Eaten: 0"; score.position = Vector2(24, 16)
	score.add_theme_font_size_override("font_size", 32)
	score.add_theme_color_override("font_outline_color", Color.BLACK)
	score.add_theme_constant_override("outline_size", 8)
	ui.add_child(score); root.add_child(ui)
	# 全域刪除區：洞滑開後還在地底往下掉的東西，在這裡刪掉並計分
	var abyss := Area3D.new(); abyss.name = "Abyss"; abyss.unique_name_in_owner = true
	abyss.collision_layer = 0; abyss.collision_mask = PROPS
	abyss.position.y = -PIT_DEPTH - 4.0
	_box_shape(abyss, "Shape", Vector3(4 * GROUND_HALF, 1, 4 * GROUND_HALF), Vector3.ZERO)
	root.add_child(abyss)
	_save(root, "res://scenes/main.tscn")
	quit()


func _checker() -> Texture2D:
	var img := Image.create(2, 2, false, Image.FORMAT_RGB8)
	img.set_pixel(0, 0, Color("8cc46a")); img.set_pixel(1, 1, Color("8cc46a"))
	img.set_pixel(1, 0, Color("7cb35a")); img.set_pixel(0, 1, Color("7cb35a"))
	var t := ImageTexture.create_from_image(img)
	ResourceSaver.save(t, "res://scenes/floor_checker.tres")
	return load("res://scenes/floor_checker.tres")
