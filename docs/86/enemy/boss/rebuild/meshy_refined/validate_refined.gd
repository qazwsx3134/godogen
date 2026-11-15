extends SceneTree
## Audit the actual Godot import, not just the editable Blender source.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var errors: Array[String] = []
	var packed := load("res://boss_meshy_refined.glb") as PackedScene
	if packed == null:
		printerr("FAILED: could not load boss.glb")
		quit(1)
		return
	var instance := packed.instantiate()
	root.add_child(instance)
	await process_frame
	var meshes := instance.find_children("*", "MeshInstance3D", true, false)
	var rigs := instance.find_children("*", "Skeleton3D", true, false)
	var players := instance.find_children("*", "AnimationPlayer", true, false)
	if meshes.size() != 1:
		printerr("FAILED: expected exactly one mesh, got ", meshes.size())
		quit(1)
		return
	var mesh_node := meshes[0] as MeshInstance3D
	var mesh := mesh_node.mesh
	if mesh == null or mesh.get_surface_count() != 1:
		printerr("FAILED: expected one mesh surface")
		quit(1)
		return
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var triangles: int = indices.size() / 3
	if triangles < 15000 or triangles > 30000 or indices.size() % 3 != 0:
		errors.append("triangle count outside 15,000–30,000 budget")
	if vertices.size() != uvs.size() or vertices.size() != normals.size():
		errors.append("missing UVs or normals")
	else:
		for i in vertices.size():
			var vertex := vertices[i]
			var uv := uvs[i]
			var normal := normals[i]
			if not (is_finite(vertex.x) and is_finite(vertex.y) and is_finite(vertex.z) and
					is_finite(uv.x) and is_finite(uv.y) and
					is_finite(normal.x) and is_finite(normal.y) and is_finite(normal.z)):
				errors.append("non-finite vertex, normal or UV")
				break
			if uv.x < -0.001 or uv.x > 1.001 or uv.y < -0.001 or uv.y > 1.001:
				errors.append("UV outside [0, 1]")
				break
			if absf(normal.length() - 1.0) > 0.02:
				errors.append("normal is not unit length")
				break
	for index in indices:
		if index < 0 or index >= vertices.size():
			errors.append("index references a missing vertex")
			break
	if errors.is_empty():
		for i in range(0, indices.size(), 3):
			var a := vertices[indices[i]]
			var b := vertices[indices[i + 1]]
			var c := vertices[indices[i + 2]]
			if (b - a).cross(c - a).length_squared() < 0.000000000000000004:
				errors.append("degenerate triangle")
				break
	var bounds := mesh.get_aabb()
	if absf(bounds.size.z - 40.0) > 0.1 or absf(bounds.position.y) > 0.1:
		errors.append("length or ground origin is incorrect")
	if not mesh_node.transform.is_equal_approx(Transform3D.IDENTITY):
		errors.append("mesh node has unexpected transform")
	if not rigs.is_empty() or not players.is_empty():
		errors.append("expected static export without skeleton or animation")
	var material := mesh.surface_get_material(0) as BaseMaterial3D
	if material == null or material.albedo_texture == null:
		errors.append("missing PBR material or albedo")
	else:
		var color_size := material.albedo_texture.get_size()
		print("GODOT_ALBEDO_SIZE ", color_size, " material=", material.get_class(),
			" cull=", material.cull_mode)
		if color_size != Vector2(2048, 2048):
			errors.append("albedo is not 2048 square")
		if material.cull_mode != BaseMaterial3D.CULL_BACK:
			errors.append("closed model should cull backfaces")
		if material is ORMMaterial3D:
			var orm := (material as ORMMaterial3D).orm_texture
			if orm == null or orm.get_size() != Vector2(1024, 1024):
				errors.append("missing 1024 square ORM texture")
		elif material is StandardMaterial3D:
			var metallic := material.metallic_texture
			var roughness := material.roughness_texture
			if metallic == null or roughness == null or metallic.get_size() != Vector2(1024, 1024) or roughness.get_size() != Vector2(1024, 1024):
				errors.append("missing 1024 square metallic/roughness texture")
			elif material.metallic_texture_channel != BaseMaterial3D.TEXTURE_CHANNEL_BLUE or material.roughness_texture_channel != BaseMaterial3D.TEXTURE_CHANNEL_GREEN:
				errors.append("incorrect metallic/roughness texture channels")
		else:
			errors.append("unexpected material type")
	print("GODOT_MODEL triangles=%d vertices=%d surfaces=%d AABB=%s rigs=%d animations=%d" %
		[triangles, vertices.size(), mesh.get_surface_count(), bounds, rigs.size(), players.size()])
	if errors.is_empty():
		print("BOSS_MESHY_GODOT_VALIDATION_PASS")
		quit(0)
	else:
		for error in errors:
			printerr("FAILED: ", error)
		quit(1)
