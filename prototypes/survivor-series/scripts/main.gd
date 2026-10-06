extends Node
## Scene navigation only. Gameplay rules are settled in the design interview.

@onready var menu: Control = %Menu
@onready var arena: Node2D = %Arena
@onready var preview_hud: Control = %PreviewHud

func _ready() -> void:
	%OpenArena.pressed.connect(open_arena)
	%ReturnToMenu.pressed.connect(return_to_menu)
	return_to_menu()

func open_arena() -> void:
	menu.hide()
	arena.show()
	preview_hud.show()

func return_to_menu() -> void:
	preview_hud.hide()
	arena.hide()
	menu.show()
