extends HBoxContainer
## One line of a list (bag, shop): name, a short info text and one action button.

signal action_pressed

@onready var name_label: Label = %Name
@onready var info_label: Label = %Info
@onready var action_button: Button = %Action


func _ready() -> void:
	action_button.pressed.connect(func() -> void: action_pressed.emit())


func setup(item_name: String, info: String, action_text: String, enabled: bool = true) -> void:
	name_label.text = item_name
	info_label.text = info
	action_button.text = action_text
	action_button.visible = action_text != ""
	action_button.disabled = not enabled
