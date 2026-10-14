extends CanvasLayer
## Title, pause, game over and ending screens, plus the full-screen fade. Runs while the tree is paused.

signal start_pressed
signal retry_pressed(from_boss: bool)
signal resume_pressed
signal mute_toggled(muted: bool)
## A phone turned upright (true) or back on its side (false). The game cannot be played upright.
signal portrait_changed(upright: bool)

@onready var title: Control = %Title
@onready var start_button: Button = %StartButton
@onready var best_label: Label = %Best
@onready var press_label: Label = %PressLabel
@onready var pause_panel: Control = %Pause
@onready var resume_button: Button = %ResumeButton
@onready var mute_button: Button = %MuteButton
@onready var restart_button: Button = %RestartButton
@onready var over: Control = %GameOver
@onready var over_stats: Label = %OverStats
@onready var retry_button: Button = %RetryButton
@onready var boss_retry_button: Button = %BossRetryButton
@onready var ending: Control = %Ending
@onready var ending_stats: Label = %EndingStats
@onready var again_button: Button = %AgainButton
@onready var ending_title: Label = %EndingTitle
@onready var fade: ColorRect = %Fade
@onready var portrait: Control = %Portrait
@onready var phone_icon: ColorRect = %Portrait/Phone

var muted := false
var _t := 0.0


func _ready() -> void:
	start_button.pressed.connect(start_pressed.emit)
	resume_button.pressed.connect(resume_pressed.emit)
	restart_button.pressed.connect(func() -> void: retry_pressed.emit(false))
	retry_button.pressed.connect(func() -> void: retry_pressed.emit(false))
	boss_retry_button.pressed.connect(func() -> void: retry_pressed.emit(true))
	again_button.pressed.connect(func() -> void: retry_pressed.emit(false))
	mute_button.pressed.connect(func() -> void:
		muted = not muted
		mute_button.text = "聲音：關" if muted else "聲音：開"
		mute_toggled.emit(muted))
	show_only(title)
	fade.color.a = 0.0
	if not DisplayServer.is_touchscreen_available():  # the scene text is the phone version
		press_label.text = "按任意鍵／點擊畫面　出擊！"
		%Controls.text = "跳躍：空白鍵 ↑ W　　斬擊・彈反：J X K →　　暫停：Esc"


func _process(delta: float) -> void:
	_t += delta
	press_label.modulate.a = 0.45 + 0.55 * absf(sin(_t * 2.4))
	var win := DisplayServer.window_get_size()
	var upright := DisplayServer.is_touchscreen_available() and win.y > win.x
	if upright != portrait.visible:
		portrait.visible = upright
		portrait_changed.emit(upright)
	if upright:  # the phone picture tips over onto its side, again and again
		phone_icon.rotation = -PI / 2.0 * clampf(fposmod(_t, 2.0) - 0.6, 0.0, 0.6) / 0.6


func show_only(panel: Control) -> void:
	for p in [title, pause_panel, over, ending]:
		p.visible = p == panel
	if panel == pause_panel:
		resume_button.grab_focus.call_deferred()
	elif panel == over:
		(boss_retry_button if boss_retry_button.visible else retry_button).grab_focus.call_deferred()
	elif panel == ending:
		again_button.grab_focus.call_deferred()


func show_title(best: int) -> void:
	best_label.text = "最高分 %06d" % best if best > 0 else ""
	show_only(title)


func show_over(stats: String, reached_boss: bool) -> void:
	over_stats.text = stats
	boss_retry_button.visible = reached_boss
	show_only(over)
	_pop_in(over)


func show_ending(stats: String) -> void:
	ending_stats.text = stats
	show_only(ending)
	_pop_in(ending)


func hide_all() -> void:
	show_only(null)


func fade_to(alpha: float, seconds: float) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", alpha, seconds)
	await tw.finished


func _pop_in(panel: Control) -> void:
	panel.modulate.a = 0.0
	create_tween().tween_property(panel, "modulate:a", 1.0, 0.35)
