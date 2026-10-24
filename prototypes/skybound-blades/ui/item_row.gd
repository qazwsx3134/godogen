extends PanelContainer
## One row in a camp list (ui/item_row.tscn): a title, a detail line and up to three actions.
## row = {title, detail, actions: [{label, action: Dictionary, enabled: bool}]}

signal action_pressed(action: Dictionary)

@onready var _title: Label = %RowTitle
@onready var _detail: Label = %RowDetail
@onready var _buttons: Array[Node] = %RowActions.get_children()

var _actions: Array = []


func _ready() -> void:
	for i in _buttons.size():
		(_buttons[i] as Button).pressed.connect(func() -> void:
			if i < _actions.size():
				action_pressed.emit(_actions[i].action))


func show_row(row: Dictionary) -> void:
	_title.text = row.get("title", "")
	_detail.text = row.get("detail", "")
	_detail.visible = _detail.text != ""
	_actions = row.get("actions", [])
	for i in _buttons.size():
		var b: Button = _buttons[i]
		b.visible = i < _actions.size()
		if b.visible:
			b.text = _actions[i].label
			b.disabled = not _actions[i].get("enabled", true)
