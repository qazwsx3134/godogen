class_name Decor
extends MultiMeshInstance3D
## Trees, rocks and flowers scattered over the endless ground. Placement is a hash of a lattice cell, so the same
## spot always grows the same thing; only the cells near the player are drawn, rebuilt when the player crosses a chunk.
## Shares the horde's two-surface mesh (shadow + billboard sprite) and materials.

@export var lattice: float = 3.5
@export var view_radius: float = 64.0
@export var chunk: float = 6.0
## Chance that a lattice cell holds something, and of what: atlas frames with their sizes and weights.
@export var density: float = 0.24
@export var frames: PackedInt32Array = PackedInt32Array([5, 6, 7])
@export var sizes: PackedFloat32Array = PackedFloat32Array([5.0, 2.0, 1.2])
@export var weights: PackedFloat32Array = PackedFloat32Array([0.25, 0.2, 0.55])
## Keep the start area clear (meters around the origin).
@export var clear_radius: float = 5.0

const STRIDE := 16

var _chunk := Vector2i(1 << 30, 0)
var _buf := PackedFloat32Array()
var _max: int = 0


func _ready() -> void:
	var span: int = int(ceil(view_radius * 2.0 / lattice)) + 1
	_max = span * span
	_buf.resize(_max * STRIDE)
	multimesh.instance_count = _max
	multimesh.visible_instance_count = 0


func follow(at: Vector2) -> void:
	var c := Vector2i(floori(at.x / chunk), floori(at.y / chunk))
	if c == _chunk:
		return
	_chunk = c
	_rebuild(at)


func _rebuild(at: Vector2) -> void:
	_buf.fill(0.0)
	var n: int = 0
	var total: float = 0.0
	for w: float in weights:
		total += w
	var r2: float = view_radius * view_radius
	var x0: int = floori((at.x - view_radius) / lattice)
	var x1: int = floori((at.x + view_radius) / lattice)
	var y0: int = floori((at.y - view_radius) / lattice)
	var y1: int = floori((at.y + view_radius) / lattice)
	for gy: int in range(y0, y1 + 1):
		for gx: int in range(x0, x1 + 1):
			var h: float = _hash(gx, gy, 0)
			if h > density:
				continue
			var p := Vector2((gx + 0.15 + 0.7 * _hash(gx, gy, 1)) * lattice, (gy + 0.15 + 0.7 * _hash(gx, gy, 2)) * lattice)
			if p.distance_squared_to(at) > r2 or p.length() < clear_radius or n >= _max:
				continue
			var pick: float = _hash(gx, gy, 3) * total
			var k: int = 0
			while k < weights.size() - 1 and pick > weights[k]:
				pick -= weights[k]
				k += 1
			var s: float = sizes[k] * (0.85 + 0.3 * _hash(gx, gy, 4))
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
