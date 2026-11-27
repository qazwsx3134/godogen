extends StaticBody3D

var mineral := 2
var anchor_cell: Vector3i
var hits_left := 2
var response: Tween

@onready var crystals: Node3D = %Crystals
@onready var calcite: Node3D = %Calcite
@onready var amethyst: Node3D = %Amethyst


func _ready() -> void:
	calcite.visible = mineral == 2
	amethyst.visible = mineral == 3


func strike(power: int) -> bool:
	hits_left -= power
	if hits_left <= 0:
		return true
	if response:
		response.kill()
	response = create_tween()
	response.tween_property(crystals, "position:z", 0.0, 0.13).from(-0.033)
	return false


func retire() -> void:
	hide()
	collision_layer = 0
	queue_free()
