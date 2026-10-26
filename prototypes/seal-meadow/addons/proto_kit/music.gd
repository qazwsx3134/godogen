extends Node
## Background music with crossfades: `play(track)` fades the old track out while the new one fades in,
## `stop()` fades to silence. `const Music = preload("res://addons/proto_kit/music.gd")`, or put the script on a
## Node of the game scene and call:
##
##   music.play(room_theme)       # a different track: the old one fades out, this one fades in, looped
##   music.play(room_theme)       # the same track again: nothing happens (walking from room to room keeps it)
##   music.stop()                 # fades to silence
##
## The node uses the AudioStreamPlayer children it finds (two is enough: one fading out, one fading in) and adds
## the missing ones itself. It runs while the game is paused (set process_mode ALWAYS on the node), and its fades
## ignore Engine.time_scale, so a hit stop does not stretch them. A track imported without looping would end and
## leave silence, so looping is switched on when a track starts. A game that needs named tracks (a room theme and
## a boss theme) extends this script and adds the exports:
##
##   extends "res://addons/proto_kit/music.gd"
##   @export var room_track: AudioStream
##   @export var boss_track: AudioStream

## Volume of a track at full level. Keep it well below the sound effects.
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
	while _players.size() < 2:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)

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
