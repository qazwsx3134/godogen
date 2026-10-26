extends RefCounted
## Camera shake by trauma. Every impact adds trauma (0..1), trauma drains at a fixed rate, and the camera moves by
## trauma squared: small hits barely stir it, big ones punch, and a stream of small ones does not add up to a big one.
## `const CameraShake = preload("res://addons/proto_kit/camera_shake.gd")`
##
##   var shake := CameraShake.new()
##   shake.camera = $Camera2D
##   func _process(delta): shake.step(delta)        # whoever owns the camera steps it once a frame
##   shake.add_trauma(0.25)                          # a small hit
##   shake.add_trauma(0.85)                          # a boss death
##   shake.add_trauma(0.25, 0.35)                    # never pushes trauma past 0.35, so a stream of crits rumbles instead of punching
##
## It moves Camera2D.offset and Camera2D.rotation only, never a body or the camera's position, so aiming and
## collisions are untouched. The motion is two sines at unrelated rates, not a random value per frame (that buzzes).
## Rotation only shows with Camera2D.ignore_rotation off. When trauma reaches 0 the camera is put back at exactly zero.

## The camera to shake. Nothing happens to the camera while this is null (trauma still drains).
var camera: Camera2D
## Accessibility: scales how far the camera moves. 0 = the camera never shakes (trauma is not even collected).
var shake_scale: float = 1.0
## Trauma lost per second. The shake itself is trauma squared, so it dies away faster than trauma does.
var decay: float = 1.5
## Camera offset (px) at full trauma, and the roll (rad) the camera turns at most.
var max_offset: Vector2 = Vector2(40.0, 30.0)
var max_roll: float = 0.02
## How fast the shake wobbles (Hz). Much above 10 it turns into a buzz on a 30 or 60 fps screen.
var frequency: float = 8.0

## 0..1, added to by every shake and drained by `decay`. The camera shakes by trauma squared.
var trauma: float = 0.0

var _clock: float = 0.0

## Shakes add up, but one never pushes the trauma past its own `ceiling` (and never lowers it).
## Does nothing while shake_scale is 0.
func add_trauma(amount: float, ceiling: float = 1.0) -> void:
	if shake_scale <= 0.0:
		return
	trauma = maxf(trauma, minf(trauma + amount, ceiling))

## Once per frame, with the frame's delta.
func step(delta: float) -> void:
	if shake_scale <= 0.0:
		trauma = 0.0
	if trauma <= 0.0:
		return
	trauma = maxf(trauma - decay * delta, 0.0)
	_clock += delta
	if camera == null:
		return
	var amount: float = trauma * trauma * shake_scale   # small hits barely move, big ones punch
	camera.offset = Vector2(max_offset.x * amount * _wave(0.0), max_offset.y * amount * _wave(11.0))
	camera.rotation = max_roll * amount * _wave(23.0)   # the last frame (trauma 0) puts both back to zero

## Smooth, not random: two sines at unrelated rates. A fresh randf() every frame would buzz. Within -1..1.
func _wave(phase: float) -> float:
	var t: float = TAU * frequency * _clock
	return 0.62 * sin(t + phase) + 0.38 * sin(t * 1.55 + phase * 2.0)
