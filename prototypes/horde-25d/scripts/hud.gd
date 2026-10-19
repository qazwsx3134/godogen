class_name Hud
extends CanvasLayer
## The run's screen layer: joystick, bars, timer, level-up cards, the result panel and the performance line.

signal option_picked(index: int)
signal restart_pressed

@export var card_scene: PackedScene

@onready var stick: Control = %Stick
@onready var _xp: ProgressBar = %XpBar
@onready var _hp: ProgressBar = %HpBar
@onready var _level: Label = %LevelLabel
@onready var _time: Label = %TimeLabel
@onready var _kills: Label = %KillsLabel
@onready var _perf: Label = %Perf
@onready var _level_up: Control = %LevelUp
@onready var _cards: Container = %Cards
@onready var _result: Control = %Result
@onready var _result_title: Label = %ResultTitle
@onready var _result_stats: Label = %ResultStats
@onready var _restart: Button = %Restart


func _ready() -> void:
	_level_up.visible = false
	_result.visible = false
	_restart.pressed.connect(func() -> void: restart_pressed.emit())
	# The editor shows sample cards; the run fills real ones.
	for child: Node in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()


func show_stats(level: int, xp_ratio: float, hp: float, max_hp: float, seconds: float, kills: int) -> void:
	_level.text = "Lv.%d" % level
	_xp.value = xp_ratio * 100.0
	_hp.max_value = max_hp
	_hp.value = hp
	_time.text = "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]
	_kills.text = "擊倒 %d" % kills


func show_perf(text: String) -> void:
	_perf.text = text


func set_perf_visible(on: bool) -> void:
	_perf.visible = on


func show_level_up(options: Array[Dictionary]) -> void:
	for child: Node in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	for i: int in options.size():
		var card: UpgradeCard = card_scene.instantiate()
		_cards.add_child(card)
		card.show_option(options[i])
		card.pressed.connect(func() -> void: _pick(i))
	_level_up.visible = true
	stick.release()


func level_up_open() -> bool:
	return _level_up.visible


func card_count() -> int:
	return _cards.get_child_count()


func close_level_up() -> void:
	_level_up.visible = false


func _pick(index: int) -> void:
	_level_up.visible = false
	option_picked.emit(index)


func show_result(won: bool, seconds: float, kills: int, level: int) -> void:
	_result_title.text = "撐過來了！" if won else "倒下了"
	_result_stats.text = "存活 %d:%02d · 擊倒 %d · Lv.%d" % [int(seconds) / 60, int(seconds) % 60, kills, level]
	_result.visible = true
	stick.release()


func result_open() -> bool:
	return _result.visible
