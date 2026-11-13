extends Control
## A title across the middle of the screen (scenes/ui/title_banner.tscn): after a scene change (a `bg` step's
## `title`) or when a search starts ("開始尋找線索"). The dark band opens from the centre, the text rises in
## over the ruled line, holds, and fades out. It never takes taps and never holds up the story.

## Seconds: the band opening, the text holding, everything fading out.
@export var open_seconds: float = 0.4
@export var hold_seconds: float = 1.3
@export var fade_seconds: float = 0.55
## How far the text rises while it comes in, in design pixels.
@export var rise: float = 26.0
## 畫面效果：減少 — a plain fade, no movement.
var reduce_motion: bool = false

@onready var band: Control = %Band
@onready var text: Label = %Text
@onready var rule: Control = %Rule
var _tween: Tween = null
var _text_rest: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func play(title: String) -> void:
	if title.strip_edges().is_empty():
		return
	stop()
	text.text = title
	visible = true
	modulate.a = 1.0
	await get_tree().process_frame  # the band and the text have their size
	if not is_inside_tree() or text.text != title:
		return
	band.pivot_offset = band.size * 0.5
	rule.pivot_offset = rule.size * 0.5
	_text_rest = text.position.y
	_tween = create_tween()
	if reduce_motion:
		modulate.a = 0.0
		_tween.tween_property(self, "modulate:a", 1.0, 0.25)
	else:
		band.scale = Vector2(0.0, 1.0)
		rule.scale = Vector2(0.0, 1.0)
		text.modulate.a = 0.0
		text.position.y = _text_rest + rise
		_tween.tween_property(band, "scale:x", 1.0, open_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.parallel().tween_property(rule, "scale:x", 1.0, open_seconds * 1.4).set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_OUT).set_delay(open_seconds * 0.3)
		_tween.parallel().tween_property(text, "modulate:a", 1.0, open_seconds).set_delay(open_seconds * 0.4)
		_tween.parallel().tween_property(text, "position:y", _text_rest, open_seconds * 1.2) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(open_seconds * 0.4)
	_tween.tween_interval(hold_seconds)
	_tween.tween_property(self, "modulate:a", 0.0, fade_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if not reduce_motion:
		_tween.parallel().tween_property(text, "position:y", _text_rest - rise * 0.6, fade_seconds)
	_tween.tween_callback(stop)


## Ends it at once (a new title, a jump in the story, back to the title screen).
func stop() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	if text != null and visible:
		text.position.y = _text_rest if _text_rest != 0.0 else text.position.y
		text.modulate.a = 1.0
		band.scale = Vector2.ONE
		rule.scale = Vector2.ONE
	visible = false


func is_playing() -> bool:
	return visible
