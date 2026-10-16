extends "res://addons/proto_kit/test_kit.gd"
## Compare the spatial hash against a brute-force circle oracle and target distances.
const Grid := preload("res://scripts/grid.gd")
const Def := preload("res://scripts/enemy_def.gd")
class Actor extends Node2D:
	var dead: bool = false
	var definition: Resource
var actors: Array = []

func _initialize() -> void:
	_run.call_deferred()

func _actor(at: Vector2, radius: float) -> Node2D:
	var actor := Actor.new()
	actor.definition = Def.new()
	actor.definition.radius = radius
	actor.position = at
	root.add_child(actor)
	actors.append(actor)
	return actor

func _run() -> void:
	var grid := Grid.new()
	var large := _actor(Vector2(160, 0), 180.0)
	grid.rebuild(actors)
	_expect(grid.query(Vector2.ZERO, 0).has(large), "large hitboxes overlap queries across more than the old 48px padding")
	_expect(grid.nearest(Vector2.ZERO, 0) == large, "nearest uses hitbox overlap for oversized actors")
	_expect(grid.has_at_least(Vector2.ZERO, 0, 1), "density includes an overlapping oversized actor")
	large.dead = true
	_expect(grid.query(Vector2.ZERO, 200).is_empty() and grid.nearest(Vector2.ZERO, 200) == null, "dead actors cannot be queried or targeted")
	_expect(not grid.has_at_least(Vector2.ZERO, 200, 1), "dead actors do not count toward readability")
	large.dead = false
	large.queue_free()
	_expect(grid.query(Vector2.ZERO, 200).is_empty() and grid.nearest(Vector2.ZERO, 200) == null, "queued actors cannot be targeted")
	_expect(not grid.has_at_least(Vector2.ZERO, 200, 1), "queued actors do not count toward readability")
	grid.rebuild([])
	actors.clear()
	await _frames(1)
	var first := _actor(Vector2(10, 0), 10)
	_actor(Vector2(10, 0), 10)
	grid.rebuild(actors)
	_expect(grid.nearest(Vector2.ZERO, 0) == first, "equal-distance targets keep cell insertion order")
	_expect(grid.query(Vector2.ZERO, 0).size() == 2, "circle tangency includes both actors")
	var detached: Array = grid.query(Vector2.ZERO, 0)
	detached.clear()
	_expect(grid.query(Vector2.ZERO, 0).size() == 2, "callers can edit query results without changing the grid")
	for actor: Node2D in actors:
		actor.free()
	actors.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261016
	for i: int in 140:
		var actor := _actor(Vector2(rng.randf_range(-800,800), rng.randf_range(-800,800)), rng.randf_range(5,95))
		actor.dead = i % 13 == 0
	grid.rebuild(actors)
	for i: int in 100:
		var at := Vector2(rng.randf_range(-900,900), rng.randf_range(-900,900))
		var radius: float = [0.0, 25.0, 120.0, 260.0][i % 4]
		var brute: Array = actors.filter(func(a: Node2D) -> bool: return not a.dead and a.position.distance_to(at) <= radius + a.definition.radius)
		var found: Array = grid.query(at, radius)
		_expect(found.size() == brute.size() and found.all(func(a: Node2D) -> bool: return brute.has(a)), "query %d matches brute-force circles at negative and positive coordinates" % i)
		var nearest: Node2D = grid.nearest(at, radius)
		brute.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.position.distance_to(at) < b.position.distance_to(at))
		_expect(nearest == (brute[0] if not brute.is_empty() else null), "nearest %d matches the brute-force target" % i)
		for threshold: int in [0, 1, 8, 140]:
			_expect(grid.has_at_least(at, radius, threshold) == (brute.size() >= threshold), "density %d threshold %d matches the full count" % [i,threshold])
	grid.rebuild([])
	_expect(grid.nearest(Vector2.ZERO, 1000) == null and not grid.has_at_least(Vector2.ZERO, 1000, 1), "rebuild clears stale actors and density")
	for actor: Node2D in actors:
		actor.free()
	actors.clear()
	print("checks: ", checks)
	_finish("GRID TESTS")
