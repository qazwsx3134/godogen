extends Node
## Song clock for rhythm games: plays one song and says where in it we are, in song-file seconds aligned with what
## the player hears. Gameplay reads time(), never the frame clock. bpm/offset turn beats into seconds.
##   const SongClock = preload("res://addons/proto_kit/song_clock.gd")
##   var clock := SongClock.new(); add_child(clock); clock.load_song({bpm = 120, offset = 0.05, music = "res://x.mp3"})
##   clock.play(); ... clock.time(), clock.beat_at(clock.time())
## Native builds read the audio stream position. The web build (Sample playback) cannot: its reported position trails
## the sound by about a second and the first play() blocks ~0.8 s, so it uses the wall clock anchored after play().
## Tests set `clock` to a game-time Callable so they run the same under --fixed-fps.
## Extracted from kagura-dango (scripts/conductor.gd extends this).

## Native builds: read the song position from the audio stream (true) or from the moment play() returned (false).
@export var use_audio_position := true

var bpm := 120.0
var offset := 0.0
## Where in the song file playback starts (seconds), e.g. a round that plays only part of the song.
## time() keeps counting in song-file seconds, so offset (beat 0) is also a song-file time.
var music_start := 0.0
var clock := Callable()

## Song level under a spoken line (duck).
const DUCK_DB := -8.0
const SILENT_DB := -40.0

## Trim for the song itself (commercial songs are often mastered near -7 LUFS and clip against SFX at 0 dB).
@export var level_db := 0.0
## Audio bus the song plays on.
@export var bus := &"Master"

var _player: AudioStreamPlayer
var _anchor_usec := -1
var _from := 0.0
var _fade: Tween
var _duck: Tween
var _ducked := false
var _fade_db := 0.0
var _duck_db := 0.0
var _last := 0.0


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "Music"
	_player.bus = bus
	add_child(_player)


func load_song(chart: Dictionary) -> void:
	bpm = float(chart.bpm)
	offset = float(chart.offset)
	music_start = float(chart.get("music_start", 0.0))
	var music: String = chart.get("music", "")
	_player.stream = load(music) if ResourceLoader.exists(music) else null


## Plays from music_start, or from `from` (song-file seconds, e.g. a chart editor's cursor). fade_in > 0 raises the
## song from silence over that many seconds.
func play(from := -1.0, fade_in := 0.0) -> void:
	_from = music_start if from < 0.0 else from
	_last = 0.0
	_anchor_usec = Time.get_ticks_usec()
	if _fade:
		_fade.kill()  # a fade-out still running from stop() would silence the new play
	if _duck:
		_duck.kill()
	_ducked = false
	_duck_db = 0.0
	_fade_db = SILENT_DB if fade_in > 0.0 else 0.0
	_apply_volume()
	if _player.stream:
		_player.play(_from)
	# On the web a song's first play() blocks 0.8-0.9 s (registering the decoded sample) before the sound is
	# scheduled; anchoring after it keeps that stall out of the wall clock.
	_anchor_usec = Time.get_ticks_usec()
	if fade_in > 0.0:
		_fade = create_tween()
		_fade.tween_method(_set_fade, SILENT_DB, 0.0, fade_in).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)


func stop() -> void:
	_anchor_usec = -1
	if _duck:
		_duck.kill()
	_ducked = false
	if not _player.playing:
		return
	# Stopped mid-song: fade out instead of cutting.
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_method(_set_fade, _fade_db, SILENT_DB, 0.6)
	_fade.tween_callback(_player.stop)


## Lowers the song under a spoken line (on) and brings it back (off). Ignored while stopped or fading out.
## Ducking and the fades are separate amounts added together, so a line said during the fade-in does not cut it.
func duck(on: bool) -> void:
	if on == _ducked or _anchor_usec < 0:
		return
	_ducked = on
	if _duck:
		_duck.kill()
	_duck = create_tween()
	_duck.tween_method(_set_duck, _duck_db, DUCK_DB if on else 0.0, 0.15)


func _set_fade(db: float) -> void:
	_fade_db = db
	_apply_volume()


func _set_duck(db: float) -> void:
	_duck_db = db
	_apply_volume()


func _apply_volume() -> void:
	_player.volume_db = maxf(SILENT_DB, level_db + _fade_db + _duck_db)


## Length of the loaded song file in seconds (0 without one).
func song_length() -> float:
	return _player.stream.get_length() if _player.stream else 0.0


func playing() -> bool:
	return clock.is_valid() or _anchor_usec >= 0


func wall_time() -> float:
	return -1.0 if _anchor_usec < 0 else _from + (Time.get_ticks_usec() - _anchor_usec) / 1000000.0


func audio_time() -> float:
	if not _player.playing:
		return -1.0
	return _player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()


## Song seconds. Never goes backwards within one play.
func time() -> float:
	if clock.is_valid():
		return clock.call()
	if _anchor_usec < 0:
		return -1.0
	var t := wall_time()
	if OS.has_feature("web"):
		# Web (Sample playback): the browser's reported position trails what is heard by about a second, so the web
		# build follows the wall clock from the end of play() (see play()), minus output latency. Checked by ear on a
		# phone (kagura-dango, 2026-11-03); headless browsers have no audio output and cannot check this.
		t -= AudioServer.get_output_latency()
	elif use_audio_position:
		var a := audio_time()
		if a >= 0.0:
			t = a
	_last = maxf(_last, t)
	return _last


func beat_time(beat: float) -> float:
	return offset + beat * 60.0 / bpm


func beat_at(t: float) -> float:
	return (t - offset) * bpm / 60.0
