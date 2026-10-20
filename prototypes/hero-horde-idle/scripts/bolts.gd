extends MultiMeshInstance3D
## Light bolts flying from heroes to the boss: the bows' and mages' shots and the 大招 volley. A pool of
## billboard quads in one MultiMesh (use_colors); a bolt arcs over FLIGHT seconds and disappears on arrival.

const POOL := 256
const FLIGHT := 0.35
const ARC := 0.6

var _count: int = 0
var _from := PackedVector3Array()
var _to := PackedVector3Array()
var _age := PackedFloat32Array()
var _color := PackedColorArray()


func _ready() -> void:
	_from.resize(POOL)
	_to.resize(POOL)
	_age.resize(POOL)
	_color.resize(POOL)
	multimesh.instance_count = POOL
	multimesh.visible_instance_count = 0


## A negative delay holds the bolt back that long before it leaves.
func fire(from: Vector3, to: Vector3, color: Color, delay: float = 0.0) -> void:
	if _count >= POOL:
		return
	_from[_count] = from
	_to[_count] = to
	_age[_count] = -delay
	_color[_count] = color
	_count += 1


func clear() -> void:
	_count = 0
	multimesh.visible_instance_count = 0


func step(dt: float) -> void:
	var i: int = 0
	while i < _count:
		_age[i] += dt
		if _age[i] >= FLIGHT:
			_count -= 1
			_from[i] = _from[_count]
			_to[i] = _to[_count]
			_age[i] = _age[_count]
			_color[i] = _color[_count]
			continue
		var k: float = maxf(_age[i], 0.0) / FLIGHT
		var at: Vector3 = _from[i].lerp(_to[i], k) + Vector3(0.0, sin(k * PI) * ARC, 0.0)
		var s: float = 1.0 if _age[i] >= 0.0 else 0.0
		multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * s), at))
		multimesh.set_instance_color(i, _color[i])
		i += 1
	multimesh.visible_instance_count = _count
