extends Node
## Placeholder sounds from godot-kit's synth, played round-robin on a few voices.

const Synth = preload("res://addons/proto_kit/synth.gd")

@export var voices: int = 10
@export_range(-40.0, 6.0, 0.5) var volume_db: float = -6.0

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _last_ms: Dictionary = {}

func _ready() -> void:
	_streams = {
		&"throw": Synth.ramp(900.0, 1500.0, 0.08, 0.22, 0.04),
		&"hit": Synth.click(0.05, 0.3, 40.0),
		&"crit": Synth.notes([987.77, 1318.51], 0.05),
		&"gun": Synth.click(0.08, 0.45, 30.0),
		&"toss": Synth.ramp(500.0, 820.0, 0.1, 0.25, 0.05),
		&"rev": Synth.ramp(70.0, 140.0, 0.45, 0.25, 0.45, 1.5),
		&"dash": Synth.ramp(220.0, 90.0, 0.35, 0.5, 0.1),
		&"squeak": Synth.notes([1760.0, 2093.0, 1760.0], 0.04),
		&"boom": Synth.click(0.35, 0.5, 9.0),
		&"hurt": Synth.ramp(420.0, 160.0, 0.22, 0.4, 0.1),
		&"pickup": Synth.notes([1046.5], 0.04, true),
		&"level": Synth.notes([523.25, 659.25, 783.99, 1046.5], 0.09),
		&"door": Synth.notes([392.0, 523.25, 659.25], 0.12, true),
	}
	for i: int in voices:
		var player := AudioStreamPlayer.new()
		player.volume_db = volume_db
		add_child(player)
		_players.append(player)

## `min_gap` keeps a burst of hits from stacking into noise.
func play(sound: StringName, min_gap: float = 0.035) -> void:
	if not _streams.has(sound) or _players.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	if now - int(_last_ms.get(sound, -100000)) < int(min_gap * 1000.0):
		return
	_last_ms[sound] = now
	var player: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = _streams[sound]
	player.play()
