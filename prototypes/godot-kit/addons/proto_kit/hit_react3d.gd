extends Node
## Hit reaction for any 3D target: white flash, squash, visual knockback, and a death throw.
## Without these the player cannot tell a shot landed. It only moves the `visual` node
## (usually the model under a body), never the body, so physics and AI are untouched; push
## the body yourself when the target is light enough (e.g. move_and_collide(dir * 0.3)).
## `const HitReact3D = preload("res://addons/proto_kit/hit_react3d.gd")`
##
##   # scene: Scout (CharacterBody3D) > Model, HitReact (this script, visual = ../Model)
##   $HitReact.react(bullet_direction)            # every hit: flash + squash + recoil, same frame
##   $HitReact.react(dir, 2.0)                    # a heavier hit
##   $HitReact.throw(dir * 9.0 + Vector3.UP * 7.0)  # death: the model flies, spins and lands
##
## The flash is a translucent warm material_overlay on every GeometryInstance3D under `visual`
## (skinned meshes included) that fades out: the target's own texture shows through, and a white
## hull is tinted rather than blown out (additive would saturate it). The fade steps are a few
## shared materials, so no material per target. A throw keeps the
## model where it lands (y of the floor under it, found by one ray), it is not a ragdoll.

## The node to flash, squash and push: normally the model, not the physics body.
@export var visual: NodePath = ^"../Model"
## Laid over the target at the moment of the hit (alpha = strength), then fades to nothing.
@export var flash_color := Color(1.0, 0.6, 0.25, 0.5)
@export var flash_time := 0.12
## Fractional squash at strength 1: wider and flatter, then springs back.
@export var squash := 0.16
## Visual recoil distance (m) at strength 1, along the hit direction.
@export var knock_distance := 0.35
@export var recover_time := 0.16
## Physics layers the thrown model lands on.
@export_flags_3d_physics var floor_mask := 1

const FLASH_STEPS := 4
static var _flash_materials: Array[StandardMaterial3D] = []

var _visual: Node3D
var _rest_scale := Vector3.ONE
var _rest_position := Vector3.ZERO
var _meshes: Array[GeometryInstance3D] = []
var _flash_left := 0.0
var _react_left := 0.0
var _strength := 1.0
var _knock := Vector3.ZERO  # in the visual's parent space
var _throw_velocity := Vector3.ZERO
var _throw_spin := Vector3.ZERO
var _floor_y := -INF
var _thrown := false


func _ready() -> void:
	_visual = get_node_or_null(visual) as Node3D
	if _visual == null:
		push_warning("HitReact3D: visual not found: %s" % visual)
		set_process(false)
		return
	_rest_scale = _visual.scale
	_rest_position = _visual.position
	for node: Node in _visual.find_children("*", "GeometryInstance3D", true, false):
		_meshes.append(node as GeometryInstance3D)
	if _visual is GeometryInstance3D:
		_meshes.append(_visual as GeometryInstance3D)
	if _flash_materials.is_empty():
		for step in FLASH_STEPS:  # brightest first
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color = Color(flash_color, flash_color.a * float(FLASH_STEPS - step) / FLASH_STEPS)
			_flash_materials.append(m)


## Flash, squash and recoil now (call it on the frame the hit lands). direction: where the
## shot was travelling, world space. strength scales squash and recoil (kill shots: 2-3).
func react(direction: Vector3 = Vector3.ZERO, strength: float = 1.0) -> void:
	if _visual == null or _thrown: return
	_flash_left = flash_time
	_set_flash(0)
	_react_left = recover_time
	_strength = strength
	var parent := _visual.get_parent() as Node3D
	var local := parent.global_basis.inverse() * direction if parent else direction
	_knock = Vector3(local.x, 0.0, local.z).normalized() * knock_distance * strength if local.length() > 0.001 else Vector3.ZERO
	_apply(1.0)


## Death throw: the visual flies with `velocity` (world), tumbles, and rests on the floor.
func throw(velocity: Vector3, spin: Vector3 = Vector3(5.0, 2.0, 7.0)) -> void:
	if _visual == null: return
	react(velocity, 2.5)
	_thrown = true
	_throw_velocity = velocity
	_throw_spin = spin
	var space := _visual.get_world_3d().direct_space_state
	var from := _visual.global_position + Vector3.UP * 2.0
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 60.0, floor_mask))
	_floor_y = hit.position.y if not hit.is_empty() else _visual.global_position.y - 1.0


func is_reacting() -> bool:
	return _flash_left > 0.0 or _react_left > 0.0


func _process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		_set_flash(-1 if _flash_left <= 0.0 else mini(FLASH_STEPS - 1, int((1.0 - _flash_left / flash_time) * FLASH_STEPS)))
	if _thrown:
		_throw_step(delta)
		return
	if _react_left > 0.0:
		_react_left = maxf(0.0, _react_left - delta)
		_apply(_react_left / recover_time)


## t = 1 at the hit, 0 at rest. Ease-out so the hit snaps and the recovery glides.
func _apply(t: float) -> void:
	var k := t * t
	var s := squash * _strength * k
	_visual.scale = _rest_scale * Vector3(1.0 + s, 1.0 - s, 1.0 + s)
	_visual.position = _rest_position + _knock * k


func _throw_step(delta: float) -> void:
	if _throw_velocity == Vector3.ZERO: return
	_throw_velocity.y -= 22.0 * delta
	_visual.global_position += _throw_velocity * delta
	_visual.rotation += _throw_spin * delta
	if _visual.global_position.y <= _floor_y and _throw_velocity.y < 0.0:
		_visual.global_position.y = _floor_y
		if _throw_velocity.length() < 3.0:
			_throw_velocity = Vector3.ZERO  # rests where it fell
			_visual.scale = _rest_scale
		else:
			_throw_velocity = Vector3(_throw_velocity.x * 0.35, -_throw_velocity.y * 0.25, _throw_velocity.z * 0.35)
			_throw_spin *= 0.3


## step 0 = brightest, -1 = off.
func _set_flash(step: int) -> void:
	var material: Material = _flash_materials[step] if step >= 0 else null
	for mesh: GeometryInstance3D in _meshes:
		if is_instance_valid(mesh) and mesh.material_overlay != material: mesh.material_overlay = material
