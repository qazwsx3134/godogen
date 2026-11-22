## Hand-authored low-poly silhouettes based on the guide linked in the README.
## Body rings are (longitudinal position, half-height, half-width).
extends RefCounted

const Geometry = preload("res://tools/betta_geometry.gd")


static func cardinal() -> Dictionary:
	return _model(
		[[-0.34, 0.029, 0.018], [-0.24, 0.051, 0.027],
		[-0.13, 0.078, 0.042], [0.01, 0.10, 0.060],
		[0.16, 0.087, 0.059], [0.27, 0.060, 0.044],
		[0.34, 0.032, 0.024], [0.35, 0.008, 0.009]], 0.22,
		[[-0.07, 0.028], [-0.20, 0.13], [-0.28, 0.16], [-0.24, 0.062],
		[-0.166, 0], [-0.24, -0.066], [-0.275, -0.15], [-0.18, -0.121], [-0.05, -0.021]],
		[[0.11, 0.08], [0.045, 0.175], [-0.055, 0.147], [-0.13, 0.064]], Vector3(0.019, 0.059, 0),
		[[0.095, -0.085], [0.021, -0.136], [-0.095, -0.119], [-0.20, -0.055]], Vector3(-0.005, -0.062, 0),
		Vector3(0.24, 0.028, 0.043), 0.073, Vector3(0.15, -0.029, 0.049), 0.57
	)


static func discus() -> Dictionary:
	return _model(
		[[-0.45, 0.058, 0.031], [-0.37, 0.196, 0.064], [-0.29, 0.33, 0.089],
		[-0.16, 0.418, 0.109], [0.02, 0.439, 0.119], [0.18, 0.398, 0.117],
		[0.32, 0.296, 0.100], [0.43, 0.156, 0.071], [0.52, 0.059, 0.040],
		[0.55, 0.013, 0.008]], 0.91,
		[[-0.09, 0.062], [-0.25, 0.149], [-0.36, 0.141], [-0.38, 0.06],
		[-0.38, -0.06], [-0.35, -0.136], [-0.25, -0.139], [-0.08, -0.052]],
		[[0.35, 0.25], [0.29, 0.365], [0.16, 0.46], [0.01, 0.503],
		[-0.16, 0.49], [-0.30, 0.416], [-0.39, 0.304], [-0.45, 0.13]], Vector3(-0.07, 0.265, 0),
		[[0.36, -0.22], [0.28, -0.347], [0.15, -0.445], [-0.02, -0.49],
		[-0.18, -0.458], [-0.31, -0.38], [-0.4, -0.26], [-0.45, -0.12]], Vector3(-0.07, -0.24, 0),
		Vector3(0.377, 0.105, 0.077), 0.108, Vector3(0.31, -0.069, 0.094), 1.23
	)


static func pale_chub() -> Dictionary:
	return _model(
		[[-0.52, 0.041, 0.027], [-0.41, 0.068, 0.043], [-0.25, 0.121, 0.072],
		[-0.09, 0.156, 0.088], [0.13, 0.166, 0.099], [0.29, 0.129, 0.082],
		[0.43, 0.081, 0.061], [0.54, 0.045, 0.039], [0.565, 0.009, 0.012]], 0.37,
		[[-0.08, 0.041], [-0.24, 0.166], [-0.39, 0.21], [-0.31, 0.101],
		[-0.226, 0.014], [-0.32, -0.091], [-0.39, -0.18], [-0.25, -0.151], [-0.09, -0.037]],
		[[0.22, 0.145], [0.114, 0.277], [0.012, 0.23], [-0.15, 0.146]], Vector3(-0.01, 0.113, 0),
		[[0.11, -0.162], [0.028, -0.259], [-0.115, -0.221], [-0.236, -0.108]], Vector3(-0.035, -0.094, 0),
		Vector3(0.389, 0.037, 0.065), 0.092, Vector3(0.26, -0.042, 0.073), 0.88
	)


static func _model(rings: Array, uv_height: float, tail_outline: Array,
		dorsal_outline: Array, dorsal_origin: Vector3, anal_outline: Array, anal_origin: Vector3,
		eye: Vector3, eye_size: float, pectoral: Vector3, pectoral_scale: float) -> Dictionary:
	var profile := _vectors(rings)
	var tail := _vectors(tail_outline)
	var tail_bounds := AABB(Vector3.ZERO, Vector3.ZERO)
	for edge in tail:
		tail_bounds = tail_bounds.expand(edge)
	var length_x := profile[-1].x - profile[0].x
	return {
		"body": Geometry.body_from_profile(profile, uv_height),
		"caudal": Geometry.fin(tail, Vector3.ZERO),
		"dorsal": Geometry.fin(_vectors(dorsal_outline), dorsal_origin),
		"anal": Geometry.fin(_vectors(anal_outline), anal_origin),
		"tail_x": profile[0].x + 0.015,
		"body_pick_size": Vector3(length_x, uv_height, 0.24),
		"body_pick_offset": Vector3((profile[0].x + profile[-1].x) * 0.5, 0, 0),
		"tail_pick_size": Vector3(tail_bounds.size.x, tail_bounds.size.y, 0.17),
		"tail_pick_offset": tail_bounds.get_center(),
		"eye": eye, "eye_size": eye_size,
		"pectoral": pectoral, "pectoral_scale": pectoral_scale,
	}


static func _vectors(points: Array) -> PackedVector3Array:
	var vectors := PackedVector3Array()
	for point: Array in points:
		var z: float = point[2] if point.size() == 3 else 0.0
		vectors.append(Vector3(point[0], point[1], z))
	return vectors
