class_name CameraRig
extends Node3D
## Fixed-heading chase camera: it only translates with the target and never turns, always looking down -Z
## ("forward", screen up). The view is four numbers: height and back distance from the target's feet, how far
## ahead of the feet it aims, and the vertical FOV. Aiming ahead keeps the target in the lower third while the
## route and the far landmark stay on screen, so the camera can sit high and far without losing the horizon.
## Zoom (a pull-back) slides the camera along its line of sight, so the composition does not drift.
## Shake moves Camera3D.h_offset / v_offset only (trauma squared, two sines), so the view direction never changes.
## The narrow side of the screen keeps the field of view: portrait phones see as far sideways as landscape ones do up.

@export var target: Node3D
@export_group("View")
@export var height: float = 10.0
@export var back: float = 12.3
@export var look_ahead: float = 9.4
## Aim point height above the feet.
@export var look_height: float = 0.0
@export var fov: float = 60.0
@export_group("Follow")
## pokebonk.com follows XZ at 18 and Y at 10 (exponential rates per second).
@export var follow_rate_xz: float = 18.0
@export var follow_rate_y: float = 10.0
@export_group("Outline")
## The depth outline's square term is this many times the flat ground's own depth step per pixel at the current
## render height and view (camera.get_node("PixelOutline")), so far ground is never outlined at any resolution.
@export var outline_margin: float = 2.0
@export_group("Shake")
@export var trauma_decay: float = 2.0
@export var max_shake: float = 0.3
## The reference shakes its three axes at about 4.6 / 7.0 / 5.4 Hz.
@export var shake_hz: float = 6.0

## Named views for side-by-side comparison (QA `cam=<name>`): height, back, look_ahead, look_height, fov.
const PRESETS := {
	"pokebonk": [4.95, 8.09, 0.0, 1.0, 70.0],
	"madara": [9.7, 9.66, 0.0, 1.0, 50.0],
	"high": [10.0, 12.3, 9.4, 0.0, 60.0],
	"higher": [13.0, 16.0, 12.2, 0.0, 60.0],
	"steep": [10.0, 10.0, 8.0, 0.0, 60.0],
}

var trauma: float = 0.0
## Camera distance multiplier along the line of sight (a big move pulls back); eases toward `_zoom_target`.
var zoom: float = 1.0
var _zoom_target: float = 1.0
var _clock: float = 0.0
## A cutscene's Shot camera whose pose and FOV the camera copies while set (see borrow()).
var _shot: Camera3D
var _blend_left: float = 0.0
var _blend_time: float = 0.0
var _blend_from: Transform3D
var _blend_fov: float = 60.0

@onready var camera: Camera3D = %Camera


func zoom_to(target_zoom: float) -> void:
	_zoom_target = target_zoom


func _ready() -> void:
	get_viewport().size_changed.connect(_fit)
	_fit()
	_place()
	if target:
		global_position = target.global_position


## Applies a named preset (QA tuning). Returns false for an unknown name.
func use_preset(preset: String) -> bool:
	if not PRESETS.has(preset):
		return false
	var v: Array = PRESETS[preset]
	set_view(v[0], v[1], v[2], v[3], v[4])
	return true


func set_view(new_height: float, new_back: float, new_look_ahead: float, new_look_height: float, new_fov: float) -> void:
	height = new_height
	back = new_back
	look_ahead = new_look_ahead
	look_height = new_look_height
	fov = new_fov
	_place()


## Down-angle of the view's center from the horizon, in degrees.
func center_pitch() -> float:
	return rad_to_deg(atan2(height - look_height, back + look_ahead))


func aim_point() -> Vector3:
	return Vector3(0.0, look_height, -look_ahead)


## A cutscene takes the camera: every frame it copies `shot`'s pose and FOV (the outline and post effects stay on
## this camera, so they keep working). release() eases back to the chase view over `seconds` of real time.
func borrow(shot: Camera3D) -> void:
	_shot = shot
	_blend_left = 0.0


func release(seconds: float = 0.6) -> void:
	_shot = null
	_blend_from = camera.global_transform
	_blend_fov = camera.fov
	_blend_time = maxf(seconds, 0.0)
	_blend_left = _blend_time
	if _blend_time == 0.0:
		_place()


func borrowed() -> bool:
	return _shot != null


func add_trauma(amount: float, ceiling: float = 1.0) -> void:
	trauma = maxf(trauma, minf(trauma + amount, ceiling))


func step(dt: float, real_dt: float) -> void:
	if target:
		var to: Vector3 = target.global_position
		var kxz: float = 1.0 - exp(-follow_rate_xz * dt)
		var ky: float = 1.0 - exp(-follow_rate_y * dt)
		global_position = Vector3(lerpf(global_position.x, to.x, kxz), lerpf(global_position.y, to.y, ky), lerpf(global_position.z, to.z, kxz))
	var was: float = zoom
	zoom = lerpf(zoom, _zoom_target, 1.0 - exp(-3.0 * real_dt))
	if zoom != was:
		_place()
	# Shake runs on real time: a hit stop freezes the game, not the punch.
	trauma = maxf(trauma - trauma_decay * real_dt, 0.0)
	_clock += real_dt
	var a: float = trauma * trauma * max_shake
	var t: float = TAU * shake_hz * _clock
	camera.h_offset = a * (0.62 * sin(t) + 0.38 * sin(t * 1.55 + 2.0))
	camera.v_offset = a * (0.62 * sin(t + 11.0) + 0.38 * sin(t * 1.55 + 22.0))
	if _shot:
		camera.global_transform = _shot.global_transform
		camera.fov = _shot.fov
		_fit_outline()
	elif _blend_left > 0.0:
		_blend_left = maxf(_blend_left - real_dt, 0.0)
		_place()
		var k: float = smoothstep(0.0, 1.0, 1.0 - _blend_left / _blend_time)
		camera.global_transform = _blend_from.interpolate_with(camera.global_transform, k)
		camera.fov = lerpf(_blend_fov, fov, k)


func _place() -> void:
	if camera == null:
		return
	var aim: Vector3 = aim_point()
	var eye: Vector3 = aim + (Vector3(0.0, height, back) - aim) * zoom
	camera.position = eye
	camera.rotation = Vector3(-atan2(eye.y - aim.y, eye.z - aim.z), 0.0, 0.0)
	camera.fov = fov
	_fit_outline()


## Flat ground seen from height h at down-angle theta: neighboring pixels differ in view depth by about
## d^2 x cos(theta) x thickness / (h x f), f = render height / (2 tan(fov / 2)) (Codex review, 2026-10-20).
func _fit_outline() -> void:
	var outline := camera.get_node_or_null(^"PixelOutline") as MeshInstance3D
	if outline == null:
		return
	var material := outline.material_override as ShaderMaterial
	var render_height: float = float(render_size(get_viewport()).y)
	var f: float = render_height / (2.0 * tan(deg_to_rad(fov) * 0.5))
	# Unset uniforms read back as null: fall back to the shader default.
	var set_thickness: Variant = material.get_shader_parameter(&"thickness")
	var thickness: float = 1.0 if set_thickness == null else float(set_thickness)
	var step: float = cos(deg_to_rad(center_pitch())) * thickness / (maxf(height * zoom, 0.1) * f)
	material.set_shader_parameter(&"threshold_per_m2", outline_margin * step)


## Pixels the 3D is actually rendered at. For the root window that is the window size (canvas_items stretch keeps
## 3D at full resolution); the viewport texture's reported size is not (macOS HiDPI reports 1707x960 for 1280x720).
static func render_size(viewport: Viewport) -> Vector2i:
	return (viewport as Window).size if viewport is Window else (viewport as SubViewport).size


func _fit() -> void:
	var size: Vector2 = get_viewport().get_visible_rect().size
	camera.keep_aspect = Camera3D.KEEP_HEIGHT if size.x >= size.y else Camera3D.KEEP_WIDTH
	_fit_outline()
