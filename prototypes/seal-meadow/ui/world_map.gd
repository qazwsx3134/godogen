extends Control
## The two available regions and their portal connection; travel still happens in the world.

signal closed

@onready var meadow_here: Label = %MeadowHere
@onready var town_here: Label = %TownHere
@onready var close_button: Button = %MapClose


func _ready() -> void:
	close_button.pressed.connect(func() -> void:
		visible = false
		closed.emit())


func show_zone(zone: String) -> void:
	meadow_here.visible = zone == "meadow"
	town_here.visible = zone == "town"
	visible = true
