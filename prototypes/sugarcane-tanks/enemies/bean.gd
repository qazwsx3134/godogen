extends Area2D
## An enemy projectile: a thrown bean (pea, corn, carrot) that spins, or a bullet (spin 0)
## that points where it flies. Stops at walls and crates, hurts the hero.
## `bounces` > 0 makes it bounce off walls and crates that many times first (the enraged final boss's bullets);
## with `bounce_life` > 0 it then fades out that many seconds after its first bounce.

const WORLD_MASK: int = 1
const FADE_TIME: float = 0.4

@export var spin: float = 10.0

var direction: Vector2 = Vector2.RIGHT
var speed: float = 470.0
var damage: int = 55
var bounces: int = 0
var bounce_life: float = 0.0
var game: Node

var _life_left: float = INF   # counts down once the first bounce has happened

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if is_zero_approx(spin):
		rotation = direction.angle()

func _physics_process(delta: float) -> void:
	rotation += spin * delta
	if _life_left != INF:
		_life_left -= delta
		if _life_left <= 0.0:
			queue_free()
			return
		modulate.a = minf(1.0, _life_left / FADE_TIME)
	var motion: Vector2 = direction * speed * delta
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + motion, WORLD_MASK)
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		game.spawn_puff(hit["position"], modulate)
		if bounces > 0:
			bounces -= 1
			if bounce_life > 0.0 and _life_left == INF:
				_life_left = bounce_life
			var normal: Vector2 = hit["normal"]
			global_position = (hit["position"] as Vector2) + normal * 4.0
			direction = direction.bounce(normal)
			if is_zero_approx(spin):
				rotation = direction.angle()
			return
		queue_free()
		return
	global_position += motion

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_hit"):
		body.take_hit(damage)
		queue_free()
