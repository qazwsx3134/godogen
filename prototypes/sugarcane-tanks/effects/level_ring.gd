extends Node2D
## A ring of light with rays that bursts outward from the hero when a level is gained.
## The look (ring, rays, colours) is authored in level_ring.tscn.

@export var duration: float = 0.6
@export var final_scale: float = 2.2

func _ready() -> void:
	scale = Vector2.ONE * 0.25
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(self, "scale", Vector2.ONE * final_scale, duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, duration * 0.7).set_delay(duration * 0.3).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)
