extends Node2D
@onready var effects: Node2D = %NativeEffects

func _ready() -> void:
	%Replay.timeout.connect(_replay)
	_replay()

func _replay() -> void:
	effects.burst(Vector2.ZERO, &"fire", 22)
	effects.ring(Vector2.ZERO, 5.0, 75.0, &"ice", 0.7, 2)
	effects.effect(&"explosion", Vector2(180, 0), Vector2(130, 130), 1.0, &"fire")
