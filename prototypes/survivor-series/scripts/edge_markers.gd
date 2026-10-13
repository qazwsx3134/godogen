extends Node2D
## Gold arrows on the screen edge pointing at off-screen chests and elites, with the distance in metres
## (PokéSurvivor's 32 px = 1 m), so loot on the endless map is not lost.
## Lives under Street (reads its view, pickups and enemies); sizes are screen pixels.
@export var color := Color("ffd23f")
@export var size: float = 9.0
@export var inset: float = 30.0
@export var metre: float = 32.0
## Pixel font for the distance; one font pixel is drawn as `pixel` screen px.
@export var font: Font = preload("res://assets/fonts/Cubic11.ttf")
@export var pixel: float = 2.0
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
		var way: Vector2 = heading.normalized()
		var side: Vector2 = way.orthogonal()
		draw_circle(at, radius * 1.9, Color(color, 0.25))
		var tip: Vector2 = at + way * radius * 1.2
		draw_colored_polygon(PackedVector2Array([tip, at - way * radius * 0.6 + side * radius, at - way * radius * 0.6 - side * radius]), color)
		# Distance label on the inner side of the arrow, in the pixel font.
		var label: String = "%dm" % roundi(target.distance_to(street.player.position) / metre)
		var scale: float = pixel / zoom
		var spot: Vector2 = at - way * radius * 3.2
		var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x * scale
		draw_set_transform(spot - Vector2(width * 0.5, -4.0 * scale), 0.0, Vector2.ONE * scale)
		draw_string_outline(font, Vector2.ZERO, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color("120c1e"))
		draw_string(font, Vector2.ZERO, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, color)
		draw_set_transform(Vector2.ZERO)
