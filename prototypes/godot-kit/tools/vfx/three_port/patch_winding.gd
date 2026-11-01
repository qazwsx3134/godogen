extends "res://addons/proto_kit/test_kit.gd"
const BASE := "res://addons/proto_kit/vfx/3d/00gamedevs/ported/"
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	for folder: String in DirAccess.get_directories_at(BASE):
		for file: String in DirAccess.get_files_at(BASE.path_join(folder)):
			if not file.begins_with("part_") or not file.ends_with(".res"):
				continue
			var path := BASE.path_join(folder).path_join(file)
			var mesh := load(path) as ArrayMesh
			if mesh.get_meta("godot_clockwise", false):
				continue
			var format: int = mesh.surface_get_format(0)
			var arrays: Array = mesh.surface_get_arrays(0)
			var count: int = arrays[Mesh.ARRAY_VERTEX].size()
			for channel: int in Mesh.ARRAY_MAX:
				if arrays[channel] == null:
					continue
				var lanes: int = 4 if channel >= Mesh.ARRAY_CUSTOM0 and channel <= Mesh.ARRAY_CUSTOM3 else 1
				for triangle: int in range(0, count, 3):
					for lane: int in lanes:
						var a: int = (triangle + 1) * lanes + lane
						var b: int = (triangle + 2) * lanes + lane
						var value: Variant = arrays[channel][a]
						arrays[channel][a] = arrays[channel][b]
						arrays[channel][b] = value
			mesh.clear_surfaces()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, format)
			mesh.set_meta("godot_clockwise", true)
			_expect(ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS) == OK, path)
	_finish("SOURCE WINDING CONVERSION")
