extends MarginContainer
## The reading box, one scene per UI edition: scenes/ui/dialogue_box_<style>.tscn.
## Frames, spacing and colors live in the scene; this script only fills it and reports taps.
## The authored reading area stays the same height as ordinary lines change. Longer lines
## remain inside the box and can be read a page at a time.

signal menu_pressed
signal log_pressed
signal auto_pressed
signal skip_pressed
signal advance_pressed
signal collapse_pressed

const UI_STYLES: Script = preload("res://scripts/ui_styles.gd")
const TOPIC_SCENE: PackedScene = preload("res://scenes/ui/investigate_topic.tscn")

## Which edition this scene draws (set in the scene).
@export var style_id: String = "gintama"

@onready var speaker_row: Control = %SpeakerRow
## The plaque width set in the scene, the narrowest it gets.
var _plate_width: float = 0.0
@onready var speaker_mark: Label = %SpeakerMark
@onready var speaker_name: Label = %SpeakerName
@onready var chapter: Label = %Chapter
@onready var text: RichTextLabel = %Text
## Slot for per-mode controls (investigation continue, tsukkomi round buttons).
@onready var actions: Container = %Actions
@onready var toolbar: Container = %Toolbar
@onready var menu_button: Button = %Menu
@onready var log_button: Button = %Log
@onready var auto_button: Button = %Auto
@onready var skip_button: Button = get_node_or_null("%Skip") as Button
@onready var advance_button: Button = %Advance
@onready var page_hint: Label = get_node_or_null("%PageHint") as Label
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
@onready var _body_color: Color = text.get_theme_color("default_color")
@onready var _normal_font_size: int = text.get_theme_font_size("normal_font_size")
var _paper_style: StyleBox
var _line_advance: bool = false


func _ready() -> void:
	# Scaling keeps the authored bottom edge in place.
	resized.connect(func() -> void: pivot_offset = Vector2(0.0, size.y))
	text.get_v_scroll_bar().changed.connect(_refresh_page_hint)
	text.get_v_scroll_bar().value_changed.connect(func(_value: float) -> void: _refresh_page_hint())
	text.resized.connect(_refresh_page_hint)
	actions.child_entered_tree.connect(_on_action_added)
	actions.child_exiting_tree.connect(_on_action_removed)
	for child: Node in actions.get_children():  # the widgets the scene already holds
		_on_action_added(child)
	menu_button.pressed.connect(func() -> void: menu_pressed.emit())
	log_button.pressed.connect(func() -> void: log_pressed.emit())
	auto_button.pressed.connect(func() -> void: auto_pressed.emit())
	if skip_button != null:
		skip_button.pressed.connect(func() -> void: skip_pressed.emit())
	advance_button.pressed.connect(func() -> void: advance_pressed.emit())
	investigation_collapse.pressed.connect(func() -> void: collapse_pressed.emit())
	investigation_continue.visibility_changed.connect(func() -> void:
		investigation_row.visible = investigation_continue.visible
		collapse_tab.visible = investigation_continue.visible)
	_refresh_page_hint.call_deferred()


## The scrollbar represents the full laid-out line, even while its characters are revealing.
func reset_reading_page() -> void:
	text.get_v_scroll_bar().value = 0.0
	_refresh_page_hint.call_deferred()


func set_line_advance(enabled: bool) -> void:
	_line_advance = enabled
	_refresh_page_hint()


func has_next_page() -> bool:
	if not text.scroll_active:
		return false
	var scroll: VScrollBar = text.get_v_scroll_bar()
	return scroll.max_value - scroll.page - scroll.value > 1.0


func advance_reading_page() -> bool:
	if not has_next_page():
		return false
	var scroll: VScrollBar = text.get_v_scroll_bar()
	# Start the next page at the last visible wrapped line, so its first line is not cut in half.
	var next_offset: float = scroll.value
	var page_end: float = scroll.value + scroll.page
	for line: int in range(text.get_line_count()):
		var offset: float = float(text.get_line_offset(line))
		if offset >= page_end:
			break
		if offset > scroll.value + 1.0:
			next_offset = offset
	if next_offset <= scroll.value + 1.0:
		# Extremely tall lines still need to be scrollable.
		next_offset = scroll.value + maxf(1.0, scroll.page * 0.75)
	scroll.value = minf(scroll.max_value - scroll.page, next_offset)
	_refresh_page_hint()
	return true


func reading_page_count() -> int:
	var scroll: VScrollBar = text.get_v_scroll_bar()
	return maxi(1, ceili(scroll.max_value / maxf(scroll.page, 1.0)))


func _refresh_page_hint() -> void:
	if not is_node_ready():
		return
	var more: bool = has_next_page() and text.visible_characters < 0
	if page_hint != null:
		page_hint.visible = more
	advance_button.visible = _line_advance or more


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
			if UI_STYLES.washi(style_id):
				UI_STYLES.apply_button(button, style_id, "reading_action")
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


## display_name "" shows the narrator. A plaque drawn as a nine-patch (CloudPlaque) widens for a
## long name, so the name never runs into its ends; it is never narrower than in the scene.
func set_speaker(display_name: String) -> void:
	speaker_name.text = display_name if not display_name.is_empty() else "旁白"
	if not speaker_row.has_node("NamePlate/CloudPlaque") or not speaker_row.get_node("NamePlate/CloudPlaque") is NinePatchRect:
		return
	if _plate_width <= 0.0:
		_plate_width = speaker_row.offset_right - speaker_row.offset_left
	var ends: float = speaker_name.offset_left - speaker_name.offset_right  # left inset + right inset
	var text_width: float = speaker_name.get_theme_font("font").get_string_size(speaker_name.text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, speaker_name.get_theme_font_size("font_size")).x
	speaker_row.offset_right = speaker_row.offset_left + maxf(_plate_width, text_width + ends + 24.0)


func set_chapter(value: String) -> void:
	chapter.text = value


## body keeps the scene's text color; thought, accent and danger take the edition's palette color.
func set_tone(tone: String) -> void:
	var color: Color = _body_color if tone == "body" else UI_STYLES.palette(style_id).get(tone, _body_color)
	text.add_theme_color_override("font_color", color)
	text.add_theme_color_override("default_color", color)


## Applies only the paper graphic's alpha; text, names, controls and hit targets stay opaque.
func apply_reading_settings(font_scale: float, paper_alpha: float) -> void:
	for kind: String in ["normal", "bold", "italics", "bold_italics", "mono"]:
		text.add_theme_font_size_override(kind + "_font_size", roundi(_normal_font_size * font_scale))
	text.add_theme_font_size_override("font_size", roundi(_normal_font_size * font_scale))
	var panel: PanelContainer = find_child("Panel", true, false) as PanelContainer
	var cutout: NinePatchRect = find_child("PaperCutout", true, false) as NinePatchRect
	if cutout != null:
		cutout.modulate.a = paper_alpha
	elif panel != null:
		if _paper_style == null:
			_paper_style = panel.get_theme_stylebox("panel").duplicate() as StyleBox
		var style: StyleBox = _paper_style.duplicate() as StyleBox
		if style is StyleBoxFlat:
			(style as StyleBoxFlat).bg_color.a = (_paper_style as StyleBoxFlat).bg_color.a * paper_alpha
		elif style is StyleBoxTexture:
			(style as StyleBoxTexture).modulate_color.a = (_paper_style as StyleBoxTexture).modulate_color.a * paper_alpha
		panel.add_theme_stylebox_override("panel", style)


func set_reduce_motion(reduced: bool) -> void:
	for button: Button in [menu_button, log_button, auto_button, skip_button, investigation_collapse]:
		if button != null and button.has_method("set_reduce_motion"):
			button.call("set_reduce_motion", reduced)


func set_auto(active: bool) -> void:
	auto_button.set_pressed_no_signal(active)
	if auto_button.has_method("refresh_state"):
		auto_button.call("refresh_state")


func set_skip(active: bool) -> void:
	if skip_button != null:
		skip_button.set_pressed_no_signal(active)
		skip_button.disabled = auto_button.disabled
		if skip_button.has_method("refresh_state"):
			skip_button.call("refresh_state")


func set_reading_enabled(enabled: bool) -> void:
	auto_button.disabled = not enabled
	set_auto(auto_button.button_pressed)
	set_skip(skip_button.button_pressed if skip_button != null else false)


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
