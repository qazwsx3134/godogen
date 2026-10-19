class_name Horde
extends MultiMeshInstance3D
## The enemy horde. Enemies are not nodes: their state lives in packed arrays and all of them are drawn by this one
## MultiMesh (two draw calls: shadows and sprites), which is what lets a phone carry hundreds of them.
##
## Each frame the owner calls, in order:
##   step(dt, target, target_radius)   move, push apart, touch the player; returns the contact damage to apply
##   ...weapons query and hurt enemies (damage_circle, hit_first, nearest, hurt)...
##   flush_dead()                      emits `killed` for the frame's kills and removes them
##   commit()                          uploads the instance buffer
##
## The MultiMesh mesh has two surfaces sharing one instance buffer: 0 the blob shadow, 1 the billboard sprite.
## Instance custom data is (atlas frame, flash 0..1, facing +-1, walk phase), read by addons/proto_kit/sprite3d.gdshader.

signal killed(at: Vector3, def: EnemyDef)
signal damaged(at: Vector3, amount: float)

@export var defs: Array[EnemyDef] = []
@export var max_enemies: int = 800
## Spatial hash: a window of grid_cells x grid_cells cells of cell_size meters, centered on the target each frame.
## Enemies outside the window still chase, but do not separate and cannot be hit (they are far off screen).
@export var cell_size: float = 1.8
@export var grid_cells: int = 64
## How hard crowded enemies push apart (m/s at full crowding).
@export var separation: float = 2.4
@export var knockback_decay: float = 9.0
@export var flash_time: float = 0.12
## An enemy this far from the target is moved to the opposite side, back into play.
@export var recycle_distance: float = 52.0
@export var recycle_radius: float = 30.0
## Walk bob cycles per meter walked.
@export var steps_per_meter: float = 1.6

const STRIDE := 16

var count: int = 0

var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _hp := PackedFloat32Array()
var _kind := PackedInt32Array()
var _flash := PackedFloat32Array()
var _phase := PackedFloat32Array()
var _facing := PackedFloat32Array()
var _uid := PackedInt32Array()
var _dead := PackedByteArray()
var _deaths := PackedInt32Array()
var _next_uid: int = 1
var _buf := PackedFloat32Array()

var _k_speed := PackedFloat32Array()
var _k_radius := PackedFloat32Array()
var _k_damage := PackedFloat32Array()
var _k_resist := PackedFloat32Array()
var _k_frame := PackedFloat32Array()
var _k_size := PackedFloat32Array()

var _cell := PackedInt32Array()
var _cnt := PackedInt32Array()
var _start := PackedInt32Array()
var _order := PackedInt32Array()
var _sum := PackedVector2Array()
var _origin := Vector2.ZERO


func _ready() -> void:
	_pos.resize(max_enemies)
	_vel.resize(max_enemies)
	_hp.resize(max_enemies)
	_kind.resize(max_enemies)
	_flash.resize(max_enemies)
	_phase.resize(max_enemies)
	_facing.resize(max_enemies)
	_uid.resize(max_enemies)
	_dead.resize(max_enemies)
	_cell.resize(max_enemies)
	_order.resize(max_enemies)
	var cells: int = grid_cells * grid_cells
	_cnt.resize(cells)
	_sum.resize(cells)
	_start.resize(cells + 1)
	_buf.resize(max_enemies * STRIDE)
	_buf.fill(0.0)
	for def: EnemyDef in defs:
		_k_speed.append(def.speed)
		_k_radius.append(def.radius)
		_k_damage.append(def.damage)
		_k_resist.append(def.knockback_resist)
		_k_frame.append(float(def.frame))
		_k_size.append(def.size)
	# The saved MultiMesh only carries the format; the instance count is a runtime budget.
	multimesh.instance_count = max_enemies
	multimesh.visible_instance_count = 0


func kind_index(def: EnemyDef) -> int:
	return defs.find(def)


## Adds an enemy at a ground position (x, z). Returns its index, or -1 when the horde is full.
func spawn(kind: int, at: Vector2, hp_scale: float = 1.0) -> int:
	if count >= max_enemies:
		return -1
	var i: int = count
	count += 1
	_pos[i] = at
	_vel[i] = Vector2.ZERO
	_hp[i] = defs[kind].hp * hp_scale
	_kind[i] = kind
	_flash[i] = 0.0
	_phase[i] = randf() * TAU
	_facing[i] = 1.0
	_uid[i] = _next_uid
	_next_uid += 1
	_dead[i] = 0
	_cell[i] = -1
	var b: int = i * STRIDE
	var s: float = _k_size[kind]
	_buf[b] = s
	_buf[b + 5] = s
	_buf[b + 10] = s
	_buf[b + 12] = _k_frame[kind]
	return i


func step(dt: float, target: Vector2, target_radius: float) -> float:
	_rebuild_grid(target)
	var touch: float = 0.0
	var g: int = grid_cells
	var reach2: float = cell_size * cell_size
	var decay: float = exp(-knockback_decay * dt)
	var fade: float = dt / flash_time
	for i: int in count:
		var p: Vector2 = _pos[i]
		var k: int = _kind[i]
		var to: Vector2 = target - p
		var dist: float = to.length()
		if dist > recycle_distance:
			p = target + to / dist * recycle_radius
			_pos[i] = p
			_vel[i] = Vector2.ZERO
			continue
		var dir: Vector2 = to / dist if dist > 0.001 else Vector2.ZERO
		var move: Vector2 = dir * _k_speed[k]
		var c: int = _cell[i]
		if c >= 0:
			var cx: int = c % g
			var cy: int = c / g
			var push := Vector2.ZERO
			for yy: int in range(maxi(cy - 1, 0), mini(cy + 2, g)):
				var row: int = yy * g
				for xx: int in range(maxi(cx - 1, 0), mini(cx + 2, g)):
					var n: int = row + xx
					var others: int = _cnt[n]
					if others == 0:
						continue
					var away: Vector2 = p - _sum[n] / others
					var d2: float = away.length_squared()
					if d2 < reach2 and d2 > 0.0001:
						push += away * (others / sqrt(d2))
			move += push.limit_length(4.0) * separation
		var reach: float = _k_radius[k] + target_radius
		if dist < reach:
			p -= dir * (reach - dist)
			touch = maxf(touch, _k_damage[k])
		var v: Vector2 = _vel[i] * decay
		_vel[i] = v
		var step_v: Vector2 = (move + v) * dt
		p += step_v
		_pos[i] = p
		if absf(dir.x) > 0.2:
			_facing[i] = 1.0 if dir.x > 0.0 else -1.0
		_phase[i] += step_v.length() * steps_per_meter * TAU
		_flash[i] = maxf(_flash[i] - fade, 0.0)
	return touch


## Damages every enemy whose body overlaps the circle. Knockback pushes away from the center. Returns the hit count.
func damage_circle(center: Vector2, radius: float, amount: float, knockback: float) -> int:
	var hits: int = 0
	var inv: float = 1.0 / cell_size
	var g: int = grid_cells
	var reach: float = radius + 1.0
	var x0: int = maxi(int((center.x - reach - _origin.x) * inv), 0)
	var x1: int = mini(int((center.x + reach - _origin.x) * inv), g - 1)
	var y0: int = maxi(int((center.y - reach - _origin.y) * inv), 0)
	var y1: int = mini(int((center.y + reach - _origin.y) * inv), g - 1)
	for yy: int in range(y0, y1 + 1):
		for xx: int in range(x0, x1 + 1):
			var n: int = yy * g + xx
			for o: int in range(_start[n], _start[n + 1]):
				var j: int = _order[o]
				if _dead[j] == 1:
					continue
				var away: Vector2 = _pos[j] - center
				var r: float = radius + _k_radius[_kind[j]]
				if away.length_squared() <= r * r:
					hurt(j, amount, away.normalized() * knockback)
					hits += 1
	return hits


## The first living enemy overlapping the circle whose uid is not `skip_uid`, or -1. Used by projectiles.
func hit_first(center: Vector2, radius: float, skip_uid: int) -> int:
	var inv: float = 1.0 / cell_size
	var g: int = grid_cells
	var gx: int = int((center.x - _origin.x) * inv)
	var gy: int = int((center.y - _origin.y) * inv)
	for yy: int in range(maxi(gy - 1, 0), mini(gy + 2, g)):
		for xx: int in range(maxi(gx - 1, 0), mini(gx + 2, g)):
			var n: int = yy * g + xx
			for o: int in range(_start[n], _start[n + 1]):
				var j: int = _order[o]
				if _dead[j] == 1 or _uid[j] == skip_uid:
					continue
				var r: float = radius + _k_radius[_kind[j]]
				if _pos[j].distance_squared_to(center) <= r * r:
					return j
	return -1


## Index of the closest living enemy within max_distance, or -1.
func nearest(center: Vector2, max_distance: float) -> int:
	var best: int = -1
	var best_d2: float = max_distance * max_distance
	for i: int in count:
		if _dead[i] == 1:
			continue
		var d2: float = _pos[i].distance_squared_to(center)
		if d2 < best_d2:
			best_d2 = d2
			best = i
	return best


func hurt(i: int, amount: float, push: Vector2) -> void:
	if _dead[i] == 1:
		return
	_hp[i] -= amount
	_flash[i] = 1.0
	_vel[i] += push * (1.0 - _k_resist[_kind[i]])
	var p: Vector2 = _pos[i]
	damaged.emit(Vector3(p.x, _k_size[_kind[i]] * 0.6, p.y), amount)
	if _hp[i] <= 0.0:
		_dead[i] = 1
		_deaths.append(i)


func position_of(i: int) -> Vector2:
	return _pos[i]


func uid_of(i: int) -> int:
	return _uid[i]


func is_alive(i: int) -> bool:
	return i >= 0 and i < count and _dead[i] == 0


## Sum of 1/d pushes away from enemies within `radius`: which way is safest. Used by the QA autopilot.
func threat(center: Vector2, radius: float) -> Vector2:
	var away := Vector2.ZERO
	var r2: float = radius * radius
	for i: int in count:
		var d: Vector2 = center - _pos[i]
		var d2: float = d.length_squared()
		if d2 < r2 and d2 > 0.0001:
			away += d / d2
	return away


## Emits `killed` for this frame's kills and removes them (swap with the last enemy).
func flush_dead() -> void:
	if _deaths.is_empty():
		return
	_deaths.sort()
	for n: int in range(_deaths.size() - 1, -1, -1):
		var i: int = _deaths[n]
		var p: Vector2 = _pos[i]
		killed.emit(Vector3(p.x, 0.0, p.y), defs[_kind[i]])
		_remove(i)
	_deaths.clear()


func clear() -> void:
	count = 0
	_deaths.clear()
	multimesh.visible_instance_count = 0


func commit() -> void:
	for i: int in count:
		var b: int = i * STRIDE
		var p: Vector2 = _pos[i]
		_buf[b + 3] = p.x
		_buf[b + 11] = p.y
		_buf[b + 13] = _flash[i]
		_buf[b + 14] = _facing[i]
		_buf[b + 15] = _phase[i]
	RenderingServer.multimesh_set_buffer(multimesh.get_rid(), _buf)
	multimesh.visible_instance_count = count


func _remove(i: int) -> void:
	var last: int = count - 1
	if i != last:
		_pos[i] = _pos[last]
		_vel[i] = _vel[last]
		_hp[i] = _hp[last]
		_kind[i] = _kind[last]
		_flash[i] = _flash[last]
		_phase[i] = _phase[last]
		_facing[i] = _facing[last]
		_uid[i] = _uid[last]
		_dead[i] = _dead[last]
		_cell[i] = -1
		var a: int = i * STRIDE
		var b: int = last * STRIDE
		_buf[a] = _buf[b]
		_buf[a + 5] = _buf[b + 5]
		_buf[a + 10] = _buf[b + 10]
		_buf[a + 12] = _buf[b + 12]
	count = last


## Counting sort of enemies into cells: _start[n].._start[n + 1] indexes _order for cell n.
func _rebuild_grid(center: Vector2) -> void:
	var g: int = grid_cells
	var half: float = g * cell_size * 0.5
	_origin = center - Vector2(half, half)
	_cnt.fill(0)
	_sum.fill(Vector2.ZERO)
	var inv: float = 1.0 / cell_size
	for i: int in count:
		var p: Vector2 = _pos[i]
		var gx: int = int((p.x - _origin.x) * inv)
		var gy: int = int((p.y - _origin.y) * inv)
		if gx < 0 or gy < 0 or gx >= g or gy >= g:
			_cell[i] = -1
			continue
		var c: int = gy * g + gx
		_cell[i] = c
		_cnt[c] += 1
		_sum[c] += p
	var total: int = 0
	for c: int in g * g:
		total += _cnt[c]
		_start[c] = total
	_start[g * g] = total
	for i: int in count:
		var c: int = _cell[i]
		if c >= 0:
			_start[c] -= 1
			_order[_start[c]] = i
