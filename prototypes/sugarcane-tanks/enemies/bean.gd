extends Area2D
## An enemy projectile: a thrown bean (pea, corn, carrot) that spins, or a bullet (spin 0)
## that points where it flies. Stops at walls and crates, hurts the hero.

const WORLD_MASK: int = 1

@export var spin: float = 10.0

var direction: Vector2 = Vector2.RIGHT
var speed: float = 470.0
var damage: int = 55
var game: Node

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if is_zero_approx(spin):
		rotation = direction.angle()

func _physics_process(delta: float) -> void:
	rotation += spin * delta
	var motion: Vector2 = direction * speed * delta
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + motion, WORLD_MASK)
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		game.spawn_puff(hit["position"], modulate)
		queue_free()
		return
	global_position += motion

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_hit"):
		body.take_hit(damage)
		queue_free()
