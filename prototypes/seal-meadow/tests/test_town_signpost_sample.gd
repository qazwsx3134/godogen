extends "res://addons/proto_kit/test_kit.gd"
## Technical sample: editable scene, imported textured mesh and a 500-triangle budget.

const SCENE := preload("res://scenes/props/town_signpost_sample.tscn")
const MODEL_PATH := "res://assets/models/town_signpost_sample.glb"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var sign := SCENE.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	var model := sign.get_node_or_null("Model")
	_expect(model != null, "the scene contains an editable model instance")
	if model == null:
		sign.free()
		_finish("TOWN SIGNPOST SAMPLE")
		return
	_expect(model.scene_file_path == MODEL_PATH, "the model remains an instance of its GLB")
	_expect(model.owner == sign, "the model belongs to the saved scene")
	_expect(is_equal_approx(float(sign.get_meta(&"block_radius", 0.0)), 0.2), "the placement root has a small obstacle radius")
	var meshes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
	if model is MeshInstance3D:
		meshes.append(model)
	var triangles := 0
	var textured := false
	for item: Node in meshes:
		var mesh := (item as MeshInstance3D).mesh
		if mesh == null:
			continue
		for surface in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			triangles += (indices.size() if not indices.is_empty() else vertices.size()) / 3
			var material := mesh.surface_get_material(surface)
			if material is BaseMaterial3D and material.albedo_texture != null:
				textured = true
	_expect(triangles > 0 and triangles <= 500, "model fits the simple-prop triangle budget: %d" % triangles)
	_expect(textured, "the imported material retains its colour texture")
	sign.free()
	_finish("TOWN SIGNPOST SAMPLE")
