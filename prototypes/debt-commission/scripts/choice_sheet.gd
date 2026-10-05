extends MarginContainer
## The bottom choice sheet. A pov choice (and a timed tsukkomi) uses the edition's own sheet,
## scenes/ui/choice_sheet_<cinema|ledger|manga>.tscn; a director choice uses scenes/ui/choice_sheet_director.tscn,
## the same in every edition. Rows come from scenes/ui/choice_item_<edition|director>.tscn. While the player
## picks, the sheet takes the dialogue box's place: the prompt (or the line being answered), numbered rows,
## a countdown bar for a timed tsukkomi, and 目錄. main.gd names and connects the rows.

signal menu_pressed
signal censor_pressed
signal super_pressed
## The director sheet has finished springing in: its rows are where they stay.
signal pop_finished

## A pov row's tone marker (%Tone in choice_item_<edition>.tscn): the glyph for each tone.
const TONE_MARKS: Dictionary = {"loud": "！", "calm": "？", "tired": "…"}
## Between a tone marker and the row's label, in the row's own pixels (10 CSS px).
const TONE_GAP: float = 27.692308
const ROW_STATES: Array[StringName] = [&"normal", &"pressed", &"hover", &"hover_pressed", &"disabled", &"focus"]

## The edition a pov sheet belongs to; the director sheet is the same in all of them.
@export_enum("cinema", "ledger", "manga") var style_id: String = "cinema"
## Whose sheet: a pov choice's (and the timed tsukkomi's) in an edition's look, or the director's.
@export_enum("pov", "director") var perspective: String = "pov"
@export var item_scene: PackedScene
## Row numbers in order; rows past the list are numbered with index_format.
@export var index_numerals: PackedStringArray = []
## "%02d" receives the row's number ("SCENE %02d" in the director's sheet).
@export var index_format: String = "%02d"
## "%s" receives the option count: a digit, or 二三四… with count_in_chinese.
@export var count_format: String = "%s 選 1"
@export var count_in_chinese: bool = false
## The director sheet springs in over pop_seconds: its panel grows from pop_from_scale with a small overshoot.
@export var pop_seconds: float = 0.25
@export var pop_from_scale: float = 0.8

@onready var prompt: Label = %Prompt
@onready var count: Label = %Count
@onready var choices: VBoxContainer = %Choices
@onready var choices_scroll: ScrollContainer = %ChoicesScroll
@onready var timer_row: Control = %Timer
@onready var timer_bar: ProgressBar = %TimerBar
@onready var timer_value: Label = %TimerValue
@onready var feedback: Label = %Feedback
@onready var menu_button: Button = %Menu
## The fourth-wall bar of a censored line, tappable while the options run.
@onready var censor_bar: Button = %CensorBar
## The ultimate tsukkomi, once the power gauge is full.
@onready var super_button: Button = %Super
## Only the director sheet has these: its heading, its footnote (hidden without text) and the panel that
## springs in.
@onready var banner: Label = get_node_or_null("%Banner") as Label
@onready var note: Label = get_node_or_null("%Note") as Label
@onready var pop_panel: Control = get_node_or_null("%Panel") as Control

## Tallest the sheet may grow, in its own (unscaled) pixels; main.gd sets it from the screen.
## Past it the rows scroll while the prompt, the countdown and 目錄 stay on screen.
var max_height: float = INF
var _pop_tween: Tween = null
var _pop_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	# Scaled up on narrow phones (main.gd _ui_scale), the sheet grows from its bottom-left corner.
	resized.connect(func() -> void: pivot_offset = Vector2(0.0, size.y))
	menu_button.pressed.connect(func() -> void: menu_pressed.emit())
	censor_bar.pressed.connect(func() -> void: censor_pressed.emit())
	super_button.pressed.connect(func() -> void: super_pressed.emit())
	resized.connect(_cap_height)
	choices.minimum_size_changed.connect(_cap_height)  # wrapped rows settle after they get their width
	sort_children.connect(_hold_pop_scale)


## Replaces the rows and returns them in order. `tones` is the tone of each row ("" for none): a row
## with one shows the round marker of its item scene. The countdown stays hidden until set_timer.
func show_options(prompt_text: String, labels: PackedStringArray, hint: String, tones: PackedStringArray = []) -> Array[Button]:
	clear_options()
	prompt.text = prompt_text
	feedback.text = hint
	var total: int = labels.size()
	count.text = count_format % ("一二三四五六七八九十".substr(total - 1, 1) if count_in_chinese and total >= 1 and total <= 10 else str(total))
	var rows: Array[Button] = []
	for index: int in range(total):
		var row: Button = item_scene.instantiate() as Button
		row.text = labels[index]
		(row.get_node("%Index") as Label).text = index_numerals[index] if index < index_numerals.size() else index_format % (index + 1)
		choices.add_child(row)
		rows.append(row)
		if index < tones.size():
			_show_tone(row, tones[index])
	timer_row.visible = false
	censor_bar.visible = false
	super_button.visible = false
	return rows


## The director's footnote under the rows; hidden when empty.
func set_note(text: String) -> void:
	if note != null:
		note.text = text
		note.visible = not text.is_empty()


## The tone marker of one row, after its number; the row's label starts after the marker. The row's
## styles are shared by every row of the scene, so only a row with a tone gets copies of its own.
func _show_tone(row: Button, tone: String) -> void:
	var marker: Label = row.get_node_or_null("%Tone") as Label
	if marker == null or not TONE_MARKS.has(tone):
		return
	marker.text = TONE_MARKS[tone]
	marker.visible = true
	var indent: float = marker.offset_right + TONE_GAP - (row.get_theme_stylebox(&"normal") as StyleBoxFlat).content_margin_left
	for state: StringName in ROW_STATES:
		var style: StyleBoxFlat = row.get_theme_stylebox(state).duplicate() as StyleBoxFlat
		style.content_margin_left += indent
		row.add_theme_stylebox_override(state, style)


## The director's panel springs in (scale with a small overshoot, a quick fade) within pop_seconds. The
## sheet's own scale is left alone: main.gd sets that for narrow phones.
func pop_in() -> void:
	if pop_panel == null:
		return
	_stop_pop()
	_set_pop_scale(pop_from_scale)
	pop_panel.modulate.a = 0.0
	_pop_tween = create_tween().set_parallel(true)
	_pop_tween.tween_method(_set_pop_scale, pop_from_scale, 1.0, pop_seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pop_tween.tween_property(pop_panel, "modulate:a", 1.0, pop_seconds * 0.4)
	_pop_tween.chain().tween_callback(pop_finished.emit)


func _set_pop_scale(factor: float) -> void:
	_pop_scale = Vector2.ONE * factor
	pop_panel.scale = _pop_scale


## A container puts its children's scale back to 1 whenever it sorts them; the pop puts its own back.
func _hold_pop_scale() -> void:
	if pop_panel != null:
		pop_panel.scale = _pop_scale


func is_popping() -> bool:
	return _pop_tween != null and _pop_tween.is_valid() and _pop_tween.is_running()


func _stop_pop() -> void:
	if _pop_tween != null and _pop_tween.is_valid():
		_pop_tween.kill()
	_pop_tween = null
	_pop_scale = Vector2.ONE
	if pop_panel != null:
		pop_panel.scale = Vector2.ONE
		pop_panel.modulate.a = 1.0


func set_max_height(value: float) -> void:
	max_height = value
	_cap_height()


## Rows at full height while they fit under max_height; otherwise they get the room that is left
## and scroll. Decided from minimum sizes, so it gives the same answer however often layout calls.
func _cap_height() -> void:
	var content: float = choices.get_combined_minimum_size().y
	var fixed: float = get_combined_minimum_size().y - choices_scroll.get_combined_minimum_size().y
	var room: float = maxf(48.0 * 1080.0 / 390.0, max_height - fixed)
	var scroll: bool = content > room + 0.5
	var mode: ScrollContainer.ScrollMode = ScrollContainer.SCROLL_MODE_AUTO if scroll else ScrollContainer.SCROLL_MODE_DISABLED
	var height: float = room if scroll else 0.0
	if choices_scroll.vertical_scroll_mode != mode or not is_equal_approx(choices_scroll.custom_minimum_size.y, height):
		choices_scroll.vertical_scroll_mode = mode
		choices_scroll.custom_minimum_size.y = height


func clear_options() -> void:
	_stop_pop()
	set_note("")
	for row: Node in choices.get_children():
		choices.remove_child(row)
		row.queue_free()


func set_timer(remaining: float, total: float, paused: bool) -> void:
	timer_row.visible = true
	timer_bar.max_value = total
	timer_bar.value = remaining
	timer_value.text = "暫停" if paused else "%d 秒" % ceili(remaining)
