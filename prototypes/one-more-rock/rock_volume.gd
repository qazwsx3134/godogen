extends StaticBody3D

signal chipped(point: Vector3, normal: Vector3, count: int)
signal detached(mesh: ArrayMesh, base: Vector3, count: int, normal: Vector3)

const NORMALS: Array[Vector3i] = [
	Vector3i.RIGHT, Vector3i.LEFT, Vector3i.UP, Vector3i.DOWN, Vector3i.BACK, Vector3i.FORWARD,
]
const RockSkin = preload("res://rock_skin.gd")
const VoronoiCells = preload("res://voronoi_cells.gd")
const ROCK_COLOR := Color("978770")
## Cut rock is meshed in CHUNK³-cell pieces so a hit only rebuilds the pieces it touched.
const CHUNK := 6

@export var cell_size := 0.68
@export var cell_origin := Vector3.ZERO
@export var solid_cells := PackedVector3Array()
@export var simulate_overhangs := true
@export var cut_material: Material

@onready var surface: MeshInstance3D = $Surface
@onready var collider: CollisionShape3D = $RockShape

var solid: Dictionary[Vector3i, bool] = {}
var cut_cells: Dictionary[Vector3i, bool] = {}
var highest := 0
var layer_colors := PackedColorArray()
var chunks: Dictionary[Vector3i, MeshInstance3D] = {}
var chunk_shapes: Dictionary[Vector3i, CollisionShape3D] = {}
var exposed_faces: Dictionary[Vector3i, int] = {}
var fracture_faces: Dictionary[Vector3i, Dictionary] = {}
var skin: RockSkin
var prepared := false
var authored_bounds: AABB


func _ready() -> void:
	for cell in solid_cells:
		var key := Vector3i(cell)
		solid[key] = true
		highest = maxi(highest, key.y)
	authored_bounds = surface.get_aabb()
	_sample_original_colors()


## Saves the authored triangles when the player approaches. No terrain geometry changes here.
func prepare() -> void:
	if prepared:
		return
	prepared = true
	if surface.mesh != null and surface.mesh.get_surface_count() > 0:
		skin = RockSkin.new(surface)


## True when `point` is within `margin` metres of this volume's authored bounds.
func near(point: Vector3, margin: float) -> bool:
	return (global_transform * authored_bounds).grow(margin).has_point(point)


func _sample_original_colors() -> void:
	layer_colors.resize(highest + 1)
	var base := ROCK_COLOR
	var material := surface.material_override as StandardMaterial3D
	if material:
		base = material.albedo_color
	for height in layer_colors.size():
		layer_colors[height] = base
	if surface.mesh == null or surface.mesh.get_surface_count() == 0:
		return
	var arrays := surface.mesh.surface_get_arrays(0)
	var colors = arrays[Mesh.ARRAY_COLOR]
	if not colors is PackedColorArray or colors.is_empty():
		return
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var counts := PackedInt32Array()
	counts.resize(layer_colors.size())
	var sums := PackedColorArray()
	sums.resize(layer_colors.size())
	sums.fill(Color(0, 0, 0, 0))
	for index in points.size():
		var point := surface.transform * points[index]
		var height := clampi(floori((point.y - cell_origin.y) / cell_size), 0, highest)
		sums[height] += colors[index] * base
		counts[height] += 1
	var previous := -1
	var next := 0
	for height in layer_colors.size():
		if counts[height] > 0:
			layer_colors[height] = sums[height] / float(counts[height])
			previous = height
			continue
		next = maxi(next, height + 1)
		while next <= highest and counts[next] == 0:
			next += 1
		if previous == -1:
			layer_colors[height] = sums[next] / float(counts[next]) if next <= highest else base
		elif next > highest:
			layer_colors[height] = layer_colors[previous]
		else:
			layer_colors[height] = layer_colors[previous].lerp(
				sums[next] / float(counts[next]), float(height - previous) / (next - previous)
			)


func chip(world_point: Vector3, normal: Vector3, power: int) -> bool:
	if solid.is_empty():
		return false
	var point := to_local(world_point)
	var inward := -(global_basis.inverse() * normal).normalized()
	var removed: Array[Vector3i] = []
	var shell_only: Dictionary[Vector3i, bool] = {}
	var center := point + inward * cell_size * 0.53
	var key := Vector3i(((center - cell_origin) / cell_size).floor())
	var reach := clampi(power, 1, 3)
	var radius := [1.27, 1.63, 2.30][reach - 1] as float
	prepare()
	for x in range(-reach, reach + 1):
		for y in range(-reach, reach + 1):
			for z in range(-reach, reach + 1):
				var cell := key + Vector3i(x, y, z)
				if cut_cells.has(cell):
					continue
				var offset := (_center(cell) - center) / cell_size
				var depth := offset.dot(inward)
				var radial := offset - inward * depth
				# Round corners on a slightly squared footprint. Keep the interior cut
				# shallower than the surface spread so successive strikes can leave ledges.
				var edge := maxf(absf(radial.x), maxf(absf(radial.y), absf(radial.z)))
				var distance := lerpf(radial.length(), edge, 0.28)
				var rim := radius + float((hash(cell) & 15) - 7) * 0.008
				if distance * distance + depth * depth * (1.55 if depth > 0.0 else 0.58) > rim * rim:
					continue
				if solid.has(cell):
					removed.append(cell)
				elif skin != null:
					shell_only[cell] = true
	# A smoothed exterior may extend slightly beyond the first solid cell.
	if removed.is_empty():
		var nearest := cell_size * cell_size * 6.25
		for cell in solid:
			var distance := _center(cell).distance_squared_to(center)
			if distance < nearest:
				nearest = distance
				key = cell
		if nearest >= cell_size * cell_size * 6.25:
			return false
		removed.append(key)
	# Sampled air can still contain part of the authored shell. Cut it without treating it as rock mass.
	if skin != null:
		var hit_cell: Vector3i = _hit_cell(point + inward * cell_size * 0.045)
		if not cut_cells.has(hit_cell):
			if solid.has(hit_cell) and not removed.has(hit_cell):
				removed.append(hit_cell)
			elif not solid.has(hit_cell):
				shell_only[hit_cell] = true
	for cell in removed:
		solid.erase(cell)
		cut_cells[cell] = true
	var unsupported := _unsupported_above(removed) if simulate_overhangs else {}
	if simulate_overhangs and (not unsupported.is_empty() or removed.any(func(cell: Vector3i): return cell.y <= 1)):
		_strip_unrooted(unsupported, removed + unsupported.keys())
	for cell in unsupported:
		cut_cells[cell] = true
	# A detached section can carry exterior polygons in its neighboring air cells.
	for cell: Vector3i in unsupported:
		for face: Array in _faces(cell):
			var neighbor: Vector3i = cell + face[0]
			if not solid.has(neighbor) and not cut_cells.has(neighbor):
				shell_only[neighbor] = true
	_refresh_surface(removed + unsupported.keys(), shell_only)
	chipped.emit(world_point, normal, 2 if power >= 3 else 1)
	if not unsupported.is_empty():
		_release_sections(unsupported, normal)
	return true


func _unsupported_above(removed: Array[Vector3i]) -> Dictionary:
	var affected: Dictionary[Vector2i, int] = {}
	for cell in removed:
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				var key := Vector2i(cell.x + dx, cell.z + dz)
				affected[key] = mini(affected.get(key, highest + 1), cell.y + 1)
	var fallen: Dictionary[Vector3i, bool] = {}
	var lowest := highest + 1
	for column in affected:
		lowest = mini(lowest, affected[column])
	# Recheck each layer against the current support underneath; a one-cell lip can span sideways.
	for height in range(lowest, highest + 1):
		var lost: Array[Vector3i] = []
		for column in affected:
			var cell := Vector3i(column.x, height, column.y)
			if height < affected[column] or not solid.has(cell) or solid.has(cell + Vector3i.DOWN):
				continue
			var braced := false
			for step in [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
				if solid.has(cell + step) and solid.has(cell + step + Vector3i.DOWN):
					braced = true
					break
			if not braced:
				lost.append(cell)
		for cell in lost:
			fallen[cell] = true
			solid.erase(cell)
	return fallen


## Drops pieces cut off from the ground. Only searches outward from the cells that just changed.
# ponytail: a search that passes ISLAND_LIMIT cells counts as rooted, so a giant floating slab stays up.
const ISLAND_LIMIT := 900

func _strip_unrooted(fallen: Dictionary, changed: Array) -> void:
	var rooted: Dictionary[Vector3i, bool] = {}
	for origin: Vector3i in changed:
		for step in NORMALS:
			var start := origin + step
			if not solid.has(start) or rooted.has(start):
				continue
			var queue: Array[Vector3i] = [start]
			var seen: Dictionary[Vector3i, bool] = {start: true}
			var grounded := false
			var cursor := 0
			while cursor < queue.size():
				var cell := queue[cursor]
				cursor += 1
				if cell.y == 0 or rooted.has(cell) or queue.size() > ISLAND_LIMIT:
					grounded = true
					break
				for next_step in NORMALS:
					var neighbor := cell + next_step
					if solid.has(neighbor) and not seen.has(neighbor):
						seen[neighbor] = true
						queue.append(neighbor)
			for cell in seen:
				if grounded:
					rooted[cell] = true
				else:
					fallen[cell] = true
					solid.erase(cell)


func _release_sections(fallen: Dictionary, normal: Vector3) -> void:
	while not fallen.is_empty():
		var start: Vector3i = fallen.keys()[0]
		var queue: Array[Vector3i] = [start]
		var section: Dictionary[Vector3i, bool] = {start: true}
		var sum := Vector3.ZERO
		fallen.erase(start)
		var cursor := 0
		while cursor < queue.size():
			var current := queue[cursor]
			cursor += 1
			sum += _center(current)
			for direction in NORMALS:
				var next := current + direction
				if fallen.erase(next):
					queue.append(next)
					section[next] = true
		var center := sum / section.size()
		detached.emit(_mesh(section, center), to_global(center), section.size(), normal)


func _hit_cell(point: Vector3) -> Vector3i:
	var base := Vector3i(((point - cell_origin) / cell_size).floor())
	for x in range(-1, 2):
		for y in range(-1, 2):
			for z in range(-1, 2):
				var cell := base + Vector3i(x, y, z)
				var offset := (point - cell_origin) / cell_size - Vector3(cell)
				var inside := true
				for face: Array in _faces(cell):
					var normal: Vector3 = face[1]
					if normal.dot(offset - Vector3(face[2][0])) > 0.0001:
						inside = false
						break
				if inside:
					return cell
	return base


func _center(cell: Vector3i) -> Vector3:
	return cell_origin + (Vector3(cell) + Vector3.ONE * 0.5) * cell_size


## Rebuilds only cut faces near removed cells, preserving the authored surface around each cut.
func _refresh_surface(changed: Array = [], shell_only: Dictionary[Vector3i, bool] = {}) -> void:
	prepare()
	var dirty: Dictionary[Vector3i, bool] = {}
	if changed.is_empty():
		exposed_faces.clear()
		for key: Vector3i in chunks.keys():
			_drop_chunk(key)
		for cell: Vector3i in solid:
			dirty[_chunk_of(cell)] = true
	else:
		if skin != null:
			_trim_skin(changed, shell_only)
		for cell: Vector3i in changed:
			exposed_faces.erase(cell)
			fracture_faces.erase(cell)
			dirty[_chunk_of(cell)] = true
			for face: Array in _faces(cell):
				var neighbor: Vector3i = cell + face[0]
				exposed_faces.erase(neighbor)
				dirty[_chunk_of(neighbor)] = true
	for key in dirty:
		_build_chunk(key)


func _trim_skin(changed: Array, shell_only: Dictionary[Vector3i, bool]) -> void:
	var changed_skin := false
	for cell: Vector3i in changed:
		changed_skin = _trim_skin_cell(cell) or changed_skin
	for cell: Vector3i in shell_only:
		if _trim_skin_cell(cell):
			cut_cells[cell] = true
			changed.append(cell)
			changed_skin = true
	if not changed_skin and not solid.is_empty():
		return
	if solid.is_empty():
		skin.skin.clear()
	surface.transform = Transform3D.IDENTITY
	var geometry := skin.make_mesh()
	surface.mesh = geometry
	var shape: ConcavePolygonShape3D
	if geometry.get_surface_count() > 0:
		shape = geometry.create_trimesh_shape()
		shape.backface_collision = true
	collider.set_deferred("shape", shape)


func _trim_skin_cell(cell: Vector3i) -> bool:
	var offset := cell_origin + Vector3(cell) * cell_size
	var bounds := AABB(offset - Vector3.ONE * cell_size * 0.45, Vector3.ONE * cell_size * 1.9)
	var planes: Array[Plane] = []
	for face: Array in _faces(cell):
		var axis: Vector3 = face[1]
		var vertex: Vector3 = offset + face[2][0] * cell_size
		planes.append(Plane(axis, axis.dot(vertex)))
	return skin.remove(planes, bounds)


func _chunk_of(cell: Vector3i) -> Vector3i:
	return Vector3i(floori(cell.x / float(CHUNK)), floori(cell.y / float(CHUNK)), floori(cell.z / float(CHUNK)))


func _build_chunk(key: Vector3i) -> void:
	var members: Array[Vector3i] = []
	var base := key * CHUNK
	for x in CHUNK:
		for y in CHUNK:
			for z in CHUNK:
				var cell := base + Vector3i(x, y, z)
				if solid.has(cell):
					members.append(cell)
	var geometry := _mesh(solid, Vector3.ZERO, true, members) if not members.is_empty() else null
	if geometry == null or geometry.get_surface_count() == 0:
		_drop_chunk(key)
		return
	if not chunks.has(key):
		var view := MeshInstance3D.new()
		view.material_override = cut_material
		add_child(view)
		chunks[key] = view
		var shape_node := CollisionShape3D.new()
		add_child(shape_node)
		chunk_shapes[key] = shape_node
	chunks[key].mesh = geometry
	var shape := geometry.create_trimesh_shape()
	shape.backface_collision = true
	chunk_shapes[key].set_deferred("shape", shape)


func _drop_chunk(key: Vector3i) -> void:
	if chunks.has(key):
		chunks[key].queue_free()
		chunk_shapes[key].queue_free()
		chunks.erase(key)
		chunk_shapes.erase(key)


func _faces(cell: Vector3i) -> Array:
	return VoronoiCells.FACES[(cell.x & 1) * 4 + (cell.y & 1) * 2 + (cell.z & 1)]


func _exposure(cell: Vector3i, faces: Array, cells: Dictionary, fractured_only: bool) -> int:
	var mask := 0
	for index in faces.size():
		var neighbor: Vector3i = cell + faces[index][0]
		var open_face := cut_cells.has(neighbor) if fractured_only else not cells.has(neighbor)
		if open_face:
			mask |= 1 << index
	return mask


func _clipped_face(cell: Vector3i, index: int, polygon: PackedVector3Array, normal: Vector3) -> Array[PackedVector3Array]:
	if not fracture_faces.has(cell):
		fracture_faces[cell] = {}
	var cached := fracture_faces[cell]
	if not cached.has(index):
		cached[index] = skin.interior(polygon, normal)
	return cached[index]


## Shared Voronoi faces stay hidden until either neighbor is removed.
func _mesh(cells: Dictionary, pivot: Vector3, terrain := false, members: Array = []) -> ArrayMesh:
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var triangles := PackedInt32Array()
	for cell: Vector3i in (members if not members.is_empty() else cells.keys()):
		var faces := _faces(cell)
		var mask: int
		if terrain and exposed_faces.has(cell):
			mask = exposed_faces[cell]
		else:
			mask = _exposure(cell, faces, cells, terrain and skin != null)
			if terrain:
				exposed_faces[cell] = mask
		if mask == 0:
			continue
		var offset := cell_origin + Vector3(cell) * cell_size - pivot
		var tint := layer_colors[cell.y].darkened(float(hash(cell) & 7) * 0.008)
		tint.a = 1.0
		for index in faces.size():
			if mask & (1 << index) == 0:
				continue
			var face: Array = faces[index]
			var sliced := terrain and cut_cells.has(cell + face[0])
			if terrain and skin != null and not sliced:
				continue
			var shade := tint.darkened(0.16) if sliced else tint
			var normal: Vector3 = face[1]
			var polygon := PackedVector3Array()
			for vertex: Vector3 in face[2]:
				polygon.append(offset + vertex * cell_size)
			var parts: Array[PackedVector3Array] = [polygon]
			if terrain and skin != null:
				parts = _clipped_face(cell, index, polygon, normal)
			for part in parts:
				var first := points.size()
				for vertex: Vector3 in part:
					points.append(vertex)
					normals.append(normal)
					colors.append(shade)
				for corner in range(2, part.size()):
					triangles.append(first)
					triangles.append(first + corner - 1)
					triangles.append(first + corner)
	var mesh := ArrayMesh.new()
	if points.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = triangles
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, cut_material)
	return mesh
