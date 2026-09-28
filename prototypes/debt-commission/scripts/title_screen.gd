extends Control
## Title screen, one scene per UI edition: scenes/ui/title_screen_<cinema|ledger|manga>.tscn. The
## story's exterior photo under the edition's wash, and a card at the bottom: which sample story
## (tap for 章節選擇), the game title, 開始故事 / 繼續 / 讀取存檔・設定 and the edition picker.

signal begin_pressed
signal continue_pressed
signal load_pressed
signal settings_pressed
signal story_switch_pressed
signal style_pressed(style_id: String)

@export_enum("cinema", "ledger", "manga") var style_id: String = "cinema"

@onready var background: TextureRect = %Background
## Bottom-anchored card area; main.gd scales it up on narrow phones.
@onready var card_area: Control = %CardArea
@onready var story_switch: Button = %StorySwitch
@onready var begin_button: Button = %Begin
@onready var continue_button: Button = %Continue
@onready var load_button: Button = %Load
@onready var settings_button: Button = %Settings
@onready var error_label: Label = %Error
@onready var style_buttons: Dictionary = {"cinema": %Style_cinema, "ledger": %Style_ledger, "manga": %Style_manga}


func _ready() -> void:
	begin_button.pressed.connect(func() -> void: begin_pressed.emit())
	continue_button.pressed.connect(func() -> void: continue_pressed.emit())
	load_button.pressed.connect(func() -> void: load_pressed.emit())
	settings_button.pressed.connect(func() -> void: settings_pressed.emit())
	story_switch.pressed.connect(func() -> void: story_switch_pressed.emit())
	for id: String in style_buttons.keys():
		(style_buttons[id] as Button).pressed.connect(func() -> void: style_pressed.emit(id))
	card_area.resized.connect(func() -> void: card_area.pivot_offset = Vector2(0.0, card_area.size.y))


func set_error(message: String) -> void:
	error_label.text = message
	error_label.visible = not message.is_empty()


func set_active_style(id: String) -> void:
	for key: String in style_buttons.keys():
		(style_buttons[key] as Button).set_pressed_no_signal(key == id)
