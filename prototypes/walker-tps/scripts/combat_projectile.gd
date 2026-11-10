extends Node3D
## Swept ray each physics step: fast projectiles cannot tunnel between frames.
@export var speed: float = 80.0
@export var damage: float = 40.0
var direction := Vector3.FORWARD
var team := "player"
var excluded: Array[RID] = []
var life := 3.0
const Impact = preload("res://scenes/combat_impact.tscn")

func _ready() -> void:
	add_to_group("live_projectile")

func _physics_process(delta: float) -> void:
	var next := global_position + direction * speed * delta
	var query := PhysicsRayQueryParameters3D.create(global_position, next, 7, excluded)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var body: Object = hit.collider
		if body.has_method("apply_damage") and body.get("team") != team:
			body.apply_damage(damage)
		var effect := Impact.instantiate() as Node3D
		get_parent().add_child(effect)
		effect.global_position = hit.position
		queue_free()
		return
	global_position = next
	life -= delta
	if life <= 0.0: queue_free()
