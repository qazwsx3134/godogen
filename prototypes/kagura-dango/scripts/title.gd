extends Control
## Title screen. The first tap here also unlocks audio in browsers, so no song starts before it.

signal start_requested
signal calibrate_requested


func _ready() -> void:
	%Start.pressed.connect(start_requested.emit)
	%Calibrate.pressed.connect(calibrate_requested.emit)
	%CalibInfo.text = "目前延遲校準：%d ms" % roundi(Settings.calib_ms)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("tap") and not event.is_echo():
		get_viewport().set_input_as_handled()
		start_requested.emit()
