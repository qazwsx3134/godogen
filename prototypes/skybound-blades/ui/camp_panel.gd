extends PanelContainer
## Camp / bag window (ui/camp_panel.tscn): tabs of rows built by the field from the Run and
## Profile. It only shows rows and reports which action was pressed.

signal action(action: Dictionary)
signal closed

const ItemRow = preload("res://ui/item_row.tscn")
const COMPACT_MARGIN := 16.0
## Phone heights in design px: 68 is about 44 CSS px at the phone design height (field.gd phone_design_height).
const COMPACT_BUTTON_H := 68.0

var _compact: bool = false

@onready var _tabs: TabContainer = %CampTabs
@onready var _header: Label = %CampHeader


func _ready() -> void:
	%CampClose.pressed.connect(func() -> void:
		hide()
		closed.emit())


## tabs = {tab node name: {"rows": [row, ...], "badge": int}}; header = gold/warehouse line.
func show_tabs(tabs: Dictionary, header: String) -> void:
	_header.text = header
	for tab_name: String in tabs:
		var page := _tabs.get_node_or_null(tab_name)
		if page == null:
			continue
		var badge := int(tabs[tab_name].get("badge", 0))
		_tabs.set_tab_title(page.get_index(), tab_name + (" %d" % badge if badge > 0 else ""))
		var list: VBoxContainer = page.get_node("List")
		var rows: Array = tabs[tab_name].rows
		while list.get_child_count() < rows.size():
			var row := ItemRow.instantiate()
			row.action_pressed.connect(func(a: Dictionary) -> void: action.emit(a))
			list.add_child(row)
			row.set_compact(_compact, COMPACT_BUTTON_H)
		for i in list.get_child_count():
			var child: Node = list.get_child(i)
			child.visible = i < rows.size()
			if child.visible:
				child.show_row(rows[i])


## Phones (field.gd fit_screen): the window fills the screen bar a small margin, is opaque (the HUD behind it
## would show through the text) and its rows and buttons are shorter; else it is the centred box the scene draws.
func set_compact(on: bool) -> void:
	_compact = on
	if not has_meta("desk_offsets"):
		set_meta("desk_offsets", [offset_left, offset_top, offset_right, offset_bottom])
		set_meta("desk_close_h", %CampClose.custom_minimum_size.y)
	%CampClose.custom_minimum_size.y = COMPACT_BUTTON_H if on else float(get_meta("desk_close_h"))
	if on:
		var solid := get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		solid.bg_color.a = 1.0
		add_theme_stylebox_override("panel", solid)
	else:
		remove_theme_stylebox_override("panel")
	for page: Node in _tabs.get_children():
		for row: Node in page.get_node("List").get_children():
			row.set_compact(on, COMPACT_BUTTON_H)
	var desk: Array = get_meta("desk_offsets")
	set_anchors_preset(Control.PRESET_FULL_RECT if on else Control.PRESET_CENTER)
	var o: Array = [COMPACT_MARGIN, COMPACT_MARGIN, -COMPACT_MARGIN, -COMPACT_MARGIN] if on else desk
	offset_left = o[0]
	offset_top = o[1]
	offset_right = o[2]
	offset_bottom = o[3]


func select_tab(tab_name: String) -> void:
	var page := _tabs.get_node_or_null(tab_name)
	if page != null:
		_tabs.current_tab = page.get_index()


func current_tab_name() -> String:
	return String(_tabs.get_current_tab_control().name)
