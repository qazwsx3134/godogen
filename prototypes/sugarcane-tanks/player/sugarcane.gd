extends Area2D
## A thrown sugarcane. Moves with a ray against the world layer each step so it can
## bounce off walls with the surface normal; hits tanks through its Area2D shape.

const HeroStats = preload("res://domain/hero_stats.gd")
const WORLD_MASK: int = 1

var direction: Vector2 = Vector2.RIGHT
var speed: float = 1500.0
var damage: float = 50.0
var crit_chance: float = 0.0
var pierce: bool = false
var ricochets: int = 0
var bounces: int = 0
var burn: bool = false
var freeze: bool = false
var game: Node

## Turns per second of the picture (%Visual) while it flies, like a thrown stick. The Area2D itself
## still points where the cane goes, so the collision and the bounces do not care about the spin.
@export var spin_turns_per_second: float = 2.5

var _hit: Dictionary = {}
var _life: float = 1.4

@onready var _visual: Node2D = %Visual

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	_visual.rotation += TAU * spin_turns_per_second * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	var motion: Vector2 = direction * speed * delta
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + motion, WORLD_MASK)
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position += motion
		return
	if bounces > 0:
		bounces -= 1
		var normal: Vector2 = hit["normal"]
		global_position = (hit["position"] as Vector2) + normal * 4.0
		direction = direction.bounce(normal)
		rotation = direction.angle()
		game.sfx.play(&"ricochet", 0.06)
		return
	global_position = hit["position"]
	game.spawn_puff(global_position, Color(0.75, 0.9, 0.5))
	queue_free()

func _on_body_entered(body: Node2D) -> void:
	if _hit.has(body) or not body.has_method("take_hit") or body.get("dead"):
		return
	_hit[body] = true
	var crit: bool = randf() < crit_chance
	body.take_hit(damage * (HeroStats.CRIT_MULTIPLIER if crit else 1.0), crit, burn, freeze, direction, global_position)
	if ricochets > 0:
		var next: Node2D = game.nearest_enemy(global_position, _hit, 560.0)
		if next != null:
			ricochets -= 1
			damage *= HeroStats.RICOCHET_DAMAGE_FACTOR
			direction = (next.global_position - global_position).normalized()
			rotation = direction.angle()
			game.sfx.play(&"ricochet", 0.06)
			return
	if pierce:
		damage *= HeroStats.PIERCE_DAMAGE_FACTOR
		return
	queue_free()
