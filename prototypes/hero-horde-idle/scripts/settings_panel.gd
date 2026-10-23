extends PanelContainer
## 設定 panel (scenes/settings_panel.tscn; in the 營地 and in the push's pause menu): 音效 volume, 震動, 畫質 (省電／
## 標準／高: the battlefield's render scale) and 幀率 (30／60). Changes
## apply at once and are saved through the App autoload; without it (a test) they apply to its own copy.

const Settings = preload("res://domain/settings.gd")

signal closed

var settings: RefCounted

@onready var _sfx: HSlider = %SfxSlider
@onready var _sfx_value: Label = %SfxValue
@onready var _haptics: CheckButton = %Haptics
@onready var _quality: HBoxContainer = %QualityChoices
@onready var _fps: HBoxContainer = %FpsChoices


func _ready() -> void:
	var app: Node = get_node_or_null(^"/root/App")
	settings = app.settings if app != null else Settings.new()
	_sfx.value = settings.sfx
	_haptics.button_pressed = settings.haptics
	_show()
	_sfx.value_changed.connect(func(v: float) -> void:
		settings.sfx = v
		_changed())
	_haptics.toggled.connect(func(on: bool) -> void:
		settings.haptics = on
		_changed())
	for k: int in _quality.get_child_count():
		(_quality.get_child(k) as Button).pressed.connect(func() -> void:
			settings.quality = k
			_changed())
	for k: int in _fps.get_child_count():
		(_fps.get_child(k) as Button).pressed.connect(func() -> void:
			settings.fps = Settings.FPS_CHOICES[k]
			_changed())
	%Close.pressed.connect(closed.emit)


func _changed() -> void:
	var app: Node = get_node_or_null(^"/root/App")
	if app != null:
		app.settings_changed()
	else:
		settings.apply()
	_show()


func _show() -> void:
	_sfx_value.text = "%d%%" % roundi(settings.sfx * 100.0)
	_haptics.text = "開" if settings.haptics else "關"
	for k: int in _quality.get_child_count():
		(_quality.get_child(k) as Button).button_pressed = k == settings.quality
	for k: int in _fps.get_child_count():
		(_fps.get_child(k) as Button).button_pressed = Settings.FPS_CHOICES[k] == settings.fps
