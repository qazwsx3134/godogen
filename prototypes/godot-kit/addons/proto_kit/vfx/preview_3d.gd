extends Node3D
@onready var effects: Node3D = %NativeEffects

func _ready() -> void:
	%Replay.timeout.connect(_replay)

func _replay() -> void:
	effects.burst(Vector3(-1.5, 0.2, 0), 36, &"gold", 3.0, 4.0, 4)
	effects.ring(Vector3(-1.5, 0, 0), 1.6, &"cyan", 0.7)
