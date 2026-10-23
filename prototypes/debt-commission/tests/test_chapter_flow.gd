extends "res://addons/proto_kit/test_kit.gd"
## Phase 5 chapter flow on a two-chapter fixture registry: the `result` step shows the chapter
## result (numbers, grade from the glasses left, each Game Over one grade lower, the grade's
## closing line), glasses carry across rounds, the best grade is kept, clearing a chapter unlocks
## the next, 下一章 starts it, and 結局收集 lists the endings reached.

const REGISTRY: String = "res://tests/fixtures/stories_chapters.json"
const PROGRESS: String = "user://chapter_flow_test_progress.cfg"
const UI: String = "user://chapter_flow_test_ui.cfg"
const SAVES: Array[String] = ["user://fixture_chapter_a.save", "user://fixture_chapter_b.save", "user://fixture_sample.save"]
const Runner = preload("res://scripts/story_runner.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_cleanup()
	for sample: Array in [[5, 0, "S"], [4, 0, "A"], [3, 0, "B"], [2, 0, "B"], [1, 0, "C"], [5, 1, "A"], [4, 2, "C"], [1, 3, "C"]]:
		_expect(Runner.grade_for(sample[0], sample[1]) == sample[2], "grade for %d glasses, %d Game Overs is %s" % sample)

	var game: Control = _new_game()
	await _frames(3)
	_expect(game._story_ready, "fixture chapter A loads: %s" % game._story_error)
	_expect(game._story_unlocked(0) and not game._story_unlocked(1) and game._story_unlocked(2),
		"the first chapter and samples are open, the next chapter is locked")
	game._on_begin_pressed()
	await _pick(game, "miss")  # one cold take: 4 glasses
	await _pick(game, "hit")
	_expect(game._runner.node_id == "round2" and int(game._runner.gameplay["glasses"]) == 4,
		"glasses do not refill between rounds")
	await _pick(game, "hit")
	_expect(game._screen_mode == "result", "the result step shows the chapter result")
	var summary: Dictionary = game._runner.call("chapter_result")
	_expect(summary["grade"] == "A" and summary["caught"] == 2 and summary["tries"] == 3 and summary["perfect"] == 2
		and summary["fails"] == 1 and summary["hidden_total"] == 2 and summary["glasses"] == 4,
		"the numbers and the grade follow the play: %s" % [summary])
	var screen: Control = game._chapter_result
	_expect(screen.visible and screen.grade.text.contains("A") and screen.quote.text == "神樂：「還算有用阿魯。」"
		and screen.caught.text == "2 / 3" and screen.next_button.visible, "the result screen shows them, with 下一章")
	_expect(game._cleared_grade("chapter_a") == "A" and game._story_unlocked(1), "clearing chapter A unlocks chapter B")
	var progress: ConfigFile = ConfigFile.new()
	progress.load(PROGRESS)
	_expect(progress.get_value("endings", "chapter_a", []) == ["a_clear"] and progress.get_value("carry", "chapter_a", {}) == {"cold_takes": 1.0},
		"the result records its ending and carries the one cold take: %s" % [progress.get_value("carry", "chapter_a", {})])
	_expect(game._ending_note(game._story_choices[0]) == "結局 1/2", "chapter select counts 1 of 2 endings")
	game._chapter_select.call("open", [], game._chapter_endings())
	var rows: Array = game._chapter_select.call("ending_rows")
	_expect(rows == ["測試章 A｜～ 測試章 A 完 ～", "測試章 A｜？？？", "測試章 B｜？？？"],
		"結局收集 names the seen ending and hides the others: %s" % [rows])
	game._chapter_select.visible = false
	_expect(game._runner.call("advance").get("op", "") == "result", "the result is the end of the chapter")
	game._choose_story(game._story_choices[0])
	_expect(game._runner.flags["cold_takes"] == 0, "replaying chapter A does not import its own carry")

	# Replay with a Game Over: the grade drops one step even though the glasses end full again.
	game._on_begin_pressed()
	for _attempt: int in range(5):
		await _pick(game, "miss")
	_expect(game._game_over.visible, "five cold takes end in Game Over")
	_expect(game._ending_note(game._story_choices[0]) == "結局 2/2", "the Game Over end is an ending too")
	game._on_game_over_retry_pressed()
	await _read_until(game, ["boke_round"])
	_expect(int(game._runner.stats["game_overs"]) == 1 and int(game._runner.gameplay["glasses"]) == 5,
		"the retry restores the glasses and keeps the Game Over count")
	await _pick(game, "hit")
	await _pick(game, "hit")
	_expect(game._runner.call("chapter_result")["grade"] == "A" and game._cleared_grade("chapter_a") == "A",
		"5 glasses after one Game Over grade A, and the best grade stays")
	progress.load(PROGRESS)
	_expect(progress.get_value("carry", "chapter_a", {}) == {"cold_takes": 0.0},
		"the Game Over run carries nothing and the retry's adds are not counted twice: %s" % [progress.get_value("carry", "chapter_a", {})])

	game._chapter_result.next_button.pressed.emit()
	await _read_until(game, ["end"])
	_expect(game._screen_mode == "end", "下一章 starts chapter B and plays it to its end")
	_expect(game.save_path == "user://fixture_chapter_b.save" and not game._chapter_result.visible,
		"chapter B plays in its own save with the result closed")
	_expect(game._next_chapter().is_empty(), "the last chapter has no 下一章")
	_expect(game._ending_note(game._story_choices[1]) == "結局 1/1", "chapter B's end is recorded under chapter B")
	_expect(game._chapter_endings().all(func(ending: Dictionary) -> bool: return ending["seen"]),
		"結局收集 is complete once every ending was reached")
	_expect(game._runner.flags["cold_takes"] == 0 and game._previous_chapter_carry() == {"cold_takes": 0.0},
		"chapter B starts from chapter A's carried value: %s %s" % [game._runner.flags, game._previous_chapter_carry()])

	# A new chapter B starts from the carried value; a save holding a carried value is accepted.
	var runner: RefCounted = Runner.new()
	runner.load_story("res://tests/fixtures/chapter_b_story.json")
	_expect(runner.call("carry_in", {"cold_takes": 3, "unknown": true}) and runner.flags == {"cold_takes": 3},
		"carry_in starts the chapter with the carried flag and ignores others")
	_expect(runner.create_validation_probe().restore(runner.snapshot()), "a save with a carried value restores")
	_expect(runner.call("carry_in", {"cold_takes": "9"}) and runner.flags["cold_takes"] == 3,
		"a carried value of the wrong type is ignored")
	game.queue_free()
	await _frames(2)
	_cleanup()
	_finish("chapter flow")


func _new_game() -> Control:
	var game: Control = (load("res://main.tscn") as PackedScene).instantiate() as Control
	game.stories_path = REGISTRY
	game.story_path = "res://tests/fixtures/chapter_a_story.json"
	game.save_path = SAVES[0]
	game.progress_path = PROGRESS
	root.add_child(game)
	return game


## Reads on to the round, opens the timed choice and picks an option, as a player would; then
## reads on until the next round, the result, the end or Game Over.
func _pick(game: Control, option_id: String) -> void:
	await _read_until(game, ["boke_round"])
	game._on_boke_tsukkomi_pressed()
	await _until(func() -> bool: return game._screen_mode == "tsukkomi", "choice open for " + option_id)
	game._on_boke_option_pressed(option_id)
	await _read_until(game, ["boke_round", "result", "end"])


func _read_until(game: Control, modes: Array) -> void:
	for _i in range(600):
		if game._game_over.visible or (game._screen_mode in modes and not game._story_busy):
			return
		if game._screen_mode == "story" and not game._story_busy:
			if game._text_complete:
				game._advance_current_line()
			else:
				game._complete_current_line()
		await process_frame
	failures.append("timed out reading on to %s (at %s)" % [modes, game._screen_mode])


func _cleanup() -> void:
	for path: String in SAVES + [PROGRESS, UI]:
		for suffix: String in ["", ".bak", ".old", ".tmp", ".bak.tmp"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
