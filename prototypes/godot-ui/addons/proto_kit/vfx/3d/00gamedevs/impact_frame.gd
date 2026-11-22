extends CanvasLayer
## Native 00GameDevs impact-frame, MIT. Add to the target viewport then trigger on confirmed hits.
## UV coordinates use Godot top-left origin. Optional subject_mask must match viewport/camera/occlusion.
## No automatic subject selection or gameplay event binding is performed.
signal finished
const SEQUENCE := [0, 1, 2, 5, 6, 7, 8]
const DURATIONS := [4.0 / 60.0, 4.0 / 60.0, 4.0 / 60.0, 2.0 / 60.0, 2.0 / 60.0, 4.0 / 60.0, 4.0 / 60.0]
const INVERT := [1.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0]
const STARS := [
	[Vector4(-0.5,0.3,1.25,1.6),Vector4(0.28,0.22,0.45,0.55/0.45),Vector4(-0.12,-0.34,0.45,0.55/0.45)],
	[Vector4(-0.5,0.32,1.25,1.6),Vector4(0.36,0.35,0.45,0.55/0.45),Vector4(-0.12,-0.36,0.45,0.55/0.45)],
	[Vector4(-0.48,-0.27,1.25,1.6),Vector4(0.34,0.27,0.65,0.8/0.65),Vector4(-0.19,0.38,0.45,0.55/0.45),Vector4(0.3,-0.23,0.45,0.55/0.45)],
	[], [Vector4(0,0,0.38,0.4/0.38)], [], []
]
@export var auto_step: bool = true
@export_range(0.0, 1.0) var threshold: float = 0.5
@export_range(0.0, 1.0) var softness: float = 0.05
@export_range(0.0, 1.0) var stroke_length: float = 0.65
@export_range(0.0, 1.0) var ink_density: float = 0.65
@export_range(0.0, 1.0) var background_suppression: float = 0.9
@export_range(0.0, 3.0) var star_size: float = 1.0
@export_range(0.0, 3.0) var star_strength: float = 1.0
@export var subject_mask: Texture2D
@onready var overlay: ColorRect = %Overlay
var elapsed: float = 0.0
var active: bool = false
var is_finished: bool = true
var duration: float = 24.0 / 60.0
var current_pose: int = 0
var _material: ShaderMaterial
var _center := Vector2(0.5, 0.5)
var _direction := Vector2.ZERO

func _ready() -> void:
	_material = overlay.material as ShaderMaterial
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sync()

func _process(delta: float) -> void:
	if auto_step:
		step(delta)

func trigger(center: Vector2 = Vector2(0.5, 0.5), attack_direction: Vector2 = Vector2.ZERO) -> bool:
	if active or not center.is_finite() or not attack_direction.is_finite():
		return false
	_center = center.clamp(Vector2.ZERO, Vector2.ONE)
	_direction = attack_direction.normalized() if attack_direction.length_squared() > 0.0 else Vector2.ZERO
	elapsed = 0.0
	active = true
	is_finished = false
	_sync()
	return true

func reset() -> void:
	elapsed = 0.0
	active = false
	is_finished = true
	_sync()

func step(delta: float) -> void:
	if not active or not is_finite(delta) or delta < 0.0:
		return
	elapsed = minf(duration, elapsed + delta)
	if elapsed + 0.000000001 >= duration:
		elapsed = duration
		active = false
		is_finished = true
		_sync()
		finished.emit()
	else:
		_sync()

func set_subject_mask(mask: Texture2D) -> void:
	subject_mask = mask
	_sync()

func _sync() -> void:
	if _material == null:
		return
	overlay.visible = active
	_material.set_shader_parameter("intensity", 1.0 if active else 0.0)
	if not active:
		return
	var sum: float = 0.0
	var index: int = 0
	for item: int in DURATIONS.size():
		sum += DURATIONS[item]
		if elapsed + 0.0000000001 < sum:
			index = item
			break
	current_pose = SEQUENCE[index]
	_material.set_shader_parameter("frame", float(current_pose))
	_material.set_shader_parameter("inverted", INVERT[index])
	_material.set_shader_parameter("threshold", threshold)
	_material.set_shader_parameter("softness", softness)
	_material.set_shader_parameter("strokeLength", stroke_length)
	_material.set_shader_parameter("inkDensity", ink_density)
	_material.set_shader_parameter("backgroundSuppression", background_suppression)
	_material.set_shader_parameter("starSize", star_size)
	_material.set_shader_parameter("starStrength", star_strength)
	# Original GLSL is bottom-left UV. Godot's screen sample uses top-left UV;
	# convert the host coordinates consistently at the boundary.
	_material.set_shader_parameter("center", Vector2(_center.x, 1.0 - _center.y))
	_material.set_shader_parameter("attackDirection", Vector2(_direction.x, -_direction.y))
	_material.set_shader_parameter("resolution", Vector2(overlay.get_viewport_rect().size))
	_material.set_shader_parameter("hasSubject", 1.0 if subject_mask != null else 0.0)
	_material.set_shader_parameter("tSubject", subject_mask)
	var stars := PackedVector4Array()
	var reversed := PackedFloat32Array([0, 0, 0, 0])
	for star: int in 4:
		stars.append(STARS[index][star] if star < STARS[index].size() else Vector4(0, 0, 0, 1))
		if index == 1 and star == 1:
			reversed[star] = 1.0
	_material.set_shader_parameter("stars", stars)
	_material.set_shader_parameter("reverseStars", reversed)
