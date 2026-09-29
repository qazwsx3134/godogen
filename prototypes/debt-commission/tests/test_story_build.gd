extends "res://addons/proto_kit/test_kit.gd"
## Story build pipeline: .dialogue -> StoryRunner JSON, the structural version, strict errors,
## and the Phase 4 four-clue sample through StoryRunner.

const StoryBuilder = preload("res://tools/story_build/story_builder.gd")
const StoryRunner = preload("res://scripts/story_runner.gd")
const SOURCE: String = "res://story_src/phase4.dialogue"
const OUTPUT: String = "res://data/phase4_story.json"


func _init() -> void:
	_test_phase4_build_matches_committed_json()
	_test_version_ignores_text_but_tracks_structure()
	_test_errors_name_their_location()
	_test_new_commands()
	_test_phase4_four_clue_flow()
	_test_round_v2_version_and_reachability()
	_finish("STORY BUILD TESTS")


func _test_phase4_build_matches_committed_json() -> void:
	var built: Dictionary = StoryBuilder.build(SOURCE)
	_expect(String(built["error"]).is_empty(), "phase4.dialogue builds: %s" % built["error"])
	_expect(StoryBuilder.to_json(built.get("story", {})) == FileAccess.get_file_as_string(OUTPUT),
		"data/phase4_story.json matches a fresh build (run tools/story_build/build_story.gd)")
	_expect(String(built["story"].get("generated_from", "")) == "story_src/phase4.dialogue", "output records its source")


func _test_version_ignores_text_but_tracks_structure() -> void:
	var base: String = FileAccess.get_file_as_string(SOURCE)
	var original: String = String(StoryBuilder.build(SOURCE)["story"].get("version", ""))
	var reworded: Dictionary = _build_variant(base.replace("四件線索都到手了。", "線索全部找齊了。"))
	_expect(String(reworded["story"].get("version", "")) == original,
		"rewording a line keeps the version (saves stay valid): %s" % reworded["error"])
	var extra_line: Dictionary = _build_variant(base.replace("新八: 四件線索都到手了。", "新八: 四件線索都到手了。\n新八: 再確認一次。"))
	_expect(not String(extra_line["story"].get("version", "")).is_empty() and String(extra_line["story"]["version"]) != original,
		"adding a step changes the version (old step indexes would shift)")


func _test_errors_name_their_location() -> void:
	var cases: Array = [
		["~ a\n路人: 你好。\ndo end(\"x\")\n", "~ a, step 0: unknown speaker '路人'"],
		["~ a\n要選哪個？\n- 甲 => b\n- 乙 [ID:y] => b\n~ b\ndo end(\"x\")\n", "response '甲' needs [ID:option_id]"],
		["~ a\n要選哪個？\n- 甲 [if has(\"milk_bottle\")] [ID:x] => b\n- 乙 [ID:y] => b\n~ b\ndo end(\"x\")\n", "[if has(\"item\") /]"],
		["~ a\ndo quake(\"big\")\ndo end(\"x\")\n", "~ a, step 0: unsupported `do quake(big)`"],
		["~ a\ndo end(\"x\")\n~ orphan\ndo end(\"y\")\n", "unreachable from 'a': orphan"],
		["~ a\n新八: 沒有結尾。\n=> END\n", "reaches the end without `do end(\"text\")`"],
		["~ a\ndo investigate(\"missing_block\")\ndo end(\"x\")\n", "unknown block 'missing_block'"],
		["~ a\nif asked == \"x\"\n\t=> b\n~ b\ndo end(\"x\")\n", "`if` needs an `else` branch"],
		["~ a\n新八: 你好。\ndo offscreen()\ndo end(\"x\")\n", "node 'a' step 1: offscreen() must come right before a line"],
		["~ a\n旁白說明。 [#offscreen]\ndo end(\"x\")\n", "say offscreen needs a character speaker"],
		["~ a\ndo placard(1)\ndo end(\"x\")\n", "placard text must be a string"],
		["~ a\ndo enter(\"nobody\")\ndo end(\"x\")\n", "char id 'nobody' is not in asset catalog"],
	]
	for case: Array in cases:
		var result: Dictionary = _build_variant(case[0])
		_expect(String(result["error"]).contains(case[1]), "error mentions '%s' (got: %s)" % [case[1], result["error"]])


## enter(), placard() and offscreen lines (tag or offscreen()) build to the runner's steps.
func _test_new_commands() -> void:
	var built: Dictionary = _build_variant("~ a\ndo enter(\"elisabeth\", \"neutral\", \"left\")\ndo placard(\"犯人是神樂\")\n"
		+ "定春: 汪。 [#offscreen]\ndo offscreen()\n銀時: 布丁不准碰。\n新八: 好。\ndo placard(\"\")\ndo end(\"x\")\n")
	_expect(String(built["error"]).is_empty(), "the new commands build: %s" % built["error"])
	var steps: Array = built["story"]["nodes"]["a"]["steps"] if built["error"] == "" else []
	_expect(steps.size() == 7 and steps[0] == {"op": "char", "id": "elisabeth", "visible": true, "enter": true, "expression": "neutral", "position": "left"},
		"enter() is a char step that brings the character on stage")
	_expect(steps.size() == 7 and steps[1] == {"op": "placard", "text": "犯人是神樂"} and steps[5] == {"op": "placard", "text": ""},
		"placard() sets and clears the board")
	_expect(steps.size() == 7 and steps[2].get("offscreen") == true and steps[3].get("offscreen") == true and not steps[4].has("offscreen"),
		"[#offscreen] and offscreen() mark exactly the next line")


func _test_phase4_four_clue_flow() -> void:
	var runner: RefCounted = StoryRunner.new()
	_expect(runner.call("load_story", OUTPUT), "StoryRunner loads phase4_story.json")
	_advance_until(runner, "investigate")
	var command: Dictionary = runner.call("current")
	_expect((command["hotspots"] as Array).size() == 4, "investigation offers four hotspots")
	runner.call("inspect_hotspot", "empty_milk_bottle")
	runner.call("inspect_hotspot", "gintoki_mouth")
	runner.call("inspect_hotspot", "gintoki_mouth")
	_expect(runner.get("items") == ["milk_bottle", "milk_trace"], "re-inspecting a hotspot does not grant its clue twice")
	_expect(runner.call("advance").get("op", "") == "investigate", "cannot leave before every hotspot is checked")

	var saved: Dictionary = runner.call("snapshot")
	var resumed: RefCounted = StoryRunner.new()
	resumed.call("load_story", OUTPUT)
	_expect(resumed.call("restore", saved), "mid-investigation snapshot restores")
	_expect(resumed.get("items") == ["milk_bottle", "milk_trace"], "restore keeps collected clues without duplicates")
	resumed.call("inspect_hotspot", "kombu_wrapper")
	resumed.call("inspect_hotspot", "floor_paw_print")
	_expect((resumed.get("items") as Array).size() == 4, "all four clues are collected")
	_advance_until(resumed, "choice")
	_expect(resumed.call("choose", "ask_kagura"), "choose to hear Kagura first")
	_advance_until(resumed, "boke_round")
	var round: Dictionary = resumed.call("current")
	var option_ids: Array = ((round["tsukkomi"] as Dictionary)["options"] as Array).map(func(o: Dictionary) -> String: return o["id"])
	_expect(option_ids.size() == 6, "every clue unlocks its tsukkomi option: %s" % [option_ids])
	_expect(resumed.get("profiles") == ["gintoki", "sadaharu", "kagura"],
		"Gintoki, then Sadaharu (the footprints' scene), then Kagura unlock their profiles in order: %s" % [resumed.get("profiles")])
	var case_file: Dictionary = resumed.call("case_file")
	_expect((case_file["materials"] as Array).map(func(m: Dictionary) -> String: return m["name"]) \
		== ["空的草莓牛奶瓶", "銀時嘴角的白色痕跡", "神樂的醋昆布包裝", "定春的腳印"], "case file lists the four materials by name")
	_expect(String((case_file["profiles"] as Array)[1]["profile"]).contains("腳掌比人頭還大"), "case file carries catalog profile text")
	var round_save: Dictionary = resumed.call("snapshot")
	var legacy_save: Dictionary = round_save.duplicate(true)
	legacy_save.erase("profiles")
	var reloaded: RefCounted = StoryRunner.new()
	reloaded.call("load_story", OUTPUT)
	_expect(reloaded.call("restore", round_save) and reloaded.get("profiles") == ["gintoki", "sadaharu", "kagura"], "profiles survive save and load")
	_expect(reloaded.call("restore", legacy_save) and (reloaded.get("profiles") as Array).is_empty(),
		"a save from before profiles existed still loads")
	var bad_save: Dictionary = round_save.duplicate(true)
	bad_save["profiles"] = ["gintoki", "gintoki"]
	_expect(not reloaded.call("restore", bad_save), "duplicate profiles in a save are rejected")
	var result: Dictionary = resumed.call("resolve_boke", "point_to_trace")
	_expect(String(result.get("result", "")) == "perfect", "the mouth-trace clue lands a perfect tsukkomi")
	_advance_until(resumed, "end")
	_expect(String(resumed.get("node_id")) == "perfect_end" and resumed.get("flags")["asked"] == "kagura",
		"asking Kagura first routes the perfect ending through her line")


func _advance_until(runner: RefCounted, op: String) -> void:
	for _step: int in range(40):
		var command: Dictionary = runner.call("current")
		if String(command.get("op", "")) == op:
			return
		runner.call("advance")
	_expect(false, "reached op '%s' (stopped at %s)" % [op, runner.call("current")])


## Builds an edited copy of the Phase 4 source under its own path, so it shares the blocks file
## and Dialogue Manager's per-path [ID:] registry.
func _build_variant(text: String) -> Dictionary:
	return StoryBuilder.build_text(text, SOURCE)


func _test_round_v2_version_and_reachability() -> void:
	var story: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/round_v2_story.json"))
	var version: String = StoryBuilder.fingerprint(story)
	var reworded: Dictionary = story.duplicate(true)
	reworded["nodes"]["r1"]["steps"][0]["lines"][1]["text"] = "改寫過的台詞"
	var renamed: Dictionary = story.duplicate(true)
	renamed["nodes"]["r1"]["steps"][0]["lines"][1]["slot"]["options"][0]["id"] = "a2"
	var retimed: Dictionary = story.duplicate(true)
	retimed["nodes"]["r2"]["steps"][0]["rules"]["combo_timers"] = [8, 7, 5]
	_expect(StoryBuilder.fingerprint(reworded) == version, "rewording a round line keeps the version")
	_expect(StoryBuilder.fingerprint(renamed) != version and StoryBuilder.fingerprint(retimed) != version,
		"changing a round option id or its rules changes the version")
	_expect(StoryBuilder._unreachable("start", story["nodes"]).is_empty(),
		"round v2 reactions, hints and exits count as reachable")
