extends RefCounted
## Floating combat text.


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
