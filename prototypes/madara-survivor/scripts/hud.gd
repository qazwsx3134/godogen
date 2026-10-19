class_name Hud
extends CanvasLayer
## The run's screen layer: joystick and dash button, HP / chakra (XP) bars, timer, the kill counter and the multi-kill
## banner, level-up cards, the result panel and the performance line. Layout, fonts and colors live in hud.tscn.

signal option_picked(index: int)
signal restart_pressed

@export var card_scene: PackedScene
## Seconds the multi-kill banner stays after the streak ends.
@export var combo_hold: float = 1.2

@onready var stick: TouchStick = %Stick
@onready var dash_button: TouchButton = %DashButton
@onready var ult_button: TouchButton = %UltButton
@onready var sus_button: TouchButton = %SusButton
@onready var _dominance: ProgressBar = %DominanceBar
@onready var _dominance_label: Label = %DominanceLabel
@onready var _darken: ColorRect = %Darken
@onready var _flash: ColorRect = %Flash
@onready var _xp: ProgressBar = %XpBar
@onready var _hp: ProgressBar = %HpBar
@onready var _level: Label = %LevelLabel
@onready var _time: Label = %TimeLabel
@onready var _kills: Label = %KillsLabel
@onready var _combo: Control = %Combo
@onready var _combo_count: Label = %ComboCount
@onready var _combo_title: Label = %ComboTitle
@onready var _perf: Label = %Perf
@onready var _level_up: Control = %LevelUp
@onready var _cards: Container = %Cards
@onready var _result: Control = %Result
@onready var _result_title: Label = %ResultTitle
@onready var _result_stats: Label = %ResultStats
@onready var _restart: Button = %Restart

var _combo_left: float = 0.0
var _shown_count: int = 0


func _ready() -> void:
	_level_up.visible = false
	_result.visible = false
	_combo.visible = false
	ult_button.visible = false
	sus_button.visible = false
	_darken.modulate.a = 0.0
	_flash.modulate.a = 0.0
	_restart.pressed.connect(func() -> void: restart_pressed.emit())
	# The editor shows sample cards; the run fills real ones.
	for child: Node in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()


## Dominance 0..1 and the stage name for it; the ultimate button shows once learned and lights up when full.
func show_dominance(ratio: float, stage: String, ultimate_learned: bool) -> void:
	_dominance.value = ratio * 100.0
	_dominance_label.text = stage
	ult_button.visible = ultimate_learned
	ult_button.modulate = Color.WHITE if ratio >= 1.0 else Color(1, 1, 1, 0.4)
	ult_button.cooldown_ratio = 1.0 - ratio


## The Susanoo button shows once learned; dimmed with a sweep while it cools down.
func show_susanoo(learned: bool, ready_ratio: float) -> void:
	sus_button.visible = learned
	sus_button.modulate = Color.WHITE if ready_ratio >= 1.0 else Color(1, 1, 1, 0.45)
	sus_button.cooldown_ratio = 1.0 - ready_ratio


## Dims the battlefield (0..1) for the ultimate.
func darken(amount: float) -> void:
	create_tween().tween_property(_darken, "modulate:a", amount, 0.35)


## A white flash that fades out.
func flash(strength: float = 1.0) -> void:
	_flash.modulate.a = strength
	create_tween().tween_property(_flash, "modulate:a", 0.0, 0.45)


func _process(delta: float) -> void:
	if _combo_left > 0.0:
		_combo_left -= delta
		if _combo_left <= 0.0:
			_combo.visible = false
			_shown_count = 0


func show_stats(level: int, xp_ratio: float, hp: float, max_hp: float, seconds: float, kills: int, dash_ratio: float) -> void:
	_level.text = "Lv.%d" % level
	_xp.value = xp_ratio * 100.0
	_hp.max_value = max_hp
	_hp.value = hp
	_time.text = "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]
	_kills.text = str(kills)
	dash_button.cooldown_ratio = dash_ratio


## The live count of the current kill streak, with a title once it is big enough. Pops when it grows.
func show_combo(count: int, title: String) -> void:
	_combo_count.text = "%d KILLS" % count
	_combo_title.text = title
	_combo_title.visible = not title.is_empty()
	_combo.visible = true
	_combo_left = combo_hold
	if count > _shown_count:
		_combo.pivot_offset = _combo.size * 0.5
		_combo.scale = Vector2.ONE * 1.25
		create_tween().tween_property(_combo, "scale", Vector2.ONE, 0.12)
	_shown_count = count


func combo_visible() -> bool:
	return _combo.visible


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
	stick.enabled = false


func level_up_open() -> bool:
	return _level_up.visible


func card_count() -> int:
	return _cards.get_child_count()


func pick_card(index: int) -> void:
	(_cards.get_child(index) as Button).pressed.emit()


func close_level_up() -> void:
	_level_up.visible = false
	stick.enabled = true


func _pick(index: int) -> void:
	close_level_up()
	option_picked.emit(index)


func show_result(won: bool, seconds: float, kills: int, level: int, best_combo: int) -> void:
	_result_title.text = "戰場已被支配" if won else "倒下了"
	_result_stats.text = "%d:%02d · 擊倒 %d · 最大連殺 %d · Lv.%d" % [int(seconds) / 60, int(seconds) % 60, kills, best_combo, level]
	_result.visible = true
	stick.enabled = false


func result_open() -> bool:
	return _result.visible
