extends SceneTree
## Adds the cannon "juice" nodes to the saved scenes (one-time authoring tool; the scenes are
## the editable source afterwards, rerunning replaces these nodes by name):
##   walker_combat.tscn  ReloadSound (magazine out / in), ShellSound (casing clinks), TimeControl (hit stop, group time_control), Shells / Parts / Stains
##                       (kit debris3d.gd pools: one draw call each, oldest piece reused)
##   combat_projectile   Head (glow dot) + Tail (tracer streak shader) + Whiz (bullet_whiz: an enemy round passing close to the walker)
##   scout.tscn, boss.tscn  HitReact (kit hit_react3d.gd on ../Model)
## godot --headless --path . --script res://tools/build_gun_juice.gd

const Builder = preload("res://addons/proto_kit/scene_builder.gd")

func _initialize() -> void:
	quit(0 if _run() else 1)

func _unshaded(color: Color, alpha := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	if alpha: m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

func _pool(name: String, mesh: Mesh, capacity: int, group: String) -> MultiMeshInstance3D:
	var pool := MultiMeshInstance3D.new()
	pool.name = name
	pool.set_script(load("res://addons/proto_kit/debris3d.gd"))
	pool.set("piece_mesh", mesh)
	pool.set("capacity", capacity)
	pool.add_to_group(group, true)
	return pool

func _run() -> bool:
	var ok := true
	# --- walker: hit stop + debris pools ---------------------------------------------
	var walker := Builder.open_scene("res://scenes/walker_combat.tscn")
	var time := Node.new()
	time.set_script(load("res://addons/proto_kit/time_control.gd"))
	time.process_mode = Node.PROCESS_MODE_ALWAYS
	time.add_to_group("time_control", true)
	Builder.put(walker.root, time, "TimeControl")
	var reload := AudioStreamPlayer3D.new()
	reload.bus = "Weapons"
	reload.stream = load("res://assets/sound/runtime/mech_contact.ogg")
	reload.volume_db = -4.0
	Builder.put(walker.root, reload, "ReloadSound")
	var clink := AudioStreamPlayer3D.new()
	clink.bus = "Impacts"
	clink.stream = load("res://assets/sound/runtime/shell_drop.ogg")
	clink.unit_size = 4.0
	clink.max_distance = 30.0
	clink.max_polyphony = 6
	Builder.put(walker.root, clink, "ShellSound")
	var shell := CylinderMesh.new()
	shell.top_radius = 0.07
	shell.bottom_radius = 0.08
	shell.height = 0.34
	shell.radial_segments = 6
	shell.rings = 1
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.78, 0.58, 0.22)
	brass.metallic = 0.85
	brass.roughness = 0.35
	shell.material = brass
	Builder.put(walker.root, _pool("Shells", shell, 80, "debris_shells"), "Shells")
	var part := BoxMesh.new()
	part.size = Vector3(0.32, 0.12, 0.22)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.22, 0.23, 0.24)
	metal.metallic = 0.7
	metal.roughness = 0.55
	part.material = metal
	Builder.put(walker.root, _pool("Parts", part, 60, "debris_parts"), "Parts")
	var stain := QuadMesh.new()
	stain.orientation = PlaneMesh.FACE_Y
	stain.size = Vector2.ONE
	var oil := _unshaded(Color(0.05, 0.04, 0.03, 0.85), true)
	oil.albedo_texture = load("res://assets/vfx/smoke.png")
	stain.material = oil
	Builder.put(walker.root, _pool("Stains", stain, 40, "debris_stains"), "Stains")
	ok = Builder.save_scene(walker.root, "res://scenes/walker_combat.tscn", {"overwrite": true, "expected_refs": walker.refs}).ok and ok

	# --- projectile: tracer head + tail, whiz ------------------------------------------
	var shot := Builder.open_scene("res://scenes/combat_projectile.tscn")
	var old: Node = shot.root.get_node_or_null("Tracer")
	if old: shot.root.remove_child(old); old.free()
	# Head: a small camera-facing glow (what the chase camera sees straight down the line of fire).
	var head := MeshInstance3D.new()
	var dot := QuadMesh.new()
	dot.size = Vector2(0.55, 0.55)
	head.mesh = dot
	var glow := _unshaded(Color(1.0, 0.75, 0.4), true)
	glow.albedo_texture = load("res://assets/vfx/glow.png")
	glow.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	head.material_override = glow
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Builder.put(shot.root, head, "Head")
	# Tail: a camera-facing streak along the flight path (tracer.gdshader); combat_projectile.gd
	# sets scale.z to its length, so it grows out of the muzzle instead of poking through the barrel.
	var tail := MeshInstance3D.new()
	tail.mesh = QuadMesh.new()
	var streak := ShaderMaterial.new()
	streak.shader = load("res://assets/vfx/tracer.gdshader")
	tail.material_override = streak
	tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tail.extra_cull_margin = 4.0
	Builder.put(shot.root, tail, "Tail")
	var whiz := AudioStreamPlayer3D.new()
	whiz.bus = "Weapons"
	whiz.stream = load("res://assets/sound/runtime/bullet_whiz.ogg")
	whiz.unit_size = 5.0
	whiz.max_distance = 35.0
	whiz.volume_db = -8.0
	Builder.put(shot.root, whiz, "Whiz")
	ok = Builder.save_scene(shot.root, "res://scenes/combat_projectile.tscn", {"overwrite": true, "expected_refs": shot.refs}).ok and ok

	# --- targets: hit reaction ---------------------------------------------------------
	for entry: Array in [["res://scenes/scout.tscn", 0.18, 0.4], ["res://scenes/boss.tscn", 0.03, 0.12]]:
		var target := Builder.open_scene(entry[0])
		var react := Node.new()
		react.set_script(load("res://addons/proto_kit/hit_react3d.gd"))
		react.set("squash", entry[1])
		react.set("knock_distance", entry[2])
		Builder.put(target.root, react, "HitReact")
		ok = Builder.save_scene(target.root, entry[0], {"overwrite": true, "expected_refs": target.refs}).ok and ok
	return ok
