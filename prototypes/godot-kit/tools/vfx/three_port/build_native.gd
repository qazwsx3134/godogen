extends "res://addons/proto_kit/test_kit.gd"
## One-time authoring from extracted source data. Existing saved scenes are preserved.
const B = preload("res://addons/proto_kit/scene_builder.gd")
const BASE := "res://addons/proto_kit/vfx/3d/00gamedevs/"
const STANDARD := ["uTime", "uEmitterTime", "uLifeStart", "uLifeEnd", "uLifeStage", "uLifeOrigin", "uStopTime", "uImpact"]
var ok: bool = true
var source: String

func _initialize() -> void:
	source = OS.get_cmdline_user_args()[0]
	_build.call_deferred()

func _build() -> void:
	for folder: String in DirAccess.get_directories_at(source):
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source.path_join(folder).path_join("data.json")))
		_effect(data)
	_expect(ok, "all native assets saved")
	_finish("THREEJS AUTHORING")

func _effect(data: Dictionary) -> void:
	var id: String = data.id
	var out := BASE.path_join("ported").path_join(id)
	DirAccess.make_dir_recursive_absolute(out)
	var scene_path := BASE.path_join(id + ".tscn")
	if FileAccess.file_exists(scene_path):
		print("skip existing source scene: ", id)
		return
	var fx := Node3D.new()
	fx.name = id.to_pascal_case()
	fx.set_script(load(BASE + "source_effect.gd"))
	fx.effect_id = id
	fx.kind = data.preset.kind
	fx.variant = data.preset.variant
	fx.burst = data.preset.burst
	fx.duration = data.preset.duration
	fx.start_duration = data.lifecycle.start
	fx.end_duration = data.lifecycle.end
	fx.set_meta("vfx_source", "00gamedevs")
	fx.set_meta("vfx_id", id)
	var parts := Node3D.new()
	B.add(fx, B.unique(parts), "Parts")
	var player := AnimationPlayer.new()
	B.add(fx, B.unique(player), "Motion")
	var active := Animation.new()
	active.length = data.preset.duration
	active.step = 1.0 / data.fps
	for mesh_data: Dictionary in data.meshes:
		var index: int = mesh_data.index
		var state: Dictionary = data.samples[0][index]
		var shader_path := out.path_join("spatial_part_%d.gdshader" % index)
		var text := FileAccess.get_file_as_string(source.path_join(id).path_join("spatial_part_%d.gdshader" % index))
		var shader_file := FileAccess.open(shader_path, FileAccess.WRITE)
		shader_file.store_string(text)
		shader_file.close()
		var shader := load(shader_path) as Shader
		var parameter_types: Dictionary = {}
		for item: Dictionary in shader.get_shader_uniform_list():
			parameter_types[item.name] = item.type
		mesh_data["parameter_types"] = parameter_types
		if parameter_types.is_empty():
			ok = false
			fx.free()
			return
		var material := ShaderMaterial.new()
		material.resource_local_to_scene = true
		material.shader = shader
		material.render_priority = int(mesh_data.material.get("renderOrder", index))
		for parameter: String in state.uniforms:
			material.set_shader_parameter(parameter, _value(state.uniforms[parameter], parameter_types.get(parameter, TYPE_NIL)))
		material.set_shader_parameter("source_to_group", _transform(state.matrix))
		material.set_shader_parameter("source_draw_start", float(state.drawStart))
		material.set_shader_parameter("source_draw_count", float(state.drawCount))
		material.set_shader_parameter("source_vertices_per_instance", int(mesh_data.vertices_per_instance))
		material.set_shader_parameter("source_instance_count", float(state.instances))
		var mesh := MeshInstance3D.new()
		mesh.name = "Part%03d" % index
		mesh.mesh = _mesh(data.id, mesh_data, out)
		if mesh.mesh == null:
			ok = false
			mesh.free()
			fx.free()
			return
		mesh.material_override = material
		mesh.transform = _transform(state.matrix)
		mesh.visible = state.visible
		mesh.custom_aabb = AABB(Vector3(-64, -64, -64), Vector3(128, 128, 128))
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.set_meta("source_name", mesh_data.name)
		# Source planes select the dense transition mesh outside the active phase.
		var range_active: int = -1
		var range_transition: int = -1
		for sample: Array in data.samples:
			var sample_state: Dictionary = sample[index]
			if sample_state.drawStart == 0 and sample_state.drawCount > 0:
				range_active = sample_state.drawCount
			elif sample_state.drawStart > 0:
				range_transition = sample_state.drawCount
		if range_active > 0 and range_transition > 0:
			mesh.set_meta("phase_ranges", [range_active, range_transition])
		B.add(parts, mesh, String(mesh.name))
		var path := "Parts/" + String(mesh.name)
		_track(active, path + ":transform", data, index, "matrix")
		_track(active, path + ":visible", data, index, "visible")
		_track(active, path + ":material_override:shader_parameter/source_instance_count", data, index, "instances")
		for parameter: String in state.uniforms:
			if parameter not in STANDARD:
				_track(active, path + ":material_override:shader_parameter/" + parameter, data, index, "uniforms", parameter)
	var library := AnimationLibrary.new()
	library.add_animation(&"active", active)
	var motion_path := out.path_join("motion.res")
	ok = ResourceSaver.save(library, motion_path) == OK and ok
	player.add_animation_library(&"", load(motion_path))
	var result := B.save_scene(fx, scene_path)
	ok = result.ok and ok
	print(id, " mesh vertices=", data.meshes.reduce(func(total: int, item: Dictionary) -> int: return total + int(item.vertex_count), 0), " tracks=", active.get_track_count())

func _mesh(id: String, data: Dictionary, out: String) -> ArrayMesh:
	var raw := FileAccess.get_file_as_bytes(source.path_join(id).path_join(str(int(data.index)) + ".bin")).to_float32_array()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var custom: Array[PackedFloat32Array] = []
	for _channel: int in data.channels:
		custom.append(PackedFloat32Array())
	var stride: int = 8 + int(data.extra_floats)
	_expect(raw.size() == int(data.vertex_count) * stride, "packed geometry byte count")
	if raw.size() != int(data.vertex_count) * stride:
		return null
	for index: int in data.vertex_count:
		var at: int = index * stride
		vertices.append(Vector3(raw[at], raw[at + 1], raw[at + 2]))
		normals.append(Vector3(raw[at + 3], raw[at + 4], raw[at + 5]))
		uv.append(Vector2(raw[at + 6], raw[at + 7]))
		for channel: int in data.channels:
			for lane: int in 4:
				custom[channel].append(raw[at + 8 + channel * 4 + lane])
		if data.has_uv2:
			uv2.append(Vector2(raw[at + 24], raw[at + 25]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	if data.has_uv2:
		arrays[Mesh.ARRAY_TEX_UV2] = uv2
	var flags: int = 0
	for channel: int in data.channels:
		arrays[Mesh.ARRAY_CUSTOM0 + channel] = custom[channel]
		flags |= Mesh.ARRAY_CUSTOM_RGBA_FLOAT << (Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT + channel * Mesh.ARRAY_FORMAT_CUSTOM_BITS)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	mesh.set_meta("godot_clockwise", true)
	var path := out.path_join("part_%d.res" % int(data.index))
	ok = ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS) == OK and ok
	return load(path) as ArrayMesh

func _track(animation: Animation, path: String, data: Dictionary, mesh_index: int, field: String, parameter: String = "") -> void:
	var values: Array = []
	for sample: Array in data.samples:
		var value: Variant = sample[mesh_index][field]
		if not parameter.is_empty():
			value = value[parameter]
		values.append(value)
	var changing: bool = false
	for value: Variant in values:
		if value != values[0]:
			changing = true
			break
	if not changing:
		return
	var track: int = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath(path))
	var discrete: bool = field == "visible" or data.meshes[mesh_index].get("parameter_types", {}).get(parameter, TYPE_NIL) == TYPE_PACKED_VECTOR4_ARRAY
	animation.value_track_set_update_mode(track, Animation.UPDATE_DISCRETE if discrete else Animation.UPDATE_CONTINUOUS)
	for index: int in values.size():
		var value: Variant = _transform(values[index]) if field == "matrix" else _value(values[index], data.meshes[mesh_index].get("parameter_types", {}).get(parameter, TYPE_NIL))
		animation.track_insert_key(track, minf(animation.length, float(index) / data.fps), value)

func _transform(values: Array) -> Transform3D:
	return Transform3D(Basis(Vector3(values[0], values[1], values[2]), Vector3(values[4], values[5], values[6]), Vector3(values[8], values[9], values[10])), Vector3(values[12], values[13], values[14]))

func _value(value: Variant, expected: int = TYPE_NIL) -> Variant:
	if value is Dictionary:
		var a: Array = value.value
		match value.type:
			"color", "Vector4": return Vector4(a[0], a[1], a[2], a[3]) if value.type == "Vector4" else Vector3(a[0], a[1], a[2])
			"Vector3": return Vector3(a[0], a[1], a[2])
			"Vector2": return Vector2(a[0], a[1])
			"Matrix3": return Basis(Vector3(a[0], a[1], a[2]), Vector3(a[3], a[4], a[5]), Vector3(a[6], a[7], a[8]))
			"Matrix4": return Projection(Vector4(a[0], a[1], a[2], a[3]), Vector4(a[4], a[5], a[6], a[7]), Vector4(a[8], a[9], a[10], a[11]), Vector4(a[12], a[13], a[14], a[15]))
	if value is Array:
		if expected == TYPE_PACKED_VECTOR4_ARRAY and not value.is_empty() and value[0] is float:
			var packed := PackedVector4Array()
			for index: int in range(0, value.size(), 4):
				packed.append(Vector4(value[index], value[index + 1], value[index + 2], value[index + 3]))
			return packed
		if not value.is_empty() and value[0] is Dictionary:
			var vectors := PackedVector4Array()
			for item: Variant in value:
				vectors.append(_value(item))
			return vectors
		return PackedFloat32Array(value)
	return value
