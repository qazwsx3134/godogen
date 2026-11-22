extends Node3D
## Pixel hit effects on the ground of an HD-2D diorama, on the pixel-vfx rules (pixel_vfx.gd and skill pixel-vfx: one
## pixel grid, hard edges, 5-colour palettes, its own random numbers so the game's randf() and balance runs are not
## touched). The 3D counterpart of pixel_vfx.gd:
##   ring()   a shockwave on the ground (a pool of quads under %Rings with pixel_vfx3d_ring.gdshader)
##   drop()   chunks falling from the sky onto a spot, timed to land after `seconds`
##   sweep()  chunks flung sideways along a line
##   burst()  pixel chunks thrown out with gravity and one bounce: rocks, dust, sparks, armour shards (%Chunks, one
##            MultiMesh). A chunk's life ends in three steps (shrinks 100 -> 66 -> 33%), never a soft fade.
## The node needs two children (scene unique names): %Chunks, a MultiMeshInstance3D whose MultiMesh uses colours and a
## small box mesh with an unshaded vertex-colour material; %Rings, a Node3D holding a few MeshInstance3D quads (1 x 1
## PlaneMesh) sharing one ShaderMaterial of pixel_vfx3d_ring.gdshader. Call step(game_delta) every frame (game time,
## so hit stop and pause freeze the effects) and clear() when a round restarts.
##   fx.burst(at, 30, &"rock", 4.5, 4.0, 4)       fx.ring(boss.global_position, 3.4, &"cyan", 0.5)

## Metres per art pixel: chunk sizes and ring cells are counted in the game's pixels.
@export var m_per_px: float = 0.025
## Downward pull on chunks, m/s².
@export var gravity: float = 14.0
@export var max_chunks: int = 320
@export var rng_seed: int = 7
## Palettes by name, [outline, dark, mid, light, white]. Replace or add the game's own in _ready (before super()) or
## from outside; these six are the defaults.
var palettes: Dictionary = {
	&"rock": [Color(0.1, 0.08, 0.1), Color(0.33, 0.3, 0.3), Color(0.5, 0.47, 0.43), Color(0.68, 0.64, 0.58),
		Color(0.88, 0.86, 0.8)],
	&"dust": [Color(0.2, 0.17, 0.15), Color(0.48, 0.43, 0.37), Color(0.62, 0.57, 0.5), Color(0.76, 0.72, 0.64),
		Color(0.9, 0.88, 0.82)],
	&"slam": [Color(0.18, 0.05, 0.05), Color(0.62, 0.16, 0.1), Color(0.92, 0.38, 0.16), Color(1.0, 0.72, 0.38),
		Color(1.0, 0.96, 0.82)],
	&"gold": [Color(0.25, 0.14, 0.04), Color(0.72, 0.46, 0.1), Color(0.96, 0.76, 0.26), Color(1.0, 0.92, 0.56),
		Color(1.0, 1.0, 0.9)],
	&"steel": [Color(0.08, 0.1, 0.14), Color(0.34, 0.4, 0.48), Color(0.58, 0.66, 0.74), Color(0.82, 0.88, 0.93),
		Color(1.0, 1.0, 1.0)],
	&"cyan": [Color(0.04, 0.12, 0.18), Color(0.12, 0.45, 0.62), Color(0.3, 0.75, 0.9), Color(0.65, 0.95, 1.0),
		Color(1.0, 1.0, 1.0)],
}

@onready var _chunks: MultiMeshInstance3D = %Chunks
@onready var _ring_pool: Array[Node] = %Rings.get_children()

var rng := RandomNumberGenerator.new()
var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _life := PackedFloat32Array()
var _age := PackedFloat32Array()
var _size := PackedFloat32Array()
var _color := PackedColorArray()
var _bounced := PackedByteArray()
var _rings: Array[Dictionary] = []
## Frames left of the warm-up: one ring and one chunk drawn out of sight at start, so their shaders compile before the
## first real hit instead of hitching on it.
var _warm: int = 2


func _ready() -> void:
	rng.seed = rng_seed
	_chunks.multimesh.instance_count = max_chunks
	_chunks.multimesh.visible_instance_count = 0
	clear()


func clear() -> void:
	_pos.clear()
	_vel.clear()
	_life.clear()
	_age.clear()
	_size.clear()
	_color.clear()
	_bounced.clear()
	_rings.clear()
	_chunks.multimesh.visible_instance_count = 0
	for ring: Node in _ring_pool:
		(ring as Node3D).visible = false
	if _warm > 0:
		var first := _ring_pool[0] as MeshInstance3D
		first.visible = true
		first.position = Vector3(0.0, -5.0, 0.0)
		first.set_instance_shader_parameter(&"progress", 0.05)
		_chunks.multimesh.visible_instance_count = 1
		_chunks.multimesh.set_instance_transform(0, Transform3D(Basis.from_scale(Vector3.ONE * 0.1), Vector3(0.0, -5.0, 0.0)))


## A shockwave on the ground at `at`, `radius` metres at its widest. Skipped when every ring is busy.
func ring(at: Vector3, radius: float, palette: StringName, duration: float = 0.45) -> void:
	for node: Node in _ring_pool:
		var r := node as MeshInstance3D
		if r.visible:
			continue
		var pal: Array = palettes[palette]
		r.visible = true
		r.global_position = Vector3(at.x, 0.03, at.z)
		r.scale = Vector3(radius * 2.0, 1.0, radius * 2.0)
		r.set_instance_shader_parameter(&"col_dark", pal[1])
		r.set_instance_shader_parameter(&"col_mid", pal[2])
		r.set_instance_shader_parameter(&"col_light", pal[3])
		r.set_instance_shader_parameter(&"col_white", pal[4])
		r.set_instance_shader_parameter(&"texels", roundf(radius * 2.0 / m_per_px / 2.0))
		r.set_instance_shader_parameter(&"progress", 0.0)
		_rings.append({"node": r, "t": 0.0, "life": duration})
		return


## `count` chunks from `at`: thrown out at up to `speed` m/s sideways and `up` m/s upward, `size_px` texels big.
func burst(at: Vector3, count: int, palette: StringName, speed: float = 3.0, up: float = 3.5, size_px: int = 3,
		life: float = 0.7) -> void:
	var pal: Array = palettes[palette]
	for k: int in count:
		if _pos.size() >= max_chunks:
			return
		var a: float = rng.randf() * TAU
		var s: float = speed * (0.35 + 0.65 * rng.randf())
		_pos.append(at)
		_vel.append(Vector3(cos(a) * s, up * (0.5 + 0.5 * rng.randf()), sin(a) * s * 0.6))
		_life.append(life * (0.7 + 0.6 * rng.randf()))
		_age.append(0.0)
		_size.append(m_per_px * (size_px + rng.randi_range(-1, 1)))
		_color.append(pal[rng.randi_range(1, 4)])
		_bounced.append(0)


## `count` chunks falling from `height` m onto a disc of `spread` m around `at`, all landing after `seconds`.
func drop(at: Vector3, count: int, palette: StringName, seconds: float, height: float = 7.0, spread: float = 1.0,
		size_px: int = 6) -> void:
	var pal: Array = palettes[palette]
	for k: int in count:
		if _pos.size() >= max_chunks:
			return
		var t: float = seconds * (0.85 + 0.15 * rng.randf())
		var h: float = height * (0.8 + 0.4 * rng.randf())
		var land := at + Vector3(rng.randf_range(-spread, spread), 0.0, rng.randf_range(-spread, spread) * 0.8)
		_pos.append(land + Vector3(0.0, h, 0.0))
		# h = v t + g t^2 / 2, falling
		_vel.append(Vector3(0.0, -(h - 0.5 * gravity * t * t) / t, 0.0))
		_life.append(t + 0.25)
		_age.append(0.0)
		_size.append(m_per_px * (size_px + rng.randi_range(-2, 2)))
		_color.append(pal[rng.randi_range(1, 3)])
		_bounced.append(0)


## `count` chunks along the line `from` -> `to`, flung toward `push` (m/s) and up a little.
func sweep(from: Vector3, to: Vector3, count: int, palette: StringName, push: Vector3, size_px: int = 3) -> void:
	var pal: Array = palettes[palette]
	for k: int in count:
		if _pos.size() >= max_chunks:
			return
		_pos.append(from.lerp(to, rng.randf()) + Vector3(0.0, rng.randf_range(0.1, 0.9), 0.0))
		_vel.append(push * (0.6 + 0.6 * rng.randf()) + Vector3(0.0, rng.randf_range(0.5, 2.5), 0.0))
		_life.append(0.5 + 0.3 * rng.randf())
		_age.append(0.0)
		_size.append(m_per_px * (size_px + rng.randi_range(-1, 1)))
		_color.append(pal[rng.randi_range(2, 4)])
		_bounced.append(0)


func step(dt: float) -> void:
	if _warm > 0:
		_warm -= 1
		if _warm == 0 and _rings.is_empty():
			(_ring_pool[0] as Node3D).visible = false
		return
	_step_rings(dt)
	_step_chunks(dt)


func _step_rings(dt: float) -> void:
	for k: int in range(_rings.size() - 1, -1, -1):
		var e: Dictionary = _rings[k]
		e.t += dt
		var r: MeshInstance3D = e.node
		var p: float = e.t / e.life
		if p >= 1.0:
			r.visible = false
			_rings.remove_at(k)
		else:
			r.set_instance_shader_parameter(&"progress", p)


func _step_chunks(dt: float) -> void:
	var k: int = 0
	while k < _pos.size():
		_age[k] += dt
		if _age[k] >= _life[k]:
			_remove(k)
			continue
		var v: Vector3 = _vel[k]
		v.y -= gravity * dt
		var p: Vector3 = _pos[k] + v * dt
		if p.y < 0.02 and v.y < 0.0:
			p.y = 0.02
			if _bounced[k] == 0:
				v = Vector3(v.x * 0.45, -v.y * 0.3, v.z * 0.45)
				_bounced[k] = 1
			else:
				v = Vector3(v.x * 0.6, 0.0, v.z * 0.6)
		_vel[k] = v
		_pos[k] = p
		k += 1
	var mm := _chunks.multimesh
	mm.visible_instance_count = _pos.size()
	for i: int in _pos.size():
		var left: float = 1.0 - _age[i] / _life[i]
		var steps: float = 1.0 if left > 0.5 else (0.66 if left > 0.25 else 0.33)
		var s: float = _size[i] * steps
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(s, s, s)), _pos[i]))
		mm.set_instance_color(i, _color[i])


func _remove(k: int) -> void:
	var last: int = _pos.size() - 1
	_pos[k] = _pos[last]
	_vel[k] = _vel[last]
	_life[k] = _life[last]
	_age[k] = _age[last]
	_size[k] = _size[last]
	_color[k] = _color[last]
	_bounced[k] = _bounced[last]
	_pos.resize(last)
	_vel.resize(last)
	_life.resize(last)
	_age.resize(last)
	_size.resize(last)
	_color.resize(last)
	_bounced.resize(last)
