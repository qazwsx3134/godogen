extends PanelContainer
## One row in a camp list (ui/item_row.tscn): a title, a detail line and up to three actions.
## row = {title, detail, more, actions: [{label, action: Dictionary, enabled: bool}]}; a row with `more` shows it
## under the detail once tapped, and stays open while the same row is shown again.

signal action_pressed(action: Dictionary)

@onready var _title: Label = %RowTitle
@onready var _detail: Label = %RowDetail
@onready var _buttons: Array[Node] = %RowActions.get_children()

var _actions: Array = []
var _row: Dictionary = {}
var _open: bool = false


func _ready() -> void:
	for i in _buttons.size():
		(_buttons[i] as Button).pressed.connect(func() -> void:
			if i < _actions.size():
				action_pressed.emit(_actions[i].action))
	gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _row.has("more"):
			_open = not _open
			show_row(_row))


## Phones: buttons button_h tall and the row only as tall as they need; else the heights the scene draws.
func set_compact(on: bool, button_h: float) -> void:
	if not has_meta("desk_heights"):
		set_meta("desk_heights", [custom_minimum_size.y, (_buttons[0] as Control).custom_minimum_size.y])
	var desk: Array = get_meta("desk_heights")
	custom_minimum_size.y = 0.0 if on else float(desk[0])
	for b: Node in _buttons:
		(b as Control).custom_minimum_size.y = button_h if on else float(desk[1])


func show_row(row: Dictionary) -> void:
	if row.get("title", "") != _row.get("title", ""):
		_open = false
	_row = row
	_title.text = row.get("title", "")
	_detail.text = row.get("detail", "")
	if row.has("more"):
		_detail.text += ("\n" + str(row.more)) if _open else "　+ 詳情"
	_detail.visible = _detail.text != ""
	_actions = row.get("actions", [])
	for i in _buttons.size():
		var b: Button = _buttons[i]
		b.visible = i < _actions.size()
		if b.visible:
			b.text = _actions[i].label
			b.disabled = not _actions[i].get("enabled", true)
