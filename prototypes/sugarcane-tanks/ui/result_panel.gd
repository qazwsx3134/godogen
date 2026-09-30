extends Control
## Defeat / chapter clear screen.

signal restart_requested

@onready var _title: Label = %Title
@onready var _summary: Label = %Summary
@onready var _restart: Button = %RestartButton

func _ready() -> void:
	visible = false
	_restart.pressed.connect(func() -> void: restart_requested.emit())

func open(title: String, summary: String) -> void:
	_title.text = title
	_summary.text = summary
	visible = true
