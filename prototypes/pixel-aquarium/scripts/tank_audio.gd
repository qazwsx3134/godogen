extends Node

const AtomicFile = preload("res://addons/proto_kit/atomic_file.gd")
const BUSES := [&"Master", &"Music", &"Water", &"Effects"]

@onready var _harmony: AudioStreamPlayer = $Harmony
@onready var _melody: AudioStreamPlayer = $Melody
@onready var _water: AudioStreamPlayer = $Water
@onready var _effect: AudioStreamPlayer = $Effect
@onready var _cue: AudioStreamPlayer = $Cue

var playback_requested := true
var settings_path := "user://audio_settings.dat"
var _clips: Dictionary = {}
var _last_peck := -1000
var _peck := 0
var _cue_at := -1000
var _loop_count := 0
var _last_position := 0.0
var _playback_enabled := false


func bind_settings(panel: Control) -> void:
	var file := FileAccess.open(settings_path, FileAccess.READ)
	var saved: Variant = file.get_var(false) if file else null
	var sliders := panel.get_node("Rows")
	for index in BUSES.size():
		var slider := sliders.get_child(index).get_node("Slider") as HSlider
		var value: Variant = saved.get(BUSES[index], 0.72) if saved is Dictionary else 0.72
		slider.set_value_no_signal(clampf(float(value), 0.0, 1.0) if value is float or value is int else 0.72)
		_apply_volume(slider.value, index)
		slider.value_changed.connect(_change_volume.bind(index, sliders))
	for cue in ["splash", "peck1", "peck2", "peck3", "panel", "hatch", "moon"]:
		_clips[cue] = load("res://assets/audio/" + cue + ".ogg")
	_playback_enabled = playback_requested and DisplayServer.get_name() != "headless"
	if not _playback_enabled:
		return
	_play_loop(_water, "water")
	get_tree().create_timer(2.0).timeout.connect(_begin_score, CONNECT_ONE_SHOT)


func _begin_score() -> void:
	_play_loop(_harmony, "harmony")
	_play_loop(_melody, "melody")


func _play_loop(player: AudioStreamPlayer, clip: String) -> void:
	var stream := load("res://assets/audio/" + clip + ".ogg") as AudioStreamOggVorbis
	stream.loop = true
	player.stream = stream
	player.play()


func _process(_delta: float) -> void:
	if not _melody.playing:
		return
	var position := _harmony.get_playback_position()
	if position < _last_position - 2.0:
		_loop_count += 1
	_last_position = position
	var rest := 0.0
	if _loop_count % 2 == 1:
		rest = smoothstep(25.0, 27.0, position) - smoothstep(34.0, 36.0, position)
	var duck := clampf(1.0 - (Time.get_ticks_msec() - _cue_at) / 1000.0, 0.0, 1.0)
	_melody.volume_db = -45.0 * rest - 3.0 * duck


func _exit_tree() -> void:
	for player in [_harmony, _melody, _water, _effect, _cue]:
		if is_instance_valid(player):
			player.stop()


func _apply_volume(value: float, index: int) -> void:
	var bus := AudioServer.get_bus_index(BUSES[index])
	AudioServer.set_bus_mute(bus, value <= 0.0)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(value * value, 0.001)))


func _change_volume(value: float, index: int, sliders: Node) -> void:
	_apply_volume(value, index)
	var settings := {}
	for row in BUSES.size():
		settings[BUSES[row]] = sliders.get_child(row).get_node("Slider").value
	AtomicFile.write_var(settings_path, settings)


func sound(event: String) -> void:
	if not _playback_enabled:
		return
	if event == "peck":
		var now := Time.get_ticks_msec()
		if now - _last_peck < 250:
			return
		_last_peck = now
		_peck = _peck % 3 + 1
		event = "peck%d" % _peck
	if event in ["hatch", "moon"]:
		_cue.stream = _clips[event]
		_cue.play()
		_cue_at = Time.get_ticks_msec()
	else:
		_effect.stream = _clips[event]
		_effect.play()
