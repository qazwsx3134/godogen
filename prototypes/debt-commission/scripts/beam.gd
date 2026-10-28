@tool
extends Control
## The editable beam.tscn owns the strip's placement, colors and width. Only the reveal animates.
@export var reveal_seconds: float = 0.22
@onready var strip: Control = %Strip
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func play(duration: float, reduced_motion: bool = false) -> void:
	strip.pivot_offset = Vector2(0, strip.size.y * 0.5)
	strip.modulate.a = 0.7 if reduced_motion else 1.0
	var tween: Tween = create_tween()
	tween.tween_property(strip, "scale", Vector2.ONE, minf(reveal_seconds, duration * 0.4)).from(Vector2(0, 0.2)) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_interval(duration * 0.7 - minf(reveal_seconds, duration * 0.4))
	tween.tween_property(strip, "modulate:a", 0.0, duration * 0.3)
	tween.tween_callback(queue_free)
