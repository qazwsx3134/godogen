extends SceneTree
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var errors: Array[String] = []
	var packed := load("res://model.glb") as PackedScene
	if not packed:
		printerr("FAILED: model did not import")
		quit(1)
		return
	var model := packed.instantiate()
	root.add_child(model)
	await process_frame
	var instances := model.find_children("*", "MeshInstance3D", true, false)
	if instances.size() != 1:
		printerr("FAILED: expected one mesh, got ", instances.size())
		quit(1)
		return
	var mesh := (instances[0] as MeshInstance3D).mesh
	if mesh.get_surface_count() != 1:
		errors.append("expected one surface")
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if indices.size() / 3 < 2000 or indices.size() / 3 > 3000:
		errors.append("triangle count is outside 2000–3000")
	if normals.size() != vertices.size() or uvs.size() != vertices.size():
		errors.append("missing normals or texture coordinates")
	var material := mesh.surface_get_material(0) as BaseMaterial3D
	var unique_colors: Dictionary = {}
	if not material or not material.albedo_texture:
		errors.append("palette texture missing from material")
	else:
		var texture := material.albedo_texture
		if texture.get_size() != Vector2(128, 128):
			errors.append("palette texture is not 128x128")
		var image := texture.get_image()
		for y in 4:
			for x in 4:
				unique_colors[image.get_pixel(x * 32 + 16, y * 32 + 16).to_html(false)] = true
		if unique_colors.size() < 8:
			errors.append("palette lost its colour swatches")
	var bounds := mesh.get_aabb()
	var original := Vector3(1.276971, 1.161541, 1.724657)
	if absf(bounds.position.y) > 0.001 or absf(bounds.size.x-original.x) > 0.05 or absf(bounds.size.y-original.y) > 0.05 or absf(bounds.size.z-original.z) > 0.05:
		errors.append("origin or dimensions differ too much from reference")
	var degenerate := 0
	for i in range(0, indices.size(), 3):
		var a := vertices[indices[i]]
		var b := vertices[indices[i+1]]
		var c := vertices[indices[i+2]]
		if (b-a).cross(c-a).length_squared() < 0.000000000001:
			degenerate += 1
	if degenerate:
		errors.append("degenerate triangles: %d" % degenerate)
	print("PHIDO_LOW tris=",indices.size()/3," vertices=",vertices.size()," colours=",unique_colors.size()," bounds=",bounds," degenerate=",degenerate)
	model.queue_free()
	await process_frame
	if errors.is_empty():
		print("PHIDO_LOWPOLY PASSED")
		quit(0)
	else:
		for error in errors: printerr("FAILED: ",error)
		quit(1)
