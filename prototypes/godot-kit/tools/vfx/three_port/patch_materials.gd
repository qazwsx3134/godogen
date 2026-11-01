extends "res://addons/proto_kit/test_kit.gd"
const B = preload("res://addons/proto_kit/scene_builder.gd")
const BASE := "res://addons/proto_kit/vfx/3d/00gamedevs/"
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var source := OS.get_cmdline_user_args()[0]
	for file: String in DirAccess.get_files_at(source):
		if not file.ends_with(".json") or file == "stats.json":
			continue
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source.path_join(file)))
		var path: String = BASE + data.id + ".tscn"
		var opened := B.open_scene(path)
		var fx: Node = opened.root
		for index: int in data.meshes.size():
			var mesh: MeshInstance3D = fx.get_node("Parts/Part%03d" % index)
			var material := mesh.material_override as ShaderMaterial
			material.shader = load(BASE + "ported/%s/spatial_part_%d.gdshader" % [data.id, index])
			material.render_priority = int(data.meshes[index].material.renderOrder)
			if int(data.meshes[index].material.side) == 0:
				material.shader.code = material.shader.code.replace("cull_disabled", "cull_back")
				_expect(ResourceSaver.save(material.shader, material.shader.resource_path) == OK, "source culling saved")
			var always_opaque: bool = true
			for sample: Array in data.samples:
				always_opaque = always_opaque and not sample[index].transparent
			var ordinary_blend: bool = int(data.meshes[index].material.blending) in [0, 1]
			if always_opaque and ordinary_blend:
				material.shader.code = _opaque(material.shader.code)
				_expect(ResourceSaver.save(material.shader, material.shader.resource_path) == OK, "opaque source pass saved")
			elif always_opaque:
				material.render_priority = -128 + int(data.meshes[index].material.renderOrder)
			var depth_changes: bool = false
			var always_depth: bool = true
			for sample: Array in data.samples:
				depth_changes = depth_changes or sample[index].depthWrite
				always_depth = always_depth and sample[index].depthWrite
			if depth_changes:
				var shader := material.shader
				var depth_path := shader.resource_path.get_basename() + "_depth.gdshader"
				var output := FileAccess.open(depth_path, FileAccess.WRITE)
				var depth_code: String = shader.code.replace("depth_draw_never", "depth_draw_always")
				if ordinary_blend:
					depth_code = _opaque(depth_code)
				output.store_string(depth_code)
				output.close()
				mesh.set_meta("source_depth_shader", load(depth_path))
				mesh.set_meta("source_depth_mode", "always" if always_depth else "active")
				mesh.set_meta("source_transparent_shader", shader)
		var player: AnimationPlayer = fx.get_node("Motion")
		var animation: Animation = player.get_animation(&"active")
		for index: int in data.meshes.size():
			var mesh: Node = fx.get_node("Parts/Part%03d" % index)
			if mesh.has_meta("phase_ranges"):
				continue
			for field: String in ["drawStart", "drawCount"]:
				var first: float = data.samples[0][index][field]
				var changing: bool = false
				for sample: Array in data.samples:
					changing = changing or sample[index][field] != first
				if not changing:
					continue
				var parameter: String = "source_draw_start" if field == "drawStart" else "source_draw_count"
				var track_path := NodePath("Parts/Part%03d:material_override:shader_parameter/%s" % [index, parameter])
				var track: int = animation.find_track(track_path, Animation.TYPE_VALUE)
				if track >= 0:
					animation.remove_track(track)
				track = animation.add_track(Animation.TYPE_VALUE)
				animation.track_set_path(track, track_path)
				animation.value_track_set_update_mode(track, Animation.UPDATE_DISCRETE)
				for frame: int in data.samples.size():
					animation.track_insert_key(track, minf(animation.length, float(frame) / data.fps), float(data.samples[frame][index][field]))
		for track: int in animation.get_track_count():
			if animation.track_get_key_count(track) > 0 and typeof(animation.track_get_key_value(track, 0)) == TYPE_PACKED_VECTOR4_ARRAY:
				animation.value_track_set_update_mode(track, Animation.UPDATE_DISCRETE)
		var library: AnimationLibrary = player.get_animation_library(&"")
		_expect(ResourceSaver.save(library, library.resource_path) == OK, "source draw tracks saved")
		var result := B.save_scene(fx, path, {"overwrite": true, "expected_refs": opened.refs})
		_expect(result.ok, path)
	_finish("NATIVE MATERIAL POLICIES")

func _opaque(code: String) -> String:
	return code.replace("ALPHA = clamp(gl_FragColor.a, 0.0, 1.0);", "").replace("ALPHA = 1.0;", "")
