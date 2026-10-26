extends RefCounted
## Floating combat text and the sweep ring.


static func popup(parent: Node, pos: Vector3, text: String, color: Color, size: int = 44) -> void:
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 3
	label.font_size = size
	label.outline_size = 10
	label.pixel_size = 0.006
	label.modulate = color
	label.outline_modulate = Color(0.08, 0.05, 0.05)
	parent.add_child(label)
	label.global_position = pos + Vector3(randf_range(-0.25, 0.25), 0.0, 0.0)
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "global_position", label.global_position + Vector3.UP * 1.1, 0.9) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.45)
	tween.tween_property(label, "outline_modulate:a", 0.0, 0.5).set_delay(0.45)
	tween.chain().tween_callback(label.queue_free)


## A flat ring that grows to `radius` and fades: shows the sweep's reach.
static func ring(parent: Node, pos: Vector3, radius: float, color: Color) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.9
	mesh.outer_radius = 1.0
	mesh.rings = 24
	mesh.ring_segments = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	var ring_node := MeshInstance3D.new()
	ring_node.mesh = mesh
	ring_node.material_override = mat
	parent.add_child(ring_node)
	ring_node.global_position = pos + Vector3.UP * 0.1
	ring_node.scale = Vector3(0.3, 0.3, 0.3)
	var tween := ring_node.create_tween().set_parallel()
	tween.tween_property(ring_node, "scale", Vector3(radius, 1.0, radius), 0.22).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.3).set_delay(0.12)
	tween.chain().tween_callback(ring_node.queue_free)
