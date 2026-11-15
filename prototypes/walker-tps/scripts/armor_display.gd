extends Node3D
## Editable visual instance for comparing armor meshes and render cost.
## Physics and combat are intentionally supplied by a gameplay scene instead.

@export var animation_name: StringName = &"idle"
@export_range(0.0, 2.0, 0.05) var animation_phase: float = 0.0
@export var shadows_enabled: bool = true
@onready var _model: Node3D = %Model
var _meshes: Array[MeshInstance3D] = []
var _anim: AnimationPlayer


func _ready() -> void:
	for node: Node in _model.find_children("*", "MeshInstance3D", true, false):
		_meshes.append(node as MeshInstance3D)
	set_shadows_enabled(shadows_enabled)
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim != null and _anim.has_animation(animation_name):
		_anim.play(animation_name)
		_anim.seek(animation_phase, true)


func set_shadows_enabled(enabled: bool) -> void:
	shadows_enabled = enabled
	for mesh: MeshInstance3D in _meshes:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if enabled \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
