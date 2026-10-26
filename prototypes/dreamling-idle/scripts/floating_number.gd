extends Label
var _tween: Tween


func show_value(text_value: String, at: Vector2, tint: Color) -> void:
	text = text_value
	position = at
	modulate = tint
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "position:y", at.y - 40.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 0.0, 0.5).set_delay(0.3)
	_tween.chain().tween_callback(queue_free)
