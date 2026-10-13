extends Node2D
## Endless street: one repeating pavement sprite under the camera, plus one night-market cluster
## (a scene from `cluster_scenes`) per chunk in the 3×3 chunks around it. Each chunk seeds its own
## generator from its coordinates, so a chunk looks the same when revisited and the game's spawn/drop
## randomness is untouched.
## Every CollisionShape2D rectangle inside a cluster is a roadblock: the hero bumps into its StaticBody2D,
## Street pushes enemies out of it and stops flying projectiles on it (`blocked`, `push_out`).
## Props with `hp` (prop.gd) break under weapon hits; a broken prop stays broken for the rest of the run,
## even when its chunk is rebuilt, and its roadblock goes with it.
@export var cluster_scenes: Array[PackedScene] = []
## Relative pick weights, one per cluster scene; missing entries count as 1.
@export var cluster_weights: PackedFloat32Array = []
@export var chunk_size: float = 1024.0
## Chance that a chunk holds a cluster at all.
@export_range(0.0, 1.0) var cluster_chance: float = 0.8
## No cluster this close to where the hero starts a run.
@export var clear_radius: float = 420.0
@onready var ground: Sprite2D = %Ground
@onready var props: Node2D = %Props
var _chunks: Dictionary = {}
var _clear_at := Vector2.ZERO
## Roadblock rects (world space) per chunk key, and a 256 px lookup grid over all of them.
var _blocks: Dictionary = {}
var _cells: Dictionary = {}
## Keys of props broken this run, and the breakable props standing in the 3×3 chunks.
var _broken: Dictionary = {}
var _breakables: Array = []
const CELL := 256.0

func reset(start: Vector2) -> void:
	for chunk: Node in props.get_children():
		chunk.free()
	_chunks.clear()
	_blocks.clear()
	_broken.clear()
	_clear_at = start
	follow(start)

func follow(center: Vector2) -> void:
	var tile: float = ground.texture.get_width() * ground.scale.x
	ground.position = (center / tile).floor() * tile
	var here := Vector2i((center / chunk_size).floor())
	var changed: bool = false
	for key: Vector2i in _chunks.keys():
		if absi(key.x - here.x) > 1 or absi(key.y - here.y) > 1:
			_chunks[key].queue_free()
			_chunks.erase(key)
			_blocks.erase(key)
			changed = true
	for dx: int in range(-1, 2):
		for dy: int in range(-1, 2):
			var key: Vector2i = here + Vector2i(dx, dy)
			if not _chunks.has(key):
				_chunks[key] = _make_chunk(key)
				changed = true
	if changed:
		_rebuild_cells()

## Roadblocks near `at`, grown by nothing.
func blocks_near(at: Vector2) -> Array:
	return _cells.get(Vector2i((at / CELL).floor()), [])

func blocked(at: Vector2) -> bool:
	for rect: Rect2 in blocks_near(at):
		if rect.has_point(at):
			return true
	return false

## Moves a circle of `radius` at `at` out of any roadblock it overlaps. It leaves along the shallowest side and
## slides `slide` px along that face toward whichever end is the shorter way round to `goal`.
func push_out(at: Vector2, radius: float, goal: Vector2 = Vector2.ZERO, slide: float = 0.0) -> Vector2:
	for rect: Rect2 in blocks_near(at):
		var grown: Rect2 = rect.grow(radius)
		if not grown.has_point(at):
			continue
		var gaps := [at.x - grown.position.x, grown.end.x - at.x, at.y - grown.position.y, grown.end.y - at.y]
		var side: int = gaps.find(gaps.min())
		match side:
			0: at.x = grown.position.x
			1: at.x = grown.end.x
			2: at.y = grown.position.y
			_: at.y = grown.end.y
		if slide > 0.0:
			if side < 2:
				var up: float = absf(at.y - grown.position.y) + absf(goal.y - grown.position.y)
				var down: float = absf(grown.end.y - at.y) + absf(grown.end.y - goal.y)
				at.y += slide * (-1.0 if up < down else 1.0)
			else:
				var left: float = absf(at.x - grown.position.x) + absf(goal.x - grown.position.x)
				var right: float = absf(grown.end.x - at.x) + absf(grown.end.x - goal.x)
				at.x += slide * (-1.0 if left < right else 1.0)
	return at

## Breakable props whose hit circle touches the circle at `at`.
## ponytail: linear scan over the few breakables in the 3×3 chunks; index by cell if clusters get dense.
func breakables_in(at: Vector2, radius: float) -> Array:
	return _breakables.filter(func(prop: Node2D) -> bool: return prop.global_position.distance_to(at) <= radius + prop.hit_radius)

func tick(delta: float) -> void:
	for prop: Node2D in _breakables:
		prop.tick(delta)

## Breaks `prop` for the rest of the run and lifts its roadblock.
func remove_prop(prop: Node2D) -> void:
	_broken[prop.key] = true
	for key: Vector2i in _chunks:
		if _chunks[key].is_ancestor_of(prop):
			prop.get_parent().remove_child(prop)
			_collect(key)
			break
	prop.queue_free()
	_rebuild_cells()

func _rebuild_cells() -> void:
	_cells.clear()
	_breakables.clear()
	for chunk: Node2D in _chunks.values():
		for prop: Node in chunk.find_children("*", "Node2D", true, false):
			if prop.has_method("breakable") and prop.breakable():
				_breakables.append(prop)
	for list: Array in _blocks.values():
		for rect: Rect2 in list:
			var from := Vector2i((rect.position / CELL).floor())
			var to := Vector2i((rect.end / CELL).floor())
			for x: int in range(from.x - 1, to.x + 2):
				for y: int in range(from.y - 1, to.y + 2):
					var key := Vector2i(x, y)
					if not _cells.has(key):
						_cells[key] = []
					_cells[key].append(rect)

## Roadblock rects of every footprint still standing in the chunk.
func _collect(key: Vector2i) -> void:
	_blocks[key] = []
	for shape: CollisionShape2D in _chunks[key].find_children("*", "CollisionShape2D", true, false):
		var box := shape.shape as RectangleShape2D
		if box != null:
			var size: Vector2 = box.size * shape.global_scale.abs()
			_blocks[key].append(Rect2(shape.global_position - size * 0.5, size))

func _make_chunk(key: Vector2i) -> Node2D:
	var chunk := Node2D.new()
	chunk.name = "Chunk_%d_%d" % [key.x, key.y]
	chunk.position = Vector2(key) * chunk_size
	chunk.y_sort_enabled = true
	props.add_child(chunk)
	_chunks[key] = chunk
	_blocks[key] = []
	if cluster_scenes.is_empty():
		return chunk
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	if rng.randf() > cluster_chance:
		return chunk
	var at := Vector2(rng.randf_range(0.3, 0.7), rng.randf_range(0.3, 0.7)) * chunk_size
	if (chunk.position + at).distance_to(_clear_at) < clear_radius:
		return chunk
	var weights := PackedFloat32Array()
	for i: int in cluster_scenes.size():
		weights.append(cluster_weights[i] if i < cluster_weights.size() else 1.0)
	var cluster := cluster_scenes[rng.rand_weighted(weights)].instantiate() as Node2D
	cluster.position = at
	chunk.add_child(cluster)
	for prop: Node in cluster.find_children("*", "Node2D", true, false).filter(func(n: Node) -> bool: return "key" in n):
		prop.key = "%d,%d/%s" % [key.x, key.y, cluster.get_path_to(prop)]
		if _broken.has(prop.key):
			prop.get_parent().remove_child(prop)
			prop.free()
	_collect(key)
	return chunk
