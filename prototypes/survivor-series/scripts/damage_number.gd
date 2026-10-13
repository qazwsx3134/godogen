extends Node2D
## A floating damage number: pops, rises and fades. Lethal hits are bigger and warmer.
@export var rise: float = 34.0
@export var lifetime: float = 0.7
@onready var text: Label = %Text

func setup(amount: float, lethal: bool) -> void:
	text.text = str(maxi(1, roundi(amount)))
	if lethal:
		text.modulate = Color("ffcf5a")
		scale = Vector2.ONE * 1.25
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", position.y - rise, lifetime).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, lifetime * 0.4).set_delay(lifetime * 0.6)
	tween.chain().tween_callback(queue_free)
