extends Node2D
## Gold diamonds on the screen edge pointing at off-screen chests and elites, so loot on the endless map is not lost.
## Lives under Street (reads its view, pickups and enemies); sizes are screen pixels.
@export var color := Color("ffd23f")
@export var size: float = 9.0
@export var inset: float = 24.0
@onready var street: Node2D = get_parent()
var _time: float = 0.0

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func targets() -> Array[Vector2]:
	var found: Array[Vector2] = []
	for drop: Node2D in street.pickups.get_children():
		if drop.kind == "chest" and not drop.is_queued_for_deletion():
			found.append(drop.position)
	for enemy: Node2D in street.enemies.get_children():
		if enemy.elite and not enemy.dead and not enemy.is_queued_for_deletion():
			found.append(enemy.position)
	return found

func _draw() -> void:
	var view: Rect2 = street.view_rect()
	var zoom: float = street.camera.zoom.x
	var inner: Rect2 = view.grow(-inset / zoom)
	var center: Vector2 = view.get_center()
	var radius: float = size / zoom * (1.0 + 0.15 * sin(_time * 6.0))
	for target: Vector2 in targets():
		if view.has_point(target):
			continue
		var heading: Vector2 = target - center
		var reach: float = INF
		if heading.x != 0.0:
			reach = minf(reach, ((inner.end.x if heading.x > 0.0 else inner.position.x) - center.x) / heading.x)
		if heading.y != 0.0:
			reach = minf(reach, ((inner.end.y if heading.y > 0.0 else inner.position.y) - center.y) / heading.y)
		var at: Vector2 = center + heading * clampf(reach, 0.0, 1.0)
		draw_circle(at, radius * 1.9, Color(color, 0.25))
		draw_colored_polygon(PackedVector2Array([at + Vector2(0, -radius), at + Vector2(radius * 0.75, 0), at + Vector2(0, radius), at + Vector2(-radius * 0.75, 0)]), color)
