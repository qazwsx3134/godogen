extends RefCounted
## Uniform spatial hash, rebuilt once per step and shared by separation, contact and weapon queries.
var cell: float = 80.0
var cells: Dictionary = {}
var _max_radius: float = 48.0

func rebuild(actors: Array) -> void:
	cells.clear()
	_max_radius = 48.0
	for actor: Node2D in actors:
		_max_radius = maxf(_max_radius, actor.definition.radius)
		var key := Vector2i(floori(actor.position.x / cell), floori(actor.position.y / cell))
		if cells.has(key):
			cells[key].append(actor)
		else:
			cells[key] = [actor]

## Actors whose position lies within `radius` (plus their own radius) of `at`.
func query(at: Vector2, radius: float) -> Array:
	var found: Array = []
	var reach: float = radius + _max_radius
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
	var reach: float = radius + _max_radius
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
				var distance: float = actor.position.distance_squared_to(at)
				if distance >= gap:
					continue
				var limit: float = radius + actor.definition.radius
				if limit >= 0.0 and distance <= limit * limit:
					best = actor
					gap = distance
	return best

## Stop as soon as the density threshold is met; no candidate array is allocated.
func has_at_least(at: Vector2, radius: float, count: int) -> bool:
	if count <= 0:
		return true
	var remaining: int = count
	var reach: float = radius + _max_radius
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
					remaining -= 1
					if remaining == 0:
						return true
	return false
