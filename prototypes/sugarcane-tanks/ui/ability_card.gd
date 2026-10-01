extends Button
## One choice on the level-up or angel panel: the ability's picture (a coloured square while it has
## none, like the angel's heal), title, description and "owned / max" stack count. Layout lives in
## ability_card.tscn; the card is tall enough for the title and three lines of description.

@onready var _swatch: ColorRect = %Swatch
@onready var _icon: TextureRect = %Icon
@onready var _title: Label = %Title
@onready var _description: Label = %Description
@onready var _stack: Label = %Stack

func setup(option: Dictionary) -> void:
	var picture: Texture2D = option.get("icon")
	_icon.texture = picture
	_icon.visible = picture != null
	_swatch.visible = picture == null
	_swatch.color = option.get("color", Color.WHITE)
	_title.text = option.get("title", "")
	# A multi-line text in a .tres checked out with Windows line endings holds "\r\n"; the Label would
	# break the line twice and show a blank line that pushes the second line out of the frame.
	_description.text = String(option.get("description", "")).replace("\r", "")
	_stack.text = option.get("stack", "")
