extends PanelContainer
## Camp / bag window (ui/camp_panel.tscn): tabs of rows built by the field from the Run and
## Profile. It only shows rows and reports which action was pressed.

signal action(action: Dictionary)
signal closed

const ItemRow = preload("res://ui/item_row.tscn")

@onready var _tabs: TabContainer = %CampTabs
@onready var _header: Label = %CampHeader


func _ready() -> void:
	%CampClose.pressed.connect(func() -> void:
		hide()
		closed.emit())


## tabs = {tab node name: {"rows": [row, ...], "hint": String}}; header = gold/warehouse line.
func show_tabs(tabs: Dictionary, header: String) -> void:
	_header.text = header
	for tab_name: String in tabs:
		var page := _tabs.get_node_or_null(tab_name)
		if page == null:
			continue
		var list: VBoxContainer = page.get_node("List")
		var rows: Array = tabs[tab_name].rows
		while list.get_child_count() < rows.size():
			var row := ItemRow.instantiate()
			row.action_pressed.connect(func(a: Dictionary) -> void: action.emit(a))
			list.add_child(row)
		for i in list.get_child_count():
			var child: Node = list.get_child(i)
			child.visible = i < rows.size()
			if child.visible:
				child.show_row(rows[i])


func select_tab(tab_name: String) -> void:
	var page := _tabs.get_node_or_null(tab_name)
	if page != null:
		_tabs.current_tab = page.get_index()


func current_tab_name() -> String:
	return String(_tabs.get_current_tab_control().name)
