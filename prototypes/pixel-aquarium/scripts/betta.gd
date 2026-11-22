extends "res://scripts/fish.gd"

@export var long_tail := false:
	set(value):
		long_tail = value
		if is_node_ready():
			_apply_traits()
@export var silver := false:
	set(value):
		silver = value
		if is_node_ready():
			_apply_traits()

const PLAIN := preload("res://assets/plain_body.tres")
const SILVER := preload("res://assets/silver_body.tres")

@onready var _jaw: Node3D = $Rig/LowerJaw
@onready var _aperture: MeshInstance3D = $Rig/Mouth
@onready var _body: MeshInstance3D = %Body
@onready var _short_tail: MeshInstance3D = %ShortTail
@onready var _long_tail: MeshInstance3D = %LongTail


func _ready() -> void:
	super()
	_apply_traits()


func display_name() -> String:
	if not fish_name.is_empty():
		return fish_name
	if long_tail:
		return "月影鬥魚" if silver else "長尾鬥魚"
	return "銀紋鬥魚" if silver else "普通鬥魚"


func display_traits() -> String:
	return "%s · %s" % ["長尾" if long_tail else "短尾", "月牙銀紋" if silver else "無銀紋"]


func _apply_traits() -> void:
	_body.material_override = SILVER if silver else PLAIN
	_long_tail.visible = long_tail
	_short_tail.visible = not long_tail
	%LongTailPick.set_deferred("disabled", not long_tail)
	%ShortTailPick.set_deferred("disabled", long_tail)


func _process(delta: float) -> void:
	super(delta)
	_jaw.visible = _mouth_open > 0.1
	_aperture.visible = _jaw.visible
	_jaw.rotation.z = -0.74 * _mouth_open
	_aperture.scale.y = lerpf(0.029, 0.082, _mouth_open)
