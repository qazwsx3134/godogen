extends Node2D
## Endless street: one repeating pavement sprite under the camera, plus props scattered per chunk
## in the 3×3 chunks around it. Each chunk seeds its own generator from its coordinates, so a chunk
## looks the same when revisited and the game's spawn/drop randomness is untouched.
@export var prop_scenes: Array[PackedScene] = []
@export var chunk_size: float = 1024.0
## Props per chunk, each in its own cell of a 3×3 grid inside the chunk.
@export var props_per_chunk: int = 7
## No props this close to where the hero starts a run.
@export var clear_radius: float = 260.0
@onready var ground: Sprite2D = %Ground
@onready var props: Node2D = %Props
var _chunks: Dictionary = {}
var _clear_at := Vector2.ZERO

func reset(start: Vector2) -> void:
	for chunk: Node in props.get_children():
		props.remove_child(chunk)
		chunk.queue_free()
	_chunks.clear()
	_clear_at = start
	follow(start)

func follow(center: Vector2) -> void:
	var tile: float = ground.texture.get_width()
	ground.position = (center / tile).floor() * tile
	var here := Vector2i((center / chunk_size).floor())
	for key: Vector2i in _chunks.keys():
		if absi(key.x - here.x) > 1 or absi(key.y - here.y) > 1:
			_chunks[key].queue_free()
			_chunks.erase(key)
	for dx: int in range(-1, 2):
		for dy: int in range(-1, 2):
			var key: Vector2i = here + Vector2i(dx, dy)
			if not _chunks.has(key):
				_chunks[key] = _make_chunk(key)

func _make_chunk(key: Vector2i) -> Node2D:
	var chunk := Node2D.new()
	chunk.name = "Chunk_%d_%d" % [key.x, key.y]
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
		var prop := prop_scenes[rng.randi_range(0, prop_scenes.size() - 1)].instantiate() as Node2D
		prop.position = at
		chunk.add_child(prop)
	return chunk
