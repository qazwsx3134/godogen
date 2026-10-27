extends SceneTree
## One-time authoring tool: adds the hit effects (ImpactFx with its chunk MultiMesh and ring pool) and the sound bank
## (Sfx) to main.tscn, with their materials in materials/. Skips main.tscn once it has ImpactFx.
##   godot --headless --path prototypes/hero-horde-idle --script res://tools/build_fx.gd

const SceneBuilder = preload("res://addons/proto_kit/scene_builder.gd")
const MAIN := "res://scenes/main.tscn"
const RINGS := 10


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var ring_mat: ShaderMaterial = _keep(_ring_material(), "res://materials/fx_ring.tres")
	var chunk_mat: StandardMaterial3D = _keep(_chunk_material(), "res://materials/fx_chunk.tres")
	var main: Node = (load(MAIN) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	if main.get_node_or_null("ImpactFx") != null:
		print("skip (already has ImpactFx): ", MAIN)
		main.free()
		quit(0)
		return
	var fx := Node3D.new()
	fx.set_script(load("res://scripts/impact_fx.gd"))
	SceneBuilder.add(main, SceneBuilder.unique(fx), "ImpactFx")
	main.move_child(fx, main.get_node("Bolts").get_index() + 1)

	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = chunk_mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	var chunks := MultiMeshInstance3D.new()
	chunks.multimesh = mm
	chunks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chunks.custom_aabb = AABB(Vector3(-16.0, -2.0, -12.0), Vector3(32.0, 12.0, 24.0))
	SceneBuilder.add(fx, SceneBuilder.unique(chunks), "Chunks")

	var rings := SceneBuilder.add(fx, SceneBuilder.unique(Node3D.new()), "Rings") as Node3D
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	for k: int in RINGS:
		var r := MeshInstance3D.new()
		r.mesh = plane
		r.material_override = ring_mat
		r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		r.visible = false
		SceneBuilder.add(rings, r, "Ring_%d" % (k + 1))

	var sfx := Node.new()
	sfx.set_script(load("res://scripts/sfx.gd"))
	SceneBuilder.add(main, SceneBuilder.unique(sfx), "Sfx")

	var result: Dictionary = SceneBuilder.save_scene(main, MAIN, {"overwrite": true,
		"expected_refs": ["res://scenes/hud.tscn", "res://scenes/stage.tscn"]})
	quit(0 if result.ok else 1)


func _ring_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/fx_ring.gdshader")
	m.render_priority = -1
	return m


## Hard-edged square that always faces the camera; colour per chunk from the MultiMesh.
func _chunk_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	# The palettes are written in sRGB, like every Color constant.
	m.vertex_color_is_srgb = true
	m.disable_receive_shadows = true
	return m


func _keep(resource: Resource, path: String) -> Resource:
	if ResourceLoader.exists(path):
		return load(path)
	ResourceSaver.save(resource, path)
	print("saved: ", path)
	return load(path)
