extends RefCounted
## Preserves the authored rock shell. Only the polygons intersecting the removed cells are clipped.

const EPSILON := 0.0001
const MIN_FRAGMENT_WIDTH := 0.015
const HEIGHT_BUCKET := 1.0
const PROBE := Vector3.RIGHT

var original: Array[Dictionary] = []
var skin: Array[Dictionary] = []
var by_height: Dictionary[int, Array] = {}


func _init(surface: MeshInstance3D) -> void:
	var arrays := surface.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var count := index.size() if not index.is_empty() else vertices.size()
	for first in range(0, count, 3):
		var polygon := PackedVector3Array()
		for corner in range(first, first + 3):
			var vertex := index[corner] if not index.is_empty() else corner
			polygon.append(surface.transform * vertices[vertex])
		var color_index := index[first] if not index.is_empty() else first
		var color := colors[color_index] if color_index < colors.size() else Color.WHITE
		var normal := (polygon[2] - polygon[0]).cross(polygon[1] - polygon[0]).normalized()
		var plane := Plane(normal, normal.dot(polygon[0]))
		var triangle := {"polygon": polygon, "bounds": _bounds(polygon).grow(EPSILON),
			"plane": plane, "color": color}
		original.append(triangle)
		var bounds: AABB = triangle.bounds
		for bucket in range(_height_key(bounds.position.y), _height_key(bounds.end.y) + 1):
			if not by_height.has(bucket):
				by_height[bucket] = []
			by_height[bucket].append(triangle)
	skin = original.duplicate()


## The visible entry spans the surface between sampled cell centers.
func remove_entry(point: Vector3, normal: Vector3, cell_size: float) -> bool:
	var tangent := normal.cross(Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT).normalized()
	var bitangent := normal.cross(tangent)
	var planes: Array[Plane] = [
		Plane(normal, normal.dot(point) + cell_size * 0.34),
		Plane(-normal, -normal.dot(point) + cell_size * 0.75),
	]
	for side in 8:
		var angle := TAU * side / 8.0
		var axis := tangent * cos(angle) + bitangent * sin(angle)
		planes.append(Plane(axis, axis.dot(point) + cell_size * 0.67))
	return remove(planes, AABB(point, Vector3.ZERO).grow(cell_size * 1.2))


## Cut the union of the removed cells, skipping disjoint polygons by their bounds.
func remove(hole_planes: Array[Plane], bounds: AABB) -> bool:
	var changed := false
	var keep: Array[Dictionary] = []
	for piece in skin:
		if not bounds.intersects(piece.bounds):
			keep.append(piece)
			continue
		var polygon: PackedVector3Array = piece.polygon
		var remain := polygon
		var partitions: Array[PackedVector3Array] = []
		for plane: Plane in hole_planes:
			var outside := Geometry3D.clip_polygon(remain, -plane)
			remain = Geometry3D.clip_polygon(remain, plane)
			if remain.size() < 3:
				break
			if outside.size() >= 3:
				partitions.append(outside)
		if remain.size() < 3:
			keep.append(piece)
			continue
		changed = true
		for outside in partitions:
			if _usable_fragment(outside):
				keep.append({"polygon": outside, "bounds": _bounds(outside).grow(EPSILON),
					"plane": piece.plane, "color": piece.color})
	if changed:
		skin = keep
	return changed


static func _usable_fragment(polygon: PackedVector3Array) -> bool:
	if polygon.size() < 3:
		return false
	var area_vector := Vector3.ZERO
	for index in range(2, polygon.size()):
		area_vector += (polygon[index - 1] - polygon[0]).cross(polygon[index] - polygon[0])
	var longest_edge_squared := 0.0
	for index in polygon.size():
		longest_edge_squared = maxf(longest_edge_squared,
			polygon[index].distance_squared_to(polygon[(index + 1) % polygon.size()]))
	return area_vector.length_squared() > longest_edge_squared * MIN_FRAGMENT_WIDTH * MIN_FRAGMENT_WIDTH


## Partition a fracture face along authored triangles that cross it, then keep the interior pieces.
## The original volumes are not convex, so a single hull clipping pass would fill concave gaps.
func interior(polygon: PackedVector3Array, face_normal: Vector3) -> Array[PackedVector3Array]:
	var bounds := _bounds(polygon).grow(EPSILON * 4)
	var plane := Plane(face_normal, face_normal.dot(polygon[0]))
	var pieces: Array[PackedVector3Array] = [polygon]
	for triangle in original:
		if not bounds.intersects(triangle.bounds):
			continue
		if not _cuts_bounds(triangle.polygon, plane, bounds):
			continue
		var next: Array[PackedVector3Array] = []
		var splitter: Plane = triangle.plane
		for piece in pieces:
			var back := Geometry3D.clip_polygon(piece, splitter)
			var front := Geometry3D.clip_polygon(piece, -splitter)
			if back.size() >= 3 and front.size() >= 3:
				next.append(back)
				next.append(front)
			else:
				next.append(piece)
		pieces = next
	# Probe from the face towards the retained rock so an exact boundary is stable.
	var interior_pieces: Array[PackedVector3Array] = []
	for piece in pieces:
		var middle := Vector3.ZERO
		for vertex in piece:
			middle += vertex
		middle /= piece.size()
		if _usable_fragment(piece) and _inside(middle - face_normal * (EPSILON * 3)):
			interior_pieces.append(piece)
	return interior_pieces


func _inside(point: Vector3) -> bool:
	var hits: Array[float] = []
	var triangles: Array = by_height.get(_height_key(point.y), [])
	for triangle in triangles:
		var bounds: AABB = triangle.bounds
		if bounds.end.x < point.x or point.y < bounds.position.y or point.y > bounds.end.y:
			continue
		if point.z < bounds.position.z or point.z > bounds.end.z:
			continue
		var face: PackedVector3Array = triangle.polygon
		var hit: Variant = Geometry3D.ray_intersects_triangle(point, PROBE, face[0], face[1], face[2])
		if hit == null:
			continue
		var distance := point.distance_squared_to(hit)
		var unique := true
		for previous: float in hits:
			if absf(distance - previous) < 0.00001:
				unique = false
				break
		if unique:
			hits.append(distance)
	return hits.size() % 2 == 1


func _cuts_bounds(polygon: PackedVector3Array, plane: Plane, bounds: AABB) -> bool:
	var segment := PackedVector3Array()
	for index in polygon.size():
		var a := polygon[index]
		var b := polygon[(index + 1) % polygon.size()]
		var da := plane.distance_to(a)
		var db := plane.distance_to(b)
		if absf(da) < EPSILON:
			segment.append(a)
		if da * db < 0.0:
			segment.append(a.lerp(b, da / (da - db)))
	return segment.size() >= 2 and bounds.intersects_segment(segment[0], segment[1])


func make_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for piece in skin:
		var polygon: PackedVector3Array = piece.polygon
		var normal: Vector3 = piece.plane.normal
		for index in range(2, polygon.size()):
			vertices.append_array([polygon[0], polygon[index - 1], polygon[index]])
			normals.append_array([normal, normal, normal])
			colors.append_array([piece.color, piece.color, piece.color])
	var mesh := ArrayMesh.new()
	if not vertices.is_empty():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _height_key(y: float) -> int:
	return floori(y / HEIGHT_BUCKET)


static func _bounds(polygon: PackedVector3Array) -> AABB:
	var bounds := AABB(polygon[0], Vector3.ZERO)
	for vertex in polygon:
		bounds = bounds.expand(vertex)
	return bounds
