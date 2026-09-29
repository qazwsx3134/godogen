extends "res://addons/proto_kit/test_kit.gd"
## The Phase 4 rounds sample (story_src/phase4_rounds.*) is playable end to end through the
## runner: a perfect run through Gintoki's and Kagura's testimonies fills the power gauge for the
## ultimate tsukkomi and earns the combo bonus; whiffs reach the hint; the censor bar and the
## hidden give-up work; Elisabeth's placard answers its line; the give-up that is always offered
## is cold until lines 1 and 2 are caught and hidden after; saves and Game Over retries keep the
## placard's text.

const StoryRunner = preload("res://scripts/story_runner.gd")
const SAMPLE: String = "res://data/phase4_rounds_story.json"


func _init() -> void:
	_test_perfect_run_reaches_super_and_bonus()
	_test_whiffs_reach_the_hint()
	_test_hidden_needs_two_catches()
	_test_placard_follows_the_line()
	_test_conditional_give_up()
	_test_placard_survives_saves_and_retry()
	_finish("PHASE 4 ROUNDS STORY TESTS")


func _test_perfect_run_reaches_super_and_bonus() -> void:
	var runner: RefCounted = _runner()
	_to_round(runner)
	_expect(runner.get("items").has("milk_bottle") and runner.get("items").has("milk_trace"), "the opening hands over two materials")
	_expect(runner.call("listen_boke_line"), "line 1 can be heard out")
	_to_round(runner)
	_expect(runner.get("items").has("gin_sleep_testimony"), "listening to line 1 grants Gintoki's testimony")
	for step: Array in [[1, "option", "a"], [2, "censor", ""], [3, "option", "a"]]:
		runner.call("set_boke_line", step[0])
		var result: Dictionary = runner.call("resolve_censor") if step[1] == "censor" else runner.call("resolve_boke", step[2])
		_expect(result.get("result") == "perfect", "line %d is caught perfectly" % (step[0] + 1))
		_to_round(runner)
	_expect(runner.get("gameplay")["power"] == 90, "three perfect catches give 90 power (%s)" % runner.get("gameplay")["power"])
	_expect(runner.call("current")["id"] == "kagura_testimony", "the testimony round ends once every slot is caught")

	for step: Array in [[0, "option", "a"], [1, "placard", ""], [2, "option", "a"]]:
		runner.call("set_boke_line", step[0])
		var result: Dictionary = runner.call("resolve_placard") if step[1] == "placard" else runner.call("resolve_boke", step[2])
		_expect(result.get("result") == "perfect", "Kagura's line %d is caught perfectly" % (step[0] + 1))
		_to_round(runner)
	var combo: Dictionary = runner.call("current")
	_expect(combo["id"] == "r2_combo" and runner.get("gameplay")["power"] == 100 and combo["super_available"]
		and combo["timer_seconds"] == 8.0, "two testimonies caught perfectly fill the gauge: the combo opens at 8 s with the super")
	_expect(runner.call("use_super").get("result") == "perfect", "the ultimate tsukkomi fires")
	_to_round(runner)
	combo = runner.call("current")
	_expect(combo["current_line"]["id"] == "c4" and not (combo["current_line"]["qte"] as Dictionary).is_empty(),
		"the super catches every option line and leaves the QTE")
	_expect(runner.call("resolve_qte", true, 0.05).get("result") == "perfect", "a tap inside the window is perfect")
	_to_round(runner)
	_expect(runner.get("node_id") == "r2_clear" and runner.get("stats")["max_combo"] == 4 and not runner.get("stats").has("fails"),
		"an unbroken combo earns the bonus scene and reaches the end (%s)" % [runner.get("stats")])


## The placard is blank on Kagura's other lines, shows 犯人是神樂 on line 2 (tappable only on the
## round itself, not in a reaction scene), and the story flips it to 我只是路過 once caught.
func _test_placard_follows_the_line() -> void:
	var runner: RefCounted = _kagura_round()
	var view: Dictionary = runner.call("placard_view")
	_expect(view["text"] == "" and not view["tappable"], "line 1: the placard is blank and not tappable (%s)" % [view])
	_expect(runner.call("resolve_placard").is_empty(), "tapping a blank placard does nothing")
	runner.call("set_boke_line", 1)
	view = runner.call("placard_view")
	_expect(view["text"] == "犯人是神樂" and view["tappable"] and view["slot"], "line 2: the placard reads 犯人是神樂 and answers it")
	_expect(runner.call("current")["current_line"]["options"].map(func(o: Dictionary) -> String: return o["id"]) == ["b", "c", "d"],
		"the options stay beside the placard")
	_expect(runner.call("listen_boke_line"), "line 2 can be heard out")
	view = runner.call("placard_view")
	_expect(view["text"] == "犯人是神樂" and not view["tappable"], "during line 2's scene the placard still reads, but only the round takes the tap")
	_to_round(runner)
	var glasses: int = runner.get("gameplay")["glasses"]
	var power: int = runner.get("gameplay")["power"]
	_expect(runner.call("resolve_placard").get("result") == "perfect" and runner.get("node_id") == "k_l2_placard",
		"tapping it catches line 2 perfectly and plays its scene")
	_expect(runner.get("gameplay")["glasses"] == glasses and runner.get("gameplay")["power"] == power + 30, "a placard catch adds 30 power")
	_to_round(runner)
	view = runner.call("placard_view")
	_expect(view["text"] == "我只是路過" and not view["tappable"] and runner.call("current")["line_index"] == 1,
		"after the scene the story has flipped the placard to 我只是路過 (%s)" % [view])
	runner.call("set_boke_line", 2)
	_expect(runner.call("placard_view")["text"] == "我只是路過", "the flipped text stays on the other lines")


## Line 3's 放棄吐槽 is always offered: cold (a glass, Q2) until lines 1 and 2 are caught,
## hidden after (the round is left for the hidden scene).
func _test_conditional_give_up() -> void:
	var runner: RefCounted = _kagura_round()
	runner.call("set_boke_line", 2)
	_expect(runner.call("current")["current_line"]["options"].map(func(o: Dictionary) -> String: return o["id"]).has("d"),
		"the give-up is offered before anything is caught")
	var glasses: int = runner.get("gameplay")["glasses"]
	var cold: Dictionary = runner.call("resolve_boke", "d")
	_expect(cold.get("result") == "fail" and runner.get("node_id") == "k_give_up" and runner.get("gameplay")["glasses"] == glasses - 1,
		"with nothing caught the give-up is a cold take (%s)" % [cold])
	_to_round(runner)
	runner.call("set_boke_line", 0)
	runner.call("resolve_boke", "b")
	_to_round(runner)
	runner.call("set_boke_line", 2)
	_expect(runner.call("resolve_boke", "d").get("result") == "fail", "one catch is not enough: still cold")
	_to_round(runner)
	runner.call("set_boke_line", 1)
	runner.call("resolve_boke", "b")
	_to_round(runner)
	runner.call("set_boke_line", 2)
	var hidden: Dictionary = runner.call("resolve_boke", "d")
	_expect(hidden.get("result") == "hidden" and runner.get("node_id") == "k_hidden" and runner.get("round_state").is_empty(),
		"with lines 1 and 2 caught the same option is the hidden route (%s)" % [hidden])
	_expect(runner.get("stats").get("hidden", 0) == 1 and runner.get("gameplay")["glasses"] == glasses - 2,
		"the hidden route counts once and costs nothing")
	_to_round(runner)
	_expect(runner.call("current")["id"] == "r2_combo", "the hidden scene joins the combo round")


## The placard's text is part of a save and of the round's checkpoint: a Game Over retry puts back
## the blank board the round started with, and a save written before placards existed still loads.
func _test_placard_survives_saves_and_retry() -> void:
	var runner: RefCounted = _kagura_round()
	runner.call("set_boke_line", 1)
	runner.call("resolve_placard")
	_to_round(runner)
	var saved: Dictionary = runner.call("snapshot")
	_expect(saved["placard"] == "我只是路過", "the snapshot keeps the placard text")
	var resumed: RefCounted = _runner()
	_expect(resumed.call("restore", saved) and resumed.call("placard_view")["text"] == "我只是路過", "a restored game shows it again")
	var legacy: Dictionary = saved.duplicate(true)
	legacy.erase("placard")
	legacy.erase("investigations")
	(legacy["checkpoint"] as Dictionary).erase("placard")
	(legacy["checkpoint"] as Dictionary).erase("investigations")
	_expect(resumed.call("restore", legacy) and resumed.get("placard") == "", "a save from before placards loads with a blank board")
	var bad: Dictionary = saved.duplicate(true)
	bad["placard"] = 3
	_expect(not resumed.call("restore", bad), "a placard that is not text is rejected")
	for _whiff: int in range(8):
		if runner.get("gameplay")["glasses"] == 0:
			break
		runner.call("set_boke_line", 2)
		runner.call("resolve_boke", "c")
		_to_round(runner, "game_over")
	_expect(runner.get("node_id") == "game_over", "cold takes empty the glasses")
	_expect(runner.call("retry_checkpoint") and runner.call("current")["id"] == "kagura_testimony"
		and runner.call("placard_view")["text"] == "" and (runner.get("round_state")["caught"] as Dictionary).is_empty(),
		"the retry restarts Kagura's round with the blank board it began with")


## A runner at Kagura's testimony, Gintoki's caught with a weak, a censor tear and a weak.
func _kagura_round() -> RefCounted:
	var runner: RefCounted = _runner()
	_to_round(runner)
	for step: Array in [[1, "option", "b"], [2, "censor", ""], [3, "option", "b"]]:
		runner.call("set_boke_line", step[0])
		if step[1] == "censor":
			runner.call("resolve_censor")
		else:
			runner.call("resolve_boke", step[2])
		_to_round(runner)
	_expect(runner.call("current").get("id") == "kagura_testimony", "reached Kagura's testimony")
	return runner


func _test_whiffs_reach_the_hint() -> void:
	var runner: RefCounted = _runner()
	_to_round(runner)
	for attempt: int in range(3):
		_expect(runner.call("whiff_boke").get("result") == "fail", "whiff %d is a fail" % (attempt + 1))
		_to_round(runner, "r1_l1_hint")
	_expect(runner.get("node_id") == "r1_l1_hint" and runner.get("gameplay")["glasses"] == 2,
		"the third whiff plays Kagura's hint; each whiff cost a glass")


func _test_hidden_needs_two_catches() -> void:
	var runner: RefCounted = _runner()
	_to_round(runner)
	runner.call("set_boke_line", 3)
	var ids: Array = runner.call("current")["current_line"]["options"].map(func(o: Dictionary) -> String: return o["id"])
	_expect(not ids.has("d"), "the give-up option waits for lines 2 and 3 (%s)" % [ids])
	runner.call("set_boke_line", 1)
	runner.call("resolve_boke", "b")
	_to_round(runner)
	runner.call("set_boke_line", 2)
	runner.call("resolve_censor")
	_to_round(runner)
	runner.call("set_boke_line", 3)
	_expect(runner.call("resolve_boke", "d").get("result") == "hidden", "with both caught the give-up is offered")
	_to_round(runner)
	_expect(runner.call("current")["op"] == "end", "the hidden route leaves the round for its ending")


## Advances through lines and effects to the next round, choice or ending (or stop_at).
func _to_round(runner: RefCounted, stop_at: String = "") -> void:
	for _i in range(60):
		var op: String = String(runner.call("current").get("op", ""))
		if op in ["boke_round", "end", "choice"] or runner.get("node_id") == stop_at:
			return
		runner.call("advance")
	failures.append("stuck before a round at %s" % runner.get("node_id"))


func _runner() -> RefCounted:
	var runner: RefCounted = StoryRunner.new()
	_expect(runner.call("load_story", SAMPLE), "the sample loads: %s" % runner.get("error_message"))
	return runner


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
