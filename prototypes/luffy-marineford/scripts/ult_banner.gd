@tool
class_name UltBanner
extends Control
## One saved, editable full-width ultimate announcement. New play() replaces the
## current announcement; finished is emitted once when the latest one exits.
## Default: real time, including Engine.time_scale=0 and SceneTree pause.
## For this game's custom clock: set use_real_time=false, then advance(game_dt).

signal finished

@export_group("Timing")
@export var enter_seconds: float = 0.15
@export var hold_seconds: float = 0.9
@export var exit_seconds: float = 0.2
@export var use_real_time: bool = true
@export_range(0.0, 0.4) var flash_strength: float = 0.0
@export_group("Portrait and safe area")
@export var portrait_initials: String = "LF"
## Additional safe insets in logical UI pixels: left, top, right, bottom.
@export var safe_insets: Vector4 = Vector4.ZERO:
	set(value):
		safe_insets = value
		if is_node_ready():
			_fit()
@export var use_display_safe_area: bool = true

@onready var _motion: Control = %Motion
@onready var _band: Panel = %Band
@onready var _safe: MarginContainer = %SafeContent
@onready var _safe_frame: MarginContainer = %SafeFrame
@onready var _title: Label = %Title
@onready var _subtitle: Label = %Subtitle
@onready var _portrait: TextureRect = %Portrait
@onready var _initials: Label = %Initials
@onready var _accent: ColorRect = %Accent
@onready var _flash: ColorRect = %BannerFlash

var _tween: Tween
var _manual: bool = false
var _slide: float = 0.0:
	set(value):
		_slide = value
		if is_instance_valid(_motion):
			# Only this animation container moves; anchors own the actual layout.
			_motion.position.x = value * (size.x * 1.5 + 128.0)


func _ready() -> void:
	resized.connect(_fit)
	_band.resized.connect(_fit)
	_fit()
	if not Engine.is_editor_hint():
		hide()


## Shows one announcement. Layout/styles are authored in scenes/ult_banner.tscn.
func play(title: String, subtitle: String, color: Color, portrait: Texture2D = null) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_title.text = title
	_subtitle.text = subtitle
	_portrait.texture = portrait
	_initials.text = portrait_initials
	_initials.visible = portrait == null
	_accent.color = color
	%PortraitAccent.self_modulate = color
	%Eyebrow.self_modulate = color
	_flash.modulate.a = flash_strength
	_slide = -1.0
	show()
	_manual = not use_real_time
	_tween = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(self, "_slide", 0.0, maxf(enter_seconds, 0.001)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if flash_strength > 0.0:
		_tween.parallel().tween_property(_flash, "modulate:a", 0.0, minf(0.12, maxf(enter_seconds, 0.001)))
	_tween.tween_interval(maxf(hold_seconds, 0.0))
	_tween.tween_property(self, "_slide", 1.0, maxf(exit_seconds, 0.001)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.finished.connect(_complete)
	if _manual:
		_tween.pause()


## In manual game-time mode, the caller supplies its own scaled/paused game dt.
func advance(game_delta: float) -> void:
	if _manual and _tween and _tween.is_valid() and game_delta > 0.0:
		_tween.custom_step(game_delta)


func _complete() -> void:
	hide()
	_flash.modulate.a = 0.0
	_slide = 0.0
	_tween = null
	finished.emit()


func _fit() -> void:
	# A transform pivot is responsive; positions/sizes/rotation remain scene data.
	_band.pivot_offset = _band.size * 0.5
	_slide = _slide
	var insets: Vector4 = safe_insets
	if use_display_safe_area and not Engine.is_editor_hint() and (OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")):
		var window := get_window()
		var safe: Rect2i = DisplayServer.get_display_safe_area()
		var window_rect := Rect2i(window.position, window.size)
		var usable: Rect2i = window_rect.intersection(safe)
		if usable.has_area():
			var scale_ui: Vector2 = size / Vector2(window.size).max(Vector2.ONE)
			insets.x += maxf(usable.position.x - window_rect.position.x, 0) * scale_ui.x
			insets.z += maxf(window_rect.end.x - usable.end.x, 0) * scale_ui.x
			insets.y += maxf(usable.position.y - window_rect.position.y, 0) * scale_ui.y
			insets.w += maxf(window_rect.end.y - usable.end.y, 0) * scale_ui.y
	# Match the band's authored 16% bleed so content stays inside screen edges.
	var bleed: int = roundi((_band.size.x - size.x) * 0.5)
	_safe.add_theme_constant_override("margin_left", bleed + 24 + ceili(maxf(insets.x, 0)))
	_safe.add_theme_constant_override("margin_right", bleed + 24 + ceili(maxf(insets.z, 0)))
	_safe_frame.add_theme_constant_override("margin_top", ceili(maxf(insets.y, 0)))
	_safe_frame.add_theme_constant_override("margin_bottom", ceili(maxf(insets.w, 0)))
