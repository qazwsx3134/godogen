extends Control
## Player block (portrait, level, HP, EXP), stage number, coins, pause, ability slots, the boss
## layout, banner and fade. Layout, colours and static text live in hud.tscn; this script only
## fills in values and switches between the room layout and the boss layout.
## Feedback on top of that (game/juice.gd asks for it): the HP bar's white trail, number pops, the red
## edge flash when the hero is hurt, the white flash over the screen, the boss bar filling up.

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
@onready var _hp_ghost: ProgressBar = %HpGhost
@onready var _hp_label: Label = %HpLabel
@onready var _exp_bar: ProgressBar = %ExpBar
@onready var _boss_panel: Control = %BossPanel
@onready var _boss_portrait: TextureRect = %BossPortrait
@onready var _boss_name: Label = %BossName
@onready var _boss_bar: ProgressBar = %BossBar
@onready var _bottom_panel: Control = %BottomHeroPanel
@onready var _bottom_portrait: TextureRect = %BottomPortrait
@onready var _bottom_bar: ProgressBar = %BottomHpBar
@onready var _bottom_ghost: ProgressBar = %BottomHpGhost
@onready var _vignette: Control = %Vignette
@onready var _white_flash: ColorRect = %WhiteFlash
@onready var _slot_row: Container = %AbilityChips
@onready var _pause_button: Button = %PauseButton
@onready var _pause_overlay: Control = %PauseOverlay
@onready var _resume_button: Button = %ResumeButton
@onready var _fade: ColorRect = %Fade
@onready var _banner: Label = %Banner

var _slots: Dictionary = {}          # ability id -> slot node
var _recent: Array[StringName] = []  # ability ids, least recently taken first
var _hp_shown: int = -1              # the HP last shown, to tell damage from healing
var _coins_shown: int = 0   # the numbers pop when they go up (set_coins, set_level)
var _level_shown: int = 0
var _exp_shown: int = 0
var _boss_hp: int = 0
var _ghost_tween: Tween
var _boss_fill: Tween
var _vignette_tween: Tween
var _flash_tween: Tween

func _ready() -> void:
	_set_boss_layout(false)
	_pause_overlay.visible = false
	_banner.modulate.a = 0.0
	_vignette.modulate.a = 0.0
	_white_flash.color.a = 0.0
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
	if _level_shown > 0:   # not the first value of the run
		if level > _level_shown:
			pop_level()
		if level > _level_shown or experience > _exp_shown:
			pop_exp()
	_level_shown = level
	_exp_shown = experience

## The bars drop at once; the white ghost bars behind them hold the old HP for a moment, then slide
## down to catch up, so the size of the hit stays visible. Healing moves the ghosts along with the HP.
func set_hp(hp: int, max_hp: int) -> void:
	for bar: ProgressBar in [_hp_bar, _bottom_bar, _hp_ghost, _bottom_ghost]:
		bar.max_value = max_hp
	_hp_bar.value = hp
	_bottom_bar.value = hp
	_hp_label.text = "%d / %d" % [hp, max_hp]
	if _hp_shown < 0 or hp > _hp_shown:
		_stop(_ghost_tween)
		_hp_ghost.value = hp
		_bottom_ghost.value = hp
	elif hp < _hp_shown:
		_stop(_ghost_tween)
		_ghost_tween = create_tween().set_parallel()
		for ghost: ProgressBar in [_hp_ghost, _bottom_ghost]:
			_ghost_tween.tween_property(ghost, "value", float(hp), 0.4).set_delay(0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hp_shown = hp

func set_coins(amount: int) -> void:
	_coin_label.text = str(amount)
	if amount > _coins_shown:
		pop_coin()
	_coins_shown = amount

## Idempotent: the game calls this on every boss hit. A null `portrait` keeps the current picture.
## When the boss bar first appears it fills up from empty.
func show_boss(title: String, hp: int, max_hp: int, portrait: Texture2D = null) -> void:
	var entering: bool = not _boss_panel.visible
	_set_boss_layout(true)
	_boss_name.text = title
	_boss_bar.max_value = max_hp
	_boss_hp = hp
	if entering:
		_boss_bar.value = 0.0
		_stop(_boss_fill)
		_boss_fill = create_tween()
		_boss_fill.tween_method(_fill_boss_bar, 0.0, 1.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	elif _boss_fill == null or not _boss_fill.is_running():
		_boss_bar.value = hp
	if portrait != null:
		_boss_portrait.texture = portrait
		_sync_placeholder(_boss_portrait)

func _fill_boss_bar(progress: float) -> void:
	_boss_bar.value = _boss_hp * progress   # reads the latest HP, so hits during the fill are not lost

func hide_boss() -> void:
	_stop(_boss_fill)
	_set_boss_layout(false)

# --- feedback (asked for by game/juice.gd) --------------------------------------

func _stop(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()

## A control jumps to `from` times its size around its middle and settles back with an overshoot.
func _pop(control: Control, from: Vector2) -> void:
	if control.has_meta(&"pop_tween"):
		_stop(control.get_meta(&"pop_tween") as Tween)
	control.pivot_offset = control.size * 0.5
	control.scale = from
	var tween: Tween = create_tween()
	tween.tween_property(control, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	control.set_meta(&"pop_tween", tween)

func pop_coin() -> void:
	_pop(_coin_label, Vector2(1.35, 1.35))
	_pop(_coin_icon, Vector2(1.25, 1.25))

func pop_exp() -> void:
	_pop(_exp_bar, Vector2(1.0, 2.2))

func pop_level() -> void:
	_pop(_level_label, Vector2(1.45, 1.45))

## The screen edges flash red (strength 0..1), then fade.
func hurt_flash(strength: float = 1.0) -> void:
	_stop(_vignette_tween)
	_vignette.modulate.a = strength
	_vignette_tween = create_tween()
	_vignette_tween.tween_property(_vignette, "modulate:a", 0.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## The whole screen flashes white (alpha `strength`), then fades over `time`.
func white_flash(strength: float = 0.85, time: float = 0.5) -> void:
	_stop(_flash_tween)
	_white_flash.color.a = strength
	_flash_tween = create_tween()
	_flash_tween.tween_property(_white_flash, "color:a", 0.0, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

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
