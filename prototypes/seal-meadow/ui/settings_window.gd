extends Control
## Editable modal for the single-player audio and accessibility settings.

signal changed(key: String, enabled: bool)

@onready var sound: CheckButton = %SoundToggle
@onready var large_text: CheckButton = %LargeTextToggle
@onready var reduced_motion: CheckButton = %ReducedMotionToggle
@onready var close_button: Button = %SettingsClose


func _ready() -> void:
	sound.toggled.connect(func(value: bool) -> void: changed.emit("sound", value))
	large_text.toggled.connect(func(value: bool) -> void: changed.emit("large_text", value))
	reduced_motion.toggled.connect(func(value: bool) -> void: changed.emit("reduced_motion", value))
	close_button.pressed.connect(func() -> void: visible = false)


func show_settings(settings: Dictionary) -> void:
	sound.set_pressed_no_signal(bool(settings.get("sound", true)))
	large_text.set_pressed_no_signal(bool(settings.get("large_text", false)))
	reduced_motion.set_pressed_no_signal(bool(settings.get("reduced_motion", false)))
	visible = true
