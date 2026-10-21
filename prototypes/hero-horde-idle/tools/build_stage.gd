extends SceneTree
## One-time authoring tool for the HD-2D stage: writes the environment, camera attributes, stage materials, the
## camera shots and scenes/stage.tscn, then puts the stage into main.tscn (replacing the old flat Ground) and gives
## the camera its director script and main its shots.
##   godot --headless --path prototypes/hero-horde-idle --script res://tools/build_stage.gd
## Existing resources and stage.tscn are kept, so hand edits survive a rerun; main.tscn is only patched while it still
## has its old Ground node. After the first run the saved files are the source: edit them in the editor, not here.

const SceneBuilder = preload("res://addons/proto_kit/scene_builder.gd")
const CameraShot = preload("res://scripts/camera_shot.gd")

const STAGE := "res://scenes/stage.tscn"
const MAIN := "res://scenes/main.tscn"
const GRASS := "res://assets/stage/grass.png"
const ARENA := "res://assets/stage/arena.png"
const CLIFF := "res://assets/stage/cliff.png"
const BOSS_AT := Vector3(3.7, 0.0, 0.0)

var _failed: bool = false


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var env: Environment = _keep(_environment(), "res://materials/stage_environment.tres")
	var attrs: CameraAttributesPractical = _keep(_camera_attributes(), "res://materials/stage_camera_attributes.tres")
	var ground: ShaderMaterial = _keep(_ground_material(), "res://materials/stage_ground.tres")
	var cliff: StandardMaterial3D = _keep(_cliff_material(), "res://materials/stage_cliff.tres")
	var cap: StandardMaterial3D = _keep(_cap_material(), "res://materials/stage_cliff_cap.tres")
	var mote: StandardMaterial3D = _keep(_glow_material(Color(1.0, 0.86, 0.5)), "res://materials/stage_mote.tres")
	var ember: StandardMaterial3D = _keep(_glow_material(Color(1.0, 0.55, 0.2)), "res://materials/stage_ember.tres")
	var shots := {
		"volley_shot": _keep(_shot(3.2, 6.0, -4.0, -3.0, 0.22, 0.75, 0.55, 2, 0.08, 0.5), "res://camera/volley.tres"),
		"break_shot": _keep(_shot(2.4, -3.0, 0.0, -2.0, 0.14, 0.5, 0.4, 2, 0.1, 0.35), "res://camera/break.tres"),
		"phase2_shot": _keep(_shot(1.8, 0.0, -7.0, 2.0, 0.35, 0.9, 0.6, 3, 0.12, 0.8), "res://camera/phase2.tres"),
		"won_shot": _keep(_shot(4.5, -8.0, -5.0, -4.0, 1.4, -1.0, 0.6, 9, 0.0, 0.6), "res://camera/won.tres"),
	}
	if _failed:
		quit(1)
		return
	var result: Dictionary = SceneBuilder.save_scene(_stage(env, attrs, ground, cliff, cap, mote, ember), STAGE)
	if not result.ok:
		quit(1)
		return
	quit(0 if _patch_main(shots) else 1)


func _stage(env: Environment, attrs: CameraAttributes, ground: Material, cliff: Material, cap_material: Material,
		mote: Material, ember: Material) -> Node3D:
	var stage := Node3D.new()
	stage.name = "Stage"
	stage.set_script(load("res://scripts/stage.gd"))

	var world := WorldEnvironment.new()
	world.environment = env
	world.camera_attributes = attrs
	SceneBuilder.add(stage, world, "WorldEnvironment")

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.8, 0.6)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.8
	sun.shadow_blur = 1.5
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 40.0
	# Low sun from the upper left of the screen (far side), so shadows fall toward the lower right like the art's light.
	var sun_at := Vector3(-7.0, 7.0, -9.0)
	sun.transform = Transform3D(Basis.looking_at(-sun_at), sun_at)
	SceneBuilder.add(stage, SceneBuilder.unique(sun), "Sun")

	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(60.0, 60.0)
	var floor_node := MeshInstance3D.new()
	floor_node.mesh = floor_mesh
	floor_node.material_override = ground
	floor_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	SceneBuilder.add(stage, SceneBuilder.unique(floor_node), "Floor")

	# Back wall of the valley: rock blocks of uneven height, a taller second row behind.
	var cliffs := SceneBuilder.add(stage, SceneBuilder.unique(Node3D.new()), "Cliffs") as Node3D
	# [x, z, height, width]; a grass cap sits on each block.
	var rows := [
		[-9.0, -11.5, 2.2, 3.5], [-5.2, -12.0, 3.0, 4.0], [-1.0, -11.8, 2.0, 4.2], [2.6, -12.6, 3.4, 3.6],
		[6.4, -11.6, 2.4, 4.0], [10.2, -12.2, 3.0, 4.2], [-7.0, -15.5, 5.0, 6.0], [0.5, -16.0, 5.6, 6.5],
		[8.0, -15.8, 5.2, 6.0],
	]
	for k: int in rows.size():
		var r: Array = rows[k]
		var box := BoxMesh.new()
		box.size = Vector3(r[3], r[2], 3.0)
		var block := MeshInstance3D.new()
		block.mesh = box
		block.material_override = cliff
		block.position = Vector3(r[0], r[2] * 0.5, r[1])
		block.rotation.y = deg_to_rad([4.0, -6.0, 3.0, -2.0, 7.0, -5.0, 2.0, -3.0, 5.0][k])
		SceneBuilder.add(cliffs, block, "Cliff_%d" % (k + 1))
		var cap_mesh := BoxMesh.new()
		cap_mesh.size = Vector3(r[3] + 0.2, 0.25, 3.2)
		var cap := MeshInstance3D.new()
		cap.mesh = cap_mesh
		cap.material_override = cap_material
		cap.position = Vector3(0.0, r[2] * 0.5, 0.0)
		SceneBuilder.add(block, cap, "Cap")

	SceneBuilder.add(stage, SceneBuilder.unique(Node3D.new()), "Props")

	var braziers := SceneBuilder.add(stage, SceneBuilder.unique(Node3D.new()), "BrazierLights") as Node3D
	for side: int in [-1, 1]:
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.6, 0.28)
		light.light_energy = 1.6
		light.omni_range = 5.0
		light.position = BOSS_AT + Vector3(side * 2.6, 1.3, -4.6)
		SceneBuilder.add(braziers, light, "Brazier_L" if side < 0 else "Brazier_R")
		SceneBuilder.add(stage, _embers(ember, light.position), "Embers_L" if side < 0 else "Embers_R")

	var tele := SceneBuilder.add(stage, SceneBuilder.unique(Node3D.new()), "TelegraphLights") as Node3D
	for k: int in 3:
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.18, 0.1)
		light.omni_range = 3.4
		light.position = Vector3(0.0, 1.1, 0.0)
		light.visible = false
		SceneBuilder.add(tele, light, "Telegraph_%d" % (k + 1))

	var volley := OmniLight3D.new()
	volley.light_color = Color(1.0, 0.82, 0.4)
	volley.omni_range = 9.0
	volley.visible = false
	SceneBuilder.add(stage, SceneBuilder.unique(volley), "VolleyLight")

	SceneBuilder.add(stage, _motes(mote), "Motes")

	var layer := CanvasLayer.new()
	layer.layer = 0
	SceneBuilder.add(stage, layer, "Vignette")
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vignette := ShaderMaterial.new()
	vignette.shader = load("res://shaders/vignette.gdshader")
	shade.material = vignette
	SceneBuilder.add(layer, shade, "Shade")
	return stage


## Drifting warm motes over the whole field: the dusk air catching the light.
func _motes(material: Material) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 48
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.position = Vector3(1.0, 1.6, -1.0)
	p.visibility_aabb = AABB(Vector3(-12.0, -3.0, -12.0), Vector3(24.0, 8.0, 24.0))
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(8.0, 1.4, 7.0)
	m.gravity = Vector3(0.0, 0.03, 0.0)
	m.direction = Vector3(1.0, 0.3, 0.0)
	m.spread = 180.0
	m.initial_velocity_min = 0.05
	m.initial_velocity_max = 0.25
	m.scale_min = 0.5
	m.scale_max = 1.0
	m.color_ramp = _fade_ramp()
	p.process_material = m
	p.draw_pass_1 = _glow_quad(material, 0.07)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func _embers(material: Material, at: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 14
	p.lifetime = 1.4
	p.preprocess = 1.4
	p.position = at + Vector3(0.0, -0.3, 0.0)
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.2
	m.gravity = Vector3(0.0, 1.2, 0.0)
	m.direction = Vector3(0.0, 1.0, 0.0)
	m.spread = 25.0
	m.initial_velocity_min = 0.3
	m.initial_velocity_max = 0.8
	m.color_ramp = _fade_ramp()
	p.process_material = m
	p.draw_pass_1 = _glow_quad(material, 0.06)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func _fade_ramp() -> GradientTexture1D:
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
	g.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	g.add_point(0.2, Color(1.0, 1.0, 1.0, 1.0))
	g.add_point(0.75, Color(1.0, 1.0, 1.0, 0.8))
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


func _glow_quad(material: Material, size: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = material
	return q


## Unshaded additive square, bright enough to bloom; billboarded, coloured by the particle ramp.
func _glow_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = color * 2.2
	m.disable_receive_shadows = true
	return m


func _environment() -> Environment:
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.18, 0.16, 0.24)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.64, 0.9)
	e.ambient_light_energy = 0.85
	# Linear keeps the pixel art's palette as painted; only HDR highlights (motes, flashes, fire) bloom.
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	e.glow_enabled = true
	e.glow_intensity = 0.5
	e.glow_strength = 1.0
	e.glow_bloom = 0.0
	e.glow_hdr_threshold = 1.05
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_DEPTH
	e.fog_light_color = Color(0.78, 0.64, 0.62)
	e.fog_density = 0.55
	e.fog_depth_begin = 17.0
	e.fog_depth_end = 34.0
	e.fog_sky_affect = 0.0
	e.adjustment_enabled = true
	e.adjustment_brightness = 1.06
	e.adjustment_contrast = 1.06
	e.adjustment_saturation = 1.12
	return e


## Tilt-shift: the far side of the valley (cliffs, the gate) goes soft, the field stays sharp.
func _camera_attributes() -> CameraAttributesPractical:
	var a := CameraAttributesPractical.new()
	a.dof_blur_far_enabled = true
	a.dof_blur_far_distance = 19.0
	a.dof_blur_far_transition = 6.0
	a.dof_blur_amount = 0.08
	return a


func _ground_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/ground.gdshader")
	m.set_shader_parameter(&"grass", load(GRASS))
	m.set_shader_parameter(&"arena", load(ARENA))
	return m


func _cap_material() -> StandardMaterial3D:
	var m := _cliff_material()
	m.albedo_texture = load(GRASS)
	return m


func _cliff_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(CLIFF)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.42, 0.42, 0.42)
	m.roughness = 1.0
	return m


func _shot(push: float, yaw: float, pitch: float, fov_delta: float, ease_in: float, hold: float, ease_out: float,
		priority: int, hit_stop: float, trauma: float) -> Resource:
	var s: Resource = CameraShot.new()
	s.push_m = push
	s.yaw_deg = yaw
	s.pitch_deg = pitch
	s.fov_delta = fov_delta
	s.ease_in = ease_in
	s.hold = hold
	s.ease_out = ease_out
	s.priority = priority
	s.hit_stop = hit_stop
	s.trauma = trauma
	return s


## Swaps main.tscn's flat Ground for the stage, gives the camera the director script, and hands main its shots.
func _patch_main(shots: Dictionary) -> bool:
	var main: Node = (load(MAIN) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var old: Node = main.get_node_or_null("Ground")
	if old == null:
		print("skip (already patched): ", MAIN)
		main.free()
		return true
	var at: int = old.get_index()
	main.remove_child(old)
	old.free()
	var stage: Node = SceneBuilder.instance(STAGE)
	stage.name = "Stage"
	main.add_child(stage)
	main.move_child(stage, at)
	stage.unique_name_in_owner = true
	var camera := main.get_node("Camera") as Camera3D
	camera.set_script(load("res://scripts/camera_director.gd"))
	for key: String in shots:
		main.set(key, shots[key])
	var result: Dictionary = SceneBuilder.save_scene(main, MAIN, {"overwrite": true,
		"expected_refs": ["res://scenes/hud.tscn", STAGE]})
	return result.ok


func _keep(resource: Resource, path: String) -> Resource:
	if ResourceLoader.exists(path):
		print("keep (exists): ", path)
		return load(path)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var error: Error = ResourceSaver.save(resource, path)
	if error != OK:
		push_error("cannot save %s: %s" % [path, error_string(error)])
		_failed = true
		return resource
	print("saved: ", path)
	return load(path)
