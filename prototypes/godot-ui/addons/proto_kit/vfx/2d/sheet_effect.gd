extends AnimatedSprite2D
## Assign SpriteFrames in the inspector; instance this saved scene at the hit position.
## Loops remain alive until the owner frees them. One-shots emit finished then free.
signal finished

@export var play_on_ready: bool = true
@export var free_on_finish: bool = true

func _ready() -> void:
	animation_finished.connect(_complete)
	if play_on_ready and sprite_frames != null and sprite_frames.has_animation(animation):
		if sprite_frames.get_frame_count(animation) > 0:
			set_frame_and_progress(0, 0.0)
			play(animation)

func _complete() -> void:
	finished.emit()
	if free_on_finish:
		queue_free()
