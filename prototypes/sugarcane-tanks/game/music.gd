extends Node
## Background music: one looping track for normal rooms, one for the boss room. Changing track fades the
## old one out while the new one fades in; `play(null)` fades to silence.
## The node keeps running while the game is paused (level-up panel, pause menu), and its fades ignore
## Engine.time_scale, so a hit stop does not stretch them. To swap a track, drop another file on the export
## in the Inspector (the tracks and their licence are in assets/music/).

## Played in normal rooms.
@export var room_track: AudioStream
## Played in the boss room.
@export var boss_track: AudioStream
## Volume of a track at full level. The sound effects play at -6 dB (sfx.gd); the music sits well below them.
@export_range(-60.0, 0.0, 0.5) var volume_db: float = -12.0
## Seconds the old track takes to fade out and the new one to fade in.
@export_range(0.05, 5.0, 0.05) var fade_time: float = 0.8

## What is meant to be playing now (null = silence).
var track: AudioStream

var _players: Array[AudioStreamPlayer] = []

func _ready() -> void:
	for child: Node in get_children():
		if child is AudioStreamPlayer:
			_players.append(child)

## Starts `new_track`, looped, and fades whatever else plays out. Asking for the track that is already
## playing changes nothing, so walking from room to room does not restart the music.
func play(new_track: AudioStream) -> void:
	if new_track == track:
		return
	track = new_track
	for player: AudioStreamPlayer in _players:
		if player.playing:
			_fade(player, 0.0, true)
	if new_track == null:
		return
	var player: AudioStreamPlayer = _spare_player()
	player.stream = _looped(new_track)
	_set_level(0.0, player)
	player.play()
	_fade(player, 1.0, false)

func stop() -> void:
	play(null)

## A player that is silent, else the quietest one (a third track in quick succession cuts the fading one).
func _spare_player() -> AudioStreamPlayer:
	var best: AudioStreamPlayer = _players[0]
	for player: AudioStreamPlayer in _players:
		if not player.playing:
			return player
		if _level_of(player) < _level_of(best):
			best = player
	return best

## A track imported without looping would end and leave silence, so looping is switched on here.
func _looped(stream: AudioStream) -> AudioStream:
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = true
	elif stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = roundi(wav.get_length() * wav.mix_rate)   # in sample frames
	return stream

func _fade(player: AudioStreamPlayer, to_level: float, stop_after: bool) -> void:
	if player.has_meta(&"fade"):
		var old: Tween = player.get_meta(&"fade") as Tween
		if old != null and old.is_valid():
			old.kill()
	var tween: Tween = create_tween().set_ignore_time_scale(true)
	tween.tween_method(_set_level.bind(player), _level_of(player), to_level, fade_time)
	if stop_after:
		tween.tween_callback(player.stop)
	player.set_meta(&"fade", tween)

func _level_of(player: AudioStreamPlayer) -> float:
	return player.get_meta(&"level") if player.has_meta(&"level") else 0.0

## Level 1 = `volume_db`, 0 = silent. Linear in amplitude, like a fade in an audio editor.
func _set_level(level: float, player: AudioStreamPlayer) -> void:
	player.set_meta(&"level", level)
	player.volume_db = volume_db + linear_to_db(maxf(level, 0.0001))
