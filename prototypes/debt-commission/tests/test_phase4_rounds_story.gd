extends "res://addons/proto_kit/test_kit.gd"
## The Phase 4 rounds sample (story_src/phase4_rounds.*) is playable end to end through the
## runner: a perfect run fills the power gauge in time for the ultimate tsukkomi and earns the
## combo bonus; whiffs reach the hint; the censor bar and the hidden give-up both work.

const StoryRunner = preload("res://scripts/story_runner.gd")
const SAMPLE: String = "res://data/phase4_rounds_story.json"


func _init() -> void:
	_test_perfect_run_reaches_super_and_bonus()
	_test_whiffs_reach_the_hint()
	_test_hidden_needs_two_catches()
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
	_expect(runner.call("current")["id"] == "r2_combo", "the testimony round ends once every slot is caught")

	var combo: Dictionary = runner.call("current")
	_expect(combo["timer_seconds"] == 8.0 and not combo["super_available"], "the combo opens at 8 s without the super")
	runner.call("resolve_boke", "a")
	_to_round(runner)
	combo = runner.call("current")
	_expect(runner.get("gameplay")["power"] == 100 and combo["super_available"] and combo["timer_seconds"] == 6.0,
		"a perfect first catch fills the gauge: the super lights up and the timer drops to 6 s")
	_expect(runner.call("use_super").get("result") == "perfect", "the ultimate tsukkomi fires")
	_to_round(runner)
	combo = runner.call("current")
	_expect(combo["current_line"]["id"] == "c4" and not (combo["current_line"]["qte"] as Dictionary).is_empty(),
		"the super catches every option line and leaves the QTE")
	_expect(runner.call("resolve_qte", true, 0.05).get("result") == "perfect", "a tap inside the window is perfect")
	_to_round(runner)
	_expect(runner.get("node_id") == "r2_clear" and runner.get("stats")["max_combo"] == 4 and not runner.get("stats").has("fails"),
		"an unbroken combo earns the bonus scene and reaches the end (%s)" % [runner.get("stats")])


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
