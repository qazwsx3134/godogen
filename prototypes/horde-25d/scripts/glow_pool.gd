class_name GlowPool
extends MultiMeshInstance3D
## Every additive pixel effect of a frame in one MultiMesh (one draw call): projectiles, orbs, sparks, puffs.
## Systems call add() for what they want drawn this frame; the owner calls commit() once at the end of the frame.
## Shapes are drawn by fx_glow.gdshader: 0 dot, 1 ring, 2 spark.

const DOT := 0.0
const RING := 1.0
const SPARK := 2.0
## Transform (12 floats), color (4), custom (4), in that order.
const STRIDE := 20

@export var max_instances: int = 768

var _buf := PackedFloat32Array()
var _n: int = 0
## How many effects the last commit() drew.
var last_drawn: int = 0


func _ready() -> void:
	_buf.resize(max_instances * STRIDE)
	_buf.fill(0.0)
	multimesh.instance_count = max_instances
	multimesh.visible_instance_count = 0


func add(at: Vector3, size: float, color: Color, shape: float, progress: float = 0.0) -> void:
	if _n >= max_instances:
		return
	var b: int = _n * STRIDE
	_buf[b] = size
	_buf[b + 3] = at.x
	_buf[b + 5] = size
	_buf[b + 7] = at.y
	_buf[b + 10] = size
	_buf[b + 11] = at.z
	_buf[b + 12] = color.r
	_buf[b + 13] = color.g
	_buf[b + 14] = color.b
	_buf[b + 15] = color.a
	_buf[b + 16] = shape
	_buf[b + 17] = progress
	_n += 1


func commit() -> void:
	RenderingServer.multimesh_set_buffer(multimesh.get_rid(), _buf)
	multimesh.visible_instance_count = _n
	last_drawn = _n
	_n = 0
