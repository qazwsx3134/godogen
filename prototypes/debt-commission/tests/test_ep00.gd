extends "res://addons/proto_kit/test_kit.gd"
## EP00「今天也沒有工作的萬事屋」(data/ep00_story.json, built from story_src/ep00.dialogue): the whole chain of
## VN Framework Prototype v0.1 on one script, Story JSON -> StoryRunner -> A screen -> POV choice -> branch ->
## comedy overlay -> interaction mode -> flags -> director choice -> ending -> save/load.
## Data (build freshness, references, reachability, the spec's own lines), every path through the runner
## (3 POV rows x job found or not x milk touched or not x 3 endings), then the shell: scene one's stage, the two
## choice panels, the overlay, the search by real taps, saves in the search and at the director's choice.

const MAIN_SCENE: PackedScene = preload("res://main.tscn")
const StoryRunner = preload("res://scripts/story_runner.gd")
const StoryBuilder = preload("res://tools/story_build/story_builder.gd")
const DmSource = preload("res://tools/story_build/dm_source.gd")
const STORY: String = "res://data/ep00_story.json"
const SOURCE: String = "res://story_src/ep00.dialogue"
const STORIES: String = "res://data/stories.json"
const CATALOG: String = "res://data/asset_catalog.json"
const TEST_SAVE: String = "user://ep00_test.save"
const TEST_UI: String = "user://ep00_test_ui.cfg"
const TEST_SETTINGS: String = "user://ep00_test_settings.cfg"
const TITLE: String = "EP00 今天也沒有工作的萬事屋（Prototype v0.1，非核准）"
const POV_SHEET: String = "res://scenes/ui/choice_sheet_cinema.tscn"
const DIRECTOR_SHEET: String = "res://scenes/ui/choice_sheet_director.tscn"
const POV_PROMPT: String = "這句要怎麼吐槽才好……？"
const POV_LABELS: Array[String] = ["問題是你有工作的時候也在休息啊！！", "首先，請你把桌上那疊委託書看完。", "……算了，我甚至不知道從哪裡開始說。"]
const POV_IDS: Array[String] = ["pov_loud", "pov_calm", "pov_tired"]
const POV_STYLES: Array[String] = ["loud", "calm", "tired"]
const DIRECTOR_PROMPT: String = "接下來發生什麼？"
const DIRECTOR_NOTE: String = "※製作組經費有限"
const DIRECTOR_LABELS: Array[String] = ["登勢闖進來", "電話突然響", "定春撞進房間"]
const DIRECTOR_IDS: Array[String] = ["director_otose", "director_phone", "director_sadaharu"]
const ENDING_FLAGS: Array[String] = ["debt", "request", "unknown"]
const ENDING_TEXTS: Array[String] = ["EP00 完 ── 欠債篇", "EP00 完 ── 委託篇", "EP00 完 ── ？？？篇"]
const ENDING_NODES: Array[String] = ["end_debt", "end_request", "end_unknown"]
const GIN_LINES: Array[String] = ["幹嘛。", "你一直點我也不會掉道具。", "這不是手遊角色首頁。"]
const SCENE_ONE: Array = [
	["gintoki", "今天也完全沒有工作啊。"],
	["shinpachi", "不是沒有，是你全部都拒絕掉了吧！"],
	["kagura", "阿銀今天已經睡第三次了阿魯。"],
	["sadaharu", "汪。"],
	["gintoki", "沒有工作的時候休息不是很合理嗎？"],
]
## The line each POV row's branch must show, and the one after the overlay (or the thought).
const REACTION_LINES: Array[String] = ["新八，你的聲音太大了阿魯，耳朵要壞掉了。", "新八，他已經在摳鼻孔了阿魯。", "……我什麼都沒說，卻覺得自己輸了。"]
const JOB_LINES: Array[String] = ["這不是有工作嗎！", "沒看到。", "你剛才明明就在旁邊！！"]
const MISSED_LINE: String = "……算了，我自己找。"
const MILK_LINE: String = "剛剛有人碰了我的草莓牛奶，我都看到了阿魯。"
const BORED_LINE: String = "這裡感覺有點無聊。"


## Collects every error the engine logs (script errors, push_error) while a check runs.
class ErrorCatcher extends Logger:
	var messages: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
			_error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		messages.append("%s (%s:%d) %s %s" % [function, file, line, code, rationale])


var catcher: ErrorCatcher = ErrorCatcher.new()


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	OS.add_logger(catcher)
	_cleanup()
	_test_script_data()
	_test_spec_lines()
	_test_every_path()
	_test_tap_counts_in_the_runner()
	_test_bool_flags_in_the_adapters()
	await _test_scene_one_in_the_shell()
	await _test_pov_choice_panel()
	await _test_overlay_waits_and_taps_do_not_skip()
	await _test_other_reactions()
	await _test_search_by_taps_without_the_job()
	await _test_search_with_the_job()
	await _test_endings_in_the_shell()
	await _test_save_in_the_search()
	await _test_save_at_the_director_choice()
	await _test_old_save_does_not_replay_the_overlay()
	await _test_chapter_label_trims_with_an_ellipsis()
	_expect(catcher.messages.is_empty(), "no engine errors were logged: %s" % [catcher.messages.slice(0, 3)])
	OS.remove_logger(catcher)
	_cleanup()
	print("EP00 checks: %d" % checks)
	_finish("EP00 TESTS")


# ---------------------------------------------------------------- data

func _test_script_data() -> void:
	var runner: RefCounted = _loaded()
	var story: Dictionary = _story()
	var nodes: Dictionary = story["nodes"] as Dictionary
	_expect(story["id"] == "ep00" and story["title"] == TITLE, "the story is ep00, titled %s: %s" % [TITLE, story["title"]])
	_expect(runner.call("has_gameplay"), "an investigation makes it a story with the gameplay shell (HUD, materials)")

	# data/stories.json: ep00 is a sample, last, after choices; ?sample=ep00 finds it by this id.
	var entries: Array = (JSON.parse_string(FileAccess.get_file_as_string(STORIES)) as Dictionary)["stories"] as Array
	var last: Dictionary = entries[-1] as Dictionary
	_expect(last["id"] == "ep00" and last["kind"] == "sample" and last["path"] == STORY and (entries[-2] as Dictionary)["id"] == "choices",
		"stories.json ends with the ep00 sample after choices: %s" % [last])

	# A fresh build of the source: syntax, speakers, option ids, unreachable nodes and StoryRunner's own validation.
	var built: Dictionary = StoryBuilder.build(SOURCE)
	_expect(String(built["error"]).is_empty(), "ep00.dialogue builds: %s" % built["error"])
	_expect(FileAccess.get_file_as_string(STORY) == StoryBuilder.to_json(built["story"]), "data/ep00_story.json is a fresh build of ep00.dialogue")
	_expect(StoryBuilder._unreachable(String(story["entry"]), nodes).is_empty(), "every node is reachable from the entry %s" % story["entry"])

	# No jump goes nowhere (nodes), no reference goes missing (catalog).
	for node_id: String in nodes.keys():
		var node: Dictionary = nodes[node_id] as Dictionary
		if node.has("next"):
			_expect(nodes.has(String(node["next"])), "%s: next %s exists" % [node_id, node["next"]])
		for step: Dictionary in node["steps"]:
			for target: String in _targets(step):
				_expect(nodes.has(target), "%s: jump to %s exists" % [node_id, target])
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOG)) as Dictionary
	var characters: Dictionary = catalog["characters"] as Dictionary
	var backgrounds_seen: Array[String] = []
	var nodes_with_bg: Array[String] = []
	for node_id: String in nodes.keys():
		for step: Dictionary in (nodes[node_id] as Dictionary)["steps"]:
			match String(step["op"]):
				"bg":
					_expect((catalog["backgrounds"] as Dictionary).has(step["id"]), "%s: background %s is in the catalog" % [node_id, step["id"]])
					backgrounds_seen.append(String(step["id"]))
					nodes_with_bg.append(node_id)
				"char":
					_expect(characters.has(step["id"]), "%s: character %s is in the catalog" % [node_id, step["id"]])
					_expect_drawn(characters, String(step["id"]), String(step.get("expression", "")), node_id)
				"say":
					var speaker: String = String(step["speaker"])
					_expect(speaker == "narrator" or characters.has(speaker), "%s: speaker %s is in the catalog" % [node_id, speaker])
					if speaker != "narrator" and not bool(step.get("offscreen", false)):
						_expect_drawn(characters, speaker, String(step.get("expression", "")), node_id)
				"comedy":
					_expect(characters.has(step["speaker"]), "%s: comedy speaker %s is in the catalog" % [node_id, step["speaker"]])
					_expect_drawn(characters, String(step["speaker"]), String(step.get("expression", "")), node_id)
				"se":
					_expect((catalog["sounds"] as Dictionary).has(step["id"]), "%s: sound %s is in the catalog" % [node_id, step["id"]])
				"bgm":
					_expect((catalog["music"] as Dictionary).has(step["id"]), "%s: music %s is in the catalog" % [node_id, step["id"]])
				"investigate":
					for hotspot: Dictionary in step["hotspots"]:
						if hotspot.has("item"):
							_expect((catalog["items"] as Dictionary).has(hotspot["item"]), "hotspot %s: item %s is in the catalog" % [hotspot["id"], hotspot["item"]])
						if hotspot.has("character"):
							_expect(characters.has(hotspot["character"]), "hotspot %s: character is in the catalog" % hotspot["id"])
	_expect(backgrounds_seen == ["yorozuya_living_room"] and nodes_with_bg == ["s01_open"],
		"one background, set once in scene one (a later change would clear the stage and the search's character): %s %s" % [backgrounds_seen, nodes_with_bg])
	var living: Dictionary = (catalog["backgrounds"] as Dictionary)["yorozuya_living_room"] as Dictionary
	_expect(ResourceLoader.exists(String(living["path"])), "the living room's picture file is there")
	var job: Dictionary = (catalog["items"] as Dictionary)["job_document"] as Dictionary
	_expect(String(job["name"]).contains("尋找失蹤寵物") and not String(job["description"]).is_empty(), "the job document has its name and text: %s" % [job])

	# About 45-65 sentences in all: lines, overlay lines, prompts, options and ending texts.
	var sentences: int = 0
	for node: Dictionary in nodes.values():
		for step: Dictionary in node["steps"]:
			match String(step["op"]):
				"say", "comedy", "end":
					sentences += 1
				"choice":
					sentences += 1 + (step["options"] as Array).size()
	_expect(sentences >= 45 and sentences <= 65, "the episode is about 45-65 sentences long: %d" % sentences)
	_expect(story["initial_flags"] == {"pov_style": "", "found_job": false, "examined_strawberry_milk": false, "ep00_ending": ""},
		"the four flags are declared with their types: %s" % [story["initial_flags"]])


## Every (character, expression) a line shows has its own picture in the catalog (no `lazy` that falls back to the default).
func _expect_drawn(characters: Dictionary, character: String, expression: String, where: String) -> void:
	if expression.is_empty():
		return
	var pictures: Dictionary = (characters[character] as Dictionary).get("expressions", {}) as Dictionary
	_expect(pictures.has(expression) and ResourceLoader.exists(String(pictures[expression])),
		"%s: %s has a picture for the face %s" % [where, character, expression])


func _test_spec_lines() -> void:
	var story: Dictionary = _story()
	var nodes: Dictionary = story["nodes"] as Dictionary
	# Scene 01: the three lines of the plan, in their places, the dog off stage.
	var first: Array = _steps(nodes, "s01_open", "say")
	for index: int in range(SCENE_ONE.size()):
		_expect(first[index]["speaker"] == SCENE_ONE[index][0] and first[index]["text"] == SCENE_ONE[index][1], "scene 1 line %d: %s" % [index, first[index]])
	_expect(first[3].get("offscreen") == true and _steps(nodes, "s01_open", "se").size() == 1 and _steps(nodes, "s01_open", "se")[0]["id"] == "crow",
		"the dog barks off stage and there is a sound effect")
	var stage: Array = _steps(nodes, "s01_open", "char")
	_expect(stage.map(func(step: Dictionary) -> String: return "%s@%s" % [step["id"], step["position"]]) == ["gintoki@center", "shinpachi@left", "kagura@right"],
		"the three stand left, centre and right: %s" % [stage])
	# Scene 02: a POV choice of Shinpachi's, three rows that each set pov_style and have a tone.
	var pov: Dictionary = (_steps(nodes, "s02_pov", "choice") as Array)[0] as Dictionary
	_expect(pov["pov"] == "shinpachi" and not pov.has("perspective") and pov["prompt"] == POV_PROMPT, "scene 2 is Shinpachi's thought: %s" % [pov["prompt"]])
	for index: int in range(3):
		var option: Dictionary = (pov["options"] as Array)[index] as Dictionary
		_expect(option["id"] == POV_IDS[index] and option["label"] == POV_LABELS[index] and option["tone"] == POV_STYLES[index]
			and option["set_flags"] == {"pov_style": POV_STYLES[index]} and option["next"] == "s03_" + POV_STYLES[index],
			"POV row %d: %s" % [index, option])
	# Scene 03: the overlay lines.
	var loud: Array = _steps(nodes, "s03_loud", "comedy")
	_expect(loud.size() == 1 and loud[0]["preset"] == "tsukkomi_impact" and loud[0]["speaker"] == "shinpachi" and loud[0]["text"] == POV_LABELS[0]
		and loud[0]["expression"] == "shout", "the loud row gets a tsukkomi_impact of Shinpachi saying the row, shouting: %s" % [loud])
	var steps: Array = (nodes["s03_loud"] as Dictionary)["steps"]
	_expect(steps[0]["op"] == "say" and steps[0]["text"] == "嗯？" and steps[1]["op"] == "comedy" and steps[2]["op"] == "say" and steps[2]["speaker"] == "kagura",
		"Gintoki's 嗯？, then the overlay, then Kagura: %s" % [steps.map(func(step: Dictionary) -> String: return step["op"])])
	steps = (nodes["s03_calm"] as Dictionary)["steps"]
	_expect(steps[0]["op"] == "say" and steps[0]["speaker"] == "gintoki" and steps[1]["op"] == "comedy" and steps[1]["preset"] == "small_reaction"
		and steps[2]["op"] == "say" and steps[2]["speaker"] == "kagura", "the calm row: Gintoki brushes it off, a small_reaction, Kagura")
	steps = (nodes["s03_tired"] as Dictionary)["steps"]
	_expect(steps[0]["text"] == "對吧？休息很重要的。" and steps[1]["speaker"] == "shinpachi" and steps[1].get("thought") == true,
		"the tired row: Gintoki agrees, Shinpachi only thinks: %s" % [steps[1]])
	# Scene 04: the search keeps its cast; four optional spots; Gintoki's three lines.
	var room: Dictionary = (_steps(nodes, "s04_room", "investigate") as Array)[0] as Dictionary
	_expect(room["keep_cast"] == true and (room["hotspots"] as Array).size() == 4
		and (room["hotspots"] as Array).all(func(spot: Dictionary) -> bool: return spot.get("optional") == true),
		"the search keeps the cast and its four spots are all optional")
	var spots: Dictionary = {}
	for spot: Dictionary in room["hotspots"]:
		spots[spot["id"]] = spot
	_expect(spots["gintoki"]["character"] == "gintoki" and spots["gintoki"]["lines"] == ["s04_gintoki_1", "s04_gintoki_2", "s04_gintoki_3"],
		"Gintoki's spot is his portrait with three lines")
	for index: int in range(3):
		_expect((_steps(nodes, "s04_gintoki_%d" % (index + 1), "say") as Array)[0]["text"] == GIN_LINES[index], "Gintoki's line %d is %s" % [index + 1, GIN_LINES[index]])
	_expect(spots["strawberry_milk"]["set"] == {"examined_strawberry_milk": true} and spots["strawberry_milk"]["goto"] == "s04_milk"
		and (_steps(nodes, "s04_milk", "say") as Array)[0]["text"] == "那是我的阿魯！" and (_steps(nodes, "s04_milk", "say") as Array)[0]["speaker"] == "kagura",
		"the milk: Kagura's line and its flag")
	_expect(spots["job_document"]["set"] == {"found_job": true} and spots["job_document"]["item"] == "job_document"
		and String((_steps(nodes, "s04_job", "say") as Array)[0]["text"]).contains("尋找失蹤寵物"), "the job: the document, its flag and 尋找失蹤寵物")
	_expect(not spots["television"].has("set") and not spots["television"].has("item") and (_steps(nodes, "s04_tv", "say") as Array).size() == 1,
		"the television is a joke with no flag and no item")
	# Scene 05: both conditions read what the search wrote.
	var check: Dictionary = (_steps(nodes, "s05_check", "condition") as Array)[0] as Dictionary
	_expect(check["flag"] == "found_job" and check["equals"] == true and check["then"] == "s05_found" and check["else"] == "s05_missed", "found_job picks the branch")
	_expect(((_steps(nodes, "s05_found", "say") as Array).map(func(step: Dictionary) -> String: return step["text"])) == JOB_LINES, "the found branch has the three lines")
	_expect((_steps(nodes, "s05_missed", "say") as Array)[0]["text"] == MISSED_LINE, "the other branch is 我自己找")
	var milk: Dictionary = (_steps(nodes, "s05_milk", "condition") as Array)[0] as Dictionary
	_expect(milk["flag"] == "examined_strawberry_milk" and milk["equals"] == true and milk["then"] == "s05_milk_yes", "a second flag decides Kagura's extra line")
	# Scene 06: a director choice with a footnote and three real branches that each end.
	var director: Dictionary = (_steps(nodes, "s06_open", "choice") as Array)[0] as Dictionary
	_expect(director["perspective"] == "director" and director["prompt"] == DIRECTOR_PROMPT and director["note"] == DIRECTOR_NOTE and not director.has("pov"),
		"scene 6 is a director choice with the footnote: %s" % [director])
	for index: int in range(3):
		var option: Dictionary = (director["options"] as Array)[index] as Dictionary
		_expect(option["id"] == DIRECTOR_IDS[index] and option["label"] == DIRECTOR_LABELS[index] and option["set_flags"] == {"ep00_ending": ENDING_FLAGS[index]}
			and option["next"] == ENDING_NODES[index] and not option.has("tone"), "director card %d: %s" % [index, option])
		var branch: Array = (nodes[ENDING_NODES[index]] as Dictionary)["steps"] as Array
		_expect(branch[0]["speaker"] == "shinpachi" and String(branch[0]["text"]).contains("玩家") and branch[-1]["op"] == "end" and branch[-1]["text"] == ENDING_TEXTS[index],
			"branch %d: Shinpachi complains about the player, then ends with %s" % [index, ENDING_TEXTS[index]])


# ---------------------------------------------------------------- every path through the runner

func _test_every_path() -> void:
	var story: Dictionary = _story()
	var visited: Dictionary = {}
	var paths: int = 0
	for pov: int in range(3):
		for job: bool in [false, true]:
			for milk: bool in [false, true]:
				for ending: int in range(3):
					# Some taps on Gintoki and the television along the way, so the other reactions are visited too.
					var todo: Array[String] = []
					if milk:
						todo.append("strawberry_milk")
					for _n: int in range((paths + 1) % 5):
						todo.append("gintoki")
					if paths % 3 == 0:
						todo.append("television")
					if job:
						todo.append("job_document")
					var run: Dictionary = _play(POV_IDS[pov], todo, DIRECTOR_IDS[ending])
					paths += 1
					var label: String = "pov %s, job %s, milk %s, ending %s" % [POV_STYLES[pov], job, milk, ENDING_FLAGS[ending]]
					for node_id: String in run["nodes"]:
						visited[node_id] = true
					var flags: Dictionary = run["flags"] as Dictionary
					var texts: Array = run["texts"] as Array
					_expect(run["op"] == "end" and run["end_text"] == ENDING_TEXTS[ending], "%s: the path ends on %s (%s)" % [label, ENDING_TEXTS[ending], run["end_text"]])
					_expect(flags == {"pov_style": POV_STYLES[pov], "found_job": job, "examined_strawberry_milk": milk, "ep00_ending": ENDING_FLAGS[ending]},
						"%s: the flags are %s" % [label, flags])
					_expect((run["items"] as Array) == (["job_document"] if job else []), "%s: the job document is held only when found: %s" % [label, run["items"]])
					_expect(texts.has(REACTION_LINES[pov]), "%s: the row's own reaction shows" % label)
					for other: int in range(3):
						if other != pov:
							_expect(not texts.has(REACTION_LINES[other]), "%s: the other rows' reactions do not" % label)
					_expect(texts.has(JOB_LINES[0]) == job and texts.has(JOB_LINES[2]) == job and texts.has(MISSED_LINE) == (not job),
						"%s: found_job picks 這不是有工作嗎 or 我自己找" % label)
					_expect(texts.has(MILK_LINE) == milk, "%s: Kagura's extra line only if the milk was touched" % label)
					_expect(String(run["nodes"][-1]) == ENDING_NODES[ending], "%s: the last node is the ending's" % label)
	_expect(paths == 36, "all 36 paths ran")
	# A node of nothing but a condition is never "current" (the runner resolves it on the way): it counts as visited
	# when both of its targets were.
	var nodes: Dictionary = story["nodes"] as Dictionary
	var missing: Array[String] = []
	for node_id: String in nodes.keys():
		if visited.has(node_id):
			continue
		var steps: Array = (nodes[node_id] as Dictionary)["steps"] as Array
		var only_a_condition: bool = steps.size() == 1 and steps[0]["op"] == "condition"
		if not (only_a_condition and visited.has(steps[0]["then"]) and visited.has(steps[0]["else"])):
			missing.append(node_id)
	_expect(missing.is_empty(), "every node was visited by some path (the nodes of the taps included): %s" % [missing])
	# `end` is final: the runner does not step past it.
	var finished: Dictionary = _play(POV_IDS[0], [], DIRECTOR_IDS[0])
	var runner: RefCounted = finished["runner"] as RefCounted
	runner.call("advance")
	_expect(String((runner.call("current") as Dictionary).get("op", "")) == "end", "advancing at the end stays on the end")


## One run: the POV id, the spots to tap in the search (in order; each reaction is read through), the director's id.
func _play(pov_id: String, taps: Array[String], director_id: String) -> Dictionary:
	var runner: RefCounted = _loaded()
	var todo: Array[String] = taps.duplicate()
	var nodes: Array[String] = []
	var texts: Array[String] = []
	var op: String = ""
	for _step: int in range(600):
		var current: Dictionary = runner.call("current") as Dictionary
		op = String(current.get("op", ""))
		var node_id: String = String(current.get("node_id", ""))
		if nodes.is_empty() or nodes[-1] != node_id:
			nodes.append(node_id)
		if op == "end":
			break
		match op:
			"choice":
				var pick: String = director_id if String(current.get("perspective", "pov")) == "director" else pov_id
				_expect(runner.call("choose", pick), "choosing %s: %s" % [pick, runner.get("error_message")])
			"investigate":
				runner.set("cast", ["gintoki"])  # the shell sets it from who is on stage: only Gintoki, after the hides
				if todo.is_empty():
					runner.call("advance")
				else:
					var spot: String = todo.pop_front()
					_expect(runner.call("inspect_hotspot", spot), "tapping %s: %s" % [spot, runner.get("error_message")])
			"say", "comedy":
				texts.append(String(current["text"]))
				runner.call("advance")
			_:
				runner.call("advance")
	var current_end: Dictionary = runner.call("current") as Dictionary
	return {"runner": runner, "op": op, "end_text": String(current_end.get("text", "")), "nodes": nodes, "texts": texts,
		"flags": (runner.get("flags") as Dictionary).duplicate(), "items": (runner.get("items") as Array).duplicate()}


func _test_tap_counts_in_the_runner() -> void:
	var runner: RefCounted = _loaded()
	_advance_to(runner, "choice")
	runner.call("choose", "pov_tired")
	_advance_to(runner, "investigate")
	runner.set("cast", ["gintoki"])
	for tap: int in range(5):
		var node: String = ["s04_gintoki_1", "s04_gintoki_2", "s04_gintoki_3", "s04_gintoki_3", "s04_gintoki_3"][tap]
		_expect(runner.call("inspect_hotspot", "gintoki") and runner.get("node_id") == node, "tap %d on Gintoki plays %s (at %s)" % [tap + 1, node, runner.get("node_id")])
		_advance_to(runner, "investigate")
	_expect((runner.get("investigations") as Dictionary)["yorozuya_room"]["counts"] == {"gintoki": 5}, "the taps are counted")
	var room: Dictionary = runner.call("current") as Dictionary
	_expect(room["complete"] == true and room["progress"] == [0, 0], "nothing is required: 繼續 is open from the start (%s)" % [room["progress"]])
	_expect(runner.call("advance").get("op") != "investigate", "and leaving the search without the job works")
	_expect(runner.get("flags")["found_job"] == false and runner.get("node_id") == "s05_missed", "found_job is still false: the 我自己找 branch (at %s)" % runner.get("node_id"))
	# Without Gintoki on stage his spot cannot be tapped (and would not hold 繼續 back).
	var alone: RefCounted = _loaded()
	_advance_to(alone, "choice")
	alone.call("choose", "pov_loud")
	_advance_to(alone, "investigate")
	alone.set("cast", [])
	_expect(not alone.call("inspect_hotspot", "gintoki") and String(alone.get("error_message")).contains("not on stage"), "an off-stage Gintoki cannot be tapped")


func _test_bool_flags_in_the_adapters() -> void:
	# Dialogue Manager tokenizes `true` and `false` as variables; the adapters read them as booleans.
	_expect(DmSource.flag_equals(DmSource.expression_tokens("found_job == true")) == {"flag": "found_job", "equals": true}, "`if found_job == true` is a bool test")
	_expect(DmSource.flag_equals(DmSource.expression_tokens("found_job == false")) == {"flag": "found_job", "equals": false}, "`if found_job == false` is a bool test")
	_expect(DmSource.flag_equals(DmSource.expression_tokens('asked == "kagura"')) == {"flag": "asked", "equals": "kagura"}, "a string test is as before")
	_expect(DmSource.flag_equals(DmSource.expression_tokens("count == 3")) == {"flag": "count", "equals": 3}, "a number test is as before")
	_expect(DmSource.command_step("set seen = true", "t") == {"op": "flag", "key": "seen", "value": true}, "`set seen = true` writes the bool")
	_expect(DmSource.command_step("set seen = false", "t") == {"op": "flag", "key": "seen", "value": false}, "`set seen = false` writes the bool")
	_expect(DmSource.command_step('set seen = "yes"', "t") == {"op": "flag", "key": "seen", "value": "yes"}, "`set seen = \"yes\"` writes the string")
	var text: String = '~ a\nset seen = false\nif seen == false\n\t=> b\nelse\n\t=> c\n\n~ b\ndo end("b")\n\n~ c\ndo end("c")\n'
	var built: Dictionary = StoryBuilder.build_text(text, "res://story_src/__ep00_bool.dialogue")
	_expect(String(built["error"]).is_empty(), "a script with a bool flag and a bool test builds: %s" % built["error"])
	if String(built["error"]).is_empty():
		var steps: Array = ((built["story"] as Dictionary)["nodes"] as Dictionary)["a"]["steps"] as Array
		_expect(steps[0] == {"op": "flag", "key": "seen", "value": false} and steps[1]["equals"] == false and steps[1]["then"] == "b",
			"as a flag step and a condition on false: %s" % [steps])
	# A word that is only called true is still a variable: `if a == b` stays an error.
	_expect(DmSource.flag_equals(DmSource.expression_tokens("a == b")).is_empty(), "comparing two flags is still not supported")


# ---------------------------------------------------------------- shell: scene one

func _test_scene_one_in_the_shell() -> void:
	var game: Control = await _new_game()
	game._settings["text_speed"] = 0  # slow, so a tap lands while a line is still being typed
	game._effects._se_player.stream = null
	_expect(game._story_switch.text.contains("EP00 今天也沒有工作的萬事屋"), "the title shows the story: %s" % game._story_switch.text)
	game._on_begin_pressed()
	await _until(func() -> bool: return game._screen_mode == "story" and game._full_text == SCENE_ONE[0][1], "the first line shows")
	_expect(game._current_bg_id == "yorozuya_living_room", "the living room is the background")
	_expect(game._effects.current_bgm == "bgm_daily", "the daily music plays")
	_expect(game._current_speaker == "gintoki" and str(game._sprites["gintoki"].get("expression")) == "nosepick", "Gintoki speaks with the lazy face (nosepick)")
	_expect(game._phase3_enabled, "a story with an investigation runs the shell's gameplay mode (materials menu, HUD)")

	# Typewriter: the line is revealed letter by letter, then whole.
	var lengths: Array[int] = []
	while not game._text_complete and lengths.size() < 3000:
		lengths.append(game._visible_text.length())
		await process_frame
	var distinct: Dictionary = {}
	for length: int in lengths:
		distinct[length] = true
	_expect(distinct.size() >= 3 and lengths[0] < String(SCENE_ONE[0][1]).length(), "the first line types out: %d lengths seen, from %d" % [distinct.size(), lengths[0]])
	_expect(game._text_complete and game._visible_text == SCENE_ONE[0][1], "and ends whole")

	# Tap, tap: a tap while typing completes the line, the next tap goes on. The crow plays as the next line starts.
	var tap_point: Vector2 = game._game.position + Vector2(game._game.size.x * 0.5, game._game.size.y * 0.34)
	await _tap(tap_point)
	await _until(func() -> bool: return game._full_text == SCENE_ONE[1][1], "the tap goes on to Shinpachi's line")
	var crow: AudioStream = game._effects.call("_stream", "sounds", "crow") as AudioStream
	_expect(crow != null and game._effects._se_player.stream == crow, "the crow played between the two lines (a placeholder sound)")
	await _tap(tap_point)
	_expect(game._text_complete and game._visible_text == SCENE_ONE[1][1] and game._full_text == SCENE_ONE[1][1],
		"the first tap on a line being typed completes it and does not go on")
	_expect(str(game._sprites["shinpachi"].get("expression")) == "angry", "Shinpachi is angry")
	await _tap(tap_point)
	await _until(func() -> bool: return game._full_text == SCENE_ONE[2][1] and game._screen_mode == "story", "the second tap goes on to Kagura")

	await _read_until(game, func() -> bool: return game._full_text == SCENE_ONE[3][1] and game._text_complete, "the dog's line")
	_expect(game._current_speaker == "sadaharu" and game._dialog_panel.speaker_name.text == "定春" and not game._sprites["sadaharu"].visible,
		"the dog barks from off stage: his name shows, he does not come on (%s)" % game._dialog_panel.speaker_name.text)
	var stage: Dictionary = {}
	for actor: String in ["shinpachi", "gintoki", "kagura"]:
		stage[actor] = [game._sprites[actor].visible, game._actor_slots[actor]]
	_expect(stage == {"shinpachi": [true, "left"], "gintoki": [true, "center"], "kagura": [true, "right"]},
		"three on stage: Shinpachi left, Gintoki centre, Kagura right: %s" % [stage])
	var centres: Array[float] = []
	for actor: String in ["shinpachi", "gintoki", "kagura"]:
		centres.append((game._sprites[actor].art_rect() as Rect2).get_center().x)
	_expect(centres[0] < centres[1] and centres[1] < centres[2], "and their portraits really stand in that order: %s" % [centres])
	_expect(str(game._sprites["kagura"].get("expression")) == "smile" and str(game._sprites["gintoki"].get("expression")) == "nosepick",
		"Kagura smiles, Gintoki still has the lazy face")
	await _read_until(game, func() -> bool: return game._full_text == SCENE_ONE[4][1] and game._text_complete, "Gintoki's reply")
	_expect(str(game._sprites["gintoki"].get("expression")) == "smug", "Gintoki changed his face to smug for his excuse")
	await _free(game)


func _test_pov_choice_panel() -> void:
	var game: Control = await _new_game()
	game._on_begin_pressed()
	await _read_until(game, func() -> bool: return game._screen_mode == "choice", "the POV choice")
	await _frames(3)
	var sheet: Control = game._choice_sheet
	_expect(sheet.get("perspective") == "pov" and sheet.scene_file_path == POV_SHEET and sheet.style_id == "cinema",
		"a POV choice is in the edition's ordinary panel, not the director's: %s" % sheet.scene_file_path)
	_expect(sheet.get_node("%Prompt").text == POV_PROMPT, "the prompt is Shinpachi's thought")
	var labels: Array[String] = []
	for row: Button in game._choice_buttons:
		labels.append(row.text)
	_expect(labels == POV_LABELS, "the three rows: %s" % [labels])
	_expect(game._choice_qa_state(game._runner_current()) == {"perspective": "pov", "pov": "shinpachi", "note": "", "sheet": "cinema", "tones": POV_STYLES},
		"the QA choice field: %s" % [game._choice_qa_state(game._runner_current())])
	_expect(game._current_speaker == "shinpachi" and game._dialog_panel.speaker_name.text == "新八・心聲", "Shinpachi is the one thinking (%s)" % game._dialog_panel.speaker_name.text)
	var markers: Array = game._choice_buttons.map(func(row: Button) -> String: return (row.get_node("%Tone") as Label).text)
	_expect(markers == ["！", "？", "…"], "every row has its tone marker: %s" % [markers])
	# Each row is a real branch: pressing it goes to its reaction and sets pov_style.
	await _press(game._choice_buttons[1])
	await _until(func() -> bool: return game._screen_mode != "choice", "the calm row is chosen")
	_expect(game._runner.flags["pov_style"] == "calm" and game._runner.node_id == "s03_calm", "the calm row sets pov_style=calm and goes to s03_calm (at %s)" % game._runner.node_id)
	await _free(game)


# ---------------------------------------------------------------- shell: the overlay

func _test_overlay_waits_and_taps_do_not_skip() -> void:
	var story: Dictionary = _story()
	var impact_index: int = _index_of(story, "s03_loud", "comedy")
	var game: Control = await _new_game()
	game._on_begin_pressed()
	await _read_until(game, func() -> bool: return game._screen_mode == "choice", "the POV choice")
	await _press(game._choice_buttons[0])
	await _read_to_overlay(game, "tsukkomi_impact")
	var layer: Control = game._comedy_layer
	var started: int = Time.get_ticks_msec()
	var current: Dictionary = game._runner_current()
	_expect(current["op"] == "comedy" and current["node_id"] == "s03_loud" and current["step_index"] == impact_index and game._story_busy and game._screen_mode == "busy",
		"the story waits on the comedy step while the overlay plays: %s" % [current])
	_expect(layer.visible and layer.current_preset() == "tsukkomi_impact" and layer.get_child_count() == 1, "tsukkomi_impact is on screen over the reading screen")
	_expect(game._full_text == "嗯？", "under it is Gintoki's 嗯？ (the A screen stays below)")
	await create_timer(0.45).timeout
	var zoomed: float = game._bg_layer.scale.x
	_expect(layer.is_active() and zoomed > 1.0 and zoomed <= 1.0501, "still playing 0.45 s in, the stage zooming (%.3f)" % zoomed)
	var shook: bool = game._effects._shake_tween != null and game._effects._shake_tween.is_valid()
	_expect(shook, "the stage shakes")
	var qa: Dictionary = layer.qa_state()
	_expect(qa.get("text_fits") == true and qa.has("burst"), "the big line is in its balloon and fits: %s" % [qa])
	var held: bool = true
	while layer.is_active() and Time.get_ticks_msec() - started < 4000:
		await process_frame
		if layer.is_active():  # the frame it ends is the frame the story goes on
			held = held and game._runner_current()["step_index"] == impact_index
	var length: float = float(Time.get_ticks_msec() - started) / 1000.0
	_expect(length > 1.2 and length < 1.8, "it lasts about 1.35 s (%.2f)" % length)
	_expect(held, "the story did not move while it played")
	await _until(func() -> bool: return game._screen_mode == "story" and game._runner_current().get("step_index") == impact_index + 1, "the next line appears when it ends")
	_expect(game._full_text == REACTION_LINES[0] and game._current_speaker == "kagura", "after the overlay Kagura answers: %s" % game._full_text)
	_expect(not layer.visible and layer.get_child_count() == 0, "the overlay is gone and hidden afterwards")
	var logged: Array = game._history.filter(func(entry: Dictionary) -> bool: return str(entry["key"]).begins_with("comedy:"))
	_expect(logged.size() == 1 and logged[0]["speaker"] == "shinpachi" and logged[0]["text"] == POV_LABELS[0], "the overlay's line is in the log, said by Shinpachi: %s" % [logged])
	await _free(game)

	# A tap while it plays only ends it: the next line shows whole and is current (it is not skipped).
	game = await _new_game()
	game._on_begin_pressed()
	await _read_until(game, func() -> bool: return game._screen_mode == "choice", "the POV choice")
	await _press(game._choice_buttons[0])
	await _read_to_overlay(game, "tsukkomi_impact")
	await create_timer(0.45).timeout
	_expect(game._comedy_layer.is_active(), "playing 0.45 s in")
	var stage_point: Vector2 = game._game.position + Vector2(game._game.size.x * 0.5, game._game.size.y * 0.34)
	_mouse(stage_point, true)
	await _frames(1)
	var tapped: int = Time.get_ticks_msec()
	_mouse(stage_point, false)
	while game._comedy_layer.is_active() and Time.get_ticks_msec() - tapped < 2000:
		await process_frame
	var took: float = float(Time.get_ticks_msec() - tapped) / 1000.0
	_expect(not game._comedy_layer.is_active() and took <= 0.15, "a tap ends the overlay within 0.15 s (%.3f)" % took)
	await _until(func() -> bool: return game._screen_mode == "story", "the story goes on")
	await _frames(4)
	_expect(game._runner_current()["step_index"] == impact_index + 1 and game._full_text == REACTION_LINES[0],
		"the tap did not also advance: Kagura's line is current (step %s: %s)" % [game._runner_current()["step_index"], game._full_text])
	await _until(func() -> bool: return game._text_complete, "Kagura's line types out")
	_expect(game._visible_text == REACTION_LINES[0] and game._runner_current()["step_index"] == impact_index + 1, "and shows whole, still the current line")
	await _free(game)


## The calm row's small_reaction leaves the reading box in place; the tired row has Shinpachi think, in the thought tone.
func _test_other_reactions() -> void:
	var game: Control = await _new_game()
	game._on_begin_pressed()
	await _read_until(game, func() -> bool: return game._screen_mode == "choice", "the POV choice")
	await _press(game._choice_buttons[1])
	await _read_to_overlay(game, "small_reaction")
	_expect(game._dialog_panel.visible and game._comedy_layer.is_active(), "small_reaction plays without hiding the reading box")
	await _until(func() -> bool: return not game._comedy_layer.is_active(), "it ends by itself", 3.0)
	await _until(func() -> bool: return game._screen_mode == "story" and game._full_text == REACTION_LINES[1], "Kagura's answer follows")
	await _free(game)

	game = await _new_game()
	game._on_begin_pressed()
	await _read_until(game, func() -> bool: return game._screen_mode == "choice", "the POV choice")
	await _press(game._choice_buttons[2])
	await _read_until(game, func() -> bool: return game._full_text == REACTION_LINES[2] and game._text_complete, "Shinpachi's thought")
	_expect(game._dialog_panel.speaker_name.text == "新八・心聲" and game._text_tone == "thought" and not game._comedy_layer.is_active(),
		"the tired row is a silent thought (%s, tone %s) with no overlay" % [game._dialog_panel.speaker_name.text, game._text_tone])
	await _free(game)


# ---------------------------------------------------------------- shell: the search

## Path B: the tired row, the search without the job, then Kagura's milk line, the director's first card.
func _test_search_by_taps_without_the_job() -> void:
	var game: Control = await _new_game()
	await _to_search(game, 2)
	var visible_actors: Array = game._sprites.keys().filter(func(actor: String) -> bool: return game._sprites[actor].visible)
	_expect(visible_actors == ["gintoki"], "only Gintoki is left on stage for the search (the other two stepped out): %s" % [visible_actors])
	_expect(game._hotspots.keys() == ["gintoki", "strawberry_milk", "job_document", "television"], "four spots: %s" % [game._hotspots.keys()])
	var gin_spot: Control = game._hotspots["gintoki"]
	_expect(gin_spot.get_parent() == game._interaction_layer and game._hotspots["television"].get_parent() == game._hotspot_layer,
		"Gintoki's spot lies on the interaction layer over his portrait, the objects on the picture")
	var portrait: Rect2 = game._sprites["gintoki"].art_rect()
	_expect(gin_spot.get_global_rect().is_equal_approx(portrait.intersection(Rect2(game._game.global_position, game._game.size))),
		"his spot is his portrait on screen (%s vs %s)" % [gin_spot.get_global_rect(), portrait])
	_expect(not game._investigation_continue_button.disabled and game._current_command["progress"] == [0, 0],
		"nothing is required: 繼續 is open from the start")
	# The point to tap on Gintoki lies in no object's tap area, wherever the picture is dragged.
	var point: Vector2 = _above_box(game, portrait)
	for pan: float in [game._pan_range.x, 0.0, game._pan_range.y]:
		game._set_pan(pan)
		for spot_id: String in ["strawberry_milk", "job_document", "television"]:
			_expect(not game._hotspot_hit_rect(game._hotspots[spot_id]).has_point(point), "pan %d: the point on Gintoki (%s) is not in %s's tap area" % [pan, point, spot_id])
	game._set_pan(0.0)
	_expect(String(game._runner_current()["hotspots"][0]["label"]) == "銀時", "his spot is labelled 銀時")

	# Four taps: his three lines in order, then the last again.
	for tap: int in range(4):
		await _tap(point)
		await _until(func() -> bool: return game._screen_mode == "story", "tap %d on Gintoki plays a line" % [tap + 1])
		var expected: String = GIN_LINES[mini(tap, 2)]
		_expect(game._full_text == expected and game._current_speaker == "gintoki", "tap %d says '%s' (got '%s')" % [tap + 1, expected, game._full_text])
		await _read_back(game)
	_expect(game._runner.investigations["yorozuya_room"]["counts"] == {"gintoki": 4} and game._runner.flags["found_job"] == false, "four taps counted; no flag moved")
	_expect(game._hotspots["gintoki"].found, "his spot is checked")

	# The objects, by real taps with the reading box folded away: milk and television. Kagura speaks from off stage.
	game._set_investigation_collapsed(true)
	await _tap_object(game, "strawberry_milk")
	await _until(func() -> bool: return game._screen_mode == "story", "the milk plays its scene")
	_expect(game._full_text == "那是我的阿魯！" and game._current_speaker == "kagura" and not game._sprites["kagura"].visible and game._dialog_panel.speaker_name.text == "神樂",
		"Kagura answers from off stage (%s)" % game._full_text)
	await _read_back(game)
	_expect(game._runner.flags["examined_strawberry_milk"] == true and game._runner.flags["found_job"] == false, "the milk set its flag and only its flag")
	game._set_investigation_collapsed(true)
	await _tap_object(game, "television")
	await _until(func() -> bool: return game._screen_mode == "story", "the television plays its scene")
	await _read_back(game)
	_expect(game._runner.flags == {"pov_style": "tired", "found_job": false, "examined_strawberry_milk": true, "ep00_ending": ""} and game._runner.items.is_empty(),
		"the television set nothing: %s" % [game._runner.flags])
	var visible_after: Array = game._sprites.keys().filter(func(actor: String) -> bool: return game._sprites[actor].visible)
	_expect(visible_after == ["gintoki"], "the off-stage voices brought nobody on: %s" % [visible_after])

	# 繼續 without the job: 我自己找, then (the milk was touched) Kagura's extra line, then the director's choice.
	game._set_investigation_collapsed(false)
	game._on_investigation_continue_pressed()
	await _until(func() -> bool: return game._screen_mode == "story" and game._full_text == MISSED_LINE, "the story goes on to 我自己找")
	_expect(game._runner.node_id == "s05_missed" and game._current_speaker == "shinpachi" and game._sprites["shinpachi"].visible and game._actor_slots["shinpachi"] == "left",
		"Shinpachi walks back on at his place to say it (at %s)" % game._runner.node_id)
	await _read_until(game, func() -> bool: return game._full_text == MILK_LINE and game._text_complete, "Kagura's extra line")
	_expect(game._runner.node_id == "s05_milk_yes", "the milk flag made it (at %s)" % game._runner.node_id)
	await _read_until(game, func() -> bool: return game._full_text == BORED_LINE and game._text_complete, "the narration")
	_expect(game._current_speaker == "narrator", "這裡感覺有點無聊 is narration")
	await _read_until(game, func() -> bool: return game._screen_mode == "choice", "the director's choice")
	await _frames(3)
	_expect(await _is_director_choice(game), "the choice is the director's: its own panel, prompt, footnote and cards")
	_expect(game._current_speaker == "" and game._dialog_panel.speaker_name.text == "旁白", "the question is narration")
	await _free(game)


## Path A: the loud row, the job found by a tap, the milk left alone, the director's third card.
func _test_search_with_the_job() -> void:
	var game: Control = await _new_game()
	await _to_search(game, 0)
	game._set_investigation_collapsed(true)
	await _tap_object(game, "job_document")
	_expect(game._toast.visible and game._toast.text == "取得線索：委託書：尋找失蹤寵物", "a toast announces the clue: %s" % game._toast.text)
	await _until(func() -> bool: return game._screen_mode == "story", "the job document plays its scene")
	_expect(String(game._full_text).contains("尋找失蹤寵物") and game._current_speaker == "narrator", "the scene shows 尋找失蹤寵物: %s" % game._full_text)
	await _read_back(game)
	_expect(game._runner.flags["found_job"] == true and game._runner.flags["examined_strawberry_milk"] == false and game._runner.items == ["job_document"],
		"found_job is set, the document is held, the milk flag is not: %s %s" % [game._runner.flags, game._runner.items])
	_expect(game._hotspots["job_document"].found and not game._hotspots["strawberry_milk"].found, "the document's spot is checked, the milk's is not")
	game._set_investigation_collapsed(false)
	game._on_investigation_continue_pressed()
	await _read_until(game, func() -> bool: return game._full_text == JOB_LINES[0] and game._text_complete, "這不是有工作嗎")
	_expect(game._runner.node_id == "s05_found" and game._sprites["shinpachi"].visible, "the found branch: Shinpachi is back on stage (at %s)" % game._runner.node_id)
	await _read_until(game, func() -> bool: return game._full_text == JOB_LINES[1] and game._text_complete, "沒看到")
	_expect(game._current_speaker == "gintoki", "Gintoki: 沒看到")
	await _read_until(game, func() -> bool: return game._full_text == JOB_LINES[2] and game._text_complete, "你剛才明明就在旁邊")
	await _read_until(game, func() -> bool: return game._full_text == BORED_LINE and game._text_complete, "the narration")
	_expect(game._runner.node_id == "s06_open", "no milk line: straight to the director's scene (at %s)" % game._runner.node_id)
	await _free(game)


# ---------------------------------------------------------------- shell: endings

func _test_endings_in_the_shell() -> void:
	for ending: int in range(3):
		var game: Control = await _new_game()
		await _to_director(game)
		_expect(await _is_director_choice(game), "ending %d: the director's choice shows" % ending)
		var card: Button = game._choice_buttons[ending]
		_expect(card.text == DIRECTOR_LABELS[ending], "card %d is %s" % [ending, DIRECTOR_LABELS[ending]])
		await _until(func() -> bool: return not game._choice_sheet.is_popping(), "the sheet settles")
		await _press(card)
		await _until(func() -> bool: return game._screen_mode == "story" and game._runner.node_id == ENDING_NODES[ending], "card %d goes to %s" % [ending, ENDING_NODES[ending]])
		_expect(game._runner.flags["ep00_ending"] == ENDING_FLAGS[ending], "card %d sets ep00_ending=%s" % [ending, ENDING_FLAGS[ending]])
		await _read_until(game, func() -> bool: return game._screen_mode == "end", "the ending %d" % ending)
		_expect(game._full_text == ENDING_TEXTS[ending] and game._runner.flags["ep00_ending"] == ENDING_FLAGS[ending] and game._end_box.visible,
			"ending %d ends the story with %s (%s)" % [ending, ENDING_TEXTS[ending], game._full_text])
		_expect(game._runner.flags["pov_style"] == "loud" and game._runner.flags["found_job"] == true,
			"and the flags of the whole run are kept: %s" % [game._runner.flags])
		await _free(game)
		_cleanup()


# ---------------------------------------------------------------- shell: saves

## Saved in the search after two taps on Gintoki; a new shell reads it and the third tap plays the third line.
func _test_save_in_the_search() -> void:
	var game: Control = await _new_game()
	await _to_search(game, 2)
	var portrait: Rect2 = game._sprites["gintoki"].art_rect()
	var point: Vector2 = _above_box(game, portrait)
	for tap: int in range(2):
		await _tap(point)
		await _until(func() -> bool: return game._screen_mode == "story", "tap %d plays a line" % [tap + 1])
		_expect(game._full_text == GIN_LINES[tap], "tap %d says %s" % [tap + 1, GIN_LINES[tap]])
		await _read_back(game)
	_expect(game._runner.investigations["yorozuya_room"]["counts"] == {"gintoki": 2}, "two taps counted")
	_expect(game._save_game(), "the search is saved")
	var payload: Dictionary = game._build_save_payload("")
	await _free(game)

	game = await _new_game()
	game._on_continue_pressed()
	await _until(func() -> bool: return game._screen_mode == "investigate", "the auto-save comes back to the search")
	await _frames(3)
	_expect(game._runner.investigations["yorozuya_room"]["counts"] == {"gintoki": 2} and game._hotspots.has("gintoki") and game._hotspots["gintoki"].found,
		"his two taps and his checked spot are back")
	var visible_actors: Array = game._sprites.keys().filter(func(actor: String) -> bool: return game._sprites[actor].visible)
	_expect(visible_actors == ["gintoki"] and game._runner.flags["pov_style"] == "tired", "only Gintoki is on stage; pov_style is tired")
	await _tap(_above_box(game, game._sprites["gintoki"].art_rect()))
	await _until(func() -> bool: return game._screen_mode == "story", "the third tap plays a line")
	_expect(game._full_text == GIN_LINES[2], "the third tap after loading says the third line: %s" % game._full_text)
	await _read_back(game)
	await _tap(_above_box(game, game._sprites["gintoki"].art_rect()))
	await _until(func() -> bool: return game._screen_mode == "story", "the fourth tap plays a line")
	_expect(game._full_text == GIN_LINES[2], "the fourth repeats the third (got '%s')" % game._full_text)
	await _free(game)

	# The same through a manual slot's payload, into a shell that never played.
	game = await _new_game()
	_expect(game._validate_save_payload(payload), "the slot payload taken in the search is valid")
	game._load_payload_from_picker(payload, "已讀取")
	await _until(func() -> bool: return game._screen_mode == "investigate", "the slot comes back to the search")
	await _frames(3)
	await _tap(_above_box(game, game._sprites["gintoki"].art_rect()))
	await _until(func() -> bool: return game._screen_mode == "story", "a tap plays a line")
	_expect(game._full_text == GIN_LINES[2], "from the slot too, the third tap is the third line: %s" % game._full_text)
	await _free(game)
	_cleanup()


func _test_save_at_the_director_choice() -> void:
	var game: Control = await _new_game()
	await _to_director(game)
	_expect(await _is_director_choice(game), "the director's choice shows")
	_expect(game._save_game(), "it is saved")
	var payload: Dictionary = game._build_save_payload("")
	await _free(game)

	game = await _new_game()
	game._on_continue_pressed()
	await _frames(4)
	_expect(await _is_director_choice(game), "続 lands on the same director's choice, in the director's panel: %s" % game._screen_mode)
	_expect(game._runner.flags["pov_style"] == "loud" and game._runner.flags["found_job"] == true, "with the flags of the run: %s" % [game._runner.flags])
	await _until(func() -> bool: return not game._choice_sheet.is_popping(), "it settles")
	await _free(game)

	game = await _new_game()
	_expect(game._validate_save_payload(payload), "the slot payload is valid")
	game._load_payload_from_picker(payload, "已讀取")
	await _frames(4)
	_expect(await _is_director_choice(game), "a manual slot restores the same director's choice")
	await _until(func() -> bool: return not game._choice_sheet.is_popping(), "it settles")
	await _press(game._choice_buttons[0])
	await _until(func() -> bool: return game._runner.node_id == "end_debt", "and the card still works after loading")
	await _free(game)
	_cleanup()


## A save taken while the runner stands on the overlay's step never replays it; nor does one taken after it.
func _test_old_save_does_not_replay_the_overlay() -> void:
	var impact_index: int = _index_of(_story(), "s03_loud", "comedy")
	var game: Control = await _new_game()
	game._on_begin_pressed()
	await _read_until(game, func() -> bool: return game._screen_mode == "choice", "the POV choice")
	await _press(game._choice_buttons[0])
	await _read_to_overlay(game, "tsukkomi_impact")
	var during: Dictionary = game._build_save_payload("")  # the runner is on the overlay's step
	_expect(during["runner"]["node_id"] == "s03_loud" and int(during["runner"]["step_index"]) == impact_index, "the save was taken on the comedy step: %s" % [during["runner"]])
	await _until(func() -> bool: return game._screen_mode == "story" and game._runner_current().get("step_index") == impact_index + 1, "the line after the overlay shows", 4.0)
	await _until(func() -> bool: return game._text_complete, "it types out")
	_expect(game._save_game(), "the line after the overlay is saved")
	await _free(game)

	game = await _new_game()
	game._on_continue_pressed()
	await _frames(6)
	_expect(not game._comedy_layer.is_active() and not game._comedy_layer.visible and game._screen_mode == "story" and game._full_text == REACTION_LINES[0]
		and game._runner_current().get("step_index") == impact_index + 1, "続 lands on the line after the overlay and it does not play again")
	await _free(game)

	game = await _new_game()
	_expect(game._validate_save_payload(during), "a save whose runner stands on the overlay's step is valid")
	game._load_payload_from_picker(during, "已讀取")
	await _frames(6)
	_expect(not game._comedy_layer.is_active() and game._runner_current().get("step_index") == impact_index + 1 and game._screen_mode == "story"
		and game._full_text == REACTION_LINES[0], "loading it skips the overlay and shows Kagura's line instead (%s)" % game._full_text)
	await create_timer(1.6).timeout
	_expect(not game._comedy_layer.is_active() and game._comedy_layer.get_child_count() == 0 and game._runner_current().get("step_index") == impact_index + 1,
		"and no overlay appears afterwards")
	var logged: Array = game._history.filter(func(entry: Dictionary) -> bool: return str(entry["key"]).begins_with("comedy:"))
	_expect(logged.size() == 1, "its line is still in the log, once: %s" % [logged])
	await _free(game)
	_cleanup()


## The chapter label is the story's title up to the first （ ("EP00 今天也沒有工作的萬事屋"), more than the speaker row has room
## for: in every edition's box it trims with an ellipsis instead of being cut off on its left.
func _test_chapter_label_trims_with_an_ellipsis() -> void:
	for style: String in ["cinema", "ledger", "manga"]:
		var box: Control = (load("res://scenes/ui/dialogue_box_%s.tscn" % style) as PackedScene).instantiate() as Control
		var chapter: Label = box.get_node("%Chapter") as Label
		_expect(chapter.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS and chapter.clip_text and chapter.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT,
			"%s: the chapter label trims with an ellipsis (overrun %d)" % [style, chapter.text_overrun_behavior])
		box.free()
	var game: Control = await _new_game()
	_expect(game._dialog_panel.chapter.text == "EP00 今天也沒有工作的萬事屋" and game._dialog_panel.chapter.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS,
		"the shell shows the long chapter label and trims it: %s" % game._dialog_panel.chapter.text)
	await _free(game)


# ---------------------------------------------------------------- helpers

func _story() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(STORY)) as Dictionary


func _loaded() -> RefCounted:
	var runner: RefCounted = StoryRunner.new()
	_expect(runner.call("load_story", STORY), "EP00 loads: %s" % runner.get("error_message"))
	return runner


func _advance_to(runner: RefCounted, op: String) -> void:
	for _step: int in range(200):
		if String((runner.call("current") as Dictionary).get("op", "")) == op:
			return
		runner.call("advance")
	_expect(false, "reached op '%s' (stopped at %s)" % [op, runner.get("node_id")])


func _steps(nodes: Dictionary, node_id: String, op: String) -> Array:
	return ((nodes[node_id] as Dictionary)["steps"] as Array).filter(func(step: Dictionary) -> bool: return step["op"] == op)


func _index_of(story: Dictionary, node_id: String, op: String) -> int:
	var steps: Array = ((story["nodes"] as Dictionary)[node_id] as Dictionary)["steps"] as Array
	for index: int in range(steps.size()):
		if steps[index]["op"] == op:
			return index
	return -1


## Every node id a step can jump to.
func _targets(step: Dictionary) -> Array[String]:
	var targets: Array[String] = []
	for key: String in ["then", "else", "target", "game_over"]:
		if step.has(key):
			targets.append(String(step[key]))
	for option: Dictionary in step.get("options", []):
		targets.append(String(option["next"]))
	for spot: Dictionary in step.get("hotspots", []):
		if spot.has("goto"):
			targets.append(String(spot["goto"]))
		for line: Variant in spot.get("lines", []):
			targets.append(String(line))
	return targets


func _new_game() -> Control:
	var game: Control = MAIN_SCENE.instantiate() as Control
	game.story_path = STORY
	game.save_path = TEST_SAVE
	game.ui_preference_path = TEST_UI
	game.settings_path = TEST_SETTINGS
	root.add_child(game)
	await _frames(3)
	_expect(game._story_ready, "EP00 loads in the shell: %s" % game._story_error)
	return game


func _free(game: Control) -> void:
	game.queue_free()
	await _frames(2)


## Reads like a player: finish the line, go on, until `done` (never past a choice or a search).
func _read_until(game: Control, done: Callable, label: String, timeout: float = 30.0) -> void:
	var deadline: int = Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if done.call():
			return
		if game._screen_mode == "story" and not game._story_busy:
			if not game._text_complete:
				game._complete_current_line()
			else:
				game._advance_current_line()
		await _frames(2)
	failures.append("timed out: " + label)


## Reads on until the overlay plays that preset.
func _read_to_overlay(game: Control, preset: String) -> void:
	await _read_until(game, func() -> bool: return game._comedy_layer.is_active() and game._comedy_layer.current_preset() == preset, "the %s overlay" % preset)


## Skips from the start to the POV choice, picks the row, skips to the search.
func _to_search(game: Control, row: int) -> void:
	game._on_begin_pressed()
	await _until(func() -> bool: return game._screen_mode == "story", "the story starts")
	game._set_skip(true)
	await _until(func() -> bool: return game._screen_mode == "choice", "the POV choice", 20.0)
	await _frames(2)
	game._on_choice_pressed(POV_IDS[row])
	game._set_skip(true)
	await _until(func() -> bool: return game._screen_mode == "investigate", "the search", 20.0)
	await _frames(4)


## The loud row, the job found, then on to the director's choice (the way path A goes).
func _to_director(game: Control) -> void:
	await _to_search(game, 0)
	game._collect_hotspot("job_document")
	game._set_skip(true)
	await _until(func() -> bool: return game._screen_mode == "investigate", "back from the job document", 20.0)
	game._on_investigation_continue_pressed()
	game._set_skip(true)
	await _until(func() -> bool: return game._screen_mode == "choice", "the director's choice", 20.0)
	await _frames(3)


func _is_director_choice(game: Control) -> bool:
	var sheet: Control = game._choice_sheet
	var labels: Array[String] = []
	for row: Button in game._choice_buttons:
		labels.append(row.text)
	var ok: bool = game._screen_mode == "choice" and sheet.get("perspective") == "director" and sheet.scene_file_path == DIRECTOR_SHEET \
		and sheet.get_node("%Note").text == DIRECTOR_NOTE and sheet.get_node("%Prompt").text == DIRECTOR_PROMPT and sheet.get_node("%Banner").text == "── 導演選擇 ──" \
		and labels == DIRECTOR_LABELS \
		and game._choice_qa_state(game._runner_current()) == {"perspective": "director", "pov": "", "note": DIRECTOR_NOTE, "sheet": "director", "tones": ["", "", ""]}
	await _frames(1)
	return ok


## A point on the upper part of the rect, above the reading box.
func _above_box(game: Control, rect: Rect2) -> Vector2:
	var visible_rect: Rect2 = rect.intersection(Rect2(game._game.global_position, game._game.size))
	var bottom: float = minf(visible_rect.end.y, game._dialog_panel.get_global_rect().position.y) if game._dialog_panel.visible else visible_rect.end.y
	return Vector2(visible_rect.get_center().x, visible_rect.position.y + (bottom - visible_rect.position.y) * 0.25)


## Drags the picture until the object is in reach (its tap area wholly on screen, above the reading bar), then taps its centre.
func _tap_object(game: Control, spot_id: String) -> void:
	var spot: Control = game._hotspots[spot_id]
	var screen: Rect2 = Rect2(game._game.global_position, game._game.size)
	var current: Rect2 = game._hotspot_hit_rect(spot)
	# The free strip left of Gintoki, but never with the object's own left edge off the screen.
	var target_x: float = maxf(screen.position.x + screen.size.x * 0.18, screen.position.x + current.size.x * 0.5 + 8.0)
	var shift: float = target_x - current.get_center().x
	game._set_pan(game._pan + shift)
	await _frames(2)
	var hit: Rect2 = game._hotspot_hit_rect(spot)
	_expect(screen.encloses(hit), "%s is wholly on screen after dragging the picture: %s" % [spot_id, hit])
	await _tap(hit.get_center())


## Reads a reaction scene through until the search is back.
func _read_back(game: Control) -> void:
	for _i: int in range(900):
		if game._screen_mode == "investigate" and not game._story_busy:
			return
		if game._screen_mode == "story" and not game._story_busy:
			if game._text_complete:
				game._advance_current_line()
			else:
				game._complete_current_line()
		await process_frame
	failures.append("timed out reading back to the search (at %s)" % game._screen_mode)


func _cleanup() -> void:
	for base: String in [TEST_SAVE, TEST_UI, TEST_SETTINGS]:
		for suffix: String in ["", ".bak", ".bak.old", ".old", ".tmp", ".bak.tmp"]:
			var absolute: String = ProjectSettings.globalize_path(base + suffix)
			if FileAccess.file_exists(absolute):
				DirAccess.remove_absolute(absolute)
