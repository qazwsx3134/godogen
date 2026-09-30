extends Button
## One choice on the level-up or angel panel.

@onready var _swatch: ColorRect = %Swatch
@onready var _title: Label = %Title
@onready var _description: Label = %Description
@onready var _stack: Label = %Stack

func setup(option: Dictionary) -> void:
	_swatch.color = option.get("color", Color.WHITE)
	_title.text = option.get("title", "")
	_description.text = option.get("description", "")
	_stack.text = option.get("stack", "")
