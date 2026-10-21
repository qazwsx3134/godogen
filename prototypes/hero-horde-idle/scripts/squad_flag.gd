extends Node3D
## One 團 (squad): its flag (pole and cloth in the squad's colour, a label with the name and living heroes) and a
## ellipse on the ground around the squad while it is selected. scripts/main.gd places the flag on the sim's
## flag point, or under the finger while it is dragged. Where the flag stands in the saved scene is the squad's
## muster point (read once, before the first push moves it).

@export var squad_index: int = 0
@export var color: Color = Color.WHITE

## Ground point (x, z) of the flag in the saved scene.
var home := Vector2.ZERO

@onready var _cloth: MeshInstance3D = %Cloth
@onready var _ring: MeshInstance3D = %Ring
@onready var _label: Label3D = %FlagLabel


func _ready() -> void:
	home = Vector2(position.x, position.z)
	var m := _cloth.material_override.duplicate() as StandardMaterial3D
	m.albedo_color = color
	_cloth.material_override = m
	_ring.set_instance_shader_parameter(&"color", color)


## at: where the flag stands; block: the squad on the ground (centre, ellipse radii); dragged: the flag is
## under the finger.
func show_state(at: Vector2, title: String, living: int, block_center: Vector2, block_half: Vector2,
		selected: bool, dragged: bool, threatened: bool) -> void:
	position = Vector3(at.x, 0.0, at.y)
	visible = living > 0
	_label.text = "%s %d" % [title, living]
	_label.modulate = Color(1.0, 0.45, 0.4) if threatened else Color.WHITE
	_ring.visible = selected or dragged
	var size: Vector2 = block_half * 2.0 + Vector2(0.5, 0.5)
	_ring.global_position = Vector3(block_center.x, 0.035, block_center.y)
	_ring.scale = Vector3(size.x, 1.0, size.y)
	_ring.set_instance_shader_parameter(&"texels", (size / 0.05).round())
	_ring.set_instance_shader_parameter(&"inner_alpha", 0.12 if dragged else 0.06)
