extends Control
## Title screen (scenes/ui/title_screen_gintama.tscn): the story's exterior photo under a wash, and
## a card at the bottom: the story on its plaque (tap for 章節選擇), the game title and
## 開始故事 / 繼續 / 讀取存檔・設定.

signal begin_pressed
signal continue_pressed
signal load_pressed
signal settings_pressed
signal story_switch_pressed

@export var style_id: String = "gintama"

@onready var background: TextureRect = %Background
## Authored card area; main.gd applies the shared interface scale.
@onready var card_area: Control = %CardArea
@onready var story_switch: Button = %StorySwitch
@onready var begin_button: Button = %Begin
@onready var continue_button: Button = %Continue
@onready var load_button: Button = %Load
@onready var settings_button: Button = %Settings
@onready var error_label: Label = %Error


func _ready() -> void:
	begin_button.pressed.connect(func() -> void: begin_pressed.emit())
	continue_button.pressed.connect(func() -> void: continue_pressed.emit())
	load_button.pressed.connect(func() -> void: load_pressed.emit())
	settings_button.pressed.connect(func() -> void: settings_pressed.emit())
	story_switch.pressed.connect(func() -> void: story_switch_pressed.emit())
	card_area.resized.connect(func() -> void: card_area.pivot_offset = Vector2(0.0, card_area.size.y))


func set_error(message: String) -> void:
	error_label.text = message
	error_label.visible = not message.is_empty()


