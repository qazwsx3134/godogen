## Source geometry for fish bodies and fins. The head points toward local +X.
extends RefCounted


static func body() -> ArrayMesh:
	var profile := PackedVector3Array([
		Vector3(-0.37, 0.049, 0.039), Vector3(-0.27, 0.078, 0.06),
		Vector3(-0.14, 0.123, 0.087), Vector3(0.04, 0.165, 0.108),
		Vector3(0.22, 0.152, 0.104), Vector3(0.36, 0.108, 0.076),
		Vector3(0.45, 0.052, 0.043), Vector3(0.47, 0.008, 0.008)
	])
	return body_from_profile(profile, 0.36)


static func body_from_profile(profile: PackedVector3Array, uv_height: float) -> ArrayMesh:
	var tail_x := profile[0].x
	var body_length := profile[-1].x - tail_x
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 20
	for ring in profile.size() - 1:
		for side in sides:
			for corner in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1),
					Vector2i(0, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var section := profile[ring + corner.x]
				var angle := float(side + corner.y) * TAU / sides
				var y := cos(angle) * section.y
				var z := sin(angle) * section.z
				mesh.set_uv(Vector2((section.x - tail_x) / body_length, 0.5 - y / uv_height))
				mesh.add_vertex(Vector3(section.x, y, z))
	mesh.generate_normals()
	return mesh.commit()


static func fin(outline: PackedVector3Array, origin: Vector3) -> ArrayMesh:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 5
	for edge in outline.size() - 1:
		for ring in steps:
			var inner := float(ring) / steps
			var outer := float(ring + 1) / steps
			_fin_vertex(mesh, outline, origin, edge, inner)
			_fin_vertex(mesh, outline, origin, edge + 1, outer)
			_fin_vertex(mesh, outline, origin, edge, outer)
			if ring > 0:
				_fin_vertex(mesh, outline, origin, edge, inner)
				_fin_vertex(mesh, outline, origin, edge + 1, inner)
				_fin_vertex(mesh, outline, origin, edge + 1, outer)
	mesh.generate_normals()
	return mesh.commit()


static func _fin_vertex(mesh: SurfaceTool, outline: PackedVector3Array, origin: Vector3,
		edge: int, distance: float) -> void:
	var spread := float(edge) / (outline.size() - 1)
	var point := origin.lerp(outline[edge], distance)
	point.z += sin(spread * TAU * 2.0) * distance * distance * 0.035
	mesh.set_uv(Vector2(distance, spread))
	mesh.add_vertex(point)


static func short_tail() -> ArrayMesh:
	return fin(PackedVector3Array([
		Vector3(-0.17, 0.03, 0.0), Vector3(-0.29, 0.14, -0.012),
		Vector3(-0.4, 0.16, 0.0), Vector3(-0.43, 0.08, 0.018),
		Vector3(-0.45, 0.0, 0.025), Vector3(-0.4, -0.11, 0.0),
		Vector3(-0.32, -0.154, -0.018), Vector3(-0.21, -0.10, 0.0),
		Vector3(-0.13, -0.028, 0.0)
	]), Vector3.ZERO)


static func long_tail() -> ArrayMesh:
	return fin(PackedVector3Array([
		Vector3(-0.23, 0.13, 0.0), Vector3(-0.41, 0.254, -0.022),
		Vector3(-0.62, 0.29, -0.035), Vector3(-0.82, 0.22, 0.018),
		Vector3(-0.74, 0.11, 0.04), Vector3(-0.61, 0.022, 0.033),
		Vector3(-0.78, -0.053, 0.029), Vector3(-0.89, -0.19, 0.012),
		Vector3(-0.68, -0.234, -0.034), Vector3(-0.49, -0.19, -0.02),
		Vector3(-0.24, -0.08, 0.0)
	]), Vector3.ZERO)


static func dorsal() -> ArrayMesh:
	return fin(PackedVector3Array([
		Vector3(0.19, 0.135, 0.0), Vector3(0.055, 0.243, 0.013),
		Vector3(-0.06, 0.278, -0.018), Vector3(-0.23, 0.252, -0.028),
		Vector3(-0.36, 0.177, 0.01), Vector3(-0.33, 0.062, 0.0)
	]), Vector3(-0.085, 0.075, 0.0))


static func anal() -> ArrayMesh:
	return fin(PackedVector3Array([
		Vector3(0.14, -0.136, 0.0), Vector3(0.035, -0.214, 0.003),
		Vector3(-0.105, -0.247, 0.013), Vector3(-0.32, -0.25, -0.013),
		Vector3(-0.44, -0.20, -0.018), Vector3(-0.34, -0.056, 0.0)
	]), Vector3(-0.14, -0.065, 0.0))


static func pectoral(side: float) -> ArrayMesh:
	return fin(PackedVector3Array([
		Vector3(-0.055, 0.01, 0.015 * side), Vector3(-0.18, -0.038, 0.08 * side),
		Vector3(-0.24, -0.104, 0.095 * side), Vector3(-0.15, -0.09, 0.09 * side)
	]), Vector3.ZERO)
