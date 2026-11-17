extends SceneTree
## One-time editor tool. Existing scenes are only updated when --overwrite is
## supplied; normal game execution never rebuilds them.
const Builder = preload("res://addons/proto_kit/scene_builder.gd")

func _initialize() -> void:
	_run.call_deferred()

func _save(node: Node, path: String, refs: Array = []) -> void:
	var result := Builder.save_scene(node, path, {"overwrite": true, "expected_refs": refs})
	if not result.ok:
		push_error("Could not save " + path)
		quit(1)

func _mesh(parent: Node, node_name: String, shape: Mesh, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = shape
	node.material_override = mat
	Builder.add(parent, node, node_name)
	return node

func _material(color: Color, metallic: float = 0.5) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = 0.48
	return mat

func _run() -> void:
	if "--overwrite" not in OS.get_cmdline_user_args():
		print("Existing scenes preserved. Pass --overwrite only after reviewing changes.")
		quit(0)
		return
	var armor := _material(Color(0.36, 0.42, 0.46), 0.78)

	var blur := CanvasLayer.new()
	blur.name = "SpeedBlur"
	blur.layer = 0
	var screen := ColorRect.new()
	screen.name = "Screen"
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.visible = false
	var blur_mat := ShaderMaterial.new()
	blur_mat.resource_local_to_scene = true
	blur_mat.shader = load("res://shaders/speed_blur.gdshader")
	blur_mat.set_shader_parameter("strength", 0.0)
	screen.material = blur_mat
	Builder.add(blur, screen)
	_save(blur, "res://scenes/speed_blur.tscn")

	var boss := CharacterBody3D.new()
	boss.name = "Boss"
	boss.collision_layer = 4
	boss.collision_mask = 3
	boss.floor_snap_length = 0.5
	boss.set_script(load("res://scripts/boss.gd"))
	Builder.add(boss, Builder.unique(Builder.instance("res://assets/boss/boss_animated.glb")), "Model")
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10.0, 6.0, 15.0)
	collision.shape = box
	collision.position = Vector3(0, 3.1, 1.5)
	Builder.add(boss, collision, "Body")
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.5
	beam_mesh.bottom_radius = 0.5
	beam_mesh.height = 1.0
	beam_mesh.radial_segments = 8
	var beam_mat := _material(Color(1, 0.3, 0.04), 0.0)
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.emission_enabled = true
	beam_mat.emission = Color(1, 0.3, 0.04)
	var beam := _mesh(boss, "Beam", beam_mesh, beam_mat)
	beam.top_level = true
	beam.visible = false
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var status := Label3D.new()
	status.position = Vector3(0, 11.0, 0)
	status.text = "BOSS 600 / 600"
	status.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	status.pixel_size = 0.03
	Builder.add(boss, status, "Status")
	var audio := AudioStreamPlayer3D.new()
	audio.bus = "Weapons"
	audio.unit_size = 25.0
	audio.max_distance = 160.0
	Builder.add(boss, audio, "AttackSound")
	_save(boss, "res://scenes/boss.tscn", ["res://assets/boss/boss_animated.glb"])

	var walker_data := Builder.open_scene("res://scenes/walker.tscn")
	var walker: Node3D = walker_data.root
	Builder.add(walker, Builder.instance("res://scenes/speed_blur.tscn"), "SpeedBlur")
	var model := walker.get_node("Model")
	walker.set_editable_instance(model, true)
	var cannon := model.find_child("Cannon", true, false) as Node3D
	cannon.scale = Vector3(1.75, 1.75, 1.12)
	var walker_refs: Array = walker_data.refs
	walker_refs.append("res://scenes/speed_blur.tscn")
	_save(walker, "res://scenes/walker.tscn", walker_refs)

	var combat_data := Builder.open_scene("res://scenes/walker_combat.tscn")
	var combat: Node3D = combat_data.root
	var hook_sound := AudioStreamPlayer3D.new()
	hook_sound.bus = "Weapons"
	hook_sound.unit_size = 12.0
	hook_sound.max_distance = 80.0
	Builder.put(combat.get_node("Grapple"), hook_sound, "HookSound")
	_save(combat, "res://scenes/walker_combat.tscn", combat_data.refs)

	var impact_data := Builder.open_scene("res://scenes/combat_impact.tscn")
	var impact: Node3D = impact_data.root
	Builder.add(impact, Builder.instance("res://addons/proto_kit/vfx/3d/scenario/cinder-explosion.tscn"), "Explosion")
	var impact_refs: Array = impact_data.refs
	impact_refs.append("res://addons/proto_kit/vfx/3d/scenario/cinder-explosion.tscn")
	_save(impact, "res://scenes/combat_impact.tscn", impact_refs)

	var terrain := Builder.instance("res://scenes/map_01_green_rust.tscn") as Node3D
	root.add_child(terrain)
	await physics_frame
	await physics_frame
	var query := PhysicsRayQueryParameters3D.create(Vector3(0, 100, -20), Vector3(0, -100, -20), 1)
	var hit := terrain.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		push_error("No terrain below Boss spawn")
		quit(1)
		return
	var ground_y: float = hit.position.y
	terrain.queue_free()
	var battle_data := Builder.open_scene("res://scenes/boss_battlefield.tscn")
	var battle: Node3D = battle_data.root
	(battle.get_node("Boss") as Node3D).position.y = ground_y + 0.05
	(battle.find_child("BossIdle") as Button).text = "1 BEAM"
	(battle.find_child("BossFly") as Button).text = "2 PILLARS"
	(battle.find_child("BossFire") as Button).text = "3 TAIL"
	_save(battle, "res://scenes/boss_battlefield.tscn", battle_data.refs)
	print("GROUND_BOSS_SCENES_CREATED ground_y=", ground_y)
	quit(0)

