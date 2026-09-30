extends Control
## Level-up (3 abilities) and angel (heal or ability) choices. Pauses the game while open;
## this panel keeps processing (process_mode ALWAYS in the scene).

signal chosen(index: int)

@export var card_scene: PackedScene

@onready var _title: Label = %Title
@onready var _subtitle: Label = %Subtitle
@onready var _cards: Container = %Cards

func _ready() -> void:
	visible = false

func open(title: String, subtitle: String, options: Array) -> void:
	_title.text = title
	_subtitle.text = subtitle
	for old: Node in _cards.get_children():
		old.queue_free()
	for i: int in options.size():
		var card: Button = card_scene.instantiate() as Button
		_cards.add_child(card)
		card.setup(options[i])
		card.pressed.connect(_pick.bind(i))
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)

func cards() -> Array[Node]:
	return _cards.get_children()

func _pick(index: int) -> void:
	if not visible:
		return
	visible = false
	chosen.emit(index)
