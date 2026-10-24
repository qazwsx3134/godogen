extends Control
## 製作名單 (scenes/ui/credits_roll.tscn): each story's credits, then the tools and assets the game
## uses (data/credits.json), rolling upward in game time. Dragging or tapping the list takes over
## and stops the roll; with reduced motion it starts still at the top. Sections are
## credits_section.tscn, each role a credits_entry.tscn.

signal closed

const SECTION_SCENE: PackedScene = preload("res://scenes/ui/credits_section.tscn")
const ENTRY_SCENE: PackedScene = preload("res://scenes/ui/credits_entry.tscn")

## Roll speed in design px per second.
@export var roll_speed: float = 110.0
## Where the first section starts when rolling, as a fraction of the box height from its top.
@export_range(0.0, 1.0) var lead_in_ratio: float = 0.6

var rolling: bool = false
var _offset: float = 0.0

@onready var scroll: ScrollContainer = %Scroll
@onready var close_button: Button = %Close
@onready var _list: VBoxContainer = %Roll
@onready var _lead_in: Control = %LeadIn
@onready var _end: Label = %End


func _ready() -> void:
	visible = false
	set_process(false)
	close_button.pressed.connect(close)
	scroll.gui_input.connect(_on_scroll_input)


## sections: [{title, credits: [{role, names}]}] in order. moving: false keeps it still (reduced motion).
func open(sections: Array, moving: bool = true) -> void:
	for child: Node in _list.get_children():
		if child != _lead_in and child != _end:
			_list.remove_child(child)
			child.queue_free()
	for section: Dictionary in sections:
		var heading: Label = SECTION_SCENE.instantiate() as Label
		heading.text = str(section.get("title", ""))
		_insert(heading)
		for credit: Dictionary in section.get("credits", []):
			var entry: Control = ENTRY_SCENE.instantiate() as Control
			(entry.get_node("Role") as Label).text = str(credit["role"])
			(entry.get_node("Names") as Label).text = "\n".join(PackedStringArray(credit["names"]))
			_insert(entry)
	# Rolling starts with the first section in the lower part of the box, so it is read at once.
	_lead_in.custom_minimum_size.y = scroll.size.y * lead_in_ratio if moving else 0.0
	_offset = 0.0
	scroll.scroll_vertical = 0
	rolling = moving
	set_process(moving)
	visible = true


func close() -> void:
	rolling = false
	set_process(false)
	visible = false
	closed.emit()


## Every line of text on the roll, top to bottom, for tests and QA.
func lines() -> Array[String]:
	var texts: Array[String] = []
	for label: Label in _list.find_children("*", "Label", true, false):
		if not label.is_queued_for_deletion() and not label.get_parent().is_queued_for_deletion():
			texts.append(label.text)
	return texts


func _process(delta: float) -> void:
	_offset += roll_speed * delta
	var limit: float = maxf(0.0, _list.size.y - scroll.size.y)
	if _offset >= limit:
		_offset = limit
		rolling = false
		set_process(false)
	scroll.scroll_vertical = roundi(_offset)


func _insert(node: Node) -> void:
	_list.add_child(node)
	_list.move_child(node, _end.get_index())


func _on_scroll_input(event: InputEvent) -> void:
	if rolling and (event is InputEventScreenDrag or event is InputEventScreenTouch
			or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed)):
		rolling = false
		set_process(false)
