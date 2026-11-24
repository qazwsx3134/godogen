extends Area2D

signal activated(point: Area2D)

@export var prompt_text := "E  Interact"

@onready var _prompt: PanelContainer = %Prompt
@onready var _label: Label = %PromptText


func _ready() -> void:
	_label.text = prompt_text
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(_body: Node2D) -> void:
	_prompt.show()


func _on_body_exited(_body: Node2D) -> void:
	_prompt.hide()


func _unhandled_input(event: InputEvent) -> void:
	if _prompt.visible and event.is_action_pressed(&"interact"):
		get_viewport().set_input_as_handled()
		activated.emit(self)
