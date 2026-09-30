extends Control
## Player block (portrait, level, HP, EXP), stage number, coins, pause, ability slots, the boss
## layout, banner and fade. Layout, colours and static text live in hud.tscn; this script only
## fills in values and switches between the room layout and the boss layout.

signal pause_toggled(paused: bool)

const MAX_SLOTS: int = 5

@export var slot_scene: PackedScene

@onready var joystick: Control = %Joystick
@onready var _room_label: Label = %RoomLabel
@onready var _coin_icon: TextureRect = %CoinIcon
@onready var _coin_label: Label = %CoinLabel
@onready var _player_panel: Control = %PlayerPanel
@onready var _hero_portrait: TextureRect = %HeroPortrait
@onready var _level_label: Label = %LevelLabel
@onready var _hp_bar: ProgressBar = %HpBar
@onready var _hp_label: Label = %HpLabel
@onready var _exp_bar: ProgressBar = %ExpBar
@onready var _boss_panel: Control = %BossPanel
@onready var _boss_portrait: TextureRect = %BossPortrait
@onready var _boss_name: Label = %BossName
@onready var _boss_bar: ProgressBar = %BossBar
@onready var _bottom_panel: Control = %BottomHeroPanel
@onready var _bottom_portrait: TextureRect = %BottomPortrait
@onready var _bottom_bar: ProgressBar = %BottomHpBar
@onready var _slot_row: Container = %AbilityChips
@onready var _pause_button: Button = %PauseButton
@onready var _pause_overlay: Control = %PauseOverlay
@onready var _resume_button: Button = %ResumeButton
@onready var _fade: ColorRect = %Fade
@onready var _banner: Label = %Banner

var _slots: Dictionary = {}          # ability id -> slot node
var _recent: Array[StringName] = []  # ability ids, least recently taken first

func _ready() -> void:
	_set_boss_layout(false)
	_pause_overlay.visible = false
	_banner.modulate.a = 0.0
	for sample: Node in _slot_row.get_children():   # sample slots that only fill the editor view
		_slot_row.remove_child(sample)
		sample.queue_free()
	if _bottom_portrait.texture == null:
		_bottom_portrait.texture = _hero_portrait.texture
	for portrait: TextureRect in [_hero_portrait, _boss_portrait, _bottom_portrait, _coin_icon]:
		_sync_placeholder(portrait)
	_pause_button.pressed.connect(func() -> void: _set_paused(true))
	_resume_button.pressed.connect(func() -> void: _set_paused(false))

## The gold ring / gold disc (child "Frame") is a stand-in: shown only while the picture is empty.
func _sync_placeholder(rect: TextureRect) -> void:
	var frame: CanvasItem = rect.get_node_or_null("Frame") as CanvasItem
	if frame != null:
		frame.visible = rect.texture == null

func _set_boss_layout(boss: bool) -> void:
	_boss_panel.visible = boss
	_bottom_panel.visible = boss
	_player_panel.visible = not boss
	_slot_row.visible = not boss

func _set_paused(paused: bool) -> void:
	_pause_overlay.visible = paused
	pause_toggled.emit(paused)

func set_room(number: int, _total: int = 0) -> void:
	_room_label.text = "%02d" % number

func set_level(level: int, experience: int, needed: int) -> void:
	_level_label.text = "LV %d" % level
	_exp_bar.max_value = needed
	_exp_bar.value = experience

func set_hp(hp: int, max_hp: int) -> void:
	for bar: ProgressBar in [_hp_bar, _bottom_bar]:
		bar.max_value = max_hp
		bar.value = hp
	_hp_label.text = "%d / %d" % [hp, max_hp]

func set_coins(amount: int) -> void:
	_coin_label.text = str(amount)

## Idempotent: the game calls this on every boss hit. A null `portrait` keeps the current picture.
func show_boss(title: String, hp: int, max_hp: int, portrait: Texture2D = null) -> void:
	_set_boss_layout(true)
	_boss_name.text = title
	_boss_bar.max_value = max_hp
	_boss_bar.value = hp
	if portrait != null:
		_boss_portrait.texture = portrait
		_sync_placeholder(_boss_portrait)

func hide_boss() -> void:
	_set_boss_layout(false)

## One slot per ability: taking it again only updates the pips. Only the MAX_SLOTS most recently
## taken abilities are shown.
func set_ability(def: Resource, stacks: int) -> void:
	var slot: Control = _slots.get(def.id)
	if slot == null:
		slot = slot_scene.instantiate() as Control
		_slot_row.add_child(slot)
		_slots[def.id] = slot
	slot.setup(def, stacks)
	_recent.erase(def.id)
	_recent.append(def.id)
	while _recent.size() > MAX_SLOTS:
		var oldest: StringName = _recent.pop_front()
		var gone: Control = _slots[oldest]
		_slots.erase(oldest)
		_slot_row.remove_child(gone)
		gone.queue_free()

func banner(text: String) -> void:
	_banner.text = text
	_banner.modulate.a = 1.0
	var tween: Tween = create_tween()
	tween.tween_interval(0.9)
	tween.tween_property(_banner, "modulate:a", 0.0, 0.4)

func fade_out(duration: float = 0.25) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_fade, "color:a", 1.0, duration)
	await tween.finished

func fade_in(duration: float = 0.3) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_fade, "color:a", 0.0, duration)
	await tween.finished
