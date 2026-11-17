extends Node3D
## Lightweight patrol for the load-test units; movement follows the terrain.

@export var animation_name: StringName = &"idle"
@export_range(0.0, 2.0, 0.05) var animation_phase: float = 0.0
@export var shadows_enabled: bool = true
@export var patrol_speed: float = 1.8
@export var patrol_radius: float = 3.0
@onready var _model: Node3D = %Model
var _meshes: Array[MeshInstance3D] = []
var _anim: AnimationPlayer
var _home := Vector3.ZERO
var _destination := Vector3.ZERO
var _patrol_axis := Vector3.FORWARD
var _forward := true
var _ground_wait := 0.0
var _time := 0.0
var _session: Node


func _ready() -> void:
	for node: Node in _model.find_children("*", "MeshInstance3D", true, false):
		_meshes.append(node as MeshInstance3D)
	set_shadows_enabled(shadows_enabled)
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_home = global_position
	_patrol_axis = global_basis.z.normalized()
	_destination = _home + _patrol_axis * patrol_radius
	_session = get_tree().get_first_node_in_group("battle_session")
	if _anim != null and _anim.has_animation(animation_name):
		_anim.play(animation_name)
		_anim.seek(animation_phase, true)

func _physics_process(delta: float) -> void:
	if _session == null or _session.match_state != "playing": return
	_time += delta
	var to := _destination - global_position
	to.y = 0.0
	if to.length() < 0.3:
		_forward = not _forward
		_destination = _home + _patrol_axis * (patrol_radius if _forward else -patrol_radius)
		to = _destination - global_position
		to.y = 0.0
	var dir := to.normalized()
	var step := minf(patrol_speed * delta, to.length())
	if step > 0.0:
		var next := global_position + dir * step
		_ground_wait -= delta
		if _ground_wait <= 0.0:
			_ground_wait = 0.2
			var ray := PhysicsRayQueryParameters3D.create(next + Vector3.UP * 3.0, next - Vector3.UP * 5.0, 1)
			var hit := get_world_3d().direct_space_state.intersect_ray(ray)
			if not hit.is_empty(): next.y = hit.position.y + 0.05
		global_position = next
		rotation.y = rotate_toward(rotation.y, atan2(dir.x, dir.z), delta * 1.6)
	if _anim != null and _anim.has_animation(&"walk"):
		if _anim.current_animation != &"walk": _anim.play(&"walk", 0.2)
	else:
		# The provided Phido is a single static mesh; use a small moving bob.
		_model.position.y = sin(_time * 8.0 + animation_phase) * 0.04


func set_shadows_enabled(enabled: bool) -> void:
	shadows_enabled = enabled
	for mesh: MeshInstance3D in _meshes:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if enabled \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
