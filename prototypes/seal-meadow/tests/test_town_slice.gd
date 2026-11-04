extends "res://addons/proto_kit/test_kit.gd"
## Playable town slice: saved scene ownership, clear critical path, blockers and textured shop.

const SHOP_SCENE := "res://scenes/props/town_shop_draft.tscn"
const SHOP_MODEL := "res://assets/models/town_shop_draft.glb"
const SIGN_SCENE := "res://scenes/props/town_signpost_sample.tscn"
const EDITED_SCENE := "user://test_town_slice_edited.tscn"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var before := FileAccess.get_file_as_bytes("res://scenes/town.tscn")
	var main := load("res://scenes/main.tscn").instantiate() as Node3D
	main.save_path = "user://test_town_slice/save.json"
	root.add_child(main)
	await _frames(3)
	var town: Node3D = main.get_node("%Town")
	var player: Node3D = main.get_node("%Player")
	var shop: Node3D = town.get_node("Props/MeadowShop")
	var sign: Node3D = town.get_node("Props/MeadowSign")
	var path: MeshInstance3D = town.get_node("Ground/EntrancePath")
	_expect(shop.scene_file_path == SHOP_SCENE, "shop is an editable scene instance")
	_expect(sign.scene_file_path == SIGN_SCENE, "sign is an editable scene instance")
	_expect(shop.get_node("Model").scene_file_path == SHOP_MODEL, "shop retains its GLB instance")
	_expect(shop.get_node("ShopLabel").text == "雜貨屋", "shop label is a separate editable node")
	_expect(is_equal_approx(float(shop.get_meta(&"block_radius", 0.0)), 2.9), "shop has its conservative blocker")
	var stats := _mesh_stats(shop)
	_expect(stats.triangles > 0 and stats.triangles <= 4000, "complete shop fits the ordinary model budget: %d" % stats.triangles)
	_expect(stats.textured > 0, "shop roof retains its imported texture")
	_expect(stats.missing_materials == 0, "shop meshes have materials")
	var visible_roof := shop.get_node("Model/ShopRoof") as MeshInstance3D
	var roof_material := visible_roof.get_active_material(0) as ShaderMaterial
	var tile_color: Color = roof_material.get_shader_parameter("tile_color") if roof_material else Color.BLACK
	_expect(roof_material != null and roof_material.get_shader_parameter("palette") != null and tile_color.r > tile_color.b,
		"saved roof material keeps its palette and selected warm tile colour")
	var sign_stats := _mesh_stats(sign)
	_expect(sign_stats.triangles > 0 and sign_stats.triangles <= 500, "sign fits the simple model budget: %d" % sign_stats.triangles)

	var road_mesh := path.mesh as PlaneMesh
	_expect(road_mesh != null and path.position.y > 0.0, "entrance path is a raised editable plane")
	_expect(path.material_override is ShaderMaterial, "entrance path uses the town lighting material")
	if road_mesh:
		var north_end: float = path.position.z - road_mesh.size.y / 2.0
		_expect(north_end > 7.5, "entrance path does not overlap the plaza")
	var blockers: Array[Vector3] = town.blockers()
	var shop_blocked := false
	var sign_blocked := false
	for b: Vector3 in blockers:
		if Vector2(b.x, b.y).distance_to(Vector2(shop.global_position.x, shop.global_position.z)) < 0.001:
			shop_blocked = is_equal_approx(b.z, 2.9)
		if Vector2(b.x, b.y).distance_to(Vector2(sign.global_position.x, sign.global_position.z)) < 0.001:
			sign_blocked = is_equal_approx(b.z, 0.2)
	_expect(shop_blocked and sign_blocked, "both new props enter the real town blocker list")
	var path_clear := true
	for z in range(0, 12):
		var point := Vector2(300.0, float(z))
		for b: Vector3 in blockers:
			if point.distance_to(Vector2(b.x, b.y)) <= b.z:
				path_clear = false
	_expect(path_clear, "the elder-to-portal centre route is clear")
	player.bounds_center = Vector2(300.0, 0.0)
	player.bounds_radius = 18.0
	player.position = shop.global_position
	player._push_out()
	var distance := Vector2(player.position.x - shop.global_position.x, player.position.z - shop.global_position.z).length()
	_expect(distance >= 2.9 - 0.001, "player is pushed outside the shop footprint")
	_expect(player.actor.sheet.directions == 8 and player.actor.layer_sheets.size() >= 3,
		"existing eight-direction paper-doll player remains in the scene")
	_expect(FileAccess.get_file_as_bytes("res://scenes/town.tscn") == before, "runtime state does not rewrite the source scene")

	var original := load("res://scenes/town.tscn") as PackedScene
	var edited := original.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	var edited_shop: Node3D = edited.get_node("Props/MeadowShop")
	edited_shop.position.x = 1.25
	var saved := PackedScene.new()
	_expect(saved.pack(edited) == OK and ResourceSaver.save(saved, EDITED_SCENE) == OK, "editor placement can be saved")
	edited.free()
	var reloaded := (ResourceLoader.load(EDITED_SCENE, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	var reloaded_shop: Node3D = reloaded.get_node("Props/MeadowShop")
	_expect(is_equal_approx(reloaded_shop.position.x, 1.25), "authored shop position survives scene reload")
	_expect(reloaded_shop.scene_file_path == SHOP_SCENE and reloaded_shop.get_node("Model").scene_file_path == SHOP_MODEL,
		"scene and nested model instance relationships survive editing")
	reloaded.free()
	main.queue_free()
	await _frames(2)
	_finish("TOWN SLICE TESTS")


func _mesh_stats(parent: Node) -> Dictionary:
	var triangles := 0
	var textured := 0
	var missing_materials := 0
	var meshes: Array[Node] = parent.find_children("*", "MeshInstance3D", true, false)
	if parent is MeshInstance3D:
		meshes.append(parent)
	for node: Node in meshes:
		var mesh := (node as MeshInstance3D).mesh
		if mesh == null:
			continue
		for surface in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			triangles += (indices.size() if not indices.is_empty() else vertices.size()) / 3
			var material := mesh.surface_get_material(surface)
			if material == null:
				missing_materials += 1
			elif material is BaseMaterial3D and material.albedo_texture != null:
				textured += 1
	return {"triangles": triangles, "textured": textured, "missing_materials": missing_materials}
