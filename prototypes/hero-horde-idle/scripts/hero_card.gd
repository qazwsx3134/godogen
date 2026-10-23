extends Button
## A hero on the 養成 roster (scenes/hero_card.tscn: one instance per hero in growth.tscn's Cards, and the five march
## slots), after the commercial idle layout the author picked (docs/hd-2.5d/hero.PNG): the rarity is the card's
## background colour (no frame), the class icon top left, 行軍 and 隊長 chips top right, a red dot when the hero can be
## ascended, the picture (scripts/portraits.gd), and Lv with five stars (lit = ascensions) along the bottom. The name
## is on the hero page. Tap = the hero page.

const Portraits = preload("res://scripts/portraits.gd")
const Progression = preload("res://domain/progression.gd")
## Background colour by rarity (N, R, SR, SSR); the card shades it from light at the top to dark at the bottom.
const RARITY_BG := [Color("5f6b63"), Color("3f6f9e"), Color("7a4fae"), Color("b88a34")]
const CLASS_ICONS := ["shield", "sword", "spear", "bow", "mage", "healer"]

## Hero index (-1 = an empty march slot).
var hero: int = -1

@onready var _bg: TextureRect = %Bg
@onready var _portrait: TextureRect = %Portrait
@onready var _icon: TextureRect = %ClassIcon
@onready var _march: Control = %MarchChip
@onready var _captain: Control = %CaptainChip
@onready var _level: Label = %Level
@onready var _stars_on: Label = %StarsOn
@onready var _stars_off: Label = %StarsOff
@onready var _dot: Control = %Dot
@onready var _frame: Control = %Frame


func _ready() -> void:
	toggled.connect(func(on: bool) -> void: _frame.visible = on)


func show_hero(i: int, cls: int, hero_name: String, rarity: int, _rarity_name: String, level: int, stars: int,
		marching: bool, captain: bool, can_ascend: bool = false) -> void:
	hero = i
	tooltip_text = hero_name
	_bg.self_modulate = RARITY_BG[rarity]
	_portrait.texture = Portraits.card(cls)
	_portrait.self_modulate = Portraits.tint(i, cls)
	_portrait.material = Portraits.material(rarity)
	_icon.texture = Portraits.class_icon(cls)
	_march.visible = marching
	_captain.visible = captain
	_level.text = "Lv.%d" % level
	_stars_on.text = "★".repeat(stars)
	_stars_off.text = "★".repeat(Progression.MAX_ASCEND - stars)
	_dot.visible = can_ascend
