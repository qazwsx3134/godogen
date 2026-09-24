extends SceneTree

const StoryRunner = preload("../scripts/story_runner.gd")
const STORY_PATH: String = "res://data/phase3_story.json"
const PHASE2_STORY_PATH: String = "res://data/phase2_story.json"
const LEGACY_STORY_PATH: String = "res://data/debt_story.json"
const MAX_STEPS: int = 128

var failures: Array[String] = []


func _init() -> void:
	_test_phase3_data_and_investigation()
	_test_boke_navigation_visibility_and_snapshot()
	_test_all_results_and_single_apply()
	_test_timeout_and_checkpoint_retry()
	_test_snapshot_restore_and_legacy_compatibility()
	_test_phase3_validation()

	if failures.is_empty():
		print("PHASE 3 STORY TESTS PASSED")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		print("PHASE 3 STORY TESTS FAILED: %d" % failures.size())
		quit(1)


func _test_phase3_data_and_investigation() -> void:
	var runner = StoryRunner.new()
	var loaded: bool = runner.load_story(STORY_PATH)
	_expect(loaded, "technical Phase 3 sample loads: %s" % runner.error_message)
	if not loaded:
		return
	_expect(String(runner.current().get("op", "")) == "bg", "sample opens on living-room background")
	var investigation: Dictionary = _advance_until_op(runner, "investigate", "sample reaches hotspot")
	_expect(String(investigation.get("id", "")) == "living_room_milk_clue", "investigation has a stable id")
	_expect((investigation.get("hotspots", []) as Array).size() == 1, "sample has one hotspot")
	_expect(not bool(((investigation["hotspots"] as Array)[0] as Dictionary).get("checked", false)), "hotspot starts unchecked")

	var before: Dictionary = runner.snapshot()
	var blocked: Dictionary = runner.advance()
	_expect(String(blocked.get("op", "")) == "investigate", "advance cannot skip unchecked hotspot")
	_expect(runner.snapshot() == before, "blocked advance leaves runner state unchanged")
	_expect(not runner.inspect_hotspot("unknown_hotspot"), "unknown hotspot is rejected")
	_expect(runner.inspect_hotspot("empty_milk_bottle"), "valid hotspot is inspectable")
	_expect(runner.items == ["milk_bottle"], "inspection grants the clue item")
	_expect(runner.inspect_hotspot("empty_milk_bottle"), "inspecting same hotspot again is safe")
	_expect(runner.items == ["milk_bottle"], "same clue is granted only once")
	_expect(bool(((runner.current()["hotspots"] as Array)[0] as Dictionary).get("checked", false)), "current exposes checked hotspot state")
	_expect(String(runner.advance().get("op", "")) == "boke_round", "completed investigation advances into the round")
	_expect(_option_exists(runner.current(), "point_to_bottle"), "clue unlocks the required perfect option")

	var no_clue_story: Dictionary = _read_story()
	no_clue_story["entry"] = "gintoki_round"
	var no_clue_path: String = _write_temp_story("no_clue", no_clue_story)
	var no_clue_runner = StoryRunner.new()
	_expect(no_clue_runner.load_story(no_clue_path), "direct-round variant loads without clue")
	_expect(not _option_exists(no_clue_runner.current(), "point_to_bottle"), "required perfect option is hidden without clue")
	var no_clue_before: Dictionary = no_clue_runner.snapshot()
	_expect(no_clue_runner.resolve_boke("point_to_bottle").is_empty(), "hidden perfect option cannot be selected by id")
	_expect(no_clue_runner.snapshot() == no_clue_before, "hidden option rejection has no side effects")
	_remove_temp_story(no_clue_path)


func _test_boke_navigation_visibility_and_snapshot() -> void:
	var runner = StoryRunner.new()
	_expect(runner.load_story(STORY_PATH), "boke interaction runner loads")
	var round: Dictionary = _advance_to_round_with_clue(runner)
	_expect(String(round.get("op", "")) == "boke_round", "clue route reaches boke round")
	_expect(float(round.get("timer_seconds", 0.0)) == 8.0, "sample round uses eight-second timer")
	_expect(int(round.get("line_index", -1)) == 0, "round begins at line zero")
	_expect(not bool(round.get("listened", true)), "line starts not listened")
	_expect(_option_exists(round, "point_to_bottle") and _option_exists(round, "weak_comeback") and _option_exists(round, "missed_comeback") and _option_exists(round, "secret_comeback"), "all four outcome options are visible with clue")
	_expect(not runner.set_boke_line(2), "out-of-range line index is rejected")
	_expect(runner.set_boke_line(1), "runner navigates to second line")
	var second_line: Dictionary = runner.current()
	_expect(int(second_line.get("line_index", -1)) == 1, "current exposes selected line index")
	_expect(String((second_line.get("current_line", {}) as Dictionary).get("id", "")) == "sleep_excuse", "current exposes selected line")
	_expect(not bool(second_line.get("listened", true)), "selected line initially has no Listen follow-up state")
	_expect(runner.listen_boke_line(), "Listen action records follow-up")
	_expect(runner.listen_boke_line(), "Listen action is idempotent")
	var listened: Dictionary = runner.current()
	_expect(bool(listened.get("listened", false)), "current exposes listened state")
	_expect(String((listened.get("current_line", {}) as Dictionary).get("listen_text", "")).contains("手會自動"), "current exposes follow-up text after listening")

	var saved: Dictionary = runner.snapshot()
	var restored = StoryRunner.new()
	_expect(restored.load_story(STORY_PATH), "interactive snapshot target loads")
	_expect(restored.restore(saved), "interactive snapshot restores")
	_expect(restored.snapshot() == saved, "interactive snapshot round-trips exactly")
	_expect(int(restored.current().get("line_index", -1)) == 1 and bool(restored.current().get("listened", false)), "line and Listen state survive restore")
	_expect(not restored.set_boke_line(10), "invalid line selection leaves round active")
	_expect(restored.current() == runner.current(), "invalid line selection leaves presentation state unchanged")


func _test_all_results_and_single_apply() -> void:
	var cases: Array[Dictionary] = [
		{"id": "point_to_bottle", "result": "perfect", "node": "perfect", "glasses": 5, "power": 30},
		{"id": "weak_comeback", "result": "weak", "node": "weak", "glasses": 5, "power": 10},
		{"id": "missed_comeback", "result": "fail", "node": "cold", "glasses": 4, "power": 0},
		{"id": "secret_comeback", "result": "hidden", "node": "hidden", "glasses": 5, "power": 0}
	]
	for test_case: Dictionary in cases:
		var runner = StoryRunner.new()
		_expect(runner.load_story(STORY_PATH), "%s outcome runner loads" % test_case["result"])
		_advance_to_round_with_clue(runner)
		var resolution: Dictionary = runner.resolve_boke(String(test_case["id"]))
		_expect(String(resolution.get("result", "")) == String(test_case["result"]), "%s outcome resolves" % test_case["result"])
		_expect(String(runner.node_id) == String(test_case["node"]), "%s outcome routes to its target" % test_case["result"])
		_expect(int(runner.gameplay["glasses"]) == int(test_case["glasses"]), "%s applies expected glasses delta" % test_case["result"])
		_expect(int(runner.gameplay["power"]) == int(test_case["power"]), "%s applies expected power delta" % test_case["result"])
		_expect(String(runner.flags.get("round_result", "")) == String(test_case["result"]), "%s applies authored set_flags" % test_case["result"])
		var after: Dictionary = runner.snapshot()
		_expect(runner.resolve_boke(String(test_case["id"])).is_empty(), "%s cannot resolve twice" % test_case["result"])
		_expect(runner.snapshot() == after, "%s duplicate resolution has no effects" % test_case["result"])
		var restored = StoryRunner.new()
		_expect(restored.load_story(STORY_PATH), "%s result restore target loads" % test_case["result"])
		_expect(restored.restore(after), "%s resolved state restores" % test_case["result"])
		_expect(int(restored.gameplay["glasses"]) == int(test_case["glasses"]) and int(restored.gameplay["power"]) == int(test_case["power"]), "%s stats do not reapply on restore" % test_case["result"])

	var capped = StoryRunner.new()
	_expect(capped.load_story(STORY_PATH), "power cap runner loads")
	_advance_to_round_with_clue(capped)
	capped.gameplay["power"] = 90
	_expect(String(capped.resolve_boke("point_to_bottle").get("result", "")) == "perfect", "perfect outcome resolves at high power")
	_expect(int(capped.gameplay["power"]) == 100, "perfect power gain is capped at max_power")


func _test_timeout_and_checkpoint_retry() -> void:
	var timeout_runner = StoryRunner.new()
	_expect(timeout_runner.load_story(STORY_PATH), "timeout runner loads")
	_advance_to_round_with_clue(timeout_runner)
	var timeout_result: Dictionary = timeout_runner.timeout_boke()
	_expect(String(timeout_result.get("result", "")) == "fail", "timeout uses configured fail result")
	_expect(String(timeout_runner.node_id) == "cold" and int(timeout_runner.gameplay["glasses"]) == 4, "timeout routes cold and consumes one glass")

	var runner = StoryRunner.new()
	_expect(runner.load_story(STORY_PATH), "checkpoint runner loads")
	_advance_to_round_with_clue(runner)
	var first_checkpoint: Dictionary = runner.snapshot()["checkpoint"] as Dictionary
	_expect(String(first_checkpoint.get("round_id", "")) == "gintoki_milk_round", "first round entry captures checkpoint")
	_expect(runner.items.has("milk_bottle"), "checkpoint includes clue inventory")
	for failure_index: int in range(5):
		var result: Dictionary = runner.resolve_boke("missed_comeback")
		_expect(String(result.get("result", "")) == "fail", "failure %d resolves" % (failure_index + 1))
		if failure_index < 4:
			_expect(String(runner.node_id) == "cold", "failure %d reaches retry dialogue" % (failure_index + 1))
			_expect(int(runner.gameplay["glasses"]) == 4 - failure_index, "failure %d consumes exactly one glass" % (failure_index + 1))
			_expect((runner.snapshot()["checkpoint"] as Dictionary) == first_checkpoint, "failure does not replace pre-round checkpoint")
			_expect(String(runner.advance().get("op", "")) == "boke_round", "cold dialogue loops to round")
		else:
			_expect(bool(result.get("game_over", false)), "fifth failure enters game over")
			_expect(String(runner.node_id) == "game_over", "zero glasses route to configured game-over node")
			_expect(int(runner.gameplay["glasses"]) == 0, "game over occurs at zero glasses")
		_expect((runner.snapshot()["checkpoint"] as Dictionary) == first_checkpoint, "game over keeps original checkpoint")
	var game_over_snapshot: Dictionary = runner.snapshot()
	var resumed = StoryRunner.new()
	_expect(resumed.load_story(STORY_PATH), "game-over restore target loads")
	_expect(resumed.restore(game_over_snapshot), "game-over snapshot restores")
	_expect(resumed.retry_checkpoint(), "restored game over can retry checkpoint")
	_expect(String(resumed.current().get("op", "")) == "boke_round", "retry returns to boke round")
	_expect(int(resumed.gameplay["glasses"]) == 5 and int(resumed.gameplay["power"]) == 0, "retry restores pre-round gameplay values")
	_expect(resumed.items.has("milk_bottle"), "retry restores pre-round clue")
	_expect((resumed.snapshot()["checkpoint"] as Dictionary) == first_checkpoint, "retry preserves original checkpoint")
	_expect(not resumed.retry_checkpoint(), "retry is rejected after leaving active Game Over")


func _test_snapshot_restore_and_legacy_compatibility() -> void:
	var runner = StoryRunner.new()
	_expect(runner.load_story(STORY_PATH), "Phase 3 snapshot source loads")
	_advance_to_round_with_clue(runner)
	var phase3_snapshot: Dictionary = runner.snapshot()
	var restored = StoryRunner.new()
	_expect(restored.load_story(STORY_PATH), "Phase 3 snapshot target loads")
	_expect(restored.restore(phase3_snapshot), "Phase 3 full snapshot restores")
	_expect(restored.snapshot() == phase3_snapshot, "Phase 3 full snapshot is exact")

	for legacy_path: String in [LEGACY_STORY_PATH, PHASE2_STORY_PATH]:
		var legacy_runner = StoryRunner.new()
		_expect(legacy_runner.load_story(legacy_path), "legacy story loads: %s" % legacy_path)
		var old_snapshot: Dictionary = legacy_runner.snapshot()
		for key: String in ["gameplay", "checked_hotspots", "boke", "checkpoint", "game_over_active"]:
			old_snapshot.erase(key)
		var target = StoryRunner.new()
		_expect(target.load_story(legacy_path), "legacy restore target loads: %s" % legacy_path)
		_expect(target.restore(old_snapshot), "schema-3 snapshot without Phase 3 fields remains compatible: %s" % legacy_path)
		_expect(target.gameplay == {"glasses": 5, "max_glasses": 5, "power": 0, "max_power": 100}, "legacy restore defaults gameplay: %s" % legacy_path)
		_expect(target.snapshot().has("boke") and (target.snapshot()["boke"] as Dictionary).is_empty() == false, "new runner emits complete snapshot after legacy restore: %s" % legacy_path)

	var phase2_runner = StoryRunner.new()
	_expect(phase2_runner.load_story(PHASE2_STORY_PATH), "legacy rejection source loads")
	var legacy_snapshot: Dictionary = phase2_runner.snapshot()
	for key: String in ["gameplay", "checked_hotspots", "boke", "checkpoint", "game_over_active"]:
		legacy_snapshot.erase(key)
	var phase3_target = StoryRunner.new()
	_expect(phase3_target.load_story(STORY_PATH), "Phase 3 old-snapshot rejection target loads")
	_expect(not phase3_target.restore(legacy_snapshot), "Phase 3 story rejects pre-Phase-3 snapshot shape")

	var inconsistent: Dictionary = phase3_snapshot.duplicate(true)
	(inconsistent["gameplay"] as Dictionary)["glasses"] = 6
	var before_bad: Dictionary = restored.snapshot()
	_expect(not restored.restore(inconsistent), "snapshot rejects out-of-range glasses")
	_expect(restored.snapshot() == before_bad, "invalid Phase 3 snapshot leaves state untouched")


func _test_phase3_validation() -> void:
	var invalid_stories: Array[Dictionary] = []
	var duplicate_hotspot: Dictionary = _read_story()
	var hotspots: Array = duplicate_hotspot["nodes"]["phase3_open"]["steps"][3]["hotspots"]
	(hotspots[0] as Dictionary)["id"] = "duplicate"
	hotspots.append((hotspots[0] as Dictionary).duplicate(true))
	invalid_stories.append({"label": "duplicate_hotspot", "story": duplicate_hotspot})

	var invalid_position: Dictionary = _read_story()
	(invalid_position["nodes"]["phase3_open"]["steps"][3]["hotspots"][0] as Dictionary)["pos"] = [1.01, 0.5]
	invalid_stories.append({"label": "invalid_position", "story": invalid_position})

	var missing_item: Dictionary = _read_story()
	(missing_item["nodes"]["phase3_open"]["steps"][3]["hotspots"][0] as Dictionary)["item"] = "not_in_catalog"
	invalid_stories.append({"label": "missing_item", "story": missing_item})

	var duplicate_command_id: Dictionary = _read_story()
	duplicate_command_id["nodes"]["perfect"]["steps"] = [duplicate_command_id["nodes"]["gintoki_round"]["steps"][0].duplicate(true)]
	invalid_stories.append({"label": "duplicate_round_id", "story": duplicate_command_id})

	var invalid_result: Dictionary = _read_story()
	(invalid_result["nodes"]["gintoki_round"]["steps"][0]["tsukkomi"]["options"][0] as Dictionary)["result"] = "great"
	invalid_stories.append({"label": "invalid_result", "story": invalid_result})

	var invalid_timer: Dictionary = _read_story()
	(invalid_timer["nodes"]["gintoki_round"]["steps"][0] as Dictionary)["timer_seconds"] = 0
	invalid_stories.append({"label": "invalid_timer", "story": invalid_timer})

	var no_unconditional: Dictionary = _read_story()
	for raw_option: Variant in no_unconditional["nodes"]["gintoki_round"]["steps"][0]["tsukkomi"]["options"]:
		(raw_option as Dictionary)["require"] = "milk_bottle"
	invalid_stories.append({"label": "no_unconditional", "story": no_unconditional})

	for test_case: Dictionary in invalid_stories:
		var path: String = _write_temp_story(String(test_case["label"]), test_case["story"] as Dictionary)
		var invalid_runner = StoryRunner.new()
		_expect(not invalid_runner.load_story(path), "%s story is rejected" % test_case["label"])
		_expect(invalid_runner.error_message.contains("node '") and invalid_runner.error_message.contains("step "), "%s error identifies node and step context" % test_case["label"])
		_remove_temp_story(path)

	var missing_target: Dictionary = _read_story()
	(missing_target["nodes"]["gintoki_round"]["steps"][0]["tsukkomi"]["options"][0] as Dictionary)["goto"] = "missing_node"
	var target_path: String = _write_temp_story("missing_boke_target", missing_target)
	var target_runner = StoryRunner.new()
	_expect(not target_runner.load_story(target_path), "unknown boke target is rejected")
	_expect(target_runner.error_message.contains("node 'gintoki_round' step 0"), "unknown target error retains node/step context")
	_remove_temp_story(target_path)


func _advance_to_round_with_clue(runner) -> Dictionary:
	var investigation: Dictionary = _advance_until_op(runner, "investigate", "reach investigation")
	if not investigation.is_empty():
		runner.inspect_hotspot(String(((investigation["hotspots"] as Array)[0] as Dictionary)["id"]))
		runner.advance()
	return runner.current()


func _advance_until_op(runner, desired_op: String, context: String) -> Dictionary:
	for _step: int in range(MAX_STEPS):
		var command: Dictionary = runner.current()
		if String(command.get("op", "")) == desired_op:
			return command
		if command.is_empty() or String(command.get("op", "")) == "end" or String(command.get("op", "")) == "choice":
			break
		runner.advance()
	_expect(false, "%s: did not reach %s" % [context, desired_op])
	return {}


func _option_exists(command: Dictionary, option_id: String) -> bool:
	var tsukkomi: Dictionary = command.get("tsukkomi", {}) as Dictionary
	for raw_option: Variant in tsukkomi.get("options", []):
		if raw_option is Dictionary and String((raw_option as Dictionary).get("id", "")) == option_id:
			return true
	return false


func _read_story() -> Dictionary:
	var file: FileAccess = FileAccess.open(STORY_PATH, FileAccess.READ)
	if file == null:
		_expect(false, "Phase 3 sample opens for mutation")
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		_expect(false, "Phase 3 sample parses for mutation")
		return {}
	return (parser.data as Dictionary).duplicate(true)


func _write_temp_story(label: String, story: Dictionary) -> String:
	var path: String = "user://phase3_story_%s.json" % label
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_expect(false, "unable to create temporary story: %s" % label)
		return path
	file.store_string(JSON.stringify(story))
	file.close()
	return path


func _remove_temp_story(path: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
