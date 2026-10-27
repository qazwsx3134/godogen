extends Control

signal start_requested
signal stop_requested

@onready var information: Label = %FishingInfo
@onready var status: Label = %FishingStatus
@onready var action_button: Button = %FishingAction
@onready var close_button: Button = %FishingClose

var active: bool = false
var _last_countdown: int = -1
var _last_bait: int = -1
var _last_active: bool = false


func _ready() -> void:
	action_button.pressed.connect(func() -> void:
		if active:
			stop_requested.emit()
		else:
			start_requested.emit())
	close_button.pressed.connect(func() -> void:
		stop_requested.emit()
		visible = false)


func show_spot(bait: int) -> void:
	visible = true
	status.text = ""
	update_state(false, 0.0, bait)


func update_state(is_active: bool, left: float, bait: int) -> void:
	active = is_active
	var seconds := ceili(left)
	if _last_countdown != seconds or _last_bait != bait or _last_active != is_active:
		information.text = "釣餌 %d 個\n每次 5 秒；完成時消耗 1 個釣餌。\n取消、遭到攻擊或背包已滿時不消耗。" % bait
		if is_active:
			information.text += "\n等待中：%d 秒" % seconds
		_last_countdown = seconds
		_last_bait = bait
		_last_active = is_active
	action_button.text = "停止釣魚" if is_active else "開始釣魚"
