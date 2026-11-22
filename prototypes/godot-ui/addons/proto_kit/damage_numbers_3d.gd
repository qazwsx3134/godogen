extends Node3D
## Pooled cosmetic 3D numbers extracted from horde-25d, madara-survivor and luffy-marineford.
## Instance damage_numbers_3d.tscn; tune number_scene and exports in the editor.
## show_hit(world_position, amount, critical) -> accepted; never applies gameplay damage.
## Local placement is derived from world_position, including a transformed pool parent.
## Each pool owns its RNG. Set rng.seed for deterministic captures; never consumes global randf().
## Manual step(seconds) by default; enable auto_step OR step from the game's clock, never both.
## Capacity is fixed on _ready; changing pool_size later requires a new instance.

@export var number_scene: PackedScene
@export_range(1, 256) var pool_size: int = 32
@export_range(0.01, 10.0) var life: float = 0.6
@export var rise: float = 1.4
@export var min_shown: float = 1.0
@export var jitter: float = 0.3
@export var height: float = 0.2
@export var normal_color: Color = Color.WHITE
@export var critical_color: Color = Color(1.0, 0.85, 0.3)
@export var critical_scale: float = 1.4
@export var auto_step: bool = false

var rng := RandomNumberGenerator.new()
var _labels: Array[Label3D] = []
var _age: Array[float] = []
var _from: Array[Vector3] = []
var _base_scale: Array[Vector3] = []
var _alpha: Array[float] = []
var _next: int = 0


func _ready() -> void:
	# Saved representative label remains visible/editable before running.
	for child in get_children():
		if child is Label3D:
			child.visible = false
			if _labels.size() < maxi(1, pool_size):
				_register(child)
	while _labels.size() < maxi(1, pool_size) and number_scene != null:
		var instance: Node = number_scene.instantiate()
		if not instance is Label3D:
			instance.free()
			break
		add_child(instance)
		_register(instance)


func _register(label: Label3D) -> void:
	label.visible = false
	_labels.append(label)
	_age.append(life)
	_from.append(Vector3.ZERO)
	_base_scale.append(label.scale)
	_alpha.append(1.0)


## World metres; amount below min_shown, non-finite input or unavailable pool returns false.
## Ring reuse: when full, the oldest issued slot is reused. No allocation on accepted hits.
func show_hit(world_position: Vector3, amount: float, critical: bool = false) -> bool:
	if not is_inside_tree() or _labels.is_empty() or life <= 0.0:
		return false
	if not world_position.is_finite() or not is_finite(amount) or amount < min_shown:
		return false
	var i: int = _next
	_next = (_next + 1) % _labels.size()
	var label: Label3D = _labels[i]
	label.text = str(roundi(amount))
	label.modulate = critical_color if critical else normal_color
	_alpha[i] = label.modulate.a
	label.scale = _base_scale[i] * (critical_scale if critical else 1.0)
	_from[i] = world_position + Vector3(rng.randf_range(-absf(jitter), absf(jitter)), height, 0.0)
	label.position = to_local(_from[i])
	label.visible = true
	_age[i] = 0.0
	return true


## Nonnegative game seconds. Invalid delta is ignored; completed labels are hidden, not freed.
func step(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0:
		return
	if life <= 0.0:
		clear()
		return
	for i: int in _labels.size():
		if not _labels[i].visible:
			continue
		_age[i] += delta
		var t: float = _age[i] / life
		if t >= 1.0:
			_labels[i].visible = false
			continue
		_labels[i].position = to_local(_from[i] + Vector3.UP * rise * (1.0 - pow(1.0 - t, 2.0)))
		var color: Color = _labels[i].modulate
		var base_alpha: float = _alpha[i]
		color.a = base_alpha * (1.0 if t < 0.6 else (1.0 - t) / 0.4)
		_labels[i].modulate = color


func clear() -> void:
	for label: Label3D in _labels:
		label.visible = false
	_next = 0


func active_count() -> int:
	var count: int = 0
	for label: Label3D in _labels:
		if label.visible:
			count += 1
	return count


func _process(delta: float) -> void:
	if auto_step:
		step(delta)
