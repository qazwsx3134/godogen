extends HBoxContainer
## One line of a reward list (scenes/reward_row.tscn: the 離線戰報 and 行軍收穫 in camp.tscn): an icon on its rarity
## colour (the same colours as the item and hero cards), the name, the amount on the right.

const PixelUi = preload("res://scripts/pixel_ui.gd")

const RARITY_BG := [Color("5f6b63"), Color("3f6f9e"), Color("7a4fae"), Color("b88a34")]
const PLAIN_BG := Color("2c3530")

@onready var _bg: ColorRect = %IconBg
@onready var _icon: TextureRect = %Icon
@onready var _name: Label = %RowName
@onready var _amount: Label = %Amount


## rarity -1 = a plain dark square (gold, materials). tint and look colour a hero's sprite like the cards do.
func show_row(icon: Texture2D, rarity: int, title: String, amount: String, tint: Color = Color.WHITE,
		look: Material = null) -> void:
	_bg.color = PLAIN_BG if rarity < 0 else RARITY_BG[rarity]
	_icon.texture = icon
	_icon.self_modulate = tint
	_icon.material = look if look != null else PixelUi.material()
	_name.text = title
	_amount.text = amount
