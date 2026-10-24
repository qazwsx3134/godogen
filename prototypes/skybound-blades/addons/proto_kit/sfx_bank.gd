extends Node
## Sound for a game's events, played by name round-robin on a few voices: `sfx.play(&"hit")`.
## A game extends this script (there is no class_name) and fills the three tables that are its own: `_streams`
## (placeholder sounds), `fallback` (which event sounds like which) and `long_sounds` (which sounds are cut short).
##
##   extends "res://addons/proto_kit/sfx_bank.gd"           # game/sfx.gd, on a Node of the main scene
##   const Synth = preload("res://addons/proto_kit/synth.gd")
##   func _ready() -> void:
##       _streams = {&"hit": Synth.click(0.05, 0.3, 40.0), &"boom": Synth.click(0.35, 0.5, 9.0)}
##       fallback = {&"enemy_die": &"boom"}                          # no sound of its own: plays boom's
##       long_sounds = {&"boom": {"seconds": 0.5, "gain_db": -3.0}}  # cut after 0.5 s, 3 dB quieter, never stacked
##       super()                                                     # builds the voices: fill the tables first
##   # anywhere: sfx.play(&"hit"), sfx.play(&"enemy_die", 0.0), sfx.played.connect(func(sound): ...)
##
## An event's sound is looked up in this order:
##   1. a file in `sound_dir` named after the event: <event>.ogg, else <event>.wav
##   2. the placeholder stream registered under that name in `_streams`
##   3. the event it borrows from (`fallback`): a file or placeholder of that other name
##   4. nothing: playing an event nobody has a sound for is silent, never an error (`played` is still emitted).
## So dropping a file named like an event into `sound_dir` replaces its sound without touching code.
##
## `play()` thins a burst of hits by wall-clock time (Time.get_ticks_msec) on purpose: what the ear hears is real
## time, so an audio throttle should be too. Do not copy that for gameplay. A lock or cooldown measured in wall time
## breaks under `--fixed-fps` tests, where game time runs far faster than the wall clock, and swallows every input.
## Gameplay timing uses game time, e.g. `create_timer(seconds, true, false, true)`.

const CLIP_FADE: float = 0.12

## Emitted for every play() call, even for events with no sound. Tests and debugging listen to it.
signal played(sound: StringName)

## Where <event>.ogg and <event>.wav are looked for. Call refresh() after changing it.
@export var sound_dir: String = "res://assets/sfx"
@export var voices: int = 10
@export_range(-40.0, 6.0, 0.5) var volume_db: float = -6.0

## Events that sound like another event when they have no sound of their own (no file, no placeholder).
## The borrowing must not loop (a borrows from b, b from a).
var fallback: Dictionary[StringName, StringName] = {}

## Sounds that outlast the moment they belong to, as {event: {"seconds": float, "gain_db": float}}. They are cut
## after `seconds` (with a CLIP_FADE fade-out), play `gain_db` quieter or louder than the rest, and never stack:
## while one is sounding, the same event is skipped. For example a 5 s engine loop used for a 0.7 s wind-up.
var long_sounds: Dictionary = {}

var _streams: Dictionary = {}    # placeholder sounds: event -> AudioStream
var _resolved: Dictionary = {}   # event -> {"stream": AudioStream or null, "source": String}
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _last_ms: Dictionary = {}
var _event_of: Dictionary = {}   # voice -> the event it last played
var _cut: Dictionary = {}        # voice -> the tween that fades a long sound out

## Builds the voices. A subclass fills its tables first and then calls super().
func _ready() -> void:
	for i: int in voices:
		var player := AudioStreamPlayer.new()
		player.volume_db = volume_db
		add_child(player)
		_players.append(player)

## `min_gap` (seconds, wall clock) keeps a burst of hits from stacking into noise.
func play(sound: StringName, min_gap: float = 0.035) -> void:
	played.emit(sound)
	var stream: AudioStream = stream_for(sound)
	if stream == null or _players.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	if now - int(_last_ms.get(sound, -100000)) < int(min_gap * 1000.0):
		return
	var long: Dictionary = long_sounds.get(sound, {})
	if not long.is_empty() and _sounding(sound):
		return
	_last_ms[sound] = now
	var player: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	if _cut.has(player):   # this voice was fading out an earlier long sound
		_cut[player].kill()
		_cut.erase(player)
	player.stream = stream
	player.volume_db = volume_db + float(long.get("gain_db", 0.0))
	_event_of[player] = sound
	player.play()
	if not long.is_empty():
		var tween: Tween = player.create_tween().set_ignore_time_scale(true)
		tween.tween_interval(maxf(float(long["seconds"]) - CLIP_FADE, 0.0))
		tween.tween_property(player, "volume_db", -60.0, CLIP_FADE)
		tween.tween_callback(player.stop)
		_cut[player] = tween

func _sounding(sound: StringName) -> bool:
	for player: AudioStreamPlayer in _players:
		if player.playing and _event_of.get(player) == sound:
			return true
	return false

## The sound an event plays right now, or null if it has none.
func stream_for(sound: StringName) -> AudioStream:
	return _resolve(sound)["stream"]

## Where an event's sound comes from: the file path, "synth", "<event> (borrowed)" or "" for none.
func source_of(sound: StringName) -> String:
	return _resolve(sound)["source"]

## Forget what was found, so files added or removed since are noticed (dropped-in files are otherwise
## picked up the next time the game starts). Also needed after changing a table or `sound_dir` once an
## event has been looked up.
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
		var path: String = "%s/%s.%s" % [sound_dir, sound, extension]
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
