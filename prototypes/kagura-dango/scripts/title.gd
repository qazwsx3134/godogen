extends Control
## Title screen. The first tap here also unlocks audio in browsers, so no song starts before it.
## 第1關／第2關／第3關 (the %Rounds buttons, each with its `round` metadata) play that round straight away.

signal start_requested
signal calibrate_requested
signal round_requested(n: int)
signal settings_requested


func _ready() -> void:
	%Start.pressed.connect(start_requested.emit)
	%Calibrate.pressed.connect(calibrate_requested.emit)
	%Settings.pressed.connect(settings_requested.emit)
	for b in %Rounds.get_children():
		b.pressed.connect(round_requested.emit.bind(int(b.get_meta("round"))))
	%CalibInfo.text = "目前延遲校準：%d ms" % roundi(Settings.calib_ms)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("tap") and not event.is_echo():
		get_viewport().set_input_as_handled()
		start_requested.emit()
