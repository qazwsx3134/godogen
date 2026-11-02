extends "res://addons/proto_kit/test_kit.gd"
## The match flow through real input: title → opening → (story → round → result) ×3 → ending → final result →
## title, a replayed round, and title → calibration → title. Settings live in the temp dir.

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
	await _read_story("opening")
	var names := ["ThreeEat", "TossGame", "TossGame"]
	for i in 3:
		await _read_story(main.match_data.stages[i].story)
		_expect(main.screen.name == names[i], "round %d is %s (got %s)" % [i + 1, names[i], main.screen.name])
		_expect(main.screen.conductor.playing(), "round %d song is playing" % (i + 1))
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
