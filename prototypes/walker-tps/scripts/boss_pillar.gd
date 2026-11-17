extends StaticBody3D
## Boss "pillar rain": one pillar dropped from the sky onto a marked spot. While it waits the
## red ring on the ground (Marker) warns where it lands; it then falls point first, wounds and
## jolts a walker standing in the ring, and stays stuck in the ground as an obstacle and cover
## until it is shot apart (or crumbles after `lifetime`).
## boss.gd: pillar.drop(ground_point, wait_seconds) right after add_child.
@export var max_health := 24.0
@export var fall_speed := 60.0
@export var drop_height := 45.0
@export var damage := 12.0
@export var hit_radius := 1.5
## How deep the point goes in (m); the rest stands above the ground.
@export var sink_depth := 1.6
@export var lifetime := 30.0
const Impact = preload("res://scenes/combat_impact.tscn")
const Layers = preload("res://scripts/layers.gd")
enum Phase { WAITING, FALLING, STUCK }
var team := "enemy"
var health := 0.0
var phase := Phase.WAITING
var _ground := Vector3.ZERO
var _wait := 0.0
var _life := 0.0
@onready var _marker: Node3D = $Marker

func _ready() -> void:
	health = max_health
	add_to_group("boss_pillars")
	collision_layer = 0  # solid only once it is in the ground
	$Model.visible = false

func drop(ground: Vector3, wait: float) -> void:
	var hit := get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(ground + Vector3.UP * 30.0, ground + Vector3.DOWN * 30.0, Layers.TERRAIN))
	_ground = hit.position if not hit.is_empty() else ground
	var up: Vector3 = hit.normal if not hit.is_empty() else Vector3.UP
	_wait = wait
	global_position = _ground + Vector3.UP * drop_height
	rotation = Vector3(randf_range(-0.12, 0.12), randf_range(0.0, TAU), randf_range(-0.12, 0.12))
	_marker.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, up.normalized())), _ground + up * 0.1)

func _physics_process(delta: float) -> void:
	match phase:
		Phase.WAITING:
			_wait -= delta
			_marker.scale = Vector3.ONE * (1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.02))  # pulses: incoming
			if _wait <= 0.0:
				phase = Phase.FALLING
				$Model.visible = true
		Phase.FALLING:
			global_position.y -= fall_speed * delta
			if global_position.y <= _ground.y - sink_depth:
				_stick()
		Phase.STUCK:
			_life += delta
			if _life >= lifetime: shatter()

func _stick() -> void:
	phase = Phase.STUCK
	global_position.y = _ground.y - sink_depth
	collision_layer = Layers.ENEMY
	_marker.visible = false
	_spawn_impact(_ground + Vector3.UP * 0.5, 2.0)
	var player := get_tree().get_first_node_in_group("combat_player") as Node3D
	if player:
		var offset := player.global_position - _ground
		if Vector2(offset.x, offset.z).length() < hit_radius + 1.1 * player.scale.x and absf(offset.y) < 4.0 * player.scale.y:  # + the hull radius
			player.apply_damage(damage, player.global_position, Vector3(offset.x, 0.3, offset.z).normalized())
		var near := clampf(1.0 - Vector2(offset.x, offset.z).length() / 30.0, 0.0, 1.0)
		var feedback := get_tree().get_first_node_in_group("combat_feedback")
		if feedback and near > 0.0: feedback.rig.shake(0.35 * near, 0.6)

func apply_damage(amount: float, _hit_position: Vector3 = Vector3.ZERO, from_direction: Vector3 = Vector3.ZERO) -> void:
	if phase != Phase.STUCK or health <= 0.0: return
	health -= amount
	$HitReact.react(from_direction, 1.0)
	if health <= 0.0: shatter()

## Breaks apart: a blast halfway up and a spray of parts; the pillar is gone.
func shatter() -> void:
	if not is_inside_tree() or is_queued_for_deletion(): return
	var middle := global_position + global_basis.y.normalized() * (sink_depth + 2.0)
	_spawn_impact(middle, 2.2)
	var parts := get_tree().get_first_node_in_group("debris_parts")
	if parts:
		for i in 4: parts.spawn(middle, Vector3(randf_range(-6, 6), randf_range(5, 10), randf_range(-6, 6)), randf_range(0.9, 1.6))
	queue_free()

func _spawn_impact(at: Vector3, radius: float) -> void:
	var effect := Impact.instantiate() as Node3D
	effect.radius = radius
	get_parent().add_child(effect)
	effect.global_position = at
