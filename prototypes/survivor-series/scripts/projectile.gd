extends Node2D
## A weapon projectile. Street owns hit tests; this only moves, remembers whom it hit, and flags detonation.
@export_enum("straight", "boomerang", "orbit", "lob", "fall") var mode: String = "straight"
@export var radius: float = 16.0
## Visual spin in radians per second.
@export var spin: float = 0.0
## Aligns the visual with the travel direction.
@export var face_travel: bool = true
var velocity := Vector2.ZERO
var damage: float = 10.0
var force: float = 1.0
var lifetime: float = 1.0
var age: float = 0.0
## Hits left before the projectile is spent; -1 = unlimited.
var pierce: int = -1
## Seconds before the same enemy can be hit again; 0 = once only.
var rehit: float = 0.0
var bounce: bool = false
var homing: bool = false
var blast_radius: float = 0.0
## Zone effects on enemies inside `radius`; see Street._step_projectiles.
var slow: float = 0.0
var pull: float = 0.0
var blast_on_end: bool = false
var detonate: bool = false
var start_point := Vector2.ZERO
var target_point := Vector2.ZERO
var anchor: Node2D
var orbit_angle: float = 0.0
var orbit_radius: float = 80.0
var orbit_speed: float = 3.6
var bounds := Rect2()
var hit_at: Dictionary = {}
@onready var visual: Node2D = %Visual

func launch(at: Vector2) -> void:
	position = at
	start_point = at
	if face_travel and velocity != Vector2.ZERO:
		rotation = velocity.angle()

func step(delta: float) -> Vector2:
	var before: Vector2 = position
	age += delta
	match mode:
		"straight":
			position += velocity * delta
			if bounce and bounds.has_area():
				if position.x < bounds.position.x or position.x > bounds.end.x:
					velocity.x = -velocity.x
				if position.y < bounds.position.y or position.y > bounds.end.y:
					velocity.y = -velocity.y
				position = position.clamp(bounds.position, bounds.end)
			if face_travel:
				rotation = velocity.angle()
		"boomerang":
			# Travels out, stops at half life and comes back along the same line.
			position += velocity * (1.0 - 2.0 * age / lifetime) * delta
		"orbit":
			orbit_angle += orbit_speed * delta
			if anchor != null:
				position = anchor.position + Vector2.RIGHT.rotated(orbit_angle) * orbit_radius
		"lob", "fall":
			var t: float = clampf(age / lifetime, 0.0, 1.0)
			position = start_point.lerp(target_point, t) if mode == "lob" else target_point
			visual.position.y = -sin(t * PI) * 70.0 if mode == "lob" else -(1.0 - t) * 260.0
			if t >= 1.0:
				detonate = true
	visual.rotation += spin * delta
	if mode != "lob" and mode != "fall":
		modulate.a = clampf((lifetime - age) / 0.15, 0.0, 1.0)
		if age >= lifetime:
			if blast_radius > 0.0:
				detonate = true
			else:
				queue_free()
	return before

func can_hit(enemy: Node2D, before: Vector2) -> bool:
	if mode == "lob" or mode == "fall" or detonate or enemy.dead or pierce == 0:
		return false
	var id: int = enemy.get_instance_id()
	if hit_at.has(id) and (rehit <= 0.0 or age - float(hit_at[id]) < rehit):
		return false
	var closest: Vector2 = Geometry2D.get_closest_point_to_segment(enemy.position, before, position)
	return closest.distance_to(enemy.position) <= radius + enemy.definition.radius

func remember(enemy: Node2D) -> void:
	hit_at[enemy.get_instance_id()] = age
	if blast_radius > 0.0 and not blast_on_end:
		detonate = true
	elif pierce > 0:
		pierce -= 1
		if pierce == 0:
			queue_free()
