extends VBoxContainer
## One picked ability in the bottom bar: its icon, and yellow pips for how many stacks it has.
## Look and layout live in ability_slot.tscn. While the ability has no icon, the dark green-rimmed
## frame with a coloured square and the first letter of the title stands in for it.

const MAX_PIPS: int = 3

@onready var _frame: Control = %Frame
@onready var _swatch: Control = %Swatch
@onready var _initial: Label = %Initial
@onready var _icon: TextureRect = %Icon
@onready var _pips: Label = %Pips

func setup(def: Resource, stacks: int) -> void:
	_icon.texture = def.icon
	_frame.visible = def.icon == null
	_swatch.self_modulate = def.color
	_initial.text = def.title.left(1)
	var total: int = mini(def.max_stacks, MAX_PIPS)
	var filled: int = mini(stacks, total)
	_pips.text = "◆".repeat(filled) + "◇".repeat(total - filled)
