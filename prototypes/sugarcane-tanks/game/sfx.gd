extends Node
## Sound for every game event, played round-robin on a few voices.
##
## An event's sound is looked up in this order:
##   1. a file in res://assets/sfx/ named after the event: <event>.ogg, else <event>.wav
##   2. the placeholder synth of that name (godot-kit's synth, below)
##   3. the event it borrows from (`fallback`): a file or synth of that other name
##   4. nothing: playing an event nobody has a sound for is silent, never an error.
## So dropping a file into assets/sfx/ named like an event replaces its sound without touching code.
## The event names the game plays, and where each one's sound comes from, are listed in README.md ("音效接口").

const Synth = preload("res://addons/proto_kit/synth.gd")
const SFX_DIR: String = "res://assets/sfx"

## Events that sound like another event when they have no sound of their own (no file, no synth).
var fallback: Dictionary[StringName, StringName] = {
	&"enemy_die": &"boom",
	&"boss_die": &"boom",
	&"hero_die": &"boom",
	&"aoe_blast": &"boom",
	&"crush": &"hurt",
	&"coin": &"pickup",
}

## Emitted for every play() call, even for events with no sound. Tests and debugging listen to it.
signal played(sound: StringName)

@export var voices: int = 10
@export_range(-40.0, 6.0, 0.5) var volume_db: float = -6.0

var _streams: Dictionary = {}
var _resolved: Dictionary = {}   # event -> {"stream": AudioStream or null, "source": String}
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
	played.emit(sound)
	var stream: AudioStream = stream_for(sound)
	if stream == null or _players.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	if now - int(_last_ms.get(sound, -100000)) < int(min_gap * 1000.0):
		return
	_last_ms[sound] = now
	var player: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = stream
	player.play()

## The sound an event plays right now, or null if it has none.
func stream_for(sound: StringName) -> AudioStream:
	return _resolve(sound)["stream"]

## Where an event's sound comes from: the file path, "synth", "<event> (borrowed)" or "" for none.
func source_of(sound: StringName) -> String:
	return _resolve(sound)["source"]

## Forget what was found, so files added or removed since are noticed (dropped-in files are otherwise
## picked up the next time the game starts).
func refresh() -> void:
	_resolved.clear()

func _resolve(sound: StringName) -> Dictionary:
	if _resolved.has(sound):
		return _resolved[sound]
	var found: Dictionary = {"stream": null, "source": ""}
	var file: AudioStream = _from_file(sound)
	if file != null:
		found = {"stream": file, "source": _file_path(sound)}
	elif _streams.has(sound):
		found = {"stream": _streams[sound], "source": "synth"}
	elif fallback.has(sound):
		var borrowed: Dictionary = _resolve(fallback[sound])
		found = {"stream": borrowed["stream"], "source": "%s (borrowed)" % fallback[sound] if borrowed["stream"] != null else ""}
	_resolved[sound] = found
	return found

func _file_path(sound: StringName) -> String:
	for extension: String in ["ogg", "wav"]:
		var path: String = "%s/%s.%s" % [SFX_DIR, sound, extension]
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			return path
	return ""

## A file the editor has imported loads normally. One that was just dropped in and not imported yet
## (running the game before the editor has looked at the folder) is read straight from disk.
func _from_file(sound: StringName) -> AudioStream:
	var path: String = _file_path(sound)
	if path.is_empty():
		return null
	if ResourceLoader.exists(path):
		return load(path) as AudioStream
	return AudioStreamOggVorbis.load_from_file(path) if path.ends_with(".ogg") else AudioStreamWAV.load_from_file(path)
