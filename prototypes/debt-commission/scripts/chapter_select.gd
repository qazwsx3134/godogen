extends Panel
## 章節選擇 (scenes/ui/chapter_select.tscn): the chapters in order as an episode map — a picture card
## per chapter (scenes/ui/episode_card.tscn) under its 「第 N 章」 plaque, dots linking the cards, the
## current one in brush corners, a locked one dimmed until the chapter before it is cleared — then
## the samples as rows. Picking one makes it the title's
## story. 結局收集 lists every chapter ending: its title once seen, ？？？ before. 鑑賞 opens the
## gallery and 製作名單 the credits roll. Rows are
## scenes/ui/chapter_row.tscn and scenes/ui/ending_row.tscn; colours come from ui_styles.gd.

signal picked(index: int)
signal closed
signal credits_pressed
signal gallery_pressed

const UI_STYLES: Script = preload("res://scripts/ui_styles.gd")
const ROW_SCENE: PackedScene = preload("res://scenes/ui/chapter_row.tscn")
const EPISODE_SCENE: PackedScene = preload("res://scenes/ui/episode_card.tscn")
## How far an episode card stands in from its side; the cards alternate sides as in an episode map.
const CARD_INDENT: Vector2 = Vector2(28.0, 120.0)
const ENDING_ROW_SCENE: PackedScene = preload("res://scenes/ui/ending_row.tscn")
const UNSEEN_ENDING: String = "？？？"

var _style_id: String = "cinema"
## Each row's text by story id (row_text).
var _row_texts: Dictionary = {}

@onready var close_button: Button = %Close
@onready var credits_button: Button = %Credits
@onready var gallery_button: Button = %Gallery
@onready var _chapters: VBoxContainer = %Chapters
@onready var _chapters_empty: Label = %ChaptersEmpty
@onready var _samples: VBoxContainer = %Samples
@onready var _endings: VBoxContainer = %Endings
@onready var _endings_heading: Label = $Margins/Layout/Scroll/List/EndingsHeading


func _ready() -> void:
	visible = false
	close_button.pressed.connect(func() -> void: closed.emit())
	credits_button.pressed.connect(func() -> void: credits_pressed.emit())
	gallery_button.pressed.connect(func() -> void: gallery_pressed.emit())


func set_style(style_id: String) -> void:
	_style_id = style_id


## entries: [{index, id, kind ("chapter"/"sample"), title, note, credit, locked, current}] in order;
## a chapter also has number (1, 2, …), cover ("res://…" or "") and badge (評價・結局, "" for none).
## A sample row shows title, note and `credit` (who wrote and drew it, "" for none) on three lines.
## endings: [{chapter, title, seen}] for the chapters' endings, in order.
func open(entries: Array, endings: Array = []) -> void:
	for list: VBoxContainer in [_chapters, _samples, _endings]:
		for row: Node in list.get_children():
			list.remove_child(row)
			row.queue_free()
	_row_texts.clear()
	for entry: Dictionary in entries:
		var text: String = "%s\n%s" % [entry["title"], entry["note"]]
		if not str(entry.get("credit", "")).is_empty():
			text += "\n" + str(entry["credit"])
		_row_texts[str(entry["id"])] = text
		var button: Button
		if str(entry["kind"]) == "chapter":
			var card: Control = _episode_card(entry, _chapters.get_child_count())
			_chapters.add_child(card)
			button = card.get_node("%Card") as Button
		else:
			button = ROW_SCENE.instantiate() as Button
			button.name = "ChapterRow_%s" % entry["id"]
			button.text = text
			_samples.add_child(button)
		button.disabled = bool(entry["locked"])
		UI_STYLES.apply_button(button, _style_id, "selector", bool(entry["current"]))
		button.pressed.connect(picked.emit.bind(int(entry["index"])))
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


## Row buttons (a chapter's card button) by story id, for QA.
func rows() -> Dictionary:
	var found: Dictionary = {}
	for list: VBoxContainer in [_chapters, _samples]:
		for row: Node in list.get_children():
			if not row.is_queued_for_deletion():
				found[str(row.name).trim_prefix("ChapterRow_")] = row if row is Button else row.get_node("%Card")
	return found


## What a row says, title, note and credit on their lines, by story id (a card spreads it over its
## title, badge and plaque), for tests and QA.
func row_text(story_id: String) -> String:
	return str(_row_texts.get(story_id, ""))


func _episode_card(entry: Dictionary, position: int) -> Control:
	var card: Control = EPISODE_SCENE.instantiate() as Control
	card.name = "ChapterRow_%s" % entry["id"]
	var left: bool = position % 2 == 0
	card.add_theme_constant_override("margin_left", roundi(CARD_INDENT.x if left else CARD_INDENT.y))
	card.add_theme_constant_override("margin_right", roundi(CARD_INDENT.y if left else CARD_INDENT.x))
	card.get_node("Column/Dots").visible = position > 0
	UI_STYLES.apply_label(card.get_node("Column/Dots") as Label, _style_id, "muted")
	(card.get_node("%Number") as Label).text = "第 %d 章" % int(entry.get("number", position + 1))
	var title: String = str(entry["title"])
	(card.get_node("%Title") as Label).text = title.get_slice("・", 1) if title.contains("・") else title
	var locked: bool = bool(entry["locked"])
	var badge: Label = card.get_node("%Badge") as Label
	badge.text = str(entry.get("badge", ""))
	badge.visible = not locked
	(card.get_node("%Lock") as Label).visible = locked
	var thumb: TextureRect = card.get_node("%Thumb") as TextureRect
	var cover: String = str(entry.get("cover", ""))
	thumb.texture = load(cover) as Texture2D if not cover.is_empty() else null
	thumb.modulate = Color(0.45, 0.45, 0.5) if locked else Color.WHITE
	card.get_node("%Corners").visible = bool(entry["current"]) and not locked
	var plaque: PanelContainer = card.get_node("%Plaque") as PanelContainer
	var number: Label = card.get_node("%Number") as Label
	plaque.add_theme_stylebox_override("panel", UI_STYLES.name_plaque(_style_id))
	number.add_theme_color_override("font_color", UI_STYLES.palette(_style_id)["name_ink"] as Color)
	UI_STYLES.set_hud_font(number, _style_id)
	(card.get_node("%Corners")).set("color", UI_STYLES.palette(_style_id)["danger"] as Color)
	var credit: Label = card.get_node("%Credit") as Label
	credit.text = str(entry.get("credit", ""))
	credit.visible = not credit.text.is_empty()
	UI_STYLES.apply_label(credit, _style_id, "muted")
	return card
