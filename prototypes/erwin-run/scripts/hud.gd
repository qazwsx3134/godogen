extends CanvasLayer
## In-run HUD: lives, progress to the boss, score, hints and banners, the hurt flash and touch hints.
## Input never goes through here (main.gd reads keys and touches); the touch pads are pictures only.

signal pause_pressed

@export var heart_full: Texture2D
@export var heart_empty: Texture2D

@onready var hearts: HBoxContainer = %Hearts
@onready var progress: Panel = %Progress
@onready var fill: ColorRect = %Fill
@onready var marker: Control = %Marker
@onready var score_label: Label = %Score
@onready var combo_label: Label = %Combo
@onready var hint: Label = %Hint
@onready var banner: Label = %Banner
@onready var banner_sub: Label = %BannerSub
@onready var flash: ColorRect = %Flash
@onready var touch_pads: Control = %TouchPads
@onready var pause_button: Button = %PauseButton
@onready var top: Control = %Top

var _hint_tween: Tween
var _banner_tween: Tween


func _ready() -> void:
	pause_button.pressed.connect(pause_pressed.emit)
	touch_pads.visible = DisplayServer.is_touchscreen_available()
	hint.modulate.a = 0.0
	banner.modulate.a = 0.0
	banner_sub.modulate.a = 0.0
	flash.color.a = 0.0


func set_hp(hp: int) -> void:
	for i in hearts.get_child_count():
		var heart := hearts.get_child(i) as TextureRect
		var full := i < hp
		if heart.texture == heart_full and not full:
			var tw := create_tween()
			heart.pivot_offset = heart.size / 2.0
			tw.tween_property(heart, "scale", Vector2(1.6, 1.6), 0.06)
			tw.tween_property(heart, "scale", Vector2.ONE, 0.2)
		heart.texture = heart_full if full else heart_empty


func set_progress(ratio: float) -> void:
	fill.size.x = (progress.size.x - 2.0) * clampf(ratio, 0.0, 1.0)
	marker.position.x = progress.position.x + progress.size.x * clampf(ratio, 0.0, 1.0) - marker.size.x / 2.0
	marker.position.y = progress.position.y - 12.0


func set_score(score: int, kills: int) -> void:
	score_label.text = "%06d  討伐 %d" % [score, kills]


func set_combo(combo: int) -> void:
	combo_label.text = "連擊 ×%d" % combo if combo >= 3 else ""


func show_hint(text: String, seconds: float = 2.4) -> void:
	hint.text = text
	if _hint_tween:
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.tween_property(hint, "modulate:a", 1.0, 0.15)
	_hint_tween.tween_interval(seconds)
	_hint_tween.tween_property(hint, "modulate:a", 0.0, 0.3)


func show_banner(text: String, sub: String = "", seconds: float = 2.2) -> void:
	banner.text = text
	banner_sub.text = sub
	if _banner_tween:
		_banner_tween.kill()
	banner.scale = Vector2(1.4, 1.4)
	banner.pivot_offset = banner.size / 2.0
	_banner_tween = create_tween().set_parallel()
	_banner_tween.tween_property(banner, "modulate:a", 1.0, 0.12)
	_banner_tween.tween_property(banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_property(banner_sub, "modulate:a", 1.0, 0.2).set_delay(0.15)
	_banner_tween.chain().tween_interval(seconds)
	_banner_tween.chain().tween_property(banner, "modulate:a", 0.0, 0.35)
	_banner_tween.parallel().tween_property(banner_sub, "modulate:a", 0.0, 0.35)


func hurt_flash(color: Color = Color(0.85, 0.08, 0.06)) -> void:
	flash.color = Color(color, 0.45)
	create_tween().tween_property(flash, "color:a", 0.0, 0.4)


## Light up a touch pad for a moment (finger feedback on phones).
func press_pad(slash: bool) -> void:
	var pad: Control = %SlashPad if slash else %JumpPad
	pad.modulate.a = 0.85
	create_tween().tween_property(pad, "modulate:a", 0.4, 0.18)


func set_running(on: bool) -> void:
	top.visible = on
	pause_button.visible = on
	touch_pads.visible = on and DisplayServer.is_touchscreen_available()
