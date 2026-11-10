extends SceneTree
## One-time generator for the walker-tps scenes (walker, arena, hud, main). After it has run, the .tscn files are
## the source: edit them in the editor. Re-running skips files that exist; `-- --overwrite` replaces them and
## loses hand edits, so check `git diff scenes/` first.
##   godot --headless --path . --script res://tools/build_scenes.gd
## Applied 2026-11-10.

const SceneBuilder = preload("res://addons/proto_kit/scene_builder.gd")

var _opts := {}

func _initialize() -> void:
	_opts = {"overwrite": "--overwrite" in OS.get_cmdline_user_args()}
	_build.call_deferred()

func _build() -> void:
	var ok := true
	ok = _save(_walker(), "res://scenes/walker.tscn", ["res://assets/walker/walker.glb"]) and ok
	ok = _save(_arena(), "res://scenes/arena.tscn", []) and ok
	ok = _save(_hud(), "res://scenes/hud.tscn", []) and ok
	ok = _save(_main(), "res://scenes/main.tscn",
			["res://scenes/walker.tscn", "res://scenes/arena.tscn", "res://scenes/hud.tscn"]) and ok
	quit(0 if ok else 1)

func _save(root: Node, path: String, refs: Array) -> bool:
	var o := _opts.duplicate()
	o["expected_refs"] = refs
	var r := SceneBuilder.save_scene(root, path, o)
	print("%s: %s" % [path, "skipped (exists)" if r.skipped else ("ok, %d nodes" % r.nodes if r.ok else r.error)])
	return r.ok

# ---------------------------------------------------------------- walker
func _walker() -> Node:
	var w := CharacterBody3D.new()
	w.name = "Walker"
	w.set_script(load("res://scripts/walker_player.gd"))
	w.floor_snap_length = 0.6
	w.floor_max_angle = deg_to_rad(40.0)

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 1.1
	cap.height = 2.6
	col.shape = cap
	col.position = Vector3(0, 1.3, 0)  # bottom of the capsule at the ground, like the GLB origin
	SceneBuilder.add(w, col, "Body")

	SceneBuilder.add(w, SceneBuilder.unique(SceneBuilder.instance("res://assets/walker/walker.glb")), "Model")
	var gait := Node.new()
	gait.set_script(load("res://scripts/walker_gait.gd"))
	SceneBuilder.add(w, SceneBuilder.unique(gait), "Gait")

	var dust := SceneBuilder.add(w, SceneBuilder.unique(Node3D.new()), "Dust")
	var puff_mat := StandardMaterial3D.new()
	puff_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	puff_mat.vertex_color_use_as_albedo = true
	puff_mat.albedo_color = Color(0.66, 0.6, 0.5)
	var soft := Gradient.new()  # round, soft-edged puff instead of a square quad
	soft.set_color(0, Color(1, 1, 1, 1))
	soft.set_color(1, Color(1, 1, 1, 0))
	var disc := GradientTexture2D.new()
	disc.gradient = soft
	disc.fill = GradientTexture2D.FILL_RADIAL
	disc.fill_from = Vector2(0.5, 0.5)
	disc.fill_to = Vector2(0.5, 0.0)
	disc.width = 64
	disc.height = 64
	puff_mat.albedo_texture = disc
	var quad := QuadMesh.new()
	quad.size = Vector2(0.7, 0.7)
	quad.material = puff_mat
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.65))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.5))
	grow.add_point(Vector2(1, 1.5))
	for i: int in 4:
		var p := CPUParticles3D.new()
		p.emitting = false
		p.one_shot = true
		p.amount = 12
		p.lifetime = 0.8
		p.explosiveness = 0.95
		p.local_coords = false
		p.mesh = quad
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 0.3
		p.direction = Vector3.UP
		p.spread = 80.0
		p.initial_velocity_min = 1.0
		p.initial_velocity_max = 2.4
		p.gravity = Vector3(0, -2.5, 0)
		p.damping_min = 2.0
		p.damping_max = 3.0
		p.scale_amount_min = 0.6
		p.scale_amount_max = 1.2
		p.scale_amount_curve = grow
		p.color_ramp = fade
		SceneBuilder.add(dust, p, "Puff%d" % i)

	var sound := AudioStreamPlayer3D.new()
	sound.unit_size = 8.0
	SceneBuilder.add(w, SceneBuilder.unique(sound), "StepSound")

	var rig := Node3D.new()
	rig.set_script(load("res://scripts/orbit_camera.gd"))
	rig.top_level = true
	SceneBuilder.add(w, SceneBuilder.unique(rig), "CameraRig")
	var pitch := SceneBuilder.add(rig, SceneBuilder.unique(Node3D.new()), "Pitch")
	var arm := SpringArm3D.new()
	arm.spring_length = 7.5
	arm.margin = 0.3
	var ball := SphereShape3D.new()
	ball.radius = 0.3
	arm.shape = ball
	SceneBuilder.add(pitch, SceneBuilder.unique(arm), "Arm")
	var cam := Camera3D.new()
	cam.current = true
	cam.fov = 70.0
	cam.far = 400.0
	SceneBuilder.add(arm, SceneBuilder.unique(cam), "Camera")
	return w

# ---------------------------------------------------------------- arena
func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m

func _block(parent: Node, name: String, size: Vector3, pos: Vector3, mat: Material, rot_deg := Vector3.ZERO) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation_degrees = rot_deg
	SceneBuilder.add(parent, body, name)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = mat
	SceneBuilder.add(body, mesh, "Mesh")
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	SceneBuilder.add(body, col, "Shape")

func _arena() -> Node:
	var a := Node3D.new()
	a.name = "Arena"
	# Color code (borrowed from ASCII District's readable routes): sand = cover, cyan = walkable route up,
	# coral = far landmarks to orient by, concrete = walls and gates.
	var sand := _mat(Color(0.58, 0.53, 0.44))
	var cyan := _mat(Color(0.25, 0.72, 0.78))
	var coral := _mat(Color(0.93, 0.46, 0.36))
	var concrete := _mat(Color(0.47, 0.47, 0.46))

	var ground := StaticBody3D.new()
	SceneBuilder.add(a, ground, "Ground")
	var plane := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(160, 160)
	plane.mesh = pm
	var grid := ShaderMaterial.new()
	grid.shader = load("res://shaders/grid_ground.gdshader")
	plane.material_override = grid
	SceneBuilder.add(ground, plane, "Mesh")
	var gcol := CollisionShape3D.new()
	var gbox := BoxShape3D.new()
	gbox.size = Vector3(160, 2, 160)
	gcol.shape = gbox
	gcol.position = Vector3(0, -1, 0)
	SceneBuilder.add(ground, gcol, "Shape")

	for i: int in 4:  # low perimeter walls
		var along_x := i < 2
		var s := 1.0 if i % 2 == 0 else -1.0
		_block(a, "Wall%d" % i, Vector3(120, 2, 1) if along_x else Vector3(1, 2, 120),
				Vector3(0, 1, s * 60) if along_x else Vector3(s * 60, 1, 0), concrete)

	var slope := rad_to_deg(atan(3.0 / 11.0))
	_block(a, "Ramp", Vector3(8, 0.4, 11.4), Vector3(14, 1.3, 13.5), cyan, Vector3(-slope, 0, 0))
	_block(a, "Platform", Vector3(10, 3, 10), Vector3(14, 1.5, 24), cyan)

	_block(a, "Barrier0", Vector3(5, 1.4, 1), Vector3(-8, 0.7, 10), sand)
	_block(a, "Barrier1", Vector3(5, 1.4, 1), Vector3(-15, 0.7, 17), sand, Vector3(0, 30, 0))
	_block(a, "Barrier2", Vector3(5, 1.4, 1), Vector3(6, 0.7, -12), sand)
	_block(a, "Barrier3", Vector3(5, 1.4, 1), Vector3(-4, 0.7, -18), sand, Vector3(0, -20, 0))
	_block(a, "Crate0", Vector3(2.5, 2.5, 2.5), Vector3(-20, 1.25, -4), sand)
	_block(a, "Crate1", Vector3(2.5, 2.5, 2.5), Vector3(-22.6, 1.25, -2.5), sand, Vector3(0, 15, 0))
	_block(a, "Crate2", Vector3(2.5, 2.5, 2.5), Vector3(-21.2, 3.75, -3.2), sand, Vector3(0, 40, 0))

	_block(a, "GatePillarL", Vector3(2, 7, 2), Vector3(18, 3.5, -10), concrete)
	_block(a, "GatePillarR", Vector3(2, 7, 2), Vector3(28, 3.5, -10), concrete)
	_block(a, "GateBeam", Vector3(12, 1.5, 2), Vector3(23, 7.75, -10), concrete)

	_block(a, "TowerNW", Vector3(5, 14, 5), Vector3(-40, 7, 40), coral)
	_block(a, "TowerSE", Vector3(5, 14, 5), Vector3(42, 7, -38), coral)
	return a

# ---------------------------------------------------------------- hud
func _round(radius: int, bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	return s

func _hud() -> Node:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	hud.set_script(load("res://scripts/hud.gd"))

	var touch := Control.new()
	touch.set_script(load("res://scripts/touch_input.gd"))
	touch.set_anchors_preset(Control.PRESET_FULL_RECT)
	touch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	touch.add_to_group("touch_input", true)  # persistent: registered on enter_tree, before walker._ready
	SceneBuilder.add(hud, SceneBuilder.unique(touch), "TouchInput")
	var base := Panel.new()
	base.size = Vector2(180, 180)
	base.position = Vector2(140, 440)  # editor preview spot; moves under the finger at runtime
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.add_theme_stylebox_override("panel", _round(90, Color(1, 1, 1, 0.1), Color(1, 1, 1, 0.35), 3))
	SceneBuilder.add(touch, SceneBuilder.unique(base), "StickBase")
	var knob := Panel.new()
	knob.size = Vector2(80, 80)
	knob.position = Vector2(50, 50)
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	knob.add_theme_stylebox_override("panel", _round(40, Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.0), 0))
	SceneBuilder.add(base, SceneBuilder.unique(knob), "StickKnob")

	var stats := Label.new()
	stats.text = "FPS -- · draw calls --"
	stats.position = Vector2(16, 12)
	stats.add_theme_font_size_override("font_size", 18)
	stats.add_theme_constant_override("outline_size", 4)
	stats.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(hud, SceneBuilder.unique(stats), "Stats")

	var hint := Label.new()
	hint.text = "WASD / left stick: move   Shift / RB: sprint   Space / A: jump   mouse / right stick: look (click to lock, Esc to free)\n" \
			+ "touch: left half = move, right half = look, corner buttons = JUMP / BOOST"
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.offset_left = 16
	hint.offset_top = -64
	hint.offset_bottom = -12
	hint.offset_right = 900
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_constant_override("outline_size", 4)
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(hud, hint, "Hint")
	return hud

# ---------------------------------------------------------------- main
func _main() -> Node:
	var main := Node3D.new()
	main.name = "Main"

	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.24, 0.38, 0.56)
	sky_mat.sky_horizon_color = Color(0.64, 0.62, 0.58)
	sky_mat.ground_horizon_color = Color(0.6, 0.56, 0.5)
	sky_mat.ground_bottom_color = Color(0.3, 0.28, 0.25)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR  # warm, so the cream paint does not read blue
	env.ambient_light_color = Color(0.58, 0.54, 0.48)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.fog_enabled = true
	env.fog_light_color = Color(0.74, 0.7, 0.62)
	env.fog_density = 0.006
	var we := WorldEnvironment.new()
	we.environment = env
	SceneBuilder.add(main, we, "WorldEnvironment")

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.0
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45.0
	SceneBuilder.add(main, sun, "Sun")

	SceneBuilder.add(main, SceneBuilder.instance("res://scenes/arena.tscn"), "Arena")
	var walker := SceneBuilder.instance("res://scenes/walker.tscn") as Node3D
	walker.position = Vector3(0, 0.05, 0)
	SceneBuilder.add(main, walker, "Walker")
	SceneBuilder.add(main, SceneBuilder.instance("res://scenes/hud.tscn"), "HUD")
	return main
