extends Node2D
## A floating damage number in the pixel font: pops in, rises and fades. Lethal hits are gold and bigger;
## hits on the hero are red with a minus sign. The root's scale makes one font pixel one art pixel on screen.
@export var rise: float = 40.0
@export var lifetime: float = 0.8
@export var hit_color := Color.WHITE
@export var lethal_color := Color("ffcf5a")
@export var hurt_color := Color("ff5f6d")
@onready var text: Label = %Text

func setup(amount: float, lethal: bool, hurt: bool = false) -> void:
	var value: int = maxi(1, roundi(amount))
	text.text = ("-%d" if hurt else "%d") % value
	text.modulate = hurt_color if hurt else (lethal_color if lethal else hit_color)
	var rest: Vector2 = scale * (1.5 if lethal or hurt else 1.0)
	scale = rest * 1.6
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", rest, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", position.y - rise, lifetime).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, lifetime * 0.35).set_delay(lifetime * 0.65)
	tween.chain().tween_callback(queue_free)
