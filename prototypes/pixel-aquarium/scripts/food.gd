extends Node3D

const LIFETIME := 6.0
var age := 0.0
var sink_speed := 0.18
var color := Color("#f3b37f")
var fish_id := 0
var show_ripple := false

@onready var _ripple: MeshInstance3D = $Ripple


func _ready() -> void:
	var material := $Pellet.material_override.duplicate() as StandardMaterial3D
	material.albedo_color = color
	$Pellet.material_override = material


func _process(delta: float) -> void:
	age += delta
	position.y = maxf(position.y - delta * sink_speed, -1.77)
	_ripple.visible = age < 0.42 and show_ripple
	_ripple.scale = Vector3.ONE * (0.4 + age * 2.6)
	$Pellet.scale = Vector3.ONE * 0.068 * clampf((6.0 - age) / 0.7, 0.0, 1.0)
