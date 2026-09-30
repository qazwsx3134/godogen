extends Node2D
## One-shot blast: a flash disc that grows and fades, plus sparks.

@export var duration: float = 0.45

@onready var _flash: Node2D = %Flash
@onready var _sparks: CPUParticles2D = %Sparks

func _ready() -> void:
	_sparks.emitting = true
	_flash.scale = Vector2(0.3, 0.3)
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(_flash, "scale", Vector2.ONE, duration * 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(_flash, "modulate:a", 0.0, duration).set_ease(Tween.EASE_IN)
	tween.chain().tween_interval(maxf(0.0, _sparks.lifetime - duration))
	tween.chain().tween_callback(queue_free)
