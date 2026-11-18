extends StaticBody3D
## Each collidable piece breaks independently and leaves the underlying terrain intact.

@export var durability := 65.0
@export var attached_visual: NodePath
var broken := false
const IMPACT := preload("res://scenes/combat_impact.tscn")


func apply_damage(amount: float, at: Vector3, _direction: Vector3) -> void:
	if broken:
		return
	durability -= amount
	if durability <= 0.0:
		break_cover(at)


func break_cover(at: Vector3) -> void:
	if broken:
		return
	broken = true
	collision_layer = 0
	hide()
	if not attached_visual.is_empty():
		var visual := get_node_or_null(attached_visual) as Node3D
		if visual != null:
			visual.hide()
			visual.queue_free()
	var impact := IMPACT.instantiate() as Node3D
	impact.radius = 2.0
	var parent := get_parent() as Node3D
	impact.position = parent.to_local(at)
	parent.add_child(impact)
	queue_free()


static func crush_contacts(body: CharacterBody3D) -> void:
	for index in body.get_slide_collision_count():
		var contact := body.get_slide_collision(index)
		var cover := contact.get_collider() as StaticBody3D
		if cover != null and cover.has_method("break_cover"):
			cover.break_cover(contact.get_position())
