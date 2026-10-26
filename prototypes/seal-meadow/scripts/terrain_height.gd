extends RefCounted
## Height of the meadow at a ground point: a gentle field in a bowl of hills, with a pond.
## The terrain mesh is baked from this, and actors stand on it without physics.

const HALF := 72.0
const POND := Vector2(16.0, -12.0)
const POND_BLOCK := 6.6

static var _noise: FastNoiseLite


static func height(x: float, z: float) -> float:
	var n := _field_noise()
	var rim := smoothstep(44.0, 70.0, Vector2(x, z).length())
	var h := n.get_noise_2d(x, z) * 1.4 + rim * rim * 18.0 + rim * n.get_noise_2d(x * 2.0 + 100.0, z * 2.0) * 6.0
	h -= (1.0 - smoothstep(3.0, 9.0, Vector2(x, z).distance_to(POND))) * 2.2
	return h


static func water_level() -> float:
	return height(POND.x, POND.y) + 1.4


static func _field_noise() -> FastNoiseLite:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = 7
		_noise.frequency = 0.03
		_noise.fractal_octaves = 3
	return _noise
