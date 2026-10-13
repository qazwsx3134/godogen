extends Node2D
## Endless street: one repeating pavement sprite under the camera, plus props scattered per chunk
## in the 3×3 chunks around it. Each chunk seeds its own generator from its coordinates, so a chunk
## looks the same when revisited and the game's spawn/drop randomness is untouched.
## Props depth-sort with the hero and enemies (Street is y-sorted). Solid props block walkers;
## breakable ones stay broken for the rest of the run even when their chunk is rebuilt.
@export var prop_scenes: Array[PackedScene] = []
@export var chunk_size: float = 1024.0
## Props per chunk, each in its own cell of a 3×3 grid inside the chunk.
@export var props_per_chunk: int = 7
## No props this close to where the hero starts a run.
@export var clear_radius: float = 260.0
@onready var ground: Sprite2D = %Ground
@onready var props: Node2D = %Props
## Side of the square cells that index props for collision and hit queries.
const CELL := 256.0
var _chunks: Dictionary = {}
var _clear_at := Vector2.ZERO
var _cells: Dictionary = {}
var _broken: Dictionary = {}
var _breakables: Array = []

func reset(start: Vector2) -> void:
	for chunk: Node in props.get_children():
		props.remove_child(chunk)
		chunk.queue_free()
	_chunks.clear()
	_broken.clear()
	_clear_at = start
	follow(start)

func follow(center: Vector2) -> void:
	var tile: float = ground.texture.get_width()
	ground.position = (center / tile).floor() * tile
	var here := Vector2i((center / chunk_size).floor())
	var changed: bool = false
	for key: Vector2i in _chunks.keys():
		if absi(key.x - here.x) > 1 or absi(key.y - here.y) > 1:
			_chunks[key].queue_free()
			_chunks.erase(key)
			changed = true
	for dx: int in range(-1, 2):
		for dy: int in range(-1, 2):
			var key: Vector2i = here + Vector2i(dx, dy)
			if not _chunks.has(key):
				_chunks[key] = _make_chunk(key)
				changed = true
	if changed:
		_index()

func _index() -> void:
	_cells.clear()
	_breakables.clear()
	for chunk: Node2D in _chunks.values():
		for prop: Node2D in chunk.get_children():
			if prop.is_queued_for_deletion() or not prop.has_method("solid"):
				continue
			if prop.breakable():
				_breakables.append(prop)
			var cell := Vector2i((prop.global_position / CELL).floor())
			if not _cells.has(cell):
				_cells[cell] = []
			_cells[cell].append(prop)

func _near(at: Vector2) -> Array:
	var found: Array = []
	var cell := Vector2i((at / CELL).floor())
	for dx: int in range(-1, 2):
		for dy: int in range(-1, 2):
			found.append_array(_cells.get(cell + Vector2i(dx, dy), []))
	return found

func tick(delta: float) -> void:
	for prop: Node2D in _breakables:
		prop.tick(delta)

## `at` moved out of every solid prop it overlaps by a circle of `radius`.
func push_out(at: Vector2, radius: float) -> Vector2:
	for prop: Node2D in _near(at):
		if not prop.solid():
			continue
		var box := Rect2(prop.global_position + prop.solid_rect.position, prop.solid_rect.size)
		var closest := Vector2(clampf(at.x, box.position.x, box.end.x), clampf(at.y, box.position.y, box.end.y))
		var gap: Vector2 = at - closest
		if gap == Vector2.ZERO:
			# Center inside the box: leave by the nearest side.
			var exits: Array = [at.x - box.position.x, box.end.x - at.x, at.y - box.position.y, box.end.y - at.y]
			var side: int = exits.find(exits.min())
			at = [Vector2(box.position.x - radius, at.y), Vector2(box.end.x + radius, at.y), Vector2(at.x, box.position.y - radius), Vector2(at.x, box.end.y + radius)][side]
		elif gap.length() < radius:
			at = closest + gap.normalized() * radius
	return at

## Breakable props whose hit circle touches the circle at `at`.
func breakables_in(at: Vector2, radius: float) -> Array:
	return _near(at).filter(func(prop: Node2D) -> bool: return prop.breakable() and not prop.is_queued_for_deletion() and prop.global_position.distance_to(at) <= radius + prop.hit_radius)

func remove_prop(prop: Node2D) -> void:
	_broken[prop.key] = true
	prop.queue_free()
	_index()

func _make_chunk(key: Vector2i) -> Node2D:
	var chunk := Node2D.new()
	chunk.name = "Chunk_%d_%d" % [key.x, key.y]
	chunk.y_sort_enabled = true
	chunk.position = Vector2(key) * chunk_size
	props.add_child(chunk)
	if prop_scenes.is_empty():
		return chunk
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var cells: Array = range(9)
	var cell_size: float = chunk_size / 3.0
	for i: int in mini(props_per_chunk, 9):
		var cell: int = cells.pop_at(rng.randi_range(0, cells.size() - 1))
		var at := Vector2(cell % 3 + 0.5, floorf(cell / 3.0) + 0.5) * cell_size + Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3)) * cell_size
		if (chunk.position + at).distance_to(_clear_at) < clear_radius:
			continue
		var prop_scene: PackedScene = prop_scenes[rng.randi_range(0, prop_scenes.size() - 1)]
		var prop_key: String = "%d,%d,%d" % [key.x, key.y, i]
		if _broken.has(prop_key):
			continue
		var prop := prop_scene.instantiate() as Node2D
		prop.position = at
		if "key" in prop:
			prop.key = prop_key
		chunk.add_child(prop)
	return chunk
