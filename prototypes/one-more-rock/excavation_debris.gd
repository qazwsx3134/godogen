extends RigidBody3D

signal shattered(at: Vector3, count: int)

var ore_count := 1
@export var lands_as_ore := true
var rare := false
var mineral := -1
var age := 0.0
var grounded := false
var previous_speed := 0.0
var spent := false


func _ready() -> void:
	body_entered.connect(_landed)


func _physics_process(delta: float) -> void:
	age += delta
	if lands_as_ore:
		return
	previous_speed = linear_velocity.length()
	# Thin pieces can land lightly on a ledge; finish crumbling once they actually settle.
	if grounded and age > 1.0 and previous_speed < 0.42 or global_position.y < -3.0:
		_break_apart()


func usable() -> bool:
	return lands_as_ore and grounded and age >= 0.22 and absf(linear_velocity.y) < 1.35 and not spent


func _landed(other: Node) -> void:
	if other is CollisionObject3D and other.collision_layer & 4 != 0:
		grounded = true
	if not lands_as_ore and grounded and age > 0.15 and previous_speed > 2.15:
		_break_apart()


func _break_apart() -> void:
	if spent:
		return
	spent = true
	var point := global_position
	point.y = maxf(point.y, 0.25)
	shattered.emit(point, ore_count)
	queue_free()
