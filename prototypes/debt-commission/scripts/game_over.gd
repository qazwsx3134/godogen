extends Control
## Game Over (scenes/ui/game_over.tscn): shattered glasses and 新八的本體已損毀 over a dark screen,
## the story's end line under it, then retry from the round's checkpoint or back to the title.

signal retry_pressed
signal title_pressed

@onready var message: Label = %Message
@onready var retry_button: Button = %Retry
@onready var title_button: Button = %Title


func _ready() -> void:
	visible = false
	retry_button.pressed.connect(func() -> void: retry_pressed.emit())
	title_button.pressed.connect(func() -> void: title_pressed.emit())


func open(end_text: String) -> void:
	message.text = end_text
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.35)
