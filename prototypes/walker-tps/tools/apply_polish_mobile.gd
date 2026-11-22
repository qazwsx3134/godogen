extends SceneTree
## 製作工具：產生 scenes/polish_overlay.tscn（13 暗角顆粒＋灰塵、14 FPS 開關；掛在 walker.tscn 底下）與雲的 noise。
## 天空／AgX／霧（2、3、6）是直接改四個戰場 scene 的 Environment。存好後在編輯器調，不要重跑覆蓋。
##   godot --headless --path prototypes/walker-tps -s tools/apply_polish_mobile.gd
const K := "res://addons/proto_kit/polish3d/"


func _count(n: Node) -> int:
	var c := 1
	for k in n.get_children(): c += _count(k)
	return c


func _save(root: Node, path: String) -> void:
	var before := _count(root)
	var ps := PackedScene.new(); ps.pack(root)
	var err := ResourceSaver.save(ps, path)
	var after := _count(load(path).instantiate())
	print(path, " save ", err, " nodes ", before, "->", after)
	root.free()


func _init() -> void:
	var cloud := NoiseTexture2D.new(); cloud.width = 512; cloud.height = 512; cloud.seamless = true
	var fn := FastNoiseLite.new(); fn.frequency = 0.006; cloud.noise = fn
	ResourceSaver.save(cloud, "res://assets/env/cloud_noise.tres")
	cloud = load("res://assets/env/cloud_noise.tres")
	var w := Node3D.new(); w.name = "PolishOverlay"
	# 13 後製：暗角＋顆粒，畫在速度模糊之上、HUD（layer 3）之下
	var post := CanvasLayer.new(); post.name = "Post"; post.layer = 1
	var rect := ColorRect.new(); rect.name = "Rect"; rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pm := ShaderMaterial.new(); pm.shader = load(K + "post.gdshader"); rect.material = pm
	post.add_child(rect); w.add_child(post)
	# 13 灰塵：跟著機甲的世界座標粒子
	var dust := GPUParticles3D.new(); dust.name = "Dust"; dust.amount = 160; dust.lifetime = 8.0
	dust.position = Vector3(0, 2, 0)
	var ppm := ParticleProcessMaterial.new(); ppm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	ppm.emission_box_extents = Vector3(10, 3, 10); ppm.gravity = Vector3(0, -0.02, 0)
	ppm.initial_velocity_min = 0.05; ppm.initial_velocity_max = 0.25; ppm.spread = 180.0
	dust.process_material = ppm
	var qm := QuadMesh.new(); qm.size = Vector2(0.025, 0.025)
	var dm := StandardMaterial3D.new(); dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; dm.billboard_keep_scale = true
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; dm.albedo_color = Color(1, 0.95, 0.85, 0.45)
	qm.material = dm; dust.draw_pass_1 = qm
	dust.visibility_aabb = AABB(Vector3(-14, -6, -14), Vector3(28, 12, 28))
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.add_child(dust)
	# 14 FPS＋F1–F9 逐項開關（左下，避開戰鬥 HUD）
	var hud := CanvasLayer.new(); hud.name = "PerfHud"; hud.set_script(load(K + "perf_hud.gd"))
	hud.label_position = Vector2(8, 560)
	w.add_child(hud)
	for n in [post, rect, dust, hud]: n.owner = w
	rect.add_to_group(&"post", true)
	_save(w, "res://scenes/polish_overlay.tscn")
	quit()
