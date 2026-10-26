extends Control
## Round minimap centred on the player: portals (blue), NPCs (yellow), live monsters (red), the player (white).
## North is up: the camera's yaw is fixed at 0, so screen up is world -Z here too.

## Metres from the centre to the rim.
@export var world_radius: float = 30.0

var player: Node3D


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var r := size.x * 0.5
	var c := size * 0.5
	draw_circle(c, r, Color(0.06, 0.08, 0.16, 0.6))
	draw_arc(c, r, 0.0, TAU, 48, Color("e8c25a"), 2.0, true)
	if player == null:
		return
	for n: Node3D in get_tree().get_nodes_in_group("portal"):
		_dot(n.global_position, Color("6fc8ff"), 5.0)
	for n: Node3D in get_tree().get_nodes_in_group("npc"):
		_dot(n.global_position, Color("ffd75e"), 4.0)
	for n: Node3D in get_tree().get_nodes_in_group("monster"):
		if n.is_alive():
			_dot(n.global_position, Color("ff7a6b") if not n.aggressive else Color("ff3b3b"), 3.0)
	draw_circle(c, 4.5, Color.WHITE)


func _dot(world: Vector3, color: Color, radius: float) -> void:
	var r := size.x * 0.5
	var d := Vector2(world.x - player.global_position.x, world.z - player.global_position.z) / world_radius * r
	if d.length() <= r - radius:
		draw_circle(size * 0.5 + d, radius, color)
