extends StaticBody3D
## Authored cover may support other pieces; breaking it releases those pieces.

@export var durability := 65.0
@export var attached_visual: NodePath
@export var support: NodePath
signal support_lost
const Layers := preload("res://scripts/layers.gd")
var broken := false
const IMPACT := preload("res://scenes/combat_impact.tscn")
const WEATHERED_SHADER := preload("res://shaders/spatial_env_weathered.gdshader")


func _ready() -> void:
	if not support.is_empty():
		var base := get_node_or_null(support)
		if base != null and base.has_signal("support_lost"):
			base.connect("support_lost", _release_support)


func _release_support() -> void:
	if broken:
		return
	broken = true
	collision_layer = 0
	hide()
	support_lost.emit()
	_drop_section.call_deferred()


func _drop_section() -> void:
	var section := RigidBody3D.new()
	section.name = name + "Falling"
	section.transform = transform
	section.collision_layer = 0
	section.collision_mask = Layers.MAP_GROUND
	section.mass = 8.0
	for child: Node in get_children():
		if child is MeshInstance3D:
			var surface := child.duplicate() as MeshInstance3D
			var material := surface.material_override as ShaderMaterial
			if material and material.shader == WEATHERED_SHADER:
				material = material.duplicate() as ShaderMaterial
				material.set_shader_parameter("local_projection", true)
				material.set_shader_parameter("projection_origin", child.global_position)
				material.set_shader_parameter("projection_basis", child.global_basis)
				surface.material_override = material
			section.add_child(surface)
		elif child is CollisionShape3D:
			section.add_child(child.duplicate())
	get_parent().add_child(section, true)
	section.angular_velocity = Vector3(0.16, 0.0, randf_range(-0.55, 0.55))
	var cleanup := Timer.new()
	cleanup.one_shot = true
	cleanup.wait_time = 12.0
	section.add_child(cleanup)
	cleanup.timeout.connect(section.queue_free)
	cleanup.start()
	queue_free()


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
	support_lost.emit()
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
	var debris := get_tree().get_first_node_in_group("debris_parts")
	if debris:
		var collision := get_node_or_null("Collision") as CollisionShape3D
		var chunk_size := 1.0
		var burst_width := 1.0
		if collision != null and collision.shape is BoxShape3D:
			var extent := (collision.shape as BoxShape3D).size
			chunk_size = clampf(extent.length() * 0.22, 0.8, 2.8)
			burst_width = clampf(extent.length() * 0.22, 0.5, 3.0)
		for i in range(9):
			var angle := TAU * i / 9.0 + randf_range(-0.2, 0.2)
			var out := Vector3(cos(angle), 0, sin(angle))
			var at_piece := global_position.lerp(at, 0.45) + out * burst_width
			debris.spawn(at_piece, out * randf_range(4.0, 11.0) + Vector3.UP * randf_range(3.0, 8.0), chunk_size)
	queue_free()


static func crush_contacts(body: CharacterBody3D) -> void:
	for index in body.get_slide_collision_count():
		var contact := body.get_slide_collision(index)
		var cover := contact.get_collider() as StaticBody3D
		if cover != null and cover.has_method("break_cover"):
			cover.break_cover(contact.get_position())
