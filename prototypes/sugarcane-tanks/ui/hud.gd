extends Control
## Top bar (room, level, EXP), boss bar, picked-ability chips, pause, fade and banner.
## Layout and static text live in hud.tscn; this script only fills in values.

signal pause_toggled(paused: bool)

@export var chip_scene: PackedScene

@onready var joystick: Control = %Joystick
@onready var _room_label: Label = %RoomLabel
@onready var _level_label: Label = %LevelLabel
@onready var _exp_bar: ProgressBar = %ExpBar
@onready var _boss_panel: Control = %BossPanel
@onready var _boss_name: Label = %BossName
@onready var _boss_bar: ProgressBar = %BossBar
@onready var _chips: Container = %AbilityChips
@onready var _pause_button: Button = %PauseButton
@onready var _pause_overlay: Control = %PauseOverlay
@onready var _resume_button: Button = %ResumeButton
@onready var _fade: ColorRect = %Fade
@onready var _banner: Label = %Banner

func _ready() -> void:
	_boss_panel.visible = false
	_pause_overlay.visible = false
	_banner.modulate.a = 0.0
	_pause_button.pressed.connect(func() -> void: _set_paused(true))
	_resume_button.pressed.connect(func() -> void: _set_paused(false))

func _set_paused(paused: bool) -> void:
	_pause_overlay.visible = paused
	pause_toggled.emit(paused)

func set_room(number: int, total: int) -> void:
	_room_label.text = "第 %d / %d 間" % [number, total]

func set_level(level: int, experience: int, needed: int) -> void:
	_level_label.text = "Lv %d" % level
	_exp_bar.max_value = needed
	_exp_bar.value = experience

func show_boss(title: String, hp: int, max_hp: int) -> void:
	_boss_panel.visible = true
	_boss_name.text = title
	_boss_bar.max_value = max_hp
	_boss_bar.value = hp

func hide_boss() -> void:
	_boss_panel.visible = false

func add_chip(title: String, color: Color) -> void:
	var chip: Label = chip_scene.instantiate() as Label
	chip.text = title
	chip.self_modulate = color
	_chips.add_child(chip)

func banner(text: String) -> void:
	_banner.text = text
	_banner.modulate.a = 1.0
	var tween: Tween = create_tween()
	tween.tween_interval(0.9)
	tween.tween_property(_banner, "modulate:a", 0.0, 0.4)

func fade_out(duration: float = 0.25) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_fade, "color:a", 1.0, duration)
	await tween.finished

func fade_in(duration: float = 0.3) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_fade, "color:a", 0.0, duration)
	await tween.finished
