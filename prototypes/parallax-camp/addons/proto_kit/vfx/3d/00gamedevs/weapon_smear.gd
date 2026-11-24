extends Node3D
## 00GameDevs weapon-smear, MIT. Three native shader layers, 64 world-space samples.
## Attach after animation: attach_weapon(sword, Vector3.ZERO, Vector3(0,1,0)).
## A stationary/unbound weapon emits nothing. stop() drains the 0.18 s history.
signal finished
const CAPACITY: int = 64
const LIFETIME: float = 0.18
@export var auto_step: bool = true
@export var free_on_finish: bool = false
@export_range(0.25, 2.0) var speed: float = 1.0
@export_range(0.25, 1.0) var coverage: float = 1.0
@export var color: Color = Color("2878ff")
@export_range(0.25, 2.0) var detail: float = 1.0
@export_range(0.125, 1.0) var density: float = 0.5
@onready var layers: Array[Node] = %Layers.get_children()
var elapsed: float = 0.0
var is_finished: bool = false
var phase: StringName = &"active"
var _weapon: Node3D
var _was_bound: bool = false
var _base := Vector3.ZERO
var _tip := Vector3.UP
var _bases: Array[Vector3] = []
var _tips: Array[Vector3] = []
var _times: Array[float] = []
var _stop_at: float = -1.0
var _mesh := ArrayMesh.new()

func _ready() -> void:
	for layer: MeshInstance3D in layers:
		layer.mesh = _mesh
		var material := layer.material_override as ShaderMaterial
		material.set_shader_parameter("uColor", color)
		material.set_shader_parameter("uDetail", detail)
		material.set_shader_parameter("uDensity", density)
	reset()

func _process(delta: float) -> void:
	if auto_step:
		step(delta)

func attach_weapon(weapon: Node3D, base: Vector3 = Vector3.ZERO, tip: Vector3 = Vector3.UP) -> bool:
	if not is_instance_valid(weapon) or not base.is_finite() or not tip.is_finite() or base.distance_squared_to(tip) < 0.000000000001:
		return false
	_weapon = weapon
	_was_bound = true
	_base = base
	_tip = tip
	reset()
	return true

func detach_weapon() -> void:
	_weapon = null
	_was_bound = false
	stop()

func reset() -> void:
	_bases.clear()
	_tips.clear()
	_times.clear()
	_stop_at = -1.0
	elapsed = 0.0
	is_finished = false
	phase = &"active"
	visible = true
	_mesh.clear_surfaces()

func stop() -> void:
	if _stop_at >= 0.0 or is_finished:
		return
	_stop_at = elapsed
	phase = &"ending"

func step(delta: float) -> void:
	if is_finished or not is_finite(delta) or delta < 0.0:
		return
	elapsed += delta * clampf(speed, 0.25, 2.0)
	while not _times.is_empty() and elapsed - _times[0] > LIFETIME:
		_remove_first()
	if _stop_at < 0.0:
		if is_instance_valid(_weapon):
			var base: Vector3 = _weapon.to_global(_base)
			var tip: Vector3 = _weapon.to_global(_tip)
			var length: float = base.distance_to(tip)
			if length <= 0.000001 or not is_finite(length):
				_bases.clear()
				_tips.clear()
				_times.clear()
			else:
				var distance: float = 0.0 if _times.is_empty() else maxf(base.distance_to(_bases[-1]), tip.distance_to(_tips[-1]))
				if delta > 0.25 or distance > length * 3.0:
					_bases.clear()
					_tips.clear()
					_times.clear()
				if _times.is_empty() or distance * distance > length * length * 0.0000000001:
					if _times.size() == CAPACITY:
						_remove_first()
					_bases.append(base)
					_tips.append(tip)
					_times.append(elapsed)
		elif _was_bound:
			stop()
	_rebuild()
	if _stop_at >= 0.0 and elapsed - _stop_at >= LIFETIME - 0.000000001:
		is_finished = true
		phase = &"finished"
		visible = false
		finished.emit()
		if free_on_finish:
			queue_free()

func _remove_first() -> void:
	_bases.pop_front()
	_tips.pop_front()
	_times.pop_front()

func _rebuild() -> void:
	_mesh.clear_surfaces()
	if _times.size() < 2:
		return
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	var ages := PackedVector2Array()
	var indices := PackedInt32Array()
	for index: int in _times.size():
		vertices.append(to_local(_tips[index].lerp(_bases[index], coverage)))
		vertices.append(to_local(_tips[index]))
		uv.append(Vector2(float(index) / (CAPACITY - 1), 0))
		uv.append(Vector2(float(index) / (CAPACITY - 1), 1))
		var age: float = minf(1.0, (elapsed - _times[index]) / LIFETIME)
		ages.append(Vector2(age, 0))
		ages.append(Vector2(age, 0))
		if index < _times.size() - 1:
			var at: int = index * 2
			indices.append_array(PackedInt32Array([at, at + 1, at + 2, at + 1, at + 3, at + 2]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = ages
	arrays[Mesh.ARRAY_INDEX] = indices
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
