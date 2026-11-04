extends Panel
## 流程圖 (scenes/ui/flowchart_panel.tscn), opened from 章節選擇: one story at a time, its scenes as
## boxes left to right (scripts/flow_graph.gd). A box the player has been through shows its title;
## the rest are ？？？. Lines between two boxes the player has been through are drawn full, the others
## faint. ‹ › switch story; drag (or scroll) to look around. Boxes are flow_box.tscn.

signal closed
## A story was laid out (opening, ‹ ›); main.gd paints the new boxes.
signal story_changed

const FlowGraph = preload("res://scripts/flow_graph.gd")
const BOX_SCENE: PackedScene = preload("res://scenes/ui/flow_box.tscn")
const LOCKED: String = "？？？"

## Box size and the gaps between columns and rows, in design pixels (1920 wide).
@export var box_size: Vector2 = Vector2(440, 150)
@export var column_gap: float = 120.0
@export var row_gap: float = 48.0
@export var line_color: Color = Color(0.85, 0.72, 0.38)
@export var faint_line_color: Color = Color(0.3, 0.34, 0.44, 0.5)
@export var line_width: float = 6.0

## [{id, title, story (the parsed story), visited (node ids)}] as main.gd passed them.
var stories: Array = []
var index: int = 0
## The shown story's boxes (FlowGraph.boxes) and which of them were reached, by box id.
var boxes: Array[Dictionary] = []
var reached: Dictionary = {}

@onready var close_button: Button = %Close
@onready var prev_button: Button = %Prev
@onready var next_button: Button = %Next
@onready var _story_name: Label = %StoryName
@onready var _progress: Label = %Progress
@onready var _scroll: ScrollContainer = %Scroll
@onready var _canvas: Control = %Canvas

var _dragging: bool = false


func _ready() -> void:
	visible = false
	close_button.pressed.connect(close)
	prev_button.pressed.connect(func() -> void: show_story(index - 1))
	next_button.pressed.connect(func() -> void: show_story(index + 1))
	_canvas.draw.connect(_draw_lines)
	_canvas.gui_input.connect(_on_canvas_input)


func open(story_list: Array, start: int) -> void:
	stories = story_list
	visible = true
	show_story(clampi(start, 0, maxi(stories.size() - 1, 0)))


func close() -> void:
	visible = false
	closed.emit()


func show_story(at: int) -> void:
	if stories.is_empty():
		return
	index = posmod(at, stories.size())
	var entry: Dictionary = stories[index]
	_story_name.text = str(entry["title"])
	prev_button.disabled = stories.size() < 2
	next_button.disabled = stories.size() < 2
	boxes = FlowGraph.boxes(entry["story"] as Dictionary)
	var visited: Array = entry["visited"]
	reached.clear()
	for box: Dictionary in boxes:
		for node_id: String in box["nodes"]:
			if visited.has(node_id):
				reached[box["id"]] = true
				break
	for item: Node in _canvas.get_children():
		_canvas.remove_child(item)
		item.queue_free()
	var extent: Vector2 = Vector2.ZERO
	var endings_total: int = 0
	var endings_seen: int = 0
	for box: Dictionary in boxes:
		var item: Button = BOX_SCENE.instantiate() as Button
		item.name = "Box_" + str(box["id"])
		var seen: bool = reached.has(box["id"])
		var ending: bool = not str(box["ending"]).is_empty()
		if ending:
			endings_total += 1
			endings_seen += int(seen)
		var kind: String = "結局" if ending else ("起點" if box == boxes[0] else ("分歧" if (box["to"] as Array).size() > 1 else ""))
		(item.get_node("%Kind") as Label).text = kind
		(item.get_node("%Title") as Label).text = (str(box["ending"]) if ending else str(box["title"])) if seen else LOCKED
		item.disabled = not seen
		(item.get_node("%Title") as Label).modulate.a = 1.0 if seen else 0.6
		item.position = _box_origin(box)
		item.size = box_size
		_canvas.add_child(item)
		extent = extent.max(item.position + box_size)
	_canvas.custom_minimum_size = extent + Vector2(column_gap, row_gap) * 0.5
	_progress.text = "已走過 %d/%d" % [reached.size(), boxes.size()] + \
		("・結局 %d/%d" % [endings_seen, endings_total] if endings_total > 0 else "")
	_canvas.queue_redraw()
	_scroll.scroll_horizontal = 0
	_scroll.scroll_vertical = 0
	story_changed.emit()


## The box names on the canvas whose title shows, for tests: {box id: shown text}.
func shown() -> Dictionary:
	var found: Dictionary = {}
	for item: Node in _canvas.get_children():
		found[str(item.name).trim_prefix("Box_")] = (item.get_node("%Title") as Label).text
	return found


func _box_origin(box: Dictionary) -> Vector2:
	return Vector2(row_gap + float(box["column"]) * (box_size.x + column_gap),
		row_gap + float(box["row"]) * (box_size.y + row_gap))


func _draw_lines() -> void:
	var by_id: Dictionary = {}
	for box: Dictionary in boxes:
		by_id[box["id"]] = box
	for box: Dictionary in boxes:
		for target: String in box["to"]:
			var other: Dictionary = by_id[target]
			var from: Vector2 = _box_origin(box) + Vector2(box_size.x, box_size.y * 0.5)
			var to: Vector2 = _box_origin(other) + Vector2(0.0, box_size.y * 0.5)
			var bend: float = maxf(absf(to.x - from.x) * 0.5, column_gap)
			var points: PackedVector2Array = []
			for step: int in range(25):
				var t: float = step / 24.0
				points.append(from.bezier_interpolate(from + Vector2(bend, 0.0), to - Vector2(bend, 0.0), to, t))
			var full: bool = reached.has(box["id"]) and reached.has(target)
			_canvas.draw_polyline(points, line_color if full else faint_line_color, line_width if full else line_width * 0.6, true)


## Dragging the canvas pans it (touch is emulated as the mouse in this project).
func _on_canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_dragging = (event as InputEventMouseButton).pressed
	elif event is InputEventMouseMotion and _dragging:
		var motion: Vector2 = (event as InputEventMouseMotion).relative
		_scroll.scroll_horizontal -= int(motion.x)
		_scroll.scroll_vertical -= int(motion.y)
