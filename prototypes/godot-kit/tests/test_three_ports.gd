extends "res://addons/proto_kit/test_kit.gd"
const Library = preload("res://addons/proto_kit/vfx/library.gd")
const BASE := "res://addons/proto_kit/vfx/3d/00gamedevs/"
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	var reference: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/three_reference.json"))
	_expect(reference.size() == 42, "42 source-geometry effects have independent JS references")
	for effect: Dictionary in reference:
		_test_source(effect)
	_test_trail()
	_test_impact()
	print("THREE PORT checks: ", checks)
	_finish("THREE PORT TESTS")

func _test_source(data: Dictionary) -> void:
	var fx: Node3D = Library.get_scene(data.id, "3d").instantiate()
	fx.auto_step = false
	root.add_child(fx)
	var finished_count := [0]
	fx.finished.connect(func() -> void: finished_count[0] += 1)
	var independent: Node3D = Library.get_scene(data.id, "3d").instantiate()
	independent.auto_step = false
	root.add_child(independent)
	_expect(independent.parts.get_child(0).material_override != fx.parts.get_child(0).material_override, data.id + " instances own independent material parameters")
	_expect(independent.parts.get_child(0).mesh == fx.parts.get_child(0).mesh, data.id + " instances share immutable mesh buffers")
	_expect(fx.parts.get_child_count() == data.meshes.size(), data.id + " real part count")
	for part: Dictionary in data.meshes:
		var node := fx.parts.get_child(int(part.index)) as MeshInstance3D
		_expect(node.mesh != null and node.mesh.get_surface_count() == 1, data.id + " saved mesh exists")
		var arrays: Array = node.mesh.surface_get_arrays(0)
		_expect(arrays[Mesh.ARRAY_VERTEX].size() == part.vertices, data.id + " original triangle/instance vertex count")
		for corner: int in 3:
			var point: Array = part.first_triangle[[0,2,1][corner]]
			_expect(arrays[Mesh.ARRAY_VERTEX][corner].is_equal_approx(Vector3(point[0],point[1],point[2])), data.id + " native clockwise triangle conversion")
		var first: Vector3 = arrays[Mesh.ARRAY_VERTEX][0]
		_expect(first.is_equal_approx(Vector3(part.first_position[0],part.first_position[1],part.first_position[2])), data.id + " actual first source vertex")
		var expected_order: int = int(part.render_order) - (128 if part.always_opaque and int(part.blending) not in [0,1] else 0)
		_expect(node.material_override.render_priority == expected_order, data.id + " source render order / opaque blend pass")
		for attribute: String in part.extra:
			var source_values: Array = part.extra[attribute]
			var matches: bool = true
			for lane: int in source_values.size():
				var offset: int = int(part.layout[attribute]) + lane
				var value: float = arrays[Mesh.ARRAY_TEX_UV2][0][offset - 16] if offset >= 16 else arrays[Mesh.ARRAY_CUSTOM0 + offset / 4][offset % 4]
				matches = matches and absf(value - source_values[lane]) < 0.00001
			_expect(matches, data.id + " exact attribute: " + attribute)
	for sample: Dictionary in data.reference:
		fx.step(float(sample.time) - fx.elapsed)
		_compare(data.id, fx, sample.meshes)
	_expect(independent.elapsed == 0.0, data.id + " reference playback never advances another instance")
	independent.free()
	if not data.preset.burst:
		fx.step(float(data.preset.duration) - fx.elapsed)
		fx.stop()
		fx.step(data.ending_time)
		_compare(data.id + " STOP", fx, data.ending_reference)
		fx.step(data.lifecycle.end + 0.1)
		_expect(fx.is_finished and not fx.visible, data.id + " stop drains and finishes")
	else:
		fx.step(data.preset.duration + 2.0)
		_expect(fx.is_finished and not fx.visible, data.id + " one shot finishes")
	_expect(finished_count[0] == 1, data.id + " finish signal emitted once")
	fx.step(100.0)
	_expect(finished_count[0] == 1, data.id + " completed effect does not emit twice")
	fx.reset()
	_expect(not fx.is_finished and fx.elapsed == 0.0, data.id + " reset reuses source scene")
	fx.step(NAN)
	fx.step(INF)
	fx.step(-1)
	_expect(fx.elapsed == 0.0, data.id + " invalid time rejected")
	if fx.kind == 0:
		fx.set_direction(Vector3.UP, 2.0)
		fx.speed = 0.5
		fx.step(0.1)
		_expect(fx.position.is_equal_approx(Vector3(0, 0.2, 0)), data.id + " travel uses world delta rather than visual speed")
		_expect(is_equal_approx(fx.elapsed, 0.05), data.id + " visual speed scales the effect clock")
		fx.reset()
		fx.speed = 1.0
		fx.step(0.5)
		fx.parts.position = Vector3(0, 0.3, 0)
		fx.parts.rotation.z = 0.25
		fx.hit(Vector3(8, 2, 0), Vector3.UP)
		_expect(fx.phase == &"ending", data.id + " confirmed hit ends projectile")
		if data.id == "fireball":
			_expect(fx._materials[0].get_shader_parameter("source_instance_count") == fx._initial_instances[0] - 12.0, "fireball reserves twelve source slots for impact billows")
		for part: Node3D in fx.parts.get_children():
			if part.get_meta("source_name", "") == "lifecycle-impact":
				_expect(part.global_position.is_equal_approx(Vector3(8, 2, 0)), data.id + " actual impact anchors to world contact after editor origin adjustment")
				_expect(part.global_basis.x.normalized().dot(Vector3.UP) > 0.999, data.id + " actual impact faces the contact normal")
	if fx.kind == 1:
		fx.reset()
		fx.set_endpoints(Vector3(-2, 1, 0), Vector3(4, 1, 0))
		_expect(fx.position.is_equal_approx(Vector3(1, 1, 0)), data.id + " beam endpoints set true midpoint")
		_expect(is_equal_approx(fx.scale.x, 1.25), data.id + " beam endpoints scale original 4.8-unit mesh")
		fx.set_endpoints(Vector3.ONE, Vector3.ONE)
		_expect(not fx.visible, data.id + " zero-length beam hidden")
		fx.reset()
		_expect(not fx.visible, data.id + " reset preserves zero-length endpoint state")
	fx.free()

func _compare(id: String, fx: Node3D, states: Array) -> void:
	for index: int in states.size():
		var part := fx.parts.get_child(index) as MeshInstance3D
		var state: Dictionary = states[index]
		_expect(part.visible == state.visible, id + " part visibility " + str(index))
		var matrix: Array = state.matrix
		var expected := Transform3D(Basis(Vector3(matrix[0],matrix[1],matrix[2]),Vector3(matrix[4],matrix[5],matrix[6]),Vector3(matrix[8],matrix[9],matrix[10])),Vector3(matrix[12],matrix[13],matrix[14]))
		_expect(part.transform.is_equal_approx(expected), id + " JS transform " + str(index))
		var material := part.material_override as ShaderMaterial
		var declared: Dictionary = {}
		for parameter: Dictionary in material.shader.get_shader_uniform_list():
			declared[parameter.name] = int(parameter.type)
		for name: String in state.uniforms:
			if not declared.has(name):
				continue
			var actual: Variant = material.get_shader_parameter(name)
			if declared[name] == TYPE_PACKED_VECTOR4_ARRAY:
				_expect(typeof(actual) == TYPE_PACKED_VECTOR4_ARRAY, id + " real GPU vec4-array type " + name)
			var expected_value: Variant = state.uniforms[name]
			_expect(_same(actual, expected_value), id + " JS uniform " + name + " part " + str(index) + " at " + str(fx.elapsed))
		_expect(_same(material.get_shader_parameter("source_draw_start"), state.drawStart), id + " draw start")
		_expect(_same(material.get_shader_parameter("source_draw_count"), state.drawCount), id + " draw count")
		_expect(_same(material.get_shader_parameter("source_instance_count"), state.instances), id + " instance count")
		if part.has_meta("source_depth_shader"):
			_expect(material.shader.code.contains("depth_draw_always") == state.depthWrite, id + " source depth write phase")

func _same(actual: Variant, expected: Variant) -> bool:
	var a: Array[float] = []
	var b: Array[float] = []
	_flatten(actual, a)
	_flatten(expected, b)
	if a.size() != b.size():
		return false
	for index: int in a.size():
		if absf(a[index] - b[index]) > 0.00015:
			return false
	return true

func _flatten(value: Variant, out: Array[float]) -> void:
	if value is Dictionary:
		var array: Array = value.value
		if value.type == "color":
			array = array.slice(0, 3)
		_flatten(array, out)
	elif value is float or value is int:
		out.append(float(value))
	elif value is Vector2:
		out.append_array([value.x, value.y])
	elif value is Vector3:
		out.append_array([value.x, value.y, value.z])
	elif value is Vector4:
		out.append_array([value.x, value.y, value.z, value.w])
	elif value is Array or value is PackedFloat32Array or value is PackedVector4Array:
		for item: Variant in value:
			_flatten(item, out)

func _test_trail() -> void:
	var fx: Node3D = Library.get_scene("weapon-smear", "3d").instantiate()
	fx.auto_step = false
	var weapon := Node3D.new()
	root.add_child(weapon)
	root.add_child(fx)
	_expect(not fx.attach_weapon(weapon, Vector3.ZERO, Vector3.ZERO), "trail rejects zero-length weapon")
	_expect(fx.attach_weapon(weapon), "trail binds actual weapon")
	fx.step(0.01)
	for index: int in 8:
		weapon.position.x += 0.1
		fx.step(0.01)
	_expect(fx.get_node("Layers/Layer0").mesh.get_surface_count() == 1, "moving weapon produces real ribbon triangles")
	var arrays: Array = fx.get_node("Layers/Layer0").mesh.surface_get_arrays(0)
	_expect(arrays[Mesh.ARRAY_VERTEX].size() <= 128, "trail has bounded history")
	_expect(arrays[Mesh.ARRAY_INDEX].size() > 0, "trail has indexed triangles")
	weapon.position.x += 20.0
	fx.step(0.01)
	_expect(fx.get_node("Layers/Layer0").mesh.get_surface_count() == 0, "teleport does not bridge a giant trail")
	fx.stop()
	fx.step(0.19)
	_expect(fx.is_finished and not fx.visible, "trail stop drains 0.18-second history")
	fx.reset()
	_expect(not fx.is_finished, "trail reset reuses binding")
	weapon.free()
	fx.step(0.01)
	fx.step(0.19)
	_expect(fx.is_finished, "freed weapon drains its remaining trail safely")
	fx.free()

func _test_impact() -> void:
	var fx: Node = Library.get_scene("impact-frame", "3d").instantiate()
	fx.auto_step = false
	root.add_child(fx)
	_expect(not fx.active and not fx.overlay.visible, "postprocess inactive by default")
	_expect(fx.trigger(Vector2(0.3, 0.7)), "confirmed hit starts postprocess")
	_expect(not fx.trigger(), "active impact ignores duplicate trigger")
	_expect(fx.current_pose == 0, "first impact pose preserved")
	fx.step(4.0 / 60.0)
	_expect(fx.current_pose == 1, "second pose timing matches JS")
	fx.step(4.0 / 60.0)
	_expect(fx.current_pose == 2, "third pose timing matches JS")
	fx.step(1.0)
	_expect(fx.is_finished and not fx.overlay.visible, "impact restores unmodified frame at 0.4 seconds")
	fx.reset()
	_expect(fx.trigger(), "impact can be reused")
	fx.free()
