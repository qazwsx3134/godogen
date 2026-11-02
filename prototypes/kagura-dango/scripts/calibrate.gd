extends Control
## Latency calibration: a cowbell on every beat; the player taps along, and the average distance from the nearest
## beat (positive = late) becomes Settings.calib_ms, which every level subtracts from taps.

signal back_requested

const MAX_OFFSET := 0.25

var samples: Array[float] = []
var _last_beat := -1

@onready var conductor: Conductor = %Conductor


func _ready() -> void:
	%Apply.pressed.connect(_apply)
	%Retry.pressed.connect(_reset)
	%Back.pressed.connect(func():
		conductor.stop()
		back_requested.emit())
	conductor.load_song(JSON.parse_string(FileAccess.get_file_as_string("res://data/songs/calibrate.json")))
	_reset()


func start() -> void:
	conductor.play()


func average_ms() -> float:
	if samples.is_empty():
		return 0.0
	var total := 0.0
	for s in samples:
		total += s
	return total / samples.size() * 1000.0


func tap() -> void:
	var t := conductor.time()
	var beat := roundf(conductor.beat_at(t))
	var off := t - conductor.beat_time(beat)
	if absf(off) <= MAX_OFFSET:
		samples.append(off)
	_show()


func _process(_delta: float) -> void:
	if not conductor.playing():
		return
	var beat := floori(conductor.beat_at(conductor.time()))
	if beat != _last_beat and beat >= 0:
		_last_beat = beat
		%Dot.modulate = Color(1, 1, 1, 1)
		create_tween().tween_property(%Dot, "modulate", Color(1, 1, 1, 0.25), 0.25)


func _unhandled_input(event: InputEvent) -> void:
	var mouse: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if mouse or (event.is_action_pressed("tap") and not event.is_echo()):
		get_viewport().set_input_as_handled()
		tap()


func _apply() -> void:
	Settings.calib_ms = roundf(average_ms())
	Settings.save_all()
	_show()


func _reset() -> void:
	samples.clear()
	_show()


func _show() -> void:
	%Info.text = "已點 %d 次　平均偏差 %+d ms　目前設定 %d ms" % [samples.size(), roundi(average_ms()), roundi(Settings.calib_ms)]
	%Apply.disabled = samples.size() < 8
