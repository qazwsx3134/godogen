extends CPUParticles2D
## One-shot burst of square pixels (spark, dust, debris, gold). How it looks (size, speed, gravity,
## lifetime, fade) is authored in the scene; fire() only decides how many, which way and what colour,
## and the burst frees itself when it has played.

var _scene_amount: int = 0

func _ready() -> void:
	_scene_amount = amount
	emitting = false

## `count_scale` multiplies the scene's particle count; `tint` multiplies its colours; a non-zero
## `direction` aims the burst; `palette` gives every particle a random colour out of that gradient.
func fire(count_scale: float = 1.0, tint: Color = Color.WHITE, direction: Vector2 = Vector2.ZERO, palette: Gradient = null) -> void:
	amount = maxi(1, int(round(_scene_amount * count_scale)))
	color = tint
	if direction != Vector2.ZERO:
		self.direction = direction.normalized()
	if palette != null:
		color_initial_ramp = palette
	emitting = true
	finished.connect(queue_free)
	get_tree().create_timer(lifetime * (1.0 + lifetime_randomness) + 0.5).timeout.connect(queue_free)   # in case finished never comes
