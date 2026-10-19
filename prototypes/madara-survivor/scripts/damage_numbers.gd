class_name DamageNumbers
extends Node3D
## Floating damage numbers: a fixed pool of damage_number.tscn labels, the oldest reused when all are busy.

@export var number_scene: PackedScene
@export var pool_size: int = 32
@export var life: float = 0.6
@export var rise: float = 1.4
## Hits below this are not shown, so an aura ticking on a crowd does not bury the screen.
@export var min_shown: float = 1.0

var _labels: Array[Label3D] = []
var _age := PackedFloat32Array()
var _from := PackedVector3Array()
var _next: int = 0


func _ready() -> void:
	for i: int in pool_size:
		var label: Label3D = number_scene.instantiate()
		label.visible = false
		add_child(label)
		_labels.append(label)
		_age.append(life)
		_from.append(Vector3.ZERO)


func show_hit(at: Vector3, amount: float, big: bool = false) -> void:
	if amount < min_shown:
		return
	var i: int = _next
	_next = (_next + 1) % pool_size
	var label: Label3D = _labels[i]
	label.text = str(roundi(amount))
	label.modulate = Color(1.0, 0.85, 0.3) if big else Color.WHITE
	label.scale = Vector3.ONE * (1.4 if big else 1.0)
	label.visible = true
	_age[i] = 0.0
	_from[i] = at + Vector3(randf_range(-0.3, 0.3), 0.2, 0.0)


func step(dt: float) -> void:
	for i: int in pool_size:
		if _age[i] >= life:
			continue
		_age[i] += dt
		var t: float = _age[i] / life
		var label: Label3D = _labels[i]
		if t >= 1.0:
			label.visible = false
			continue
		# Pops up fast, then hangs and fades.
		label.position = _from[i] + Vector3(0.0, rise * (1.0 - (1.0 - t) * (1.0 - t)), 0.0)
		label.modulate.a = 1.0 if t < 0.6 else 1.0 - (t - 0.6) / 0.4
