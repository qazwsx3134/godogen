extends "res://addons/proto_kit/test_kit.gd"
## Downloaded tracks, default BGM, playback controls and explicit story overrides.

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var sources: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/music/sources.json"))
	var expected: Array = [1, 2, 3, 5, 8, 10, 13, 19, 20, 21, 22, 34, 35]
	var game: Control = (load("res://main.tscn") as PackedScene).instantiate() as Control
	game.save_path = "user://downloaded_bgm_test.save"
	root.add_child(game)
	await _frames(3)
	_expect(game._story_ready, "current story loads")
	_expect(sources["tracks"].size() == expected.size(), "all 13 requested tracks are present")
	for index: int in range(sources["tracks"].size()):
		var track: Dictionary = sources["tracks"][index]
		_expect(track["playlist_index"] == expected[index], "original playlist numbering is preserved")
		var stream: AudioStream = game._effects._stream("music", str(track["id"]))
		_expect(stream is AudioStreamOggVorbis and stream.get_length() > 1.0, "track %s loads as real OGG audio" % track["id"])
		if stream is AudioStreamOggVorbis:
			_expect(stream.loop, "track %s loops" % track["id"])
	_expect(game._effects.current_bgm == "bgm_gintama_35", "title defaults to playlist track 35")
	_expect(game._effects._bgm_player.playback_type == AudioServer.PLAYBACK_TYPE_STREAM, "BGM uses streaming playback for Web volume control")
	_expect(not game._audio_players.has("ambient"), "only one background music player is active")
	var daily: AudioStream = game._effects._stream("music", "bgm_daily")
	_expect(daily is AudioStreamOggVorbis, "daily story cue uses the downloaded default")
	_expect(game._catalog["music"]["bgm_daily"]["path"] == game._catalog["music"]["bgm_gintama_35"]["path"], "daily cue points to track 35")
	game._effects.set_volumes(1.0, 1.0)
	game._effects.set_muted(false)
	game._effects.play_bgm("bgm_gintama_01")
	_expect(game._effects.current_bgm == "bgm_gintama_01" and game._effects._bgm_player.playing, "explicit music cue overrides default")
	game._effects.set_muted(true)
	_expect(not game._effects._bgm_player.playing, "mute stops downloaded music")
	game._effects.set_muted(false)
	_expect(game._effects._bgm_player.playing, "unmute resumes selected music")
	game._effects.set_volumes(0.0, 1.0)
	_expect(not game._effects._bgm_player.playing, "zero BGM volume stops music")
	game._effects.set_volumes(1.0, 1.0)
	game._effects.play_bgm("")
	_expect(game._effects.current_bgm.is_empty() and not game._effects._bgm_player.playing, "explicit empty cue keeps silence")
	game._show_title()
	_expect(game._effects.current_bgm == "bgm_gintama_35", "returning to title restores default")
	game._on_begin_pressed()
	await _frames(3)
	_expect(game._effects.current_bgm in ["bgm_gintama_35", "bgm_daily"], "current story begins with track 35")
	game.queue_free()
	await _frames(2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://downloaded_bgm_test.save"))
	_finish("DOWNLOADED BGM TESTS (%d checks)" % checks)
