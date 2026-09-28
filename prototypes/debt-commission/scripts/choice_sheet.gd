extends MarginContainer
## The bottom choice sheet, one scene per UI edition: scenes/ui/choice_sheet_<cinema|ledger|manga>.tscn,
## rows from scenes/ui/choice_item_<edition>.tscn. While the player picks, it takes the dialogue
## box's place: the prompt (or the line being answered), numbered rows, a countdown bar for a
## timed tsukkomi, and 目錄. main.gd names and connects the rows.

signal menu_pressed
signal censor_pressed
signal super_pressed

@export_enum("cinema", "ledger", "manga") var style_id: String = "cinema"
@export var item_scene: PackedScene
## Row numbers in order; rows past the list are numbered 01, 02, ...
@export var index_numerals: PackedStringArray = []
## "%s" receives the option count: a digit, or 二三四… with count_in_chinese.
@export var count_format: String = "%s 選 1"
@export var count_in_chinese: bool = false

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

## Tallest the sheet may grow, in its own (unscaled) pixels; main.gd sets it from the screen.
## Past it the rows scroll while the prompt, the countdown and 目錄 stay on screen.
var max_height: float = INF


func _ready() -> void:
	# Scaled up on narrow phones (main.gd _ui_scale), the sheet grows from its bottom-left corner.
	resized.connect(func() -> void: pivot_offset = Vector2(0.0, size.y))
	menu_button.pressed.connect(func() -> void: menu_pressed.emit())
	censor_bar.pressed.connect(func() -> void: censor_pressed.emit())
	super_button.pressed.connect(func() -> void: super_pressed.emit())
	resized.connect(_cap_height)
	choices.minimum_size_changed.connect(_cap_height)  # wrapped rows settle after they get their width


## Replaces the rows and returns them in order. The countdown stays hidden until set_timer.
func show_options(prompt_text: String, labels: PackedStringArray, hint: String) -> Array[Button]:
	clear_options()
	prompt.text = prompt_text
	feedback.text = hint
	var total: int = labels.size()
	count.text = count_format % ("一二三四五六七八九十".substr(total - 1, 1) if count_in_chinese else str(total))
	var rows: Array[Button] = []
	for index: int in range(total):
		var row: Button = item_scene.instantiate() as Button
		row.text = labels[index]
		(row.get_node("%Index") as Label).text = index_numerals[index] if index < index_numerals.size() else "%02d" % (index + 1)
		choices.add_child(row)
		rows.append(row)
	timer_row.visible = false
	censor_bar.visible = false
	super_button.visible = false
	return rows


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
	for row: Node in choices.get_children():
		choices.remove_child(row)
		row.queue_free()


func set_timer(remaining: float, total: float, paused: bool) -> void:
	timer_row.visible = true
	timer_bar.max_value = total
	timer_bar.value = remaining
	timer_value.text = "暫停" if paused else "%d 秒" % ceili(remaining)
