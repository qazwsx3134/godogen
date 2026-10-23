extends Button
## One slot of the 道具 page (scenes/item_cell.tscn), after the author's backpack reference (docs/hd-2.5d/backpack.PNG):
## the rarity is the background colour (no frame, the same colours as the hero cards), the icon, a 新 badge top left,
## a caption bottom left (a class name in the 職業武庫, a hero's name under a 專屬飾品), a corner text bottom right (a
## count, Lv or ★), the wearer's small picture for a 專屬飾品 (show_face) and a warm white frame while selected
## (pressed). An empty
## slot (nothing in that armory, a relic not found yet) is grey with a faded icon. The page fills it (items_page.gd).

const PixelUi = preload("res://scripts/pixel_ui.gd")

const RARITY_BG := [Color("5f6b63"), Color("3f6f9e"), Color("7a4fae"), Color("b88a34")]
const EMPTY_BG := Color("2c3530")
## The icon's right and bottom offsets in item_cell.tscn.
const ICON_RIGHT := -10.0
const ICON_BOTTOM := -14.0

## What the cell shows, for the page: {kind, id / cls / k / key}.
var entry: Dictionary = {}

@onready var _bg: TextureRect = %Bg
@onready var _icon: TextureRect = %Icon
@onready var _new: Control = %New
@onready var _caption: Label = %Caption
@onready var _corner: Label = %Corner
@onready var _frame: Control = %Frame
@onready var _face: TextureRect = %Face


func _ready() -> void:
	toggled.connect(func(on: bool) -> void: _frame.visible = on)


## rarity -1 = empty (grey, faded icon).
func show_item(what: Dictionary, icon: Texture2D, rarity: int, corner: String, caption: String = "",
		fresh: bool = false) -> void:
	entry = what
	_bg.self_modulate = EMPTY_BG if rarity < 0 else RARITY_BG[rarity]
	_icon.texture = icon
	_icon.modulate = Color(1, 1, 1, 0.3 if rarity < 0 else 1.0)
	_corner.text = corner
	_caption.text = caption
	_new.visible = fresh
	_face.visible = false
	_icon.offset_right = ICON_RIGHT
	_icon.offset_bottom = ICON_BOTTOM


## The wearer's picture at the lower right (after show_item, which hides it).
func show_face(texture: Texture2D, tint: Color, look: Material) -> void:
	_face.texture = texture
	_face.self_modulate = tint
	_face.material = look if look != null else PixelUi.material()
	_face.visible = true
	# The charm moves up and left so the picture does not cover it.
	_icon.offset_right = ICON_RIGHT - 30.0
	_icon.offset_bottom = ICON_BOTTOM - 16.0
