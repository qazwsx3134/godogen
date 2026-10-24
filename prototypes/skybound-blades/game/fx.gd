extends Node3D
## One-shot effect (scenes/fx/*.tscn): drives the `progress` of its mesh's shader from 0 to 1,
## then frees itself. The look is in the scene's material; only colour and side come from code.

@export var duration: float = 0.35
@export var rise: float = 0.0

@onready var _mesh: GeometryInstance3D = $Mesh


func play(color: Color, flip_x: bool = false) -> void:
	var material := (_mesh.material_override as ShaderMaterial).duplicate() as ShaderMaterial
	_mesh.material_override = material
	material.set_shader_parameter(&"tint", color)
	material.set_shader_parameter(&"progress", 0.0)
	if flip_x:
		_mesh.scale.x = -absf(_mesh.scale.x)
	var tween := create_tween()
	tween.tween_method(func(p: float) -> void: material.set_shader_parameter(&"progress", p), 0.0, 1.0, duration)
	if rise != 0.0:
		tween.parallel().tween_property(self, "position:y", position.y + rise, duration)
	tween.tween_callback(queue_free)
