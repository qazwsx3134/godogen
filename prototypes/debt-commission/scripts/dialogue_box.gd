extends MarginContainer
## The reading box, one scene per UI edition: scenes/ui/dialogue_box_<style>.tscn.
## Frames, spacing and colors live in the scene; this script only fills it and reports taps.
## The box sits at the bottom of the game area and grows upward to fit the whole line, so its
## height stays put while the line types out (visible_characters after shaping).

signal menu_pressed
signal log_pressed
signal auto_pressed
signal advance_pressed
signal collapse_pressed

const UI_STYLES: Script = preload("res://scripts/ui_styles.gd")
const TOPIC_SCENE: PackedScene = preload("res://scenes/ui/investigate_topic.tscn")

## Which edition this scene draws (set in the scene).
@export_enum("cinema", "ledger", "manga", "gintama") var style_id: String = "cinema"

@onready var speaker_row: Control = %SpeakerRow
@onready var speaker_mark: Label = %SpeakerMark
@onready var speaker_name: Label = %SpeakerName
@onready var chapter: Label = %Chapter
@onready var text: Label = %Text
## Slot for per-mode controls (investigation continue, tsukkomi round buttons).
@onready var actions: Container = %Actions
@onready var toolbar: Container = %Toolbar
@onready var menu_button: Button = %Menu
@onready var log_button: Button = %Log
@onready var auto_button: Button = %Auto
@onready var advance_button: Button = %Advance
## Action widgets in the slot: the investigation row (continue) and the round bar with its censor
## bar. While main shows the continue button, the 收起 tab on the box's top-right edge shows too.
@onready var investigation_row: Control = %InvestigationRow
@onready var collapse_tab: Control = %CollapseTab
@onready var investigation_collapse: Button = %InvestigationCollapse
@onready var investigation_continue: Button = %InvestigationContinue
## The search's 對話 and 移動 rows (set_topics), above the continue row.
@onready var investigation_topics: Control = %InvestigationTopics
@onready var talk_row: Control = %TalkRow
@onready var talk_list: Container = %TalkList
@onready var move_row: Control = %MoveRow
@onready var move_list: Container = %MoveList
@onready var round_controls: Control = %RoundControls
@onready var censor_bar: Button = %CensorBar
@onready var boke_previous: Button = %BokePrevious
@onready var boke_line_index: Label = %BokeLineIndex
@onready var boke_next: Button = %BokeNext
@onready var boke_listen: Button = %BokeListen
@onready var boke_tsukkomi: Button = %BokeTsukkomi
@onready var _body_color: Color = text.get_theme_color("font_color")


func _ready() -> void:
	# Scaled up on narrow phones (main.gd _ui_scale), the box grows from its bottom-left corner.
	resized.connect(func() -> void: pivot_offset = Vector2(0.0, size.y))
	actions.child_entered_tree.connect(_on_action_added)
	actions.child_exiting_tree.connect(_on_action_removed)
	for child: Node in actions.get_children():  # the widgets the scene already holds
		_on_action_added(child)
	menu_button.pressed.connect(func() -> void: menu_pressed.emit())
	log_button.pressed.connect(func() -> void: log_pressed.emit())
	auto_button.pressed.connect(func() -> void: auto_pressed.emit())
	advance_button.pressed.connect(func() -> void: advance_pressed.emit())
	investigation_collapse.pressed.connect(func() -> void: collapse_pressed.emit())
	investigation_continue.visibility_changed.connect(func() -> void:
		investigation_row.visible = investigation_continue.visible
		collapse_tab.visible = investigation_continue.visible)


## Fills the 對話 and 移動 rows with one scenes/ui/investigate_topic.tscn per entry ({id, label}),
## styled like this edition's 聽下去; a row without entries hides. Returns
## {"talk:<id>" | "move:<id>": Button} for main.gd to connect.
func set_topics(talk: Array, moves: Array) -> Dictionary:
	var buttons: Dictionary = {}
	for group: Array in [[talk_list, talk, "talk"], [move_list, moves, "move"]]:
		var list: Container = group[0]
		for old: Node in list.get_children():
			list.remove_child(old)
			old.queue_free()
		for entry: Dictionary in group[1]:
			var button: Button = TOPIC_SCENE.instantiate() as Button
			button.text = str(entry.get("label", ""))
			button.name = "%s_%s" % [group[2], entry.get("id", "")]
			_style_like(button, boke_listen)
			list.add_child(button)
			buttons["%s:%s" % [group[2], entry.get("id", "")]] = button
	talk_row.visible = talk_list.get_child_count() > 0
	move_row.visible = move_list.get_child_count() > 0
	investigation_topics.visible = talk_row.visible or move_row.visible
	return buttons


func _style_like(button: Button, model: Button) -> void:
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		if model.has_theme_stylebox_override(state):
			button.add_theme_stylebox_override(state, model.get_theme_stylebox(state))
	for color: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_hover_pressed_color", "font_disabled_color"]:
		if model.has_theme_color_override(color):
			button.add_theme_color_override(color, model.get_theme_color(color))


## display_name "" shows the narrator.
func set_speaker(display_name: String) -> void:
	speaker_name.text = display_name if not display_name.is_empty() else "旁白"


func set_chapter(value: String) -> void:
	chapter.text = value


## body keeps the scene's text color; thought, accent and danger take the edition's palette color.
func set_tone(tone: String) -> void:
	var color: Color = _body_color if tone == "body" else UI_STYLES.palette(style_id).get(tone, _body_color)
	text.add_theme_color_override("font_color", color)


func set_auto(active: bool) -> void:
	auto_button.set_pressed_no_signal(active)


## Shows the actions slot only while something in it is visible.
func refresh_actions() -> void:
	var any_visible: bool = false
	for child: Node in actions.get_children():
		any_visible = any_visible or (child as CanvasItem).visible
	actions.visible = any_visible


func _on_action_added(node: Node) -> void:
	(node as CanvasItem).visibility_changed.connect(refresh_actions)
	refresh_actions()


func _on_action_removed(node: Node) -> void:
	if (node as CanvasItem).visibility_changed.is_connected(refresh_actions):
		(node as CanvasItem).visibility_changed.disconnect(refresh_actions)
	refresh_actions.call_deferred()
