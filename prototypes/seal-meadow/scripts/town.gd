extends Node3D
## The village: a flat plaza with the elder and a portal back to the meadow. Walking circles come from its props.

@onready var props: Node3D = %Props


## Vector3(x, z, radius) for every prop whose block_radius > 0 (world coordinates).
func blockers() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for prop: Node3D in props.get_children():
		var r: float = prop.get_meta(&"block_radius", 0.0) * prop.scale.x
		if r > 0.0:
			out.append(Vector3(prop.global_position.x, prop.global_position.z, r))
	return out
