extends "res://addons/proto_kit/test_kit.gd"
## Round v2 (scripts/tsukkomi_round.gd through StoryRunner): testimony with several slots,
## whiffs, listening for items, hints after three fails, require_caught, the censor bar,
## hidden exits, Game Over retry, combo timing and breaks, the QTE, the ultimate tsukkomi,
## saves, conditional outcomes (`when`), and data validation (placard and `when` included).

const StoryRunner = preload("res://scripts/story_runner.gd")
const TsukkomiRound = preload("res://scripts/tsukkomi_round.gd")
const StoryBuilder = preload("res://tools/story_build/story_builder.gd")
const FIXTURE: String = "res://tests/fixtures/round_v2_story.json"
const BROKEN: String = "user://round_v2_broken.json"


func _init() -> void:
	_test_testimony_round()
	_test_hidden_exit()
	_test_game_over_retry_keeps_hint_counts()
	_test_save_in_the_middle_of_a_reaction()
	_test_combo_round()
	_test_combo_bonus_and_super()
	_test_qte_judgement()
	_test_when_outcomes()
	_test_validation_errors()
	_finish("ROUND V2 TESTS")


func _test_testimony_round() -> void:
	var runner: RefCounted = _runner()
	runner.call("advance")
	var round: Dictionary = runner.call("current")
	_expect(round.get("mode") == "testimony" and round["line_index"] == 0 and not round["current_line"]["has_slot"],
		"the round opens on its first line")
	_expect(runner.call("resolve_boke", "a").is_empty(), "a line without a slot has no options to answer")

	var whiff: Dictionary = runner.call("whiff_boke")
	_expect(whiff.get("result") == "fail" and runner.get("node_id") == "l1_whiff", "pressing 吐槽 on a plain line whiffs")
	_expect(runner.get("gameplay")["glasses"] == 4, "a whiff costs a glass by default")
	runner.call("advance")
	round = runner.call("current")
	_expect(runner.get("node_id") == "r1" and round["line_index"] == 0, "the whiff reaction returns to the same line")

	_expect(runner.call("listen_boke_line") and runner.get("node_id") == "l1_listen", "listening plays the listen node")
	runner.call("advance")
	_expect(runner.get("items") == ["milk_trace"] and runner.call("current")["current_line"]["listened"],
		"the listen node grants its material and the line is marked as heard")

	runner.call("set_boke_line", 1)
	var option_ids: Array = runner.call("current")["current_line"]["options"].map(func(o: Dictionary) -> String: return o["id"])
	_expect(option_ids == ["b", "c"], "an option whose material is missing stays hidden: %s" % [option_ids])
	for attempt: int in range(3):
		runner.call("resolve_boke", "c")
		_expect(runner.get("node_id") == "l2_c", "fail %d plays the option's reaction" % (attempt + 1))
		runner.call("advance")
	_expect(runner.get("node_id") == "l2_hint", "the third fail on a line queues its hint after the reaction")
	runner.call("advance")
	round = runner.call("current")
	_expect(runner.get("node_id") == "r1" and round["line_index"] == 1 and runner.get("gameplay")["glasses"] == 1,
		"after the hint the player is back on the same line")

	runner.call("resolve_boke", "b")
	runner.call("advance")
	_expect(runner.get("gameplay")["power"] == 10 and runner.get("round_state")["caught"] == {"l2": "weak"},
		"a weak answer catches the slot and adds 10 power")
	runner.call("set_boke_line", 2)
	round = runner.call("current")
	_expect(round["current_line"]["speaker"] == "kagura" and not round["current_line"]["censor"].is_empty(),
		"a line can have its own speaker and a censor bar")
	_expect(round["current_line"]["options"].map(func(o: Dictionary) -> String: return o["id"]).has("h"),
		"require_caught unlocks the hidden option once l2 is caught")
	var censored: Dictionary = runner.call("resolve_censor")
	_expect(censored.get("result") == "perfect" and runner.get("node_id") == "l3_censor", "tapping the censor bar is a perfect")
	runner.call("advance")
	_expect(runner.get("node_id") == "r1_clear" and runner.get("round_state").is_empty(),
		"with every slot caught the round hands over to clear")
	_expect(runner.get("stats") == {"fails": 4, "caught": 2, "perfect": 1, "max_combo": 2},
		"stats count fails, catches, perfects and the best combo: %s" % [runner.get("stats")])


func _test_hidden_exit() -> void:
	var runner: RefCounted = _runner()
	runner.call("advance")
	runner.call("set_boke_line", 1)
	runner.call("resolve_boke", "b")
	runner.call("advance")
	runner.call("set_boke_line", 2)
	var hidden: Dictionary = runner.call("resolve_boke", "h")
	_expect(hidden.get("result") == "hidden" and runner.get("node_id") == "hidden_end", "the hidden option leaves the round")
	_expect(runner.get("round_state").is_empty() and runner.get("stats").get("hidden") == 1, "leaving ends the round state")


func _test_game_over_retry_keeps_hint_counts() -> void:
	var runner: RefCounted = _runner()
	runner.call("advance")
	runner.call("set_boke_line", 1)
	for attempt: int in range(5):
		runner.call("resolve_boke", "c")
		if attempt < 4:
			while runner.get("node_id") != "r1":
				runner.call("advance")
	_expect(runner.get("node_id") == "go" and runner.call("snapshot")["game_over_active"], "the fifth glass lost is Game Over")
	_expect(runner.call("retry_checkpoint"), "Game Over can retry")
	var round: Dictionary = runner.call("current")
	_expect(runner.get("node_id") == "r1" and round["caught_line_ids"].is_empty() and runner.get("gameplay")["glasses"] == 5,
		"retry restarts the round with full glasses")
	_expect(runner.get("round_state")["fails"] == {"l2": 5}, "fail counts survive the retry so hints keep playing")


func _test_save_in_the_middle_of_a_reaction() -> void:
	var runner: RefCounted = _runner()
	runner.call("advance")
	runner.call("set_boke_line", 1)
	runner.call("resolve_boke", "c")
	var saved: Dictionary = runner.call("snapshot")
	var resumed: RefCounted = _runner()
	_expect(resumed.call("restore", saved) and resumed.get("node_id") == "l2_c", "a save inside a reaction restores there")
	resumed.call("advance")
	var round: Dictionary = resumed.call("current")
	_expect(round["line_index"] == 1 and resumed.get("round_state")["fails"] == {"l2": 1},
		"after loading, the reaction still returns to the same round state")
	var legacy: Dictionary = saved.duplicate(true)
	legacy.erase("round")
	legacy.erase("stats")
	_expect(_runner().call("restore", legacy), "a save from before round v2 still loads")
	var tampered: Dictionary = saved.duplicate(true)
	tampered["round"]["caught"] = {"l9": "perfect"}
	_expect(not _runner().call("restore", tampered), "a round state naming an unknown line is rejected")
	var bad_stats: Dictionary = saved.duplicate(true)
	bad_stats["stats"] = {"fails": -1}
	_expect(not _runner().call("restore", bad_stats), "negative stats are rejected")


func _test_combo_round() -> void:
	var runner: RefCounted = _runner_at("r2")
	var round: Dictionary = runner.call("current")
	_expect(round["mode"] == "combo" and round["timer_seconds"] == 8.0 and not round["current_line"]["can_listen"],
		"a combo round starts at 8 seconds and cannot listen")
	_expect(not runner.call("set_boke_line", 1), "combo lines cannot be picked by hand")
	runner.call("resolve_boke", "a")
	_back_to(runner, "r2")
	round = runner.call("current")
	_expect(round["line_index"] == 1 and round["combo"] == 1 and round["timer_seconds"] == 6.0,
		"a catch moves to the next line and shortens the timer")
	runner.call("resolve_boke", "c")
	runner.call("advance")
	_expect(runner.get("node_id") == "r2_break", "failing mid-combo queues the combo break")
	_back_to(runner, "r2")
	round = runner.call("current")
	_expect(round["line_index"] == 1 and round["combo"] == 0 and round["timer_seconds"] == 8.0,
		"a fail resets the combo and the timer, on the same line")
	runner.call("resolve_boke", "a")
	_back_to(runner, "r2")
	_expect(runner.call("current")["current_line"]["qte"].size() > 0, "the last line is a QTE")
	runner.call("resolve_qte", true, -0.3)
	_expect(runner.get("node_id") == "c3_e", "tapping too early is the early fail")
	_back_to(runner, "r2")
	runner.call("resolve_qte", true, 0.05)
	_expect(runner.get("node_id") == "c3_p", "tapping inside the window is perfect")
	runner.call("advance")
	_expect(runner.get("node_id") == "r2_clear", "a broken combo clears without the bonus")


func _test_combo_bonus_and_super() -> void:
	var runner: RefCounted = _runner_at("r2")
	for option_line: int in range(2):
		runner.call("resolve_boke", "a")
		_back_to(runner, "r2")
	runner.call("resolve_qte", true, 0.0)
	runner.call("advance")
	_expect(runner.get("node_id") == "r2_bonus", "an unbroken combo plays the bonus before clear")

	var boosted: RefCounted = _runner_at("r2", 100)
	_expect(boosted.call("current")["super_available"], "full power offers the ultimate tsukkomi")
	var super_result: Dictionary = boosted.call("use_super")
	_expect(super_result.get("result") == "perfect" and boosted.get("node_id") == "r2_super", "the ultimate tsukkomi plays its node")
	_back_to(boosted, "r2")
	var round: Dictionary = boosted.call("current")
	_expect(round["line_index"] == 2 and round["combo"] == 2 and boosted.get("gameplay")["power"] == 0,
		"it catches every option slot, adds to the combo and spends the power; the QTE remains")
	_expect(not round["super_available"], "the ultimate tsukkomi is used once")


func _test_qte_judgement() -> void:
	var qte: Dictionary = {"window": 0.12}
	_expect(TsukkomiRound.judge_qte(qte, true, 0.0) == "perfect", "on the target is perfect")
	_expect(TsukkomiRound.judge_qte(qte, true, -0.2) == "early", "before the window is early")
	_expect(TsukkomiRound.judge_qte(qte, true, 0.2) == "late", "after the window is late")
	_expect(TsukkomiRound.judge_qte(qte, false, 0.0) == "late", "no tap is late")


## An option's `when` cases: the first whose conditions all hold (caught lines, items, flags)
## replaces result and goto; set_flags comes from the case or else the option.
func _test_when_outcomes() -> void:
	var option: Dictionary = {"id": "d", "label": "……", "result": "fail", "goto": "cold", "set_flags": {"gave_up": true},
		"when": [{"require_caught": ["l1", "l2"], "result": "hidden", "goto": "secret"},
			{"require": "milk_bottle", "flags": {"asked": "kagura"}, "result": "weak", "goto": "half", "set_flags": {"gave_up": false}}]}
	var state: Dictionary = TsukkomiRound.new_state("r")
	var outcome: Dictionary = TsukkomiRound.option_outcome(option, state, [], {"asked": "kagura"})
	_expect(outcome == {"result": "fail", "goto": "cold", "set_flags": {"gave_up": true}}, "no case holds: the option's own outcome")
	outcome = TsukkomiRound.option_outcome(option, state, ["milk_bottle"], {"asked": "gintoki"})
	_expect(outcome["result"] == "fail", "every condition of a case must hold (the flag differs)")
	outcome = TsukkomiRound.option_outcome(option, state, ["milk_bottle"], {"asked": "kagura"})
	_expect(outcome == {"result": "weak", "goto": "half", "set_flags": {"gave_up": false}}, "item and flag hold: that case, with its own set_flags")
	state["caught"] = {"l1": "weak", "l2": "perfect"}
	outcome = TsukkomiRound.option_outcome(option, state, ["milk_bottle"], {"asked": "kagura"})
	_expect(outcome == {"result": "hidden", "goto": "secret", "set_flags": {"gave_up": true}},
		"the first case that holds wins; without set_flags it keeps the option's")
	var story: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var version: String = StoryBuilder.fingerprint(story)
	story["nodes"]["r1"]["steps"][0]["lines"][1]["slot"]["options"][2]["when"] = [{"require_caught": ["l1"], "result": "hidden", "goto": "hidden_end"}]
	_expect(StoryBuilder.fingerprint(story) != version, "adding a when case changes the story version")


func _test_validation_errors() -> void:
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var cases: Array = [
		[func(s: Dictionary) -> void: s["nodes"]["r2"]["steps"][0]["lines"][0].erase("slot"), "needs a slot (every combo line"],
		[func(s: Dictionary) -> void: s["nodes"]["r1"]["steps"][0]["lines"][0].erase("whiff"), "needs a whiff node"],
		[func(s: Dictionary) -> void: s["nodes"]["r1"]["steps"][0]["lines"][2]["text"] = "沒有消音", "censor needs ▇"],
		[func(s: Dictionary) -> void: s["nodes"]["r2"]["steps"][0]["lines"][2]["slot"]["qte"].erase("window"), "qte.window must be positive"],
		[func(s: Dictionary) -> void: s["nodes"]["r1"]["steps"][0]["clear"] = "nowhere", "clear target is invalid"],
		[func(s: Dictionary) -> void: s["nodes"]["r1"]["steps"][0]["lines"][2]["slot"]["options"][1]["require_caught"] = ["l9"], "require_caught line 'l9'"],
		[func(s: Dictionary) -> void: s["nodes"]["r1"]["steps"][0]["mode"] = "rapid", "mode must be testimony or combo"],
		[func(s: Dictionary) -> void: s["nodes"]["r1"]["steps"][0]["lines"][1]["slot"]["placard"] = {"text": "犯人是神樂"},
			"node 'r1' step 0 boke line 'l2' placard needs text and a goto"],
		[func(s: Dictionary) -> void: s["nodes"]["r1"]["steps"][0]["lines"][2]["slot"]["placard"] = {"text": "x", "goto": "l3_b"},
			"keep one fourth-wall target"],
		[func(s: Dictionary) -> void: s["nodes"]["r2"]["steps"][0]["lines"][2]["slot"]["placard"] = {"text": "x", "goto": "c3_p"},
			"placard needs options beside it"],
		[func(s: Dictionary) -> void: s["nodes"]["r1"]["steps"][0]["lines"][1]["slot"]["placard"] = {"text": "x", "goto": "l2_a", "result": "great"},
			"placard result is invalid"],
		[func(s: Dictionary) -> void: s["nodes"]["r1"]["steps"][0]["lines"][1]["slot"]["options"][2]["when"] = [{"result": "hidden", "goto": "hidden_end"}],
			"node 'r1' step 0 boke line 'l2' option 'c' when[0] needs a condition"],
		[func(s: Dictionary) -> void: s["nodes"]["r1"]["steps"][0]["lines"][1]["slot"]["options"][2]["when"] = [{"require_caught": ["l9"], "result": "hidden", "goto": "hidden_end"}],
			"option 'c' require_caught line 'l9'"],
		[func(s: Dictionary) -> void: s["nodes"]["r1"]["steps"][0]["lines"][1]["slot"]["options"][2]["when"] = [{"require_caught": ["l1"], "result": "great", "goto": "hidden_end"}],
			"when[0] result is invalid"],
		[func(s: Dictionary) -> void: s["nodes"]["r1"]["steps"][0]["lines"][1]["slot"]["options"][2]["when"] = [{"require_caught": ["l1"], "result": "hidden", "goto": "nowhere"}],
			"when[0] goto target is invalid"],
		[func(s: Dictionary) -> void: s["nodes"]["r1"]["steps"][0]["lines"][1]["slot"]["options"][2]["when"] = [{"require_caught": ["l1"], "result": "hidden", "goto": "hidden_end", "results": 1}],
			"when[0] has unknown field 'results'"],
		[func(s: Dictionary) -> void: s["nodes"]["r1"]["steps"][0]["lines"][1]["slot"]["options"][2]["when"] = [{"flags": {"nope": true}, "result": "hidden", "goto": "hidden_end"}],
			"node 'r1' step 0 when flags 'nope' is not a story flag"],
		[func(s: Dictionary) -> void: s["nodes"]["r1"]["steps"][0]["lines"][1]["slot"]["options"][2]["when"] = [{"flags": {"l2_caught": "yes"}, "result": "hidden", "goto": "hidden_end"}],
			"when flags 'l2_caught' is not a story flag of that type"],
	]
	for case: Array in cases:
		var story: Dictionary = base.duplicate(true)
		case[0].call(story)
		var file: FileAccess = FileAccess.open(BROKEN, FileAccess.WRITE)
		file.store_string(JSON.stringify(story))
		file.close()
		var runner: RefCounted = StoryRunner.new()
		_expect(not runner.call("load_story", BROKEN) and String(runner.get("error_message")).contains(case[1]),
			"invalid round is rejected with '%s' (got: %s)" % [case[1], runner.get("error_message")])
	DirAccess.remove_absolute(BROKEN)


func _runner() -> RefCounted:
	var runner: RefCounted = StoryRunner.new()
	_expect(runner.call("load_story", FIXTURE), "fixture loads: %s" % runner.get("error_message"))
	return runner


## A runner positioned at the start of a round, optionally with full power.
func _runner_at(round_node: String, power: int = 0) -> RefCounted:
	var runner: RefCounted = _runner()
	var saved: Dictionary = runner.call("snapshot")
	saved["node_id"] = round_node
	saved["step_index"] = 0
	saved["gameplay"]["power"] = power
	_expect(runner.call("restore", saved), "positioned at %s: %s" % [round_node, runner.get("error_message")])
	return runner


func _back_to(runner: RefCounted, round_node: String) -> void:
	for _step: int in range(6):
		if runner.get("node_id") == round_node:
			return
		runner.call("advance")
	_expect(false, "returned to %s (at %s)" % [round_node, runner.get("node_id")])
