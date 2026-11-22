extends "res://scripts/fish.gd"

@export var body_material: Material
@export var fin_material: Material


func _ready() -> void:
	super()
	%Body.material_override = body_material
	for fin: MeshInstance3D in [%Dorsal, %Anal, %Caudal, %NearFinMesh, %FarFinMesh]:
		fin.material_override = fin_material
