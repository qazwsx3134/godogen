@tool
extends EditorScenePostImport


func _post_import(scene: Node) -> Object:
	for visual: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh := visual.mesh as ArrayMesh
		if mesh == null:
			continue
		for surface in mesh.get_surface_count():
			var material := mesh.surface_get_material(surface) as StandardMaterial3D
			if material and (mesh.surface_get_format(surface) & Mesh.ARRAY_FORMAT_COLOR) != 0:
				material.vertex_color_use_as_albedo = true
				material.vertex_color_is_srgb = false
	return scene
