extends Node2D
## Floating damage text. Crits are bigger and gold.

@export var normal_color: Color = Color(1, 1, 1)
@export var crit_color: Color = Color(1.0, 0.82, 0.2)
@export var rise: float = 90.0
@export var duration: float = 0.7

@onready var _label: Label = %Label

func setup(amount: int, crit: bool) -> void:
	_label.text = ("%d!" % amount) if crit else str(amount)
	_label.modulate = crit_color if crit else normal_color
	if crit:
		scale = Vector2(1.45, 1.45)
	position.x += randf_range(-18.0, 18.0)
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(self, "position:y", position.y - rise, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate:a", 0.0, duration * 0.5).set_delay(duration * 0.5)
	tween.chain().tween_callback(queue_free)
