extends SceneTree
## 製作工具：產生 addons/proto_kit/polish3d/demo.tscn（POLISH-3D.md 每一項的示範）。存好後在編輯器改，不要重跑覆蓋。
##   godot --headless --path prototypes/godot-kit -s tools/build_polish3d_demo.gd
const D := "res://addons/proto_kit/polish3d/"


func _noise(freq: float, size := 256) -> NoiseTexture2D:
	var t := NoiseTexture2D.new(); t.width = size; t.height = size; t.seamless = true
	var n := FastNoiseLite.new(); n.frequency = freq; t.noise = n
	return t


func _mat(shader: String) -> ShaderMaterial:
	var m := ShaderMaterial.new(); m.shader = load(D + shader); return m


func _init() -> void:
	var root := Node3D.new(); root.name = "Polish3DDemo"

	# 2 天空＋雲＋環境光，3 AgX，4 SSAO/SSIL，5 SDFGI，6 霧
	var env := Environment.new()
	var sky := Sky.new(); var skym := _mat("sky.gdshader"); skym.set_shader_parameter("cloud_noise", _noise(0.006, 512))
	sky.sky_material = skym; env.sky = sky; env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY; env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_AGX; env.tonemap_exposure = 1.12; env.tonemap_agx_contrast = 1.32
	env.ssao_enabled = true; env.ssao_radius = 1.4; env.ssao_intensity = 2.4
	env.ssil_enabled = true; env.ssil_radius = 6.0
	env.sdfgi_enabled = true; env.sdfgi_energy = 1.3
	env.fog_enabled = true; env.fog_density = 0.0016; env.fog_aerial_perspective = 0.5
	env.fog_height = 0.6; env.fog_height_density = 0.035   # 地面薄霧：0.035 濃～0.007 淡
	var we := WorldEnvironment.new(); we.name = "WorldEnvironment"; we.environment = env
	var cam_attr := CameraAttributesPractical.new()
	cam_attr.dof_blur_far_enabled = true; cam_attr.dof_blur_far_distance = 30.0; cam_attr.dof_blur_far_transition = 20.0; cam_attr.dof_blur_amount = 0.06
	we.camera_attributes = cam_attr
	root.add_child(we)

	# 1 太陽：斜射、暖色、柔和陰影
	var sun := DirectionalLight3D.new(); sun.name = "Sun"
	sun.rotation_degrees = Vector3(-38, -35, 0); sun.light_color = Color(1.0, 0.92, 0.8); sun.light_energy = 1.2
	sun.shadow_enabled = true; sun.light_angular_distance = 1.1; sun.directional_shadow_max_distance = 60.0
	root.add_child(sun)

	# 11 鏡頭 FOV 55
	var cam := Camera3D.new(); cam.name = "Camera"; cam.fov = 55
	cam.position = Vector3(0, 3.2, 11); cam.rotation_degrees = Vector3(-10, 0, 0)
	root.add_child(cam)

	# 8 地面：兩種綠＋踩禿泥土（R）＋樹下（G）
	var ground := MeshInstance3D.new(); ground.name = "Ground"
	var pm := PlaneMesh.new(); pm.size = Vector2(80, 80); ground.mesh = pm
	var gm := _mat("ground.gdshader"); gm.set_shader_parameter("noise", _noise(0.05))
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	for y in 128:
		for x in 128:
			var p := Vector2(x, y) / 128.0 * 80.0 - Vector2(40, 40)   # 世界 xz
			var path := clampf(1.0 - absf(p.x - sin(p.y * 0.15) * 2.0) / 1.6, 0, 1)   # 一條踩禿的小路
			var tree := clampf(1.0 - Vector2(p.x + 5, p.y).length() / 4.0, 0, 1) + clampf(1.0 - Vector2(p.x - 6, p.y + 3).length() / 4.0, 0, 1)
			img.set_pixel(x, y, Color(path, minf(tree, 1.0), 0))
	gm.set_shader_parameter("mask", ImageTexture.create_from_image(img))
	ground.material_override = gm
	root.add_child(ground)

	# 7 樹：樹幹＋三團樹冠，樹冠用 foliage（法線從樹冠中心往外）
	for tp in [Vector3(-5, 0, 0), Vector3(6, 0, -3)]:
		var tree := Node3D.new(); tree.name = "Tree%d" % root.get_child_count(); tree.position = tp
		var trunk := MeshInstance3D.new(); trunk.name = "Trunk"
		var cy := CylinderMesh.new(); cy.top_radius = 0.18; cy.bottom_radius = 0.28; cy.height = 2.6; trunk.mesh = cy
		trunk.position.y = 1.3
		var tm := StandardMaterial3D.new(); tm.albedo_color = Color(0.33, 0.24, 0.17); trunk.material_override = tm
		tree.add_child(trunk)
		var fm := _mat("foliage.gdshader"); fm.set_shader_parameter("canopy_center", Vector3(0, 3.4, 0))
		for o in [Vector3(0, 3.6, 0), Vector3(0.8, 3.1, 0.3), Vector3(-0.7, 3.2, -0.4)]:
			var c := MeshInstance3D.new(); c.name = "Canopy%d" % tree.get_child_count()
			var sm := SphereMesh.new(); sm.radius = 1.3; sm.height = 2.3; c.mesh = sm
			c.position = o; c.material_override = fm
			# 子網格的頂點在自己的模型空間：canopy_center 換成相對這團的位置
			var own := fm.duplicate(); own.set_shader_parameter("canopy_center", Vector3(0, 3.4, 0) - o); c.material_override = own
			tree.add_child(c)
		root.add_child(tree)

	# 9 草：MultiMesh 分 chunk
	var gf := Node3D.new(); gf.name = "Grass"; gf.set_script(load(D + "grass_field.gd")); gf.add_to_group(&"grass", true)
	var grm := _mat("grass.gdshader"); grm.set_shader_parameter("wind_noise", _noise(0.02))
	gf.material = grm
	root.add_child(gf)

	# 10 角色只被自己的補光照到（cull mask），另加一盞燈籠
	var hero := MeshInstance3D.new(); hero.name = "Hero"; hero.mesh = CapsuleMesh.new(); hero.position = Vector3(0, 1, 5)
	hero.layers = 1 | 2
	var hm := StandardMaterial3D.new(); hm.albedo_color = Color(0.8, 0.3, 0.25); hero.material_override = hm
	root.add_child(hero)
	var rim := OmniLight3D.new(); rim.name = "HeroLight"; rim.light_energy = 0.7; rim.light_cull_mask = 2
	rim.omni_range = 4.0; rim.position = Vector3(0.8, 2.0, 6.5); root.add_child(rim)
	var lantern := OmniLight3D.new(); lantern.name = "Lantern"; lantern.light_color = Color(1, 0.7, 0.4)
	lantern.light_energy = 1.5; lantern.omni_range = 5.0; lantern.position = Vector3(-3.5, 1.6, 2.5); root.add_child(lantern)

	# 13 灰塵粒子＋後製
	var dust := GPUParticles3D.new(); dust.name = "Dust"; dust.amount = 200; dust.lifetime = 8.0; dust.position = Vector3(0, 2, 4)
	var ppm := ParticleProcessMaterial.new(); ppm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	ppm.emission_box_extents = Vector3(8, 2, 6); ppm.gravity = Vector3(0, -0.02, 0); ppm.initial_velocity_min = 0.05; ppm.initial_velocity_max = 0.2
	ppm.direction = Vector3(1, 0.2, 0); ppm.spread = 180.0; dust.process_material = ppm
	var qm := QuadMesh.new(); qm.size = Vector2(0.03, 0.03)
	var dm := StandardMaterial3D.new(); dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; dm.albedo_color = Color(1, 0.95, 0.8, 0.5); qm.material = dm
	dust.draw_pass_1 = qm; dust.visibility_aabb = AABB(Vector3(-10, -4, -8), Vector3(20, 8, 16))
	root.add_child(dust)
	var post := CanvasLayer.new(); post.name = "Post"; post.layer = 50
	var pr := ColorRect.new(); pr.name = "Rect"; pr.set_anchors_preset(Control.PRESET_FULL_RECT); pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pr.material = _mat("post.gdshader"); pr.add_to_group(&"post", true); post.add_child(pr)
	root.add_child(post)

	# 14 FPS 與逐項開關
	var hud := CanvasLayer.new(); hud.name = "PerfHud"; hud.set_script(load(D + "perf_hud.gd")); root.add_child(hud)

	for n in root.find_children("*", "", true, false):
		n.owner = root
	gf.build()   # 產生草 chunk（owner 設成 root）
	var count := root.find_children("*", "", true, false).size()
	var ps := PackedScene.new(); ps.pack(root)
	var path := D + "demo.tscn"
	var err := ResourceSaver.save(ps, path)
	print("save ", err, " nodes ", count, " -> ", load(path).instantiate().find_children("*", "", true, false).size())
	root.free()
	quit()
