extends RefCounted
## Uniform spatial hash, rebuilt once per step and shared by separation, contact and weapon queries.
var cell: float = 80.0
var cells: Dictionary = {}

func rebuild(actors: Array) -> void:
	cells.clear()
	for actor: Node2D in actors:
		var key := Vector2i(floori(actor.position.x / cell), floori(actor.position.y / cell))
		if cells.has(key):
			cells[key].append(actor)
		else:
			cells[key] = [actor]

## Actors whose position lies within `radius` (plus their own radius) of `at`.
func query(at: Vector2, radius: float) -> Array:
	var found: Array = []
	var reach: float = radius + 48.0
	var low := Vector2i(floori((at.x - reach) / cell), floori((at.y - reach) / cell))
	var high := Vector2i(floori((at.x + reach) / cell), floori((at.y + reach) / cell))
	for x: int in range(low.x, high.x + 1):
		for y: int in range(low.y, high.y + 1):
			var key := Vector2i(x, y)
			if not cells.has(key):
				continue
			for actor: Node2D in cells[key]:
				if actor.dead or actor.is_queued_for_deletion():
					continue
				if actor.position.distance_to(at) <= radius + actor.definition.radius:
					found.append(actor)
	return found

func nearest(at: Vector2, radius: float) -> Node2D:
	var best: Node2D
	var gap: float = INF
	for actor: Node2D in query(at, radius):
		var d: float = actor.position.distance_to(at)
		if d < gap:
			best = actor
			gap = d
	return best
