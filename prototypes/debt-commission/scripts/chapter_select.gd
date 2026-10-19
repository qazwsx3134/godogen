extends Panel
## 章節選擇 (scenes/ui/chapter_select.tscn): the chapters in order, each locked until the one before
## it is cleared and showing its best grade, then the samples. Picking one makes it the title's
## story. 結局收集 lists every chapter ending: its title once seen, ？？？ before. Rows are
## scenes/ui/chapter_row.tscn and scenes/ui/ending_row.tscn; colours come from ui_styles.gd.

signal picked(index: int)
signal closed

const UI_STYLES: Script = preload("res://scripts/ui_styles.gd")
const ROW_SCENE: PackedScene = preload("res://scenes/ui/chapter_row.tscn")
const ENDING_ROW_SCENE: PackedScene = preload("res://scenes/ui/ending_row.tscn")
const UNSEEN_ENDING: String = "？？？"

var _style_id: String = "cinema"

@onready var close_button: Button = %Close
@onready var _chapters: VBoxContainer = %Chapters
@onready var _chapters_empty: Label = %ChaptersEmpty
@onready var _samples: VBoxContainer = %Samples
@onready var _endings: VBoxContainer = %Endings
@onready var _endings_heading: Label = $Margins/Layout/Scroll/List/EndingsHeading


func _ready() -> void:
	visible = false
	close_button.pressed.connect(func() -> void: closed.emit())


func set_style(style_id: String) -> void:
	_style_id = style_id


## entries: [{index, id, kind ("chapter"/"sample"), title, note, locked, current}] in order.
## endings: [{chapter, title, seen}] for the chapters' endings, in order.
func open(entries: Array, endings: Array = []) -> void:
	for list: VBoxContainer in [_chapters, _samples, _endings]:
		for row: Node in list.get_children():
			list.remove_child(row)
			row.queue_free()
	for entry: Dictionary in entries:
		var row: Button = ROW_SCENE.instantiate() as Button
		row.name = "ChapterRow_%s" % entry["id"]
		row.text = "%s\n%s" % [entry["title"], entry["note"]]
		row.disabled = bool(entry["locked"])
		(_chapters if str(entry["kind"]) == "chapter" else _samples).add_child(row)
		UI_STYLES.apply_button(row, _style_id, "selector", bool(entry["current"]))
		row.pressed.connect(picked.emit.bind(int(entry["index"])))
	_chapters_empty.visible = _chapters.get_child_count() == 0
	for ending: Dictionary in endings:
		var row: Label = ENDING_ROW_SCENE.instantiate() as Label
		var seen: bool = bool(ending["seen"])
		row.text = "%s｜%s" % [ending["chapter"], ending["title"] if seen else UNSEEN_ENDING]
		_endings.add_child(row)
		UI_STYLES.apply_label(row, _style_id, "body" if seen else "muted")
	_endings_heading.visible = not endings.is_empty()
	_endings.visible = not endings.is_empty()
	visible = true


## The 結局收集 rows' text, for QA.
func ending_rows() -> Array[String]:
	var texts: Array[String] = []
	for row: Node in _endings.get_children():
		if not row.is_queued_for_deletion():
			texts.append((row as Label).text)
	return texts


## Row buttons by story id, for QA.
func rows() -> Dictionary:
	var found: Dictionary = {}
	for list: VBoxContainer in [_chapters, _samples]:
		for row: Node in list.get_children():
			found[str(row.name).trim_prefix("ChapterRow_")] = row
	return found
