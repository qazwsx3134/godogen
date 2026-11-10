extends Node3D
@export var duration: float = 0.32
@export var radius: float = 1.0
var age := 0.0
func _ready() -> void:
	$Sound.stream = preload("res://assets/sound/runtime/explosion.ogg") if radius>=2.0 else preload("res://assets/sound/runtime/hit_heavy.ogg")
	$Sound.play()
func _process(delta: float) -> void:
	age += delta
	$Flash.scale = Vector3.ONE * radius * (0.2 + age * 3.0)
	$Flash.visible = age < duration * 0.45
	# Let the sound tail finish after the short visual flash.
	if age>=duration and (not $Sound.playing or age>$Sound.stream.get_length()+0.25): queue_free()
