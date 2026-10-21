extends Camera3D
## The push camera. It rests on the gameplay framing saved in main.tscn; events ask it for a CameraShot (a short
## push-in or small orbit toward a focus point) and for shake. Only this script moves the camera.
## Readability first: release() snaps it back home whenever a telegraph needs the full field, and main.gd only
## requests shots while no one stands in red. Taps still pick correctly during a shot (rays use the live camera).

## Shake: offsets in metres at trauma 1 (trauma is squared, so small hits stay calm).
@export var shake_m := Vector2(0.2, 0.16)
@export var trauma_decay: float = 1.8
@export var release_seconds: float = 0.25

var _home: Transform3D
var _home_fov: float
var _shot: CameraShot
var _focus := Vector3.ZERO
var _t: float = 0.0
var _weight: float = 0.0
## Weight when the shot started easing out, so a release from mid-move eases from where it is.
var _out_from: float = 1.0
var _out_t: float = -1.0
var _out_len: float = 0.5
var _trauma: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	_home = transform
	_home_fov = fov


## Starts `shot` toward world point `focus` unless a stronger shot is playing. Returns the shot's hit stop.
func play(shot: CameraShot, focus: Vector3) -> float:
	if shot == null:
		return 0.0
	if _shot != null and _out_t < 0.0 and shot.priority < _shot.priority:
		return 0.0
	_shot = shot
	_focus = focus
	_t = 0.0
	_out_t = -1.0
	add_trauma(shot.trauma)
	return shot.hit_stop


## Ease back to the gameplay framing now (a telegraph went up, or the push is over).
func release(seconds: float = -1.0) -> void:
	if _shot == null or _out_t >= 0.0:
		return
	_out_from = _weight
	_out_len = release_seconds if seconds < 0.0 else seconds
	_out_t = 0.0


func reset() -> void:
	_shot = null
	_weight = 0.0
	_trauma = 0.0
	transform = _home
	fov = _home_fov
	h_offset = 0.0
	v_offset = 0.0


func add_trauma(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


func busy() -> bool:
	return _shot != null


func _process(delta: float) -> void:
	_time += delta
	_trauma = maxf(_trauma - delta * trauma_decay, 0.0)
	var peak := Transform3D(_home)
	var peak_fov: float = _home_fov
	if _shot != null:
		_advance(delta)
	if _shot != null:
		peak = _peak_transform(_shot, _focus)
		peak_fov = _home_fov + _shot.fov_delta
	var w: float = _weight * _weight * (3.0 - 2.0 * _weight)
	transform = _home.interpolate_with(peak, w)
	fov = lerpf(_home_fov, peak_fov, w)
	var shake: float = _trauma * _trauma
	h_offset = sin(_time * 53.0) * shake_m.x * shake
	v_offset = sin(_time * 41.0 + 1.3) * shake_m.y * shake


func _advance(delta: float) -> void:
	var s := _shot
	if _out_t >= 0.0:
		_out_t += delta
		_weight = _out_from * (1.0 - clampf(_out_t / maxf(_out_len, 0.001), 0.0, 1.0))
		if _out_t >= _out_len:
			_shot = null
			_weight = 0.0
		return
	_t += delta
	if _t < s.ease_in:
		_weight = maxf(_weight, _t / maxf(s.ease_in, 0.001))
	else:
		_weight = 1.0
		if s.hold >= 0.0 and _t >= s.ease_in + s.hold:
			_out_from = 1.0
			_out_len = s.ease_out
			_out_t = 0.0


## The shot's peak framing: orbit the home camera around the focus by yaw/pitch, then dolly toward the focus. The
## camera keeps its home orientation relative to the orbit, so the field stays on screen.
func _peak_transform(s: CameraShot, focus: Vector3) -> Transform3D:
	var t := Transform3D(_home)
	var orbit := Basis(Vector3.UP, deg_to_rad(s.yaw_deg))
	var right: Vector3 = orbit * _home.basis.x
	orbit = Basis(right.normalized(), deg_to_rad(s.pitch_deg)) * orbit
	t.origin = focus + orbit * (_home.origin - focus)
	t.basis = orbit * _home.basis
	var to_focus: Vector3 = focus - t.origin
	t.origin += to_focus.normalized() * minf(s.push_m, to_focus.length() - 1.0)
	return t
