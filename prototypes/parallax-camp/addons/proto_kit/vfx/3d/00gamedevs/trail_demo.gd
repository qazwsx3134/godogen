extends Node3D
## Preview-only weapon motion; gameplay owners attach their real weapon instead.
func _ready() -> void:
	%Trail.attach_weapon(%Weapon, Vector3.ZERO, Vector3(0, 1.4, 0))
	%Swing.play(&"swing")
