class_name StoryUi
extends CanvasLayer
## The story layer above the HUD: the dialogue box (blocks the game until tapped), the in-game subtitle line (does
## not), Musou-style toasts, the act title card, cutscene letterbox bars and the skip button. Layout lives in
## scenes/story_ui.tscn; this script only fills text and plays the motion. Everything runs on real time, so it
## keeps working while the game clock is stopped.

signal skip_pressed
signal _advance

@export var toast_scene: PackedScene
## Seconds per character of the dialogue typewriter.
@export var type_seconds: float = 0.03
## Subtitle hold when a line gives no time: base + per character.
@export var line_base: float = 1.4
@export var line_per_char: float = 0.09
@export var toast_hold: float = 2.4
@export var title_hold: float = 1.6
## QA: dialogue advances by itself after this many seconds (0 = waits for a tap).
@export var auto_advance: float = 0.0

const PORTRAITS := "res://assets/portraits/%s.png"

var _typing: Tween
var _line_left: float = 0.0
var _dialogue_open: bool = false

@onready var _box: Control = %DialogueBox
@onready var _catcher: Control = %Catcher
@onready var _speaker: Label = %Speaker
@onready var _text: Label = %Text
@onready var _portrait: TextureRect = %Portrait
@onready var _initials: Label = %Initials
@onready var _next: Control = %NextMark
@onready var _subtitle: Control = %Subtitle
@onready var _subtitle_speaker: Label = %SubtitleSpeaker
@onready var _subtitle_text: Label = %SubtitleText
@onready var _toasts: Container = %Toasts
@onready var _title: Control = %ActTitle
@onready var _title_number: Label = %TitleNumber
@onready var _title_name: Label = %TitleName
@onready var _bars_top: Control = %LetterboxTop
@onready var _bars_bottom: Control = %LetterboxBottom
@onready var _skip: Button = %Skip


func _ready() -> void:
	_catcher.gui_input.connect(_on_catcher_input)
	_skip.pressed.connect(func() -> void: skip_pressed.emit())
	for sample: Node in _toasts.get_children():
		sample.queue_free()
	_box.hide()
	_catcher.hide()
	_subtitle.hide()
	_title.hide()
	_skip.hide()
	_set_bars(0.0)


func _process(delta: float) -> void:
	if _line_left > 0.0:
		_line_left -= delta
		if _line_left <= 0.0:
			_subtitle.hide()


static func portrait(id: String) -> Texture2D:
	var path: String = PORTRAITS % id
	return load(path) if not id.is_empty() and ResourceLoader.exists(path) else null


## Blocking line in the dialogue box; returns once the player taps (or after `auto_advance` in QA).
func say(speaker: String, text: String, portrait_id: String = "", color: Color = Color("ffd16b")) -> void:
	_speaker.text = speaker
	_speaker.add_theme_color_override("font_color", color)
	_text.text = text
	var tex: Texture2D = portrait(portrait_id)
	_portrait.texture = tex
	_initials.text = speaker.left(1)
	_initials.visible = tex == null
	_box.show()
	_catcher.show()
	_dialogue_open = true
	_next.hide()
	_text.visible_ratio = 0.0
	if _typing and _typing.is_valid():
		_typing.kill()
	_typing = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_typing.tween_property(_text, "visible_ratio", 1.0, maxf(type_seconds * text.length(), 0.01))
	_typing.tween_callback(_next.show)
	if auto_advance > 0.0:
		get_tree().create_timer(auto_advance, true, false, true).timeout.connect(_auto, CONNECT_ONE_SHOT)
	await _advance
	_dialogue_open = false
	_box.hide()
	_catcher.hide()


func dialogue_open() -> bool:
	return _dialogue_open


## Taps the dialogue: the first tap finishes the typing, the next one moves on.
func tap() -> void:
	if not _dialogue_open:
		return
	if _text.visible_ratio < 1.0:
		_typing.kill()
		_text.visible_ratio = 1.0
		_next.show()
	else:
		_advance.emit()


func _auto() -> void:
	if _dialogue_open:
		_text.visible_ratio = 1.0
		_advance.emit()


func _on_catcher_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		tap()
		_catcher.accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if _dialogue_open and event.is_action_pressed(&"ui_accept"):
		tap()
		get_viewport().set_input_as_handled()


## Non-blocking subtitle line (in-game shouts and cutscene lines). `seconds` 0 = by length.
func line(speaker: String, text: String, seconds: float = 0.0, color: Color = Color("ffd16b")) -> void:
	_subtitle_speaker.text = speaker
	_subtitle_speaker.visible = not speaker.is_empty()
	_subtitle_speaker.add_theme_color_override("font_color", color)
	_subtitle_text.text = text
	_subtitle.show()
	_line_left = seconds if seconds > 0.0 else line_base + line_per_char * text.length()


func line_visible() -> bool:
	return _subtitle.visible


## Musou-style side notification: slides in, holds, slides out. Several stack.
func toast(speaker: String, text: String, portrait_id: String = "", color: Color = Color("ffd16b")) -> void:
	var item: Control = toast_scene.instantiate()
	_toasts.add_child(item)
	item.call(&"play", speaker, text, portrait(portrait_id), color, toast_hold)


func toast_count() -> int:
	return _toasts.get_child_count()


## Full-screen act title ("第四幕" / "處刑台"); returns when it has faded out.
func title_card(number: String, title: String) -> void:
	_title_number.text = number
	_title_name.text = title
	_title.modulate.a = 0.0
	_title.show()
	var tween := create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_title, "modulate:a", 1.0, 0.35)
	tween.tween_interval(title_hold)
	tween.tween_property(_title, "modulate:a", 0.0, 0.45)
	await tween.finished
	_title.hide()


## Cutscene framing: letterbox bars slide in and the skip button shows.
func cinema(on: bool) -> void:
	_skip.visible = on
	var tween := create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(_set_bars, 1.0 - float(on), float(on), 0.3)
	if not on:
		_subtitle.hide()
		_line_left = 0.0


func cinema_on() -> bool:
	return _skip.visible


func _set_bars(amount: float) -> void:
	_bars_top.scale.y = amount
	_bars_bottom.scale.y = amount
