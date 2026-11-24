extends "res://addons/proto_kit/pixel_vfx3d.gd"
## Saved scene for the kit's native volumetric chunks and ground shockwaves.
## fx.burst(position, 24, &"gold"); fx.ring(position, 2.0, &"cyan")
## Disable auto_step when the game's own clock calls step(delta).
@export var auto_step: bool = true

func _process(delta: float) -> void:
	if auto_step:
		step(delta)
