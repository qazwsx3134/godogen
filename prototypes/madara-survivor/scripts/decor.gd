class_name Decor
extends MultiMeshInstance3D
## The wind-eroded desert: hoodoo pillars, boulders and dry shrubs scattered over the endless sand, and the collision
## circles of the ones that block. Placement is a hash of a lattice cell, so the same spot always holds the same rock
## and what you see is exactly what blocks. Only the cells near the player are drawn and indexed; both are rebuilt
## when the player crosses a chunk. Uses the prop mesh (shadow + upright billboard with see-through).

@export var lattice: float = 7.0
@export var view_radius: float = 70.0
@export var chunk: float = 8.0
## Chance that a lattice cell holds something, and what: atlas frames, sizes (m), weights, collision radii (0 = walk
## through). Index 0 hoodoo pillar, 1 boulder, 2 dry shrub.
@export var density: float = 0.3
@export var frames: PackedInt32Array = PackedInt32Array([5, 6, 7])
@export var sizes: PackedFloat32Array = PackedFloat32Array([7.0, 3.0, 1.6])
@export var weights: PackedFloat32Array = PackedFloat32Array([0.3, 0.3, 0.4])
@export var radii: PackedFloat32Array = PackedFloat32Array([1.35, 1.0, 0.0])
## Keep the start area clear (meters around the origin).
@export var clear_radius: float = 9.0

const STRIDE := 16

var _chunk := Vector2i(1 << 30, 0)
var _buf := PackedFloat32Array()
var _max: int = 0
# Collision index over the drawn window: one rock per lattice cell at most.
var _span: int = 0
var _cell0 := Vector2i.ZERO
var _rock_pos := PackedVector2Array()
var _rock_r := PackedFloat32Array()


func _ready() -> void:
	_span = int(ceil(view_radius * 2.0 / lattice)) + 3
	_max = _span * _span
	_buf.resize(_max * STRIDE)
	_rock_pos.resize(_max)
	_rock_r.resize(_max)
	multimesh.instance_count = _max
	multimesh.visible_instance_count = 0


func follow(at: Vector2) -> void:
	var c := Vector2i(floori(at.x / chunk), floori(at.y / chunk))
	if c == _chunk:
		return
	_chunk = c
	_rebuild(at)


## Moves a circle at `p` with radius `r` out of any rock it overlaps. Returns `p` unchanged when it is clear.
func push_out(p: Vector2, r: float) -> Vector2:
	var gx: int = floori(p.x / lattice) - _cell0.x
	var gy: int = floori(p.y / lattice) - _cell0.y
	for yy: int in range(maxi(gy - 1, 0), mini(gy + 2, _span)):
		for xx: int in range(maxi(gx - 1, 0), mini(gx + 2, _span)):
			var n: int = yy * _span + xx
			var rr: float = _rock_r[n]
			if rr <= 0.0:
				continue
			var away: Vector2 = p - _rock_pos[n]
			var reach: float = rr + r
			var d2: float = away.length_squared()
			if d2 < reach * reach:
				var d: float = sqrt(d2)
				p = _rock_pos[n] + (away / d if d > 0.001 else Vector2.RIGHT) * reach
	return p


func blocking_rocks() -> int:
	var n: int = 0
	for r: float in _rock_r:
		if r > 0.0:
			n += 1
	return n


func _rebuild(at: Vector2) -> void:
	_buf.fill(0.0)
	_rock_r.fill(0.0)
	var n: int = 0
	var total: float = 0.0
	for w: float in weights:
		total += w
	var r2: float = view_radius * view_radius
	_cell0 = Vector2i(floori((at.x - view_radius) / lattice) - 1, floori((at.y - view_radius) / lattice) - 1)
	for yy: int in _span:
		for xx: int in _span:
			var gx: int = _cell0.x + xx
			var gy: int = _cell0.y + yy
			if _hash(gx, gy, 0) > density:
				continue
			var p := Vector2((gx + 0.2 + 0.6 * _hash(gx, gy, 1)) * lattice, (gy + 0.2 + 0.6 * _hash(gx, gy, 2)) * lattice)
			if p.length() < clear_radius:
				continue
			var pick: float = _hash(gx, gy, 3) * total
			var k: int = 0
			while k < weights.size() - 1 and pick > weights[k]:
				pick -= weights[k]
				k += 1
			var scale: float = 0.85 + 0.3 * _hash(gx, gy, 4)
			var cell: int = yy * _span + xx
			_rock_pos[cell] = p
			_rock_r[cell] = radii[k] * scale
			if p.distance_squared_to(at) > r2 or n >= _max:
				continue
			var s: float = sizes[k] * scale
			var b: int = n * STRIDE
			_buf[b] = s
			_buf[b + 3] = p.x
			_buf[b + 5] = s
			_buf[b + 10] = s
			_buf[b + 11] = p.y
			_buf[b + 12] = float(frames[k])
			_buf[b + 14] = 1.0 if _hash(gx, gy, 5) > 0.5 else -1.0
			n += 1
	RenderingServer.multimesh_set_buffer(multimesh.get_rid(), _buf)
	multimesh.visible_instance_count = n


static func _hash(x: int, y: int, salt: int) -> float:
	var h: int = (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFF) / 65535.0
