extends Node2D
@export var speed: float = 440.0
@export var lifetime: float = 0.9
@export var radius: float = 18.0
var direction := Vector2.RIGHT
var damage: float = 24.0
var force: float = 1.0
var age: float = 0.0
var hit_ids: Dictionary = {}

func setup(heading: Vector2, hit_damage: float, hit_force: float, power: int) -> void:
	direction = heading.normalized()
	rotation = direction.angle()
	damage = hit_damage
	force = hit_force
	radius += power * 4.0
	%Visual.scale = Vector2.ONE * (1.0 + power * 0.15)

func step(delta: float) -> Vector2:
	var before: Vector2 = position
	position += direction * speed * minf(delta, maxf(0.0, lifetime - age))
	age += delta
	modulate.a = clampf((lifetime - age) / 0.16, 0.0, 1.0)
	if age >= lifetime:
		queue_free()
	return before

func can_hit(enemy: Node2D, before: Vector2) -> bool:
	if enemy.dead or hit_ids.has(enemy.get_instance_id()):
		return false
	var closest: Vector2 = Geometry2D.get_closest_point_to_segment(enemy.position, before, position)
	return closest.distance_to(enemy.position) <= radius + enemy.definition.radius

func remember(enemy: Node2D) -> void:
	hit_ids[enemy.get_instance_id()] = true
