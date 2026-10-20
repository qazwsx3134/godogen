class_name FistStreak
extends Node3D
## Gomu Gomu Pistol afterimages: a small pool of arm quads (the children), each thrown from the shoulder toward the
## punch, turned around its own length to face the camera, fading out over `life` seconds of game time.

@export var life: float = 0.2
@export var shoulder_height: float = 1.1
@export var width: float = 0.42
## Texels per meter of the quad (the characters' pixel density; main sets it from the sprite set).
@export var px_per_m: float = 40.0

var _age := PackedFloat32Array()
var _next: int = 0


func _ready() -> void:
	for arm: Node in get_children():
		(arm as MeshInstance3D).visible = false
		# Own material per arm: each fades on its own.
		var mi := arm as MeshInstance3D
		mi.material_override = mi.material_override.duplicate()
		_age.append(life)


## Throws an arm `length` meters from `from` (feet position) along ground direction `dir`.
func play(from: Vector3, dir: Vector2, length: float) -> void:
	if get_child_count() == 0 or dir == Vector2.ZERO:
		return
	var arm := get_child(_next) as MeshInstance3D
	_age[_next] = 0.0
	_next = (_next + 1) % get_child_count()
	var x := Vector3(dir.x, 0.0, dir.y).normalized()
	var mid: Vector3 = from + Vector3(0.0, shoulder_height, 0.0) + x * length * 0.5
	var camera: Camera3D = get_viewport().get_camera_3d()
	var to_camera: Vector3 = (camera.global_position - mid).normalized() if camera else Vector3.UP
	var z: Vector3 = (to_camera - x * to_camera.dot(x)).normalized()
	var y: Vector3 = z.cross(x)
	arm.global_transform = Transform3D(Basis(x * length, y * width, z), mid)
	var material := arm.material_override as ShaderMaterial
	material.set_shader_parameter(&"texels", Vector2(length, width) * px_per_m)
	material.set_shader_parameter(&"progress", 0.0)
	arm.visible = true


func step(dt: float) -> void:
	for i: int in _age.size():
		if _age[i] >= life:
			continue
		_age[i] += dt
		var arm := get_child(i) as MeshInstance3D
		arm.visible = _age[i] < life
		(arm.material_override as ShaderMaterial).set_shader_parameter(&"progress", minf(_age[i] / life, 1.0))
