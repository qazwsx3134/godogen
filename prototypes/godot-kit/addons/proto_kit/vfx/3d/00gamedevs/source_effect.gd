extends Node3D
## Native meshes/shaders from 00GameDevs MIT exports; no Three.js at runtime.
## Saved Parts and Motion nodes remain editable in Godot.
## step(dt), stop(), reset(), hit(world_point?, world_normal?), set_endpoints(a,b).
signal finished
@export var auto_step: bool = true
@export var free_on_finish: bool = false
@export_range(0.25, 2.0) var speed: float = 1.0
@export_storage var effect_id: String = ""
@export_storage var burst: bool = false
@export_storage var duration: float = 5.0
@export_storage var start_duration: float = 0.35
@export_storage var end_duration: float = 0.8
@export_storage var kind: int = 0
@export_storage var variant: int = 0
@onready var parts: Node3D = %Parts
@onready var motion: AnimationPlayer = %Motion
var elapsed: float = 0.0
var phase: StringName = &"starting"
var is_finished: bool = false
var _stop_at: float = -1.0
var _ending: float = 0.0
var _origin: float = 1.0
var _impact: bool = false
var _direction: Vector3 = Vector3.RIGHT
var _travel_speed: float = 0.0
var _stretch: float = 1.0
var _endpoint_valid: bool = true
var _contact := Vector3.ZERO
var _materials: Array[ShaderMaterial] = []
var _meshes: Array[MeshInstance3D] = []
var _initial: Array[Transform3D] = []
var _initial_instances: Array[float] = []

func _ready() -> void:
	for child: Node in parts.get_children():
		var mesh := child as MeshInstance3D
		_meshes.append(mesh)
		_materials.append(mesh.material_override as ShaderMaterial)
		_initial.append(mesh.transform)
		_initial_instances.append(float(_materials[-1].get_shader_parameter("source_instance_count")))
	reset()

func _process(delta: float) -> void:
	if auto_step:
		step(delta)

func reset() -> void:
	elapsed = 0.0
	_stop_at = -1.0
	_ending = 0.0
	_origin = 1.0
	_impact = false
	is_finished = false
	phase = &"starting"
	visible = _endpoint_valid
	if not is_node_ready():
		return
	for index: int in _meshes.size():
		_meshes[index].transform = _initial[index]
		_materials[index].set_shader_parameter("source_instance_count", _initial_instances[index])
	motion.play(&"active")
	motion.pause()
	motion.seek(0.0, true)
	_sync()

func step(delta: float) -> void:
	if is_finished or not is_finite(delta) or delta < 0.0:
		return
	var visual: float = delta * clampf(speed, 0.25, 2.0)
	elapsed += visual
	if _stop_at >= 0.0:
		_ending += visual
	if kind == 0 and _travel_speed > 0.0 and _stop_at < 0.0:
		position += _direction * delta * _travel_speed
	if not is_node_ready():
		return
	# Only time-dependent JS-side channels are sampled; the original GLSL runs continuously.
	motion.seek(minf(elapsed, duration), true)
	_sync()
	if is_finished:
		finished.emit()
		if free_on_finish:
			queue_free()

func stop() -> void:
	if burst or is_finished or _stop_at >= 0.0:
		return
	_origin = minf(1.0, elapsed / start_duration)
	_stop_at = elapsed
	_ending = 0.0
	_sync()

func set_direction(direction: Vector3, travel_speed: float = 4.0) -> void:
	if kind != 0 or is_finished or _stop_at >= 0.0 or not direction.is_finite() or direction.length_squared() < 0.00000001:
		return
	_direction = direction.normalized()
	_travel_speed = maxf(0.0, travel_speed) if is_finite(travel_speed) else 0.0
	quaternion = Quaternion(Vector3.RIGHT, _direction)

## Endpoints are in the parent's coordinate space, as in the original export.
func set_endpoints(from: Vector3, to: Vector3) -> void:
	if kind != 1 or is_finished or _stop_at >= 0.0 or not from.is_finite() or not to.is_finite():
		return
	var delta := to - from
	var length: float = delta.length()
	position = (from + to) * 0.5
	_endpoint_valid = length > 0.000001
	if _endpoint_valid:
		quaternion = Quaternion(Vector3.RIGHT, delta / length)
	scale = Vector3(length / 4.8, 1.0, 1.0)
	_stretch = maxf(0.001, length / 4.8)
	visible = _endpoint_valid
	_sync()

## Confirmed hit only; no collision or gameplay damage is inferred by the effect.
func hit(world_point: Variant = null, world_normal: Variant = null) -> void:
	if kind != 0 or is_finished or _stop_at >= 0.0:
		return
	if world_point != null and (not world_point is Vector3 or not world_point.is_finite()):
		return
	_contact = _projectile_contact()
	if world_point != null:
		global_position = world_point - global_basis * (parts.transform * _contact)
	var normal: Vector3 = -parts.global_basis.x.normalized()
	if world_normal is Vector3 and world_normal.is_finite() and world_normal.length_squared() > 0.00000001:
		normal = world_normal.normalized()
	var local_normal: Vector3 = (parts.global_basis.inverse() * normal).normalized()
	for index: int in _meshes.size():
		var mesh: MeshInstance3D = _meshes[index]
		var source_name: String = mesh.get_meta("source_name", "")
		if source_name.begins_with("lifecycle-"):
			mesh.position = _contact
			if source_name == "lifecycle-impact":
				mesh.quaternion = Quaternion(Vector3.RIGHT, local_normal)
				_materials[index].set_shader_parameter("uImpactUp", (mesh.global_basis.inverse() * Vector3.UP).normalized())
	_impact = true
	stop()

func _projectile_contact() -> Vector3:
	# Original leading-surface equations at the default source size (1).
	var result := Vector3.RIGHT
	if variant == 0:
		result = Vector3(1.11 + sin(elapsed * 4.1) * 0.035, sin(5.0 + elapsed * 3.0) * 0.03, cos(7.0 + elapsed * 2.7) * 0.03)
	elif variant == 1:
		result.x = 1.7
	elif variant == 2:
		result.x = 1.78
	elif variant == 3:
		var start: float = minf(1.0, elapsed / start_duration)
		var curl: float = 1.0 - start * start * (3.0 - 2.0 * start)
		var best: float = -INF
		for index: int in 3:
			var angle: float = index * 2.094395 - elapsed * 3.0
			var center := Vector3(0.85 + sin(angle * 2.0) * 0.09, cos(angle) * 0.26, sin(angle) * 0.26)
			for tip: int in 6:
				var point := center
				var axis: int = tip / 2
				var sign_value: float = -1.0 if tip % 2 else 1.0
				point[axis] += sign_value * (0.182 if axis == 0 else 0.078)
				point.y *= 1.0 + curl * 0.8
				point.z *= 1.0 + curl * 0.8
				point.x += sin(point.y * 7.0) * curl * 0.4
				if point.x > best:
					best = point.x
					result = point
		return result
	elif variant == 6:
		result.x = 1.11
	if elapsed < start_duration:
		var start: float = elapsed / start_duration
		var grow: float = start * start * (3.0 - 2.0 * start)
		var curl: float = 1.0 - grow
		if variant == 0:
			result.y *= 0.22 + 0.78 * grow
			result.z *= 0.22 + 0.78 * grow
			result.x = (result.x * 0.38 - 0.16) * (1.0 - grow) + result.x * grow
			result.y += sin(result.x * 4.5 + start * 7.0) * curl * 0.15
		elif variant == 1:
			result.x *= 1.3 - 0.3 * grow
			result.y *= 0.08 + 0.92 * grow
			result.z *= 0.08 + 0.92 * grow
		elif variant == 2:
			var assembly: float = ceilf((atan2(result.z, result.y) + PI) * 3.0) * 0.028
			result.y *= 1.0 + curl * (0.8 + assembly)
			result.z *= 1.0 + curl * (0.8 + assembly)
			result.x -= curl * (0.2 + assembly)
	return result

func _sync() -> void:
	if not is_node_ready():
		return
	if burst:
		phase = &"finished" if elapsed + 0.000000001 >= duration else (&"ending" if elapsed >= duration - end_duration else (&"active" if elapsed >= start_duration else &"starting"))
	else:
		phase = (&"finished" if _ending + 0.000000001 >= end_duration else &"ending") if _stop_at >= 0.0 else (&"active" if elapsed >= start_duration else &"starting")
	is_finished = phase == &"finished"
	if is_finished:
		visible = false
	var beginning: float = _origin if _stop_at >= 0.0 else minf(1.0, elapsed / start_duration)
	var ending: float = clampf((elapsed - (duration - end_duration)) / end_duration, 0.0, 1.0) if burst else (minf(1.0, _ending / end_duration) if _stop_at >= 0.0 else 0.0)
	for index: int in _meshes.size():
		var mesh: MeshInstance3D = _meshes[index]
		var material: ShaderMaterial = _materials[index]
		if mesh.has_meta("source_depth_shader"):
			var target: Shader = mesh.get_meta("source_depth_shader" if phase == &"active" or mesh.get_meta("source_depth_mode", "active") == "always" else "source_transparent_shader")
			if material.shader != target:
				material.shader = target
		material.set_shader_parameter("source_to_group", mesh.transform)
		material.set_shader_parameter("uTime", elapsed)
		material.set_shader_parameter("uEmitterTime", _stop_at if _stop_at >= 0.0 else elapsed)
		material.set_shader_parameter("uLifeStart", beginning)
		material.set_shader_parameter("uLifeEnd", ending)
		material.set_shader_parameter("uLifeStage", 1.0 if phase == &"active" else (0.0 if phase == &"starting" else 2.0))
		material.set_shader_parameter("uLifeOrigin", _origin)
		material.set_shader_parameter("uStopTime", _stop_at)
		material.set_shader_parameter("uImpact", 1.0 if _impact else 0.0)
		material.set_shader_parameter("uStretch", _stretch)
		material.set_shader_parameter("uOpening", beginning)
		material.set_shader_parameter("uRetire", ending)
		material.set_shader_parameter("uStoppedAt", _stop_at)
		material.set_shader_parameter("transmissionSamplerSize", Vector2(get_viewport().get_visible_rect().size))
		var ranges: Array = mesh.get_meta("phase_ranges", [])
		if ranges.size() == 2:
			material.set_shader_parameter("source_draw_start", 0.0 if phase == &"active" else ranges[0])
			material.set_shader_parameter("source_draw_count", ranges[0] if phase == &"active" else ranges[1])
		if kind == 0 and variant == 0 and index == 0:
			material.set_shader_parameter("source_instance_count", maxf(0.0, _initial_instances[index] - (12.0 if _impact and phase == &"ending" else 0.0)))
		var name: String = mesh.get_meta("source_name", "")
		if name.begins_with("lifecycle-"):
			mesh.visible = _impact and phase == &"ending" and (name != "lifecycle-contact-glow" or ending < 0.28)
		# The sole continuous JS rotation in the source engine, without a baked loop seam.
		if effect_id == "ice-shard" and name == "projectile-core":
			mesh.rotation.x = sin(elapsed * 0.7) * 0.12
