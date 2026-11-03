extends "res://addons/proto_kit/test_kit.gd"
## The match flow through real input: title → opening → (story → round → result) ×3 → ending → final result →
## title, a replayed round, and title → calibration → title. The BGM plays through the dialogue and fades out for
## the rounds. Settings live in the temp dir.

const MAIN := preload("res://scenes/main.tscn")

var main: Node


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	Settings.path = OS.get_temp_dir().path_join("kagura-dango-test-flow.cfg")
	DirAccess.remove_absolute(Settings.path)
	main = MAIN.instantiate()
	root.add_child(main)
	await _frames(2)
	_expect(main.screen.name == "Title", "starts on the title")
	await _press(main.screen.get_node("%Start"))
	await _frames(2)
	_expect(main.get_node("%Bgm").playing, "the BGM plays during the opening dialogue")
	await _read_story("opening")
	var names := ["ThreeEat", "FeastGame", "TossGame"]
	for i in 3:
		await _read_story(main.match_data.stages[i].story)
		_expect(main.screen.name == names[i], "round %d is %s (got %s)" % [i + 1, names[i], main.screen.name])
		_expect(main.screen.conductor.playing(), "round %d song is playing" % (i + 1))
		if i == 0:
			await create_timer(1.5).timeout  # the BGM fades out over 1.2 s
			_expect(not main.get_node("%Bgm").playing, "the BGM fades out when a round starts")
		main.screen._finish()
		await _frames(2)
		_expect(main.screen.name == "Result", "round %d ends on its result" % (i + 1))
		_expect(main.screen.get_node("%Comment").text.length() > 4, "round %d result has a comment" % (i + 1))
		if i == 0:
			await _press(main.screen.get_node("%Retry"))
			await _frames(2)
			_expect(main.screen.name == "ThreeEat" and main.round_index == 0, "Retry replays round 1")
			main.screen._finish()
			await _frames(2)
		await _press(main.screen.get_node("%Next"))
		await _frames(2)
	_expect(MatchState.results.size() == 3, "three round results recorded (got %d)" % MatchState.results.size())
	await _read_story("ending_lose")
	_expect(main.screen.name == "Result" and not main.screen.get_node("%Next").visible, "the final result follows the ending")
	_expect("對手隊" in main.screen.get_node("%Rank").text, "nobody tapped, so the rival team won")
	await _press(main.screen.get_node("%Back"))
	await _frames(2)
	_expect(main.screen.name == "Title", "Back returns to the title")
	# 第3關 on the title plays round 3 straight away, with the earlier rounds counted as perfect.
	await _press(main.screen.get_node("%Rounds/Round3"))
	await _frames(2)
	_expect(main.screen.name == "TossGame" and main.round_index == 2 and main.screen.conductor.playing(), "第3關 starts round 3 (got %s)" % main.screen.name)
	_expect(MatchState.score > 0 and MatchState.eaten[&"kagura"] > 0, "round 3 starts with rounds 1–2 counted (score %d)" % MatchState.score)
	main.screen._finish()
	await _frames(2)
	await _press(main.screen.get_node("%Back"))
	await _frames(2)
	# 設定: a slider moves its bus at once and 返回 saves it.
	await _press(main.screen.get_node("%Settings"))
	await _frames(2)
	_expect(main.screen.name == "Settings" and main.get_node("%Bgm").playing, "設定 opens settings, with the BGM to judge the music level")
	main.screen.get_node("%Music").value = 0.5
	_expect(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Music"))), 0.5), "the music slider sets the Music bus")
	main.screen.get_node("%Voice").value = 0.0
	_expect(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Voice")), "voice at 0 mutes the Voice bus")
	await _press(main.screen.get_node("%Back"))
	await _frames(2)
	var cfg := ConfigFile.new()
	cfg.load(Settings.path)
	_expect(main.screen.name == "Title" and is_equal_approx(float(cfg.get_value("audio", "Music", 1.0)), 0.5), "返回 saves the volumes and returns to the title")
	Settings.volumes = {&"Music": 1.0, &"SFX": 1.0, &"Voice": 1.0}
	Settings.apply()
	await _press(main.screen.get_node("%Calibrate"))
	await _frames(2)
	_expect(main.screen.name == "Calibrate", "Calibrate opens calibration")
	await _press(main.screen.get_node("%Back"))
	await _frames(2)
	_expect(main.screen.name == "Title", "calibration Back returns to the title")
	main.queue_free()
	_finish("FLOW")


func _read_story(key: String) -> void:
	await _frames(2)
	_expect(main.screen.name == "Story", "story '%s' is showing (got %s)" % [key, main.screen.name])
	for i in StoryData.lines(key).size():
		await _tap(Vector2(320, 120))
		await _frames(1)
