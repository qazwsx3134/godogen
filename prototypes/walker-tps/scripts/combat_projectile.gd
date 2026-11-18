extends Node3D
## Swept ray each physics step: fast projectiles cannot tunnel between frames.
## The Tail tracer stretches with speed; an enemy round that passes close by the walker
## without hitting plays Whiz (the crack of a near miss) once it is past. On impact: a body gets a
## thud, flying parts and an oil stain (the target's own HitReact flashes and squashes it);
## anything else gets a ping and sparks along the surface normal.
@export var speed: float = 120.0
@export var damage: float = 40.0
@export var impact_radius: float = 1.0
## Tracer length = speed * tail_seconds (m).
@export var tail_seconds: float = 0.06
var direction := Vector3.FORWARD
var team := "player"
var excluded: Array[RID] = []
var life := 3.0
var _travelled := 0.0
## Near miss: within this many metres of the walker's hull.
@export var near_miss := 5.0
var _closest := INF
var _whizzed := false
const Impact = preload("res://scenes/combat_impact.tscn")
const Layers = preload("res://scripts/layers.gd")

func _ready() -> void:
	add_to_group("live_projectile")
	# Shooters set direction/speed right after add_child; orient before this frame is drawn.
	_setup.call_deferred()

func _setup() -> void:
	if direction.length_squared() > 0.0:
		look_at(global_position + direction, Vector3.UP if absf(direction.y) < 0.99 else Vector3.RIGHT, true)
	_stretch_tail()

func _physics_process(delta: float) -> void:
	var next := global_position + direction * speed * delta
	var query := PhysicsRayQueryParameters3D.create(global_position, next, Layers.SOLID, excluded)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var body: Object = hit.collider
		var on_cover := body.has_method("break_cover")
		var on_body: bool = not on_cover and body.has_method("apply_damage") and body.get("team") != team
		if on_cover:
			body.apply_damage(damage, hit.position, direction)
		if on_body:
			body.apply_damage(damage, hit.position, direction)
			if body.has_method("knockback"): body.knockback(direction)
			_spill(hit.position, hit.normal)
		var effect := Impact.instantiate() as Node3D
		effect.radius = impact_radius
		effect.surface = "body" if on_body else "wall"
		effect.explosive = team == "player"
		effect.normal = hit.normal
		get_parent().add_child(effect)
		effect.global_position = hit.position
		queue_free()
		return
	global_position = next
	if team == "enemy" and not _whizzed: _check_near_miss()
	_travelled += speed * delta
	_stretch_tail()
	life -= delta
	if life <= 0.0: queue_free()

func _check_near_miss() -> void:
	var player := get_tree().get_first_node_in_group("combat_player") as Node3D
	if player == null: return
	var d := global_position.distance_to(player.global_position + Vector3.UP * 1.3)
	if d > _closest and _closest < near_miss:  # just went past
		_whizzed = true
		$Whiz.pitch_scale = randf_range(1.6, 1.9)  # faster and higher than the recording
		$Whiz.play()
	_closest = minf(_closest, d)

## The tracer only reaches back over ground already covered, so it never shows inside the barrel.
func _stretch_tail() -> void:
	var length := minf(speed * tail_seconds, _travelled)
	$Tail.visible = length > 0.05
	$Tail.scale = Vector3(1.0, 1.0, maxf(length, 0.01))  # width lives in tracer.gdshader
	$Tail.position = Vector3(0, 0, -length * 0.5)

## Mechs bleed parts and oil: one chunk thrown back out of the hole, a splat on the floor.
func _spill(at: Vector3, normal: Vector3) -> void:
	var parts := get_tree().get_first_node_in_group("debris_parts")
	if parts:
		for i in randi_range(2, 3):
			var out := (normal - direction * 0.5 + Vector3(randf_range(-0.6, 0.6), 0.0, randf_range(-0.6, 0.6))).normalized()
			parts.spawn(at + normal * 0.3, out * randf_range(4.0, 8.0) + Vector3.UP * randf_range(4.0, 7.0), randf_range(0.35, 0.8))
	var stains := get_tree().get_first_node_in_group("debris_stains")
	if stains and randf() < 0.35:
		stains.stamp(at + direction * 1.5, randf_range(0.8, 1.4))
