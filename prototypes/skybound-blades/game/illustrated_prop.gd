@tool
extends "res://game/prop.gd"
## Saved billboard prop: keep authored collision radius, cut away foliage over the leader.
@onready var illustration: MeshInstance3D = $Illustration


func _ready() -> void:
	super._ready()
	if not Engine.is_editor_hint():
		illustration.material_override = illustration.material_override.duplicate()
		add_to_group("skybound_illustrated_props")


func set_focus(at: Vector3) -> void:
	(illustration.material_override as ShaderMaterial).set_shader_parameter(&"focus", at)
