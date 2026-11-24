extends MultiMeshInstance3D
## A fixed-size pool of small things that fly, bounce and stay on the floor: shell casings,
## broken parts, and flat stains (stamp()). One MultiMesh = one draw call however many lie
## around; when full, the oldest piece is reused. Flight is a few lines of CPU per moving
## piece and one floor ray per spawn; pieces at rest cost nothing.
## `const Debris3D = preload("res://addons/proto_kit/debris3d.gd")`
##
##   # scene: MultiMeshInstance3D (this script, top_level) with a small mesh assigned in `piece_mesh`
##   $Shells.spawn(breech_pos, right * 4.0 + Vector3.UP * 3.0)   # ejected casing
##   $Parts.spawn(hit_pos, -dir * 5.0 + Vector3.UP * 4.0, 1.4)   # chunk knocked off a target
##   $Stains.stamp(hit_floor_pos, 1.8)                          # oil splat, flat on the floor
##
## `landed(at, speed)` fires on every bounce harder than 2.5 m/s (casing clinks, part clunks).
##
## The MultiMesh is built in _ready from `piece_mesh` and `capacity`, so nothing is baked into
## the scene (a headless save would drop the instance buffer anyway).

@export var piece_mesh: Mesh
@export var capacity := 64
@export var gravity := 22.0
## Fraction of speed kept on each bounce; under 2 m/s the piece settles.
@export var bounce := 0.3
@export_flags_3d_physics var floor_mask := 1

signal landed(at: Vector3, speed: float)

var _pos: PackedVector3Array
var _vel: PackedVector3Array
var _rot: PackedVector3Array
var _spin: PackedVector3Array
var _scale: PackedFloat32Array
var _floor: PackedFloat32Array
var _moving: PackedByteArray
var _next := 0
var _active := 0


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = piece_mesh
	mm.instance_count = capacity
	mm.visible_instance_count = 0
	multimesh = mm
	_pos.resize(capacity); _vel.resize(capacity); _rot.resize(capacity); _spin.resize(capacity)
	_scale.resize(capacity); _floor.resize(capacity); _moving.resize(capacity)


## Throws a piece from `at` with `velocity` (world). Returns its slot.
func spawn(at: Vector3, velocity: Vector3, size: float = 1.0) -> int:
	var i := _take()
	_pos[i] = at
	_vel[i] = velocity
	_rot[i] = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	_spin[i] = Vector3(randf_range(-14, 14), randf_range(-14, 14), randf_range(-14, 14))
	_scale[i] = size * randf_range(0.8, 1.2)
	_floor[i] = _floor_below(at)
	_moving[i] = 1
	_write(i)
	set_process(true)
	return i


## Lays a flat piece (a stain) on the floor under `at`, randomly turned.
func stamp(at: Vector3, size: float = 1.0) -> int:
	var i := _take()
	_pos[i] = Vector3(at.x, _floor_below(at) + 0.03, at.z)
	_vel[i] = Vector3.ZERO
	_rot[i] = Vector3(0.0, randf() * TAU, 0.0)
	_scale[i] = size * randf_range(0.75, 1.25)
	_moving[i] = 0
	_write(i)
	return i


func active_count() -> int:
	return _active


func _take() -> int:
	var i := _next
	_next = (_next + 1) % capacity
	_active = mini(_active + 1, capacity)
	multimesh.visible_instance_count = _active
	return i


func _floor_below(at: Vector3) -> float:
	var hit := get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at + Vector3.DOWN * 40.0, floor_mask))
	return hit.position.y if not hit.is_empty() else at.y - 2.0


func _process(delta: float) -> void:
	var any := false
	for i in _active:
		if not _moving[i]: continue
		any = true
		var v := _vel[i]
		v.y -= gravity * delta
		var p := _pos[i] + v * delta
		_rot[i] += _spin[i] * delta
		if p.y <= _floor[i] and v.y < 0.0:
			p.y = _floor[i]
			if -v.y > 2.5: landed.emit(p, -v.y)
			v = Vector3(v.x, -v.y, v.z) * bounce
			_spin[i] *= bounce
			if v.length() < 2.0:
				v = Vector3.ZERO
				_moving[i] = 0
				_rot[i] = Vector3(0.0, _rot[i].y, PI * 0.5 * float(randi() % 2))  # lies on its side or flat
		_pos[i] = p
		_vel[i] = v
		_write(i)
	if not any: set_process(false)


func _write(i: int) -> void:
	var basis := Basis.from_euler(_rot[i]).scaled(Vector3.ONE * _scale[i])
	multimesh.set_instance_transform(i, Transform3D(basis, _pos[i]))
