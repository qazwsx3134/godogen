extends Control
## One Musou-style toast ("白鬍子 參戰！"): slides in from the left edge, holds, slides back out and frees itself.
## Layout lives in scenes/toast_item.tscn; only the Motion child moves.

@export var slide_seconds: float = 0.22

@onready var _motion: Control = %Motion
@onready var _speaker: Label = %ToastSpeaker
@onready var _text: Label = %ToastText
@onready var _portrait: TextureRect = %ToastPortrait
@onready var _initials: Label = %ToastInitials
@onready var _accent: ColorRect = %ToastAccent


func play(speaker: String, text: String, portrait: Texture2D, color: Color, hold: float) -> void:
	_speaker.text = speaker
	_speaker.add_theme_color_override("font_color", color)
	_text.text = text
	_portrait.texture = portrait
	_initials.text = speaker.left(1)
	_initials.visible = portrait == null
	_accent.color = color
	var width: float = maxf(size.x, custom_minimum_size.x) + 40.0
	_motion.position.x = -width
	var tween := create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_motion, "position:x", 0.0, slide_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_interval(hold)
	tween.tween_property(_motion, "position:x", -width, slide_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)
