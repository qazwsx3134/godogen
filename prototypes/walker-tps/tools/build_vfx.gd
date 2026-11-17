extends SceneTree
## Layered GPU-particle muzzle flash and impact, after the GODOT VFX tutorials
## "Muzzle Flash Effect" (YuCvAwZ3OlQ) and "Hits and Impacts" (uDjR7F-aOsc):
## additive unshaded layers with their own lifetimes, scale curves and alpha fades,
## sparks stretched along their velocity. Smoke, ground ring and a short light are
## added for cannon-sized blasts so they read as explosions rather than energy hits.
##
## Two passes, because generated PNGs must be imported before scenes can use them:
##   godot --headless --path . --script res://tools/build_vfx.gd -- textures
##   godot --headless --path . --editor --quit
##   godot --headless --path . --script res://tools/build_vfx.gd -- scenes
## The scenes pass also removes the Boss's added legs (the model's own thin legs touch
## the ground) and swaps the walker's sphere muzzle flash for the particle scene.
##   godot --headless --path . --script res://tools/build_vfx.gd -- charge   (Boss beam charge only)
##   ... -- fiber, import, then -- wings   (Boss second-form fibre wings and strands only;
##   run wings under xvfb-run WITHOUT --headless: the dummy renderer drops MultiMesh buffers on save)
## Applied 2026-11-16. Scenes are editable sources now; rerunning `scenes` replaces
## combat_impact.tscn's Fx node and muzzle_flash.tscn, so check the diff first.

const Builder = preload("res://addons/proto_kit/scene_builder.gd")
const TEX := "res://assets/vfx/"
const S := 128

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if "textures" in args: _textures()
	if "scenes" in args: quit(0 if _scenes() else 1)
	elif "charge" in args: quit(0 if _charge() else 1)
	elif "fiber" in args: _fiber_texture(); quit(0)
	elif "wings" in args: quit(0 if _wings() else 1)
	else: quit(0)

# ---------- textures ----------

func _textures() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEX))
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.05
	_paint("glow", func(x: float, y: float) -> float:
		return pow(maxf(0.0, 1.0 - Vector2(x, y).length()), 2.2))
	_paint("ring", func(x: float, y: float) -> float:
		var r := Vector2(x, y).length()
		return clampf(1.0 - absf(r - 0.82) / 0.12, 0.0, 1.0) * (1.0 if r < 1.0 else 0.0))
	_paint("flare", func(x: float, y: float) -> float:
		var fall := maxf(0.0, 1.0 - Vector2(x, y).length())
		var cross := maxf(exp(-absf(x) * 28.0), exp(-absf(y) * 28.0))
		return clampf(cross * fall + pow(fall, 6.0), 0.0, 1.0))
	# Muzzle petal: u runs along the barrel (pivot at u=0), jagged flame edges.
	_paint("muzzle", func(x: float, y: float) -> float:
		var u := (x + 1.0) * 0.5
		var w := 0.55 * sin(PI * pow(u, 0.55)) * (1.0 - u * 0.35)
		var spikes := 0.65 + 0.35 * absf(sin(u * 23.0 + 1.3)) * (1.0 + noise.get_noise_2d(u * 128.0, y * 40.0))
		var edge := clampf(1.0 - absf(y) / maxf(0.001, w * spikes), 0.0, 1.0)
		return pow(edge, 1.6) * clampf((1.0 - u) * 3.0, 0.0, 1.0))
	_paint("smoke", func(x: float, y: float) -> float:
		var r := Vector2(x, y).length()
		var n := 0.6 + 0.4 * noise.get_noise_2d(x * 64.0 + 200.0, y * 64.0)
		return clampf(pow(maxf(0.0, 1.0 - r), 1.4) * n * 1.5, 0.0, 1.0))
	print("VFX_TEXTURES_WRITTEN")

func _paint(name: String, alpha: Callable) -> void:
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	for py in S:
		for px in S:
			var a: float = alpha.call((px + 0.5) / S * 2.0 - 1.0, (py + 0.5) / S * 2.0 - 1.0)
			img.set_pixel(px, py, Color(1, 1, 1, a))
	img.save_png(TEX + name + ".png")

# ---------- scene helpers ----------

func _curve(points: Array) -> CurveTexture:
	var c := Curve.new()
	c.max_value = 4.0  # default range clamps growth to 1
	for p: Vector2 in points: c.add_point(p)
	var t := CurveTexture.new()
	t.curve = c
	return t

func _mat(tex: String, additive := true, billboard := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = load(TEX + tex + ".png")
	m.disable_receive_shadows = true
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.billboard_keep_scale = true
	return m

## One one-shot particle layer. `p` keys: amount, life, scale [min,max], color,
## grow (scale curve points), velocity [min,max], spread, gravity, damping, explosive.
func _layer(name: String, mesh: Mesh, mat: Material, p: Dictionary) -> GPUParticles3D:
	var g := GPUParticles3D.new()
	g.name = name
	g.one_shot = not p.get("loop", false)
	g.emitting = false
	g.amount = p.get("amount", 1)
	g.lifetime = p.get("life", 0.2)
	g.explosiveness = 0.0 if p.get("loop", false) else 1.0
	g.randomness = 0.5
	g.fixed_fps = 60
	# Local space so the parent scale (impact radius) applies; muzzle sparks/smoke opt out to trail.
	g.local_coords = p.get("local", true)
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.visibility_aabb = AABB(Vector3(-8, -8, -8), Vector3(16, 16, 16))
	g.transform_align = p.get("align", GPUParticles3D.TRANSFORM_ALIGN_DISABLED)
	if mesh is ArrayMesh: (mesh as ArrayMesh).surface_set_material(0, mat)
	else: mesh.set("material", mat)
	g.draw_pass_1 = mesh
	var pm := ParticleProcessMaterial.new()
	pm.gravity = p.get("gravity", Vector3.ZERO)
	pm.direction = p.get("dir", Vector3(0, 0, 1))
	pm.spread = p.get("spread", 0.0)
	var v: Array = p.get("velocity", [0.0, 0.0])
	pm.initial_velocity_min = v[0]
	pm.initial_velocity_max = v[1]
	pm.damping_min = p.get("damping", 0.0)
	pm.damping_max = p.get("damping", 0.0)
	var sc: Array = p.get("scale", [1.0, 1.0])
	pm.scale_min = sc[0]
	pm.scale_max = sc[1]
	pm.scale_curve = _curve(p.get("grow", [Vector2(0, 0.3), Vector2(1, 1)]))
	pm.alpha_curve = _curve(p.get("fade", [Vector2(0, 1), Vector2(1, 0)]))
	pm.color = p.get("color", Color.WHITE)
	if p.has("ramp"):
		var gt := GradientTexture1D.new()
		gt.gradient = p.ramp
		pm.color_ramp = gt
	if p.has("box"):
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = p.box
	pm.angle_min = -180.0 if p.get("spin", false) else 0.0
	pm.angle_max = 180.0 if p.get("spin", false) else 0.0
	if p.get("align_y", false): pm.particle_flag_align_y = true
	pm.radial_accel_min = p.get("radial", 0.0)
	pm.radial_accel_max = p.get("radial", 0.0)
	if p.get("shell", false): pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
	g.process_material = pm
	return g

func _quad(size := Vector2.ONE, face := PlaneMesh.FACE_Z) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = size
	q.orientation = face
	return q

## Two planes crossed along +Z with the pivot at z=0 (tutorial's Blender mesh).
func _cross_planes() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis: Vector3 in [Vector3.RIGHT, Vector3.UP]:
		var a := axis * 0.5
		var quad := [[-a, Vector2(0, 0)], [-a + Vector3(0, 0, 1), Vector2(1, 0)], [a + Vector3(0, 0, 1), Vector2(1, 1)], [a, Vector2(0, 1)]]
		for i: int in [0, 1, 2, 0, 2, 3]:
			st.set_uv(quad[i][1])
			st.add_vertex(quad[i][0])
	return st.commit()

func _fire_ramp() -> Gradient:
	var gr := Gradient.new()
	gr.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
	gr.colors = PackedColorArray([Color(1.0, 0.95, 0.75), Color(1.0, 0.55, 0.12), Color(0.55, 0.12, 0.03), Color(0.1, 0.03, 0.02)])
	return gr

# ---------- scenes ----------

func _scenes() -> bool:
	var ok := true
	# Muzzle flash: petals along +Z, cone flash, sparks, a puff of smoke.
	var muzzle := Node3D.new()
	muzzle.name = "MuzzleFlash"
	muzzle.set_script(load("res://scripts/one_shot_fx.gd"))
	Builder.add(muzzle, _layer("Planes", _cross_planes(), _mat("muzzle", true, false), {
		"life": 0.09, "scale": [2.6, 3.2], "color": Color(1.0, 0.62, 0.22), "local": true,
		"grow": [Vector2(0, 0.35), Vector2(0.3, 1.0), Vector2(1, 0.8)]}))
	Builder.add(muzzle, _layer("Flash", _quad(), _mat("glow"), {
		"life": 0.07, "scale": [2.4, 2.8], "color": Color(1.0, 0.8, 0.45), "local": true}))
	Builder.add(muzzle, _layer("Sparks", _quad(Vector2(0.08, 0.6)), _mat("glow", true, false), {
		"amount": 14, "life": 0.3, "scale": [0.6, 1.0], "color": Color(1.0, 0.7, 0.3),
		"velocity": [14.0, 26.0], "spread": 12.0, "damping": 20.0, "align_y": true, "local": false,
		"align": GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY, "fade": [Vector2(0, 1), Vector2(1, 0)]}))
	Builder.add(muzzle, _layer("Smoke", _quad(), _mat("smoke", false), {
		"amount": 5, "life": 0.9, "scale": [0.9, 1.5], "color": Color(0.55, 0.53, 0.5, 0.55), "spin": true, "local": false,
		"velocity": [2.0, 5.0], "spread": 25.0, "damping": 6.0, "gravity": Vector3(0, 0.6, 0),
		"grow": [Vector2(0, 0.4), Vector2(1, 1.6)], "fade": [Vector2(0, 0.8), Vector2(1, 0)]}))
	var muzzle_light := OmniLight3D.new()
	muzzle_light.light_color = Color(1.0, 0.65, 0.3)
	muzzle_light.light_energy = 0.0
	muzzle_light.omni_range = 7.0
	muzzle_light.position.z = 0.8
	Builder.add(muzzle, muzzle_light, "Light")
	muzzle.set("light_energy", 4.0)
	muzzle.set("light_time", 0.08)
	ok = Builder.save_scene(muzzle, "res://scenes/muzzle_flash.tscn", {"overwrite": true}).ok and ok

	# Impact: everything shares one Fx node so combat_impact.gd can scale it by radius.
	var fx := Node3D.new()
	Builder.add(fx, _layer("Flash", _quad(), _mat("glow"), {
		"life": 0.1, "scale": [2.6, 3.0], "color": Color(1.0, 0.75, 0.4)}))
	Builder.add(fx, _layer("Flare", _quad(), _mat("flare"), {
		"life": 0.2, "scale": [3.2, 3.6], "color": Color(1.0, 0.6, 0.25),
		"grow": [Vector2(0, 1), Vector2(0.7, 0.9), Vector2(1, 0.2)]}))
	Builder.add(fx, _layer("Sparks", _quad(Vector2(0.06, 0.7)), _mat("glow", true, false), {
		"amount": 20, "life": 0.5, "scale": [0.5, 1.0], "color": Color(1.0, 0.65, 0.3),
		"dir": Vector3.UP, "spread": 180.0, "velocity": [5.0, 18.0], "damping": 4.0,
		"gravity": Vector3(0, -12, 0), "align_y": true,
		"align": GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY}))
	Builder.add(fx, _layer("Smoke", _quad(), _mat("smoke", false), {
		"amount": 10, "life": 1.4, "scale": [1.2, 2.0], "color": Color(0.3, 0.28, 0.26, 0.95), "spin": true,
		"dir": Vector3.UP, "spread": 70.0, "velocity": [1.0, 3.0], "damping": 1.5, "box": 0.4,
		"gravity": Vector3(0, 1.2, 0), "grow": [Vector2(0, 0.4), Vector2(1, 1.8)],
		"fade": [Vector2(0, 0.0), Vector2(0.12, 1.0), Vector2(1, 0)]}))
	# Cannon-sized only (combat_impact.gd hides these under radius 2).
	Builder.add(fx, _layer("Fireball", _quad(), _mat("smoke"), {
		"amount": 14, "life": 0.6, "scale": [1.8, 2.8], "ramp": _fire_ramp(), "spin": true,
		"dir": Vector3.UP, "spread": 80.0, "velocity": [2.0, 6.0], "damping": 6.0, "box": 0.5,
		"gravity": Vector3(0, 2.0, 0), "grow": [Vector2(0, 0.5), Vector2(1, 1.4)]}))
	Builder.add(fx, _layer("Shockwave", _quad(Vector2.ONE, PlaneMesh.FACE_Y), _mat("ring", true, false), {
		"life": 0.4, "scale": [5.0, 5.5], "color": Color(1.0, 0.7, 0.4, 0.5),
		"grow": [Vector2(0, 0.15), Vector2(1, 1.0)]}))
	Builder.add(fx, _layer("Debris", _quad(Vector2(0.18, 0.18)), _mat("smoke", false), {
		"amount": 12, "life": 1.1, "scale": [0.6, 1.2], "color": Color(0.12, 0.1, 0.09), "spin": true,
		"dir": Vector3.UP, "spread": 55.0, "velocity": [6.0, 14.0], "gravity": Vector3(0, -18, 0),
		"grow": [Vector2(0, 1), Vector2(1, 1)], "fade": [Vector2(0, 1), Vector2(0.8, 1), Vector2(1, 0)]}))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.light_energy = 0.0
	light.omni_range = 9.0
	light.position.y = 0.8
	Builder.add(fx, light, "Light")
	var impact := Builder.open_scene("res://scenes/combat_impact.tscn")
	for old: String in ["Flash", "Explosion"]:
		var n: Node = impact.root.get_node_or_null(old)
		if n: impact.root.remove_child(n); n.free()
	Builder.put(impact.root, fx, "Fx", 0)
	ok = Builder.save_scene(impact.root, "res://scenes/combat_impact.tscn", {"overwrite": true}).ok and ok

	var walker := Builder.open_scene("res://scenes/walker_combat.tscn")
	var flash := Builder.instance("res://scenes/muzzle_flash.tscn") as Node3D
	flash.top_level = true
	var old_flash: Node = walker.root.get_node("MuzzleFlash")
	var index: int = old_flash.get_index()
	Builder.put(walker.root, flash, "MuzzleFlash", index)
	var refs: Array = walker.refs
	refs.append("res://scenes/muzzle_flash.tscn")
	ok = Builder.save_scene(walker.root, "res://scenes/walker_combat.tscn", {"overwrite": true, "expected_refs": refs}).ok and ok

	var boss := Builder.open_scene("res://scenes/boss.tscn")
	var legs: Node = boss.root.get_node_or_null("Legs")
	if legs: boss.root.remove_child(legs); legs.free()
	var boss_refs: Array = boss.refs.filter(func(r: String) -> bool: return r != "res://scenes/boss_leg.tscn")
	ok = Builder.save_scene(boss.root, "res://scenes/boss.tscn", {"overwrite": true, "expected_refs": boss_refs}).ok and ok
	return ok

## Boss beam charge: energy streaks pulled into a growing core at the head cannon's
## muzzle. boss.gd drives Core scale, Gather emitting and Light energy per frame.
## Targeted pass (does not touch the other scenes): -- charge
func _charge() -> bool:
	var charge := Node3D.new()
	charge.name = "BossCharge"
	charge.visible = false
	# Alpha-blended, not additive: additive orange vanishes against the white hull and pale sky.
	Builder.add(charge, _layer("Gather", _quad(Vector2(0.18, 1.2)), _mat("glow", false, false), {
		"loop": true, "amount": 64, "life": 0.45, "scale": [0.8, 1.4], "color": Color(1.0, 0.42, 0.08),
		"box": 4.0, "shell": true, "radial": -38.0, "align_y": true,
		"align": GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY,
		"grow": [Vector2(0, 1), Vector2(1, 0.3)], "fade": [Vector2(0, 0), Vector2(0.3, 1), Vector2(1, 0.6)]}))
	var core := MeshInstance3D.new()
	core.mesh = _quad()
	var core_mat := _mat("glow", false)
	core_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	core_mat.billboard_keep_scale = true  # boss.gd grows the core by node scale
	core_mat.vertex_color_use_as_albedo = false
	core_mat.albedo_color = Color(1.0, 0.5, 0.12)
	core_mat.no_depth_test = true  # the glow reads through the head armour around the muzzle
	core.material_override = core_mat
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Builder.add(charge, core, "Core")
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.light_energy = 0.0
	light.omni_range = 14.0
	Builder.add(charge, light, "Light")
	var ok: bool = Builder.save_scene(charge, "res://scenes/boss_charge.tscn", {"overwrite": true}).ok
	var boss := Builder.open_scene("res://scenes/boss.tscn")
	var node := Builder.instance("res://scenes/boss_charge.tscn") as Node3D
	node.top_level = true
	Builder.put(boss.root, node, "Charge")
	var refs: Array = boss.refs
	if not refs.has("res://scenes/boss_charge.tscn"): refs.append("res://scenes/boss_charge.tscn")
	return Builder.save_scene(boss.root, "res://scenes/boss.tscn", {"overwrite": true, "expected_refs": refs}).ok and ok

## Fibre strand texture: ~16 thin bright strands along V that wander, split and taper.
## R = core brightness, A = coverage. 64 x 256, strands run root (v=0) to tip (v=1).
func _fiber_texture() -> void:
	var w := 64
	var h := 256
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 86
	var strands := []
	for i in 16:
		strands.append([rng.randf_range(0.15, 0.85), rng.randf_range(-0.25, 0.25), rng.randf_range(0.0, 6.28), rng.randf_range(0.006, 0.02), rng.randf_range(0.55, 1.0)])
	for py in h:
		var v := (py + 0.5) / h
		for px in w:
			var u := (px + 0.5) / w
			var a := 0.0
			for st: Array in strands:
				if v > st[4]: continue
				var x: float = st[0] + st[1] * v * v + 0.03 * sin(v * 9.0 + st[2])
				var width: float = st[3] * (1.0 + 2.5 * v)
				a = maxf(a, exp(-pow((u - x) / width, 2.0)) * (1.0 - pow(v / st[4], 3.0)))
			var haze := 0.18 * exp(-pow((u - 0.5) / (0.12 + 0.3 * v), 2.0)) * (1.0 - v)
			img.set_pixel(px, py, Color(a, a, a, clampf(a + haze, 0.0, 1.0)))
	img.save_png(TEX + "fiber.png")
	print("FIBER_TEXTURE_WRITTEN")

## Two planes crossing along +Y (y 0..1, width 1); UV.y = 0 at the root.
func _strand_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis: Vector3 in [Vector3.RIGHT, Vector3.BACK]:
		var a := axis * 0.5
		var quad := [[-a, Vector2(0, 0)], [-a + Vector3.UP, Vector2(0, 1)], [a + Vector3.UP, Vector2(1, 1)], [a, Vector2(1, 0)]]
		for i: int in [0, 1, 2, 0, 2, 3]:
			st.set_uv(quad[i][1])
			st.add_vertex(quad[i][0])
	return st.commit()

func _fiber_mat(opacity := 1.0, sway := 0.6) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/fiber.gdshader")
	m.set_shader_parameter("fiber_tex", load(TEX + "fiber.png"))
	m.set_shader_parameter("opacity", opacity)
	m.set_shader_parameter("sway", sway)
	return m

## Boss second form. Each wing is ONE MultiMesh of crossed strand planes (one draw call,
## 4 triangles per strand) fanned out from the back of the hull. Strands holds the
## top-level attack strands (Stab0-2, Slam) and the slam telegraph ring; boss.gd places them.
func _wings() -> bool:
	var wings := Node3D.new()
	wings.name = "Wings"
	wings.visible = false
	var mesh := _strand_mesh()
	mesh.surface_set_material(0, _fiber_mat(0.95, 0.35))
	for side: int in [-1, 1]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = mesh
		mm.instance_count = 16
		var rng := RandomNumberGenerator.new()
		rng.seed = 40 + side
		for i in 16:
			# Strands fan from 30 deg (near vertical) to 100 deg (past horizontal), roots spread
			# outward along the back so they read as separate feathers, not one tangle.
			var f := i / 15.0
			var lean := deg_to_rad(lerpf(30.0, 100.0, f) + rng.randf_range(-3.0, 3.0))
			var length := lerpf(38.0, 24.0, f) * rng.randf_range(0.9, 1.08)
			var width := rng.randf_range(1.2, 2.0)
			var basis := Basis(Vector3.FORWARD, -side * lean) * Basis(Vector3.RIGHT, deg_to_rad(rng.randf_range(-14.0, -6.0))) * Basis(Vector3.UP, rng.randf_range(-0.25, 0.25))
			basis = basis * Basis.from_scale(Vector3(width, length, width))
			mm.set_instance_transform(i, Transform3D(basis, Vector3(side * lerpf(0.0, 5.0, f), -f * 1.5, rng.randf_range(-0.8, 0.8))))
			mm.set_instance_custom_data(i, Color(rng.randf(), 0, 0, 0))
		var wing := MultiMeshInstance3D.new()
		wing.multimesh = mm
		wing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wing.position = Vector3(side * 2.0, 0, 0)
		Builder.add(wings, wing, "Left" if side < 0 else "Right")
	var strands := Node3D.new()
	strands.top_level = true
	Builder.add(wings, strands, "Strands")
	for strand_name: String in ["Stab0", "Stab1", "Stab2", "Slam"]:
		var strand := MeshInstance3D.new()
		var smesh := _strand_mesh()
		smesh.surface_set_material(0, _fiber_mat(1.0, 0.15))
		strand.mesh = smesh
		strand.visible = false
		strand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		Builder.add(strands, strand, strand_name)
	var ring := MeshInstance3D.new()
	ring.mesh = _quad(Vector2.ONE, PlaneMesh.FACE_Y)
	var ring_mat := _mat("ring", false, false)
	ring_mat.vertex_color_use_as_albedo = false
	ring_mat.albedo_color = Color(1.0, 0.15, 0.1, 0.85)
	ring.material_override = ring_mat
	ring.visible = false
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Builder.add(strands, ring, "SlamRing")
	var ok: bool = Builder.save_scene(wings, "res://scenes/boss_wings.tscn", {"overwrite": true}).ok
	var boss := Builder.open_scene("res://scenes/boss.tscn")
	var node := Builder.instance("res://scenes/boss_wings.tscn") as Node3D
	node.position = Vector3(0, 7.4, -3.0)  # Boss model sits 1.14 m lower than its source
	Builder.put(boss.root, node, "Wings")
	var refs: Array = boss.refs
	if not refs.has("res://scenes/boss_wings.tscn"): refs.append("res://scenes/boss_wings.tscn")
	return Builder.save_scene(boss.root, "res://scenes/boss.tscn", {"overwrite": true, "expected_refs": refs}).ok and ok

