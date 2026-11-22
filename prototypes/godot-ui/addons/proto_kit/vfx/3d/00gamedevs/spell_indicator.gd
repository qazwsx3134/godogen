extends Node3D
## Godot port of 00GameDevs createSpellIndicatorEffect (MIT).
## Place on XZ ground (+X is sector centre); rotate the root to aim.
## Automatic warning: reset(). Authoritative game clock: auto_step=false, step(dt).
## Manual warning: manual_progress=true, set_progress(0..1). stop() cancels.
signal finished

@export_range(0.25, 20.0) var radius: float = 3.0
@export_range(5.0, 360.0) var angle_degrees: float = 360.0
@export_range(0.1, 30.0) var warning_duration: float = 2.0
@export_range(0.25, 2.0) var detail: float = 1.0
@export var color: Color = Color("ff303e")
@export var manual_progress: bool = false
@export var auto_step: bool = true
@export var free_on_finish: bool = false
@onready var surface: MeshInstance3D = %Surface

var progress: float = 0.0
var elapsed: float = 0.0
var is_finished: bool = false
var phase: StringName = &"active"
var _end_age: float = 0.0
var _ending: StringName = &""
var _material: ShaderMaterial

func _ready() -> void:
	# Per-instance material state; no writes to the original .tres/.tscn.
	_material = surface.material_override as ShaderMaterial
	reset()

func _process(delta: float) -> void:
	if auto_step:
		step(delta)

func reset() -> void:
	elapsed = 0.0
	progress = 0.0
	_end_age = 0.0
	_ending = &""
	is_finished = false
	phase = &"active"
	_sync()

func set_progress(value: float) -> void:
	if not manual_progress or is_finished or _ending != &"" or not is_finite(value):
		return
	progress = clampf(value, 0.0, 1.0)
	if progress == 1.0:
		_ending = &"complete"
		phase = &"ending"
	_sync()

func stop() -> void:
	if is_finished or _ending != &"":
		return
	_ending = &"cancel"
	_end_age = 0.0
	phase = &"ending"
	_sync()

func step(delta: float) -> void:
	if is_finished or not is_finite(delta) or delta < 0.0:
		return
	var remaining: float = delta
	if _ending == &"":
		if manual_progress:
			elapsed += remaining
			remaining = 0.0
		else:
			var duration: float = clampf(warning_duration, 0.1, 30.0)
			var advance: float = minf(remaining, maxf(0.0, duration - elapsed))
			elapsed += advance
			remaining -= advance
			progress = minf(1.0, elapsed / duration)
			if elapsed >= duration - 0.0000000001:
				elapsed = duration
				progress = 1.0
				_ending = &"complete"
				phase = &"ending"
	if _ending != &"":
		var duration: float = 0.15 if _ending == &"complete" else 0.12
		var advance: float = minf(remaining, maxf(0.0, duration - _end_age))
		elapsed += advance
		_end_age += advance
		if _end_age >= duration - 0.0000000001:
			_end_age = duration
			is_finished = true
			phase = &"finished"
	_sync()
	if is_finished:
		finished.emit()
		if free_on_finish:
			queue_free()

func _sync() -> void:
	if _material == null:
		return
	surface.visible = not is_finished
	var opacity: float = 1.0
	if _ending == &"cancel":
		opacity = maxf(0.0, 1.0 - _end_age / 0.12)
	elif _ending == &"complete":
		opacity = maxf(0.0, 1.0 - maxf(0.0, _end_age - 0.06) / 0.09)
	_material.set_shader_parameter("effect_radius", clampf(radius, 0.25, 20.0))
	_material.set_shader_parameter("uHalfAngle", deg_to_rad(clampf(angle_degrees, 5.0, 360.0)) * 0.5)
	_material.set_shader_parameter("uColor", color)
	_material.set_shader_parameter("uEdgeColor", _edge_color(color))
	_material.set_shader_parameter("uDetail", clampf(detail, 0.25, 2.0))
	_material.set_shader_parameter("uTime", fmod(elapsed, TAU / 2.6))
	_material.set_shader_parameter("uProgress", progress)
	_material.set_shader_parameter("uFlash", 1.0 - 0.35 * _end_age / 0.06 if _ending == &"complete" and _end_age < 0.06 else 0.0)
	_material.set_shader_parameter("uOpacity", 0.0 if is_finished else opacity)

## Three.js uses HSL in linear RGB; preserve its edge-colour calculation.
static func _edge_color(input: Color) -> Color:
	var c: Color = input.srgb_to_linear()
	var hi: float = maxf(c.r, maxf(c.g, c.b))
	var lo: float = minf(c.r, minf(c.g, c.b))
	var light: float = (hi + lo) * 0.5
	var saturation: float = 0.0
	var hue: float = 0.0
	if hi != lo:
		var d: float = hi - lo
		saturation = d / (2.0 - hi - lo) if light > 0.5 else d / (hi + lo)
		if hi == c.r:
			hue = (c.g - c.b) / d + (6.0 if c.g < c.b else 0.0)
		elif hi == c.g:
			hue = (c.b - c.r) / d + 2.0
		else:
			hue = (c.r - c.g) / d + 4.0
		hue /= 6.0
	hue = fposmod(hue + 0.045, 1.0)
	saturation *= 0.86
	light = clampf(light, 0.52, 0.68)
	var q: float = light * (1.0 + saturation) if light <= 0.5 else light + saturation - light * saturation
	var p: float = 2.0 * light - q
	return Color(_hue_channel(p, q, hue + 1.0 / 3.0), _hue_channel(p, q, hue), _hue_channel(p, q, hue - 1.0 / 3.0)).linear_to_srgb()

static func _hue_channel(p: float, q: float, hue: float) -> float:
	hue = fposmod(hue, 1.0)
	if hue < 1.0 / 6.0:
		return p + (q - p) * 6.0 * hue
	if hue < 0.5:
		return q
	if hue < 2.0 / 3.0:
		return p + (q - p) * 6.0 * (2.0 / 3.0 - hue)
	return p
