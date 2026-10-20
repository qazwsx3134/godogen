extends Node3D
## One 區 on the field: the ground tile and its label (name, living heroes). Its position and the
## Tile's PlaneMesh size are the zone's rectangle; scripts/main.gd hands them to the sim, so moving or resizing a
## tile in the editor moves the zone.

@export var zone_index: int = 0

@onready var _tile: MeshInstance3D = %Tile
@onready var _label: Label3D = %ZoneLabel

var _material: ShaderMaterial


func _ready() -> void:
	# Each run gets its own copy, so telegraph colours never touch the saved material.
	_material = _tile.material_override.duplicate()
	_tile.material_override = _material


func half_size() -> Vector2:
	return (_tile.mesh as PlaneMesh).size * 0.5 * Vector2(scale.x, scale.z)


func ground_center() -> Vector2:
	return Vector2(global_position.x, global_position.z)


## warn: 0 = not targeted, else the telegraph's progress 0..1.
func show_state(title: String, living: int, selected: bool, hovered: bool, warn: float, pulse: float) -> void:
	_label.text = "%s  %d人" % [title, living]
	_label.modulate = Color(1.0, 0.45, 0.4) if warn > 0.0 else Color.WHITE
	_material.set_shader_parameter(&"highlight", 1.0 if selected else (0.5 if hovered else 0.0))
	_material.set_shader_parameter(&"warn", warn)
	_material.set_shader_parameter(&"pulse", pulse)
