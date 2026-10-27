extends MultiMeshInstance3D
## Shots flying from heroes to the boss: the bows' and mages' shots and the 大招 volley. Pixel-vfx style, like
## impact_fx.gd: each shot is a hard-edged square head on the stage's pixel grid (0.025 m per texel) with a trail of
## smaller, darker squares along the path it just flew; no additive blending, so a crowd of shots never washes out
## into white. One MultiMesh (use_colors, sRGB vertex colours), TRAIL + 1 instances per shot.

const POOL := 256
const FLIGHT := 0.35
const ARC := 0.6
const M_PER_PX := 0.025
## Head first: size in texels, colour (lightened > 0, darkened < 0), how far behind the head along the flight (0..1).
const SEGMENTS := [[4, 0.35, 0.0], [3, 0.0, 0.07], [2, -0.3, 0.14]]

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
	multimesh.instance_count = POOL * SEGMENTS.size()
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
		for s: int in SEGMENTS.size():
			var seg: Array = SEGMENTS[s]
			var ks: float = k - seg[2]
			var size: float = M_PER_PX * seg[0] if _age[i] >= 0.0 and ks >= 0.0 else 0.0
			var at: Vector3 = _from[i].lerp(_to[i], maxf(ks, 0.0)) + Vector3(0.0, sin(maxf(ks, 0.0) * PI) * ARC, 0.0)
			var tone: float = seg[1]
			var c: Color = _color[i].lightened(tone) if tone > 0.0 else _color[i].darkened(-tone)
			var n: int = i * SEGMENTS.size() + s
			multimesh.set_instance_transform(n, Transform3D(Basis.from_scale(Vector3.ONE * size), at))
			multimesh.set_instance_color(n, c)
		i += 1
	multimesh.visible_instance_count = _count * SEGMENTS.size()
