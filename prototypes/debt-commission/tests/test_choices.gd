extends "res://addons/proto_kit/test_kit.gd"
## The two kinds of `choice`: a POV choice (a thought of `pov`; the rows in the edition's sheet, a round
## tone marker on the rows that have a tone) and a Director choice (the player steps out and decides what
## happens next; a sheet of its own, the same in every edition). Covers the data (validation, both build
## adapters, scripts written before the marks), the sheets, and the shell around them: focus, every edition,
## switching edition while a choice is up, saves, narrow phones, the sound, and that none of it rewrites a scene.

const MAIN_SCENE: PackedScene = preload("../main.tscn")
const StoryRunner = preload("res://scripts/story_runner.gd")
const StoryBuilder = preload("res://tools/story_build/story_builder.gd")
const SAMPLE: String = "res://data/choices_story.json"
const DEBT_STORY: String = "res://data/debt_story.json"
const PHASE3_STORY: String = "res://data/phase3_story.json"
const BAD_STORY: String = "user://choices_bad_story.json"
const MIXED_STORY: String = "user://choices_mixed_story.json"
const NO_NOTE_STORY: String = "user://choices_no_note_story.json"
const MANY_STORY: String = "user://choices_many_story.json"
const CHAIN_STORY: String = "user://choices_chain_story.json"
const TEST_SAVE: String = "user://choices_test.save"
const TEST_UI: String = "user://choices_test_ui.cfg"
const TEST_SETTINGS: String = "user://choices_test_settings.cfg"
const DIRECTOR_SHEET: String = "res://scenes/ui/choice_sheet_director.tscn"
const DIRECTOR_ITEM: String = "res://scenes/ui/choice_item_director.tscn"
const STYLES: Array[String] = ["cinema", "ledger", "manga", "gintama"]
const DIRECTOR_PROMPT: String = "接下來發生什麼？"
const DIRECTOR_NOTE: String = "※製作組經費有限"
const POV_LABELS: Array[String] = ["問題是你有工作的時候也在休息啊！！", "那請問這個月的房租打算怎麼辦？", "……算了，我甚至不知道從哪裡開始說。"]
const DIRECTOR_LABELS: Array[String] = ["登勢闖進來", "電話突然響了", "定春帶回奇怪的東西"]
const GLYPHS: Dictionary = {"loud": "！", "calm": "？", "tired": "…"}
## Nothing the game or this test does may write these.
const SCENE_FILES: Array[String] = [
	"res://main.tscn", DIRECTOR_SHEET, DIRECTOR_ITEM,
	"res://scenes/ui/choice_sheet_cinema.tscn", "res://scenes/ui/choice_sheet_ledger.tscn", "res://scenes/ui/choice_sheet_manga.tscn",
	"res://scenes/ui/choice_sheet_gintama.tscn",
	"res://scenes/ui/choice_item_cinema.tscn", "res://scenes/ui/choice_item_ledger.tscn", "res://scenes/ui/choice_item_manga.tscn",
	"res://scenes/ui/choice_item_gintama.tscn",
	"res://scenes/ui/dialogue_box_gintama.tscn", "res://scenes/ui/menu_panel_gintama.tscn", "res://scenes/ui/title_screen_gintama.tscn"]

## One mistake of a story per case: where it is edited, how, and what the loader must say.
## A tiny .dialogue (a POV choice, a director choice with a note, one without) and its Parley graph.
const DM_TEXT: String = """~ scene_pov
銀時: 先說一句。
do pov("gintoki")
這句要怎麼回？
- 激烈 [ID:a] [#loud]
	=> scene_director
- 普通 [ID:b]
	=> scene_director
- 累了 [ID:c] [#tired]
	=> scene_director

~ scene_director
do director("※製作組經費有限")
接下來發生什麼？
- 登勢闖進來 [ID:x]
	=> scene_plain
- 電話突然響了 [ID:y]
	=> scene_plain

~ scene_plain
do director()
接下來呢？
- 甲 [ID:p]
	=> done
- 乙 [ID:q]
	=> done

~ done
do end("結束")
"""
const DM_PATH: String = "res://story_src/__choices_check.dialogue"
const DS_PATH: String = "res://story_src/__choices_check.ds"
const SPEAKER_GINTOKI: String = "uid://x::銀時"


## Collects every error the engine logs (script errors, push_error) while a check runs.
class ErrorCatcher extends Logger:
	var messages: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
			_error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		messages.append("%s (%s:%d) %s %s" % [function, file, line, code, rationale])


## The Parley graph of DM_TEXT, built node by node (`.ds` is a JSON graph of groups).
class Graph:
	var nodes: Array = []
	var edges: Array = []

	func add(type: String, fields: Dictionary = {}) -> String:
		var id: String = "node:%d" % (nodes.size() + 1)
		var node: Dictionary = {"id": id, "type": type, "position": "(0.0, %d.0)" % (nodes.size() * 100)}
		node.merge(fields)
		nodes.append(node)
		return id

	func link(from_id: String, to_id: String) -> void:
		edges.append({"id": "edge:%d" % (edges.size() + 1), "from_node": from_id, "from_slot": 0, "to_node": to_id, "to_slot": 0})

	func chain(ids: Array) -> void:
		for index: int in range(ids.size() - 1):
			link(ids[index], ids[index + 1])

	func group(group_name: String, members: Array) -> void:
		add("GROUP", {"name": group_name, "node_ids": members})

	func action(command: String) -> String:
		return add("ACTION", {"description": command, "action_type": "SCRIPT", "action_script_ref": "", "values": []})

	func option(key: String, text: String) -> String:
		return add("DIALOGUE_OPTION", {"character": "", "text": text, "text_translation_key": key})

	func to_json() -> String:
		return JSON.stringify({"title": "check", "nodes": nodes, "edges": edges})


var catcher: ErrorCatcher = ErrorCatcher.new()
var scene_sources: Dictionary = {}


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	OS.add_logger(catcher)
	for path: String in SCENE_FILES:
		scene_sources[path] = FileAccess.get_file_as_string(path)
	_cleanup()
	_test_scenes()
	_test_validation()
	_test_scripts_without_the_marks()
	_test_adapters_agree()
	_test_adapter_misuse()
	await _test_legacy_choice_in_the_shell()
	await _test_pov_choice()
	await _test_director_choice()
	await _test_every_edition_and_kind()
	await _test_switching_edition()
	await _test_sheet_follows_the_choice()
	await _test_saves()
	await _test_pop_in()
	await _test_sound()
	await _test_narrow_phones()
	for path: String in SCENE_FILES:
		_expect(FileAccess.get_file_as_string(path) == scene_sources[path], "playing never rewrites %s" % path)
	_expect(catcher.messages.is_empty(), "no engine errors were logged: %s" % [catcher.messages.slice(0, 3)])
	OS.remove_logger(catcher)
	_cleanup()
	_finish("CHOICE TESTS")


# ---------------------------------------------------------------- scenes

func _test_scenes() -> void:
	var sheet: Control = (load(DIRECTOR_SHEET) as PackedScene).instantiate() as Control
	for node_name: String in ["Prompt", "Count", "Choices", "ChoicesScroll", "Timer", "TimerBar", "TimerValue", "Feedback", "Menu",
			"CensorBar", "Super", "Banner", "Note", "Panel"]:
		_expect(sheet.get_node_or_null("%" + node_name) != null, "the director sheet has %%%s" % node_name)
	_expect((sheet.get_node("%Banner") as Label).text == "── 導演選擇 ──", "the heading reads ── 導演選擇 ──")
	_expect(str(sheet.get("perspective")) == "director" and sheet.get("item_scene") == load(DIRECTOR_ITEM),
		"the sheet is the director's and its rows are the director item scene")
	_expect((sheet.get_node("%Choices") as Control).get_child_count() >= 3 and (sheet.get_node("%Note") as Label).text == DIRECTOR_NOTE,
		"the editor shows sample rows and a sample footnote")
	var every: Array[Node] = _descendants(sheet)
	_expect(every.all(func(node: Node) -> bool: return node == sheet or node.owner == sheet or (node.owner != null and node.owner.owner == sheet)),
		"every node belongs to the scene (the sample rows' own nodes to their instances)")
	_expect(every.all(func(node: Node) -> bool: return not node.has_meta("ui_style_role")),
		"nothing in it takes the edition's colours (no ui_style_role)")
	var item: Control = (load(DIRECTOR_ITEM) as PackedScene).instantiate() as Control
	_expect(item.get_node_or_null("%Index") != null and item.get_node_or_null("%Tone") == null, "a director row has its number and no tone marker")
	_expect(item.custom_minimum_size.y >= 48.0 * 1080.0 / 390.0 - 0.01, "a director row is at least 48 CSS px tall")
	item.free()
	sheet.free()
	for style: String in STYLES:
		var row: Control = (load("res://scenes/ui/choice_item_%s.tscn" % style) as PackedScene).instantiate() as Control
		var marker: Label = row.get_node_or_null("%Tone") as Label
		_expect(marker != null and not marker.visible and row.get_child(-1) == marker and row.get_node_or_null("%Index") != null,
			"%s: the row has a hidden %%Tone, the last child, beside its number" % style)
		row.free()


# ---------------------------------------------------------------- data

## [what is wrong, the choice it is done to, how, what the loader says]
func _test_validation() -> void:
	var story: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAMPLE))
	var pov_at: Array = _find_choice(story, "choices_open")
	var director_at: Array = _find_choice(story, "choices_director")
	var cases: Array[Array] = [
		["an unknown perspective", pov_at, func(step: Dictionary) -> void: step["perspective"] = "bogus",
			"choice perspective 'bogus' is not one of pov, director"],
		["pov on a director choice", director_at, func(step: Dictionary) -> void: step["pov"] = "gintoki",
			"choice pov is only for a pov choice"],
		["an unknown pov character", pov_at, func(step: Dictionary) -> void: step["pov"] = "nobody",
			"choice pov 'nobody' is not a character in the asset catalog"],
		["note on a pov choice", pov_at, func(step: Dictionary) -> void: step["note"] = "※不該在這裡",
			"choice note is only for a director choice"],
		["an empty note", director_at, func(step: Dictionary) -> void: step["note"] = "",
			"choice note must be a non-empty string"],
		["an unknown tone", pov_at, func(step: Dictionary) -> void: (step["options"] as Array)[0]["tone"] = "angry",
			"option 'reply_loud' tone 'angry' is not one of loud, calm, tired"],
		["a tone on a director choice", director_at, func(step: Dictionary) -> void: (step["options"] as Array)[1]["tone"] = "loud",
			"option 'phone_rings' tone is only for a pov choice"],
		["a director choice with one option", director_at, func(step: Dictionary) -> void: step["options"] = [(step["options"] as Array)[0]],
			"director choice needs at least two options"],
	]
	for case: Array in cases:
		var broken: Dictionary = story.duplicate(true)
		var location: Array = case[1]
		var step: Dictionary = ((broken["nodes"][location[0]]["steps"]) as Array)[location[1]]
		(case[2] as Callable).call(step)
		var runner: RefCounted = _load_story(broken)
		var message: String = str(runner.get("error_message"))
		_expect(not bool(runner.get("_loaded")) and message.contains("node '%s' step %d" % [location[0], location[1]]) and message.contains(case[3]),
			"%s is rejected with its node and step: %s" % [case[0], message])
	# What is allowed still loads: another POV character, the explicit default, tones on some rows only.
	var fine: Dictionary = story.duplicate(true)
	var fine_step: Dictionary = ((fine["nodes"][pov_at[0]]["steps"]) as Array)[pov_at[1]]
	fine_step["pov"] = "gintoki"
	fine_step["perspective"] = "pov"
	(fine_step["options"] as Array)[1].erase("tone")
	_expect(bool(_load_story(fine).get("_loaded")), "a pov choice may name another character and tag only some of its rows")
	_expect(bool(_load_story(story).get("_loaded")), "the sample story loads")


## Scripts written before the marks: no new field anywhere, built and played the same as before.
func _test_scripts_without_the_marks() -> void:
	for path: String in ["debt", "phase2", "phase3", "phase4", "phase4_rounds", "comedy"]:
		var story: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/%s_story.json" % path))
		var marked: int = 0
		for node: Dictionary in (story["nodes"] as Dictionary).values():
			for step: Dictionary in node["steps"]:
				if step["op"] != "choice":
					continue
				marked += int(step.has("perspective") or step.has("pov") or step.has("note"))
				marked += (step["options"] as Array).filter(func(option: Dictionary) -> bool: return option.has("tone")).size()
		_expect(marked == 0, "%s has no perspective, pov, note or tone anywhere" % path)
	for name: String in ["phase4", "phase4_rounds", "comedy", "choices"]:
		var built: Dictionary = StoryBuilder.build("res://story_src/%s.dialogue" % name)
		_expect(String(built["error"]).is_empty() and FileAccess.get_file_as_string("res://data/%s_story.json" % name) == StoryBuilder.to_json(built["story"]),
			"data/%s_story.json is a fresh build of its .dialogue (%s)" % [name, built["error"]])


func _test_adapters_agree() -> void:
	var from_dm: Dictionary = StoryBuilder.build_text(DM_TEXT, DM_PATH)
	var from_ds: Dictionary = StoryBuilder.build_text(_parley_graph().to_json(), DS_PATH)
	_expect(String(from_dm["error"]).is_empty() and String(from_ds["error"]).is_empty(), "both sources build: %s | %s" % [from_dm["error"], from_ds["error"]])
	if not String(from_dm["error"]).is_empty() or not String(from_ds["error"]).is_empty():
		return
	var dm_nodes: Dictionary = from_dm["story"]["nodes"]
	var ds_nodes: Dictionary = from_ds["story"]["nodes"]
	_expect(dm_nodes == ds_nodes, "the .dialogue and the Parley graph build the same nodes")
	var pov_step: Dictionary = dm_nodes["scene_pov"]["steps"][1]
	_expect(pov_step == {"op": "choice", "prompt": "這句要怎麼回？", "pov": "gintoki", "options": [
			{"id": "a", "label": "激烈", "next": "scene_director", "tone": "loud"},
			{"id": "b", "label": "普通", "next": "scene_director"},
			{"id": "c", "label": "累了", "next": "scene_director", "tone": "tired"}]},
		"pov('gintoki') and the tone tags / tone() nodes become pov and tone: %s" % [pov_step])
	var director_step: Dictionary = dm_nodes["scene_director"]["steps"][0]
	_expect(director_step.get("perspective") == "director" and director_step.get("note") == DIRECTOR_NOTE and not director_step.has("pov"),
		"director(note) becomes perspective director with its note: %s" % [director_step])
	var plain_step: Dictionary = dm_nodes["scene_plain"]["steps"][0]
	_expect(plain_step.get("perspective") == "director" and not plain_step.has("note"), "director() has no note: %s" % [plain_step])
	_expect(dm_nodes["scene_pov"]["steps"].size() == 2 and dm_nodes["scene_director"]["steps"].size() == 1,
		"the marks are folded into their choice, not left as steps of their own")
	# pov() takes a displayed name too, and the marks are not part of a save's position: the version stays.
	var by_name: Dictionary = StoryBuilder.build_text(DM_TEXT.replace('do pov("gintoki")', 'do pov("銀時")'), DM_PATH)
	_expect(String(by_name["error"]).is_empty() and by_name["story"]["nodes"]["scene_pov"]["steps"][1]["pov"] == "gintoki",
		"pov('銀時') is stored as the catalog id: %s" % by_name["error"])
	var other_marks: Dictionary = StoryBuilder.build_text(DM_TEXT.replace(" [#loud]", "").replace("經費有限", "沒有預算"), DM_PATH)
	_expect(String(other_marks["error"]).is_empty() and other_marks["story"]["version"] == from_dm["story"]["version"],
		"changing a tone or a note keeps the story's version (saves stay valid): %s" % other_marks["error"])


func _test_adapter_misuse() -> void:
	var dm_cases: Array[Array] = [
		["an unknown tone tag", "[ID:a] [#loud]", "[ID:a] [#angry]", "~ scene_pov, step 2: response 'a' has unknown tag [#angry]"],
		["two tone tags", "[ID:a] [#loud]", "[ID:a] [#loud] [#calm]", "~ scene_pov, step 2: response 'a' has more than one tone tag"],
		["a tone on a director choice", "- 登勢闖進來 [ID:x]", "- 登勢闖進來 [ID:x] [#loud]",
			"node 'scene_director' step 1: a director choice has no tones (option 'x' is tagged loud)"],
		["an unknown pov character", 'do pov("gintoki")', 'do pov("nobody")', "node 'scene_pov' step 1: pov('nobody') is not a catalog character"],
		["an empty note", 'do director("※製作組經費有限")', 'do director("")', "node 'scene_director' step 0: director() note must be non-empty text"],
		["a mark before a line", "銀時: 先說一句。", "do director()\n銀時: 先說一句。", "node 'scene_pov' step 0: director() must come right before a choice prompt"],
		["pov and director on one choice", 'do director()\n接下來呢？', 'do director()\ndo pov("gintoki")\n接下來呢？',
			"node 'scene_plain' step 0: a choice takes one of pov() or director(), not both"],
		["a loose tone()", 'do pov("gintoki")', 'do tone("loud")', "node 'scene_pov' step 1: tone() belongs right after a choice option"],
	]
	for case: Array in dm_cases:
		var text: String = DM_TEXT.replace("\r\n", "\n").replace(case[1], case[2])
		_expect(text != DM_TEXT, "%s: the case edits the source" % case[0])
		var built: Dictionary = StoryBuilder.build_text(text, DM_PATH)
		_expect(String(built["error"]).contains(case[3]), "[.dialogue] %s is reported with its title and step (got: %s)" % [case[0], built["error"]])
	# The same mistakes in a Parley graph. Each case builds the graph with extra ACTION nodes, or edits one.
	var graph_cases: Array[Array] = [
		["an unknown tone", func() -> Graph: return _edited(_parley_graph(), 'tone("loud")', 'tone("angry")'),
			"group 'scene_pov', step 2: option 'a' tone 'angry' is not one of loud, calm, tired"],
		["a tone on a director choice", func() -> Graph: return _edited(_parley_graph(), 'pov("gintoki")', 'director("※不該有")'),
			"node 'scene_pov' step 2: a director choice has no tones (option 'a' is tagged loud)"],
		["an unknown pov character", func() -> Graph: return _edited(_parley_graph(), 'pov("gintoki")', 'pov("nobody")'),
			"node 'scene_pov' step 1: pov('nobody') is not a catalog character"],
		["an empty note", func() -> Graph: return _edited(_parley_graph(), 'director("※製作組經費有限")', 'director("")'),
			"node 'scene_director' step 0: director() note must be non-empty text"],
		["a mark before a line", func() -> Graph: return _parley_graph('director()'),
			"node 'scene_pov' step 0: director() must come right before a choice prompt"],
		["pov and director on one choice", func() -> Graph: return _parley_graph("", 'director()'),
			"node 'scene_pov' step 1: a choice takes one of pov() or director(), not both"],
		["a loose tone()", func() -> Graph: return _parley_graph('tone("loud")'),
			"node 'scene_pov' step 0: tone() belongs right after a choice option"],
	]
	for case: Array in graph_cases:
		var graph: Graph = (case[1] as Callable).call()
		var built: Dictionary = StoryBuilder.build_text(graph.to_json(), DS_PATH)
		_expect(String(built["error"]).contains(case[2]), "[Parley] %s is reported with its group and step (got: %s)" % [case[0], built["error"]])


func _edited(graph: Graph, from_text: String, to_text: String) -> Graph:
	_set_description(graph, from_text, to_text)
	return graph


func _set_description(graph: Graph, from_text: String, to_text: String) -> void:
	for node: Dictionary in graph.nodes:
		if str(node.get("description", "")) == from_text:
			node["description"] = to_text
			return
	_expect(false, "the graph has an ACTION %s" % from_text)


## `before_say` is a command put in front of the first line of scene_pov, `after_pov` one after its pov(...).
func _parley_graph(before_say: String = "", after_pov: String = "") -> Graph:
	var g: Graph = Graph.new()
	var start: String = g.add("START")
	# scene_pov: a line, pov("gintoki"), the prompt and three options (loud / none / tired)
	var first: String = g.action(before_say) if not before_say.is_empty() else ""
	var say: String = g.add("DIALOGUE", {"character": SPEAKER_GINTOKI, "text": "先說一句。", "text_translation_key": ""})
	var pov: String = g.action('pov("gintoki")')
	var extra: String = g.action(after_pov) if not after_pov.is_empty() else ""
	var pov_prompt: String = g.add("DIALOGUE", {"character": "", "text": "這句要怎麼回？", "text_translation_key": ""})
	var opt_a: String = g.option("a", "激烈")
	var tone_a: String = g.action('tone("loud")')
	var opt_b: String = g.option("b", "普通")
	var opt_c: String = g.option("c", "累了")
	var tone_c: String = g.action('tone("tired")')
	g.chain([say, pov] + ([extra] if not extra.is_empty() else []) + [pov_prompt])
	if not first.is_empty():
		g.link(first, say)
	g.link(pov_prompt, opt_a)
	g.link(pov_prompt, opt_b)
	g.link(pov_prompt, opt_c)
	g.link(opt_a, tone_a)
	g.link(opt_c, tone_c)
	g.group("scene_pov", ([first] if not first.is_empty() else []) + [say, pov] + ([extra] if not extra.is_empty() else []) + [pov_prompt, opt_a, tone_a, opt_b, opt_c, tone_c])
	# scene_director: director("note"), the prompt, two options
	var director: String = g.action('director("※製作組經費有限")')
	var director_prompt: String = g.add("DIALOGUE", {"character": "", "text": "接下來發生什麼？", "text_translation_key": ""})
	var opt_x: String = g.option("x", "登勢闖進來")
	var opt_y: String = g.option("y", "電話突然響了")
	g.link(director, director_prompt)
	g.link(director_prompt, opt_x)
	g.link(director_prompt, opt_y)
	g.group("scene_director", [director, director_prompt, opt_x, opt_y])
	# scene_plain: director() without a note
	var plain: String = g.action("director()")
	var plain_prompt: String = g.add("DIALOGUE", {"character": "", "text": "接下來呢？", "text_translation_key": ""})
	var opt_p: String = g.option("p", "甲")
	var opt_q: String = g.option("q", "乙")
	g.link(plain, plain_prompt)
	g.link(plain_prompt, opt_p)
	g.link(plain_prompt, opt_q)
	g.group("scene_plain", [plain, plain_prompt, opt_p, opt_q])
	# done
	var finish: String = g.action('end("結束")')
	var end_node: String = g.add("END")
	g.link(finish, end_node)
	g.group("done", [finish])  # the END node stands outside the group
	g.link(start, first if not first.is_empty() else say)
	g.link(tone_a, director)
	g.link(opt_b, director)
	g.link(tone_c, director)
	g.link(opt_x, plain)
	g.link(opt_y, plain)
	g.link(opt_p, finish)
	g.link(opt_q, finish)
	return g


# ---------------------------------------------------------------- the shell

## A choice nobody marked looks and works as before: Shinpachi's thought in the edition's sheet.
func _test_legacy_choice_in_the_shell() -> void:
	var game: Control = await _new_game(DEBT_STORY)
	await _to_choice(game, "the debt story's first choice")
	var sheet: Control = game._choice_sheet
	_expect(sheet.get("perspective") == "pov" and sheet.style_id == "cinema" and sheet.scene_file_path == "res://scenes/ui/choice_sheet_cinema.tscn",
		"an unmarked choice is in the edition's sheet")
	_expect(game._current_speaker == "shinpachi" and game._dialog_panel.speaker_name.text == "新八・心聲",
		"it is Shinpachi's thought: %s" % game._dialog_panel.speaker_name.text)
	var shinpachi: Control = game._sprites["shinpachi"]
	_expect(shinpachi.visible and shinpachi.modulate.r > 0.9 and str(shinpachi.get("expression")) == "thinking",
		"Shinpachi is in focus with the thinking face")
	_expect(game._choice_buttons.size() == 2 and game._choice_buttons.all(func(row: Button) -> bool: return not (row.get_node("%Tone") as Control).visible),
		"no row shows a tone marker")
	var base: StyleBox = ((load("res://scenes/ui/choice_item_cinema.tscn") as PackedScene).instantiate() as Control).get_theme_stylebox("normal")
	_expect(game._choice_buttons.all(func(row: Button) -> bool: return row.get_theme_stylebox("normal") == base),
		"each row keeps the scene's own styles")
	_expect(game._choice_qa_state(game._runner_current()) == {"perspective": "pov", "pov": "shinpachi", "note": "", "sheet": "cinema", "tones": ["", ""]},
		"the QA choice field: %s" % [game._choice_qa_state(game._runner_current())])
	await _press(game._choice_buttons[0])
	_expect(game._runner.flags.get("question_method") == "hear_first", "choosing still sets its flags and goes on")
	await _free(game)


func _test_pov_choice() -> void:
	var story: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAMPLE))
	var location: Array = _find_choice(story, "choices_open")
	var step: Dictionary = ((story["nodes"][location[0]]["steps"]) as Array)[location[1]]
	step["pov"] = "gintoki"
	(step["options"] as Array)[1].erase("tone")  # a row without a tone between two with one
	_write(MIXED_STORY, story)
	var game: Control = await _new_game(MIXED_STORY)
	await _to_choice(game, "the mixed POV choice")
	var sheet: Control = game._choice_sheet
	var gintoki: Control = game._sprites["gintoki"]
	_expect(game._current_speaker == "gintoki" and game._dialog_panel.speaker_name.text == "銀時・心聲",
		"the thought is the one named by pov: %s" % game._dialog_panel.speaker_name.text)
	_expect(gintoki.visible and gintoki.modulate.r > 0.9 and str(gintoki.get("expression")) == "thinking",
		"that character is in focus with the thinking face")
	_expect(not game._sprites["shinpachi"].visible or game._sprites["shinpachi"].modulate.r < 0.9, "Shinpachi is not the one in focus")
	_expect(sheet.get("perspective") == "pov" and sheet.style_id == "cinema" and sheet.get_node("%Prompt").text == "這句要怎麼吐槽才好……？",
		"it is the edition's sheet with the prompt")
	var base: StyleBoxFlat = ((load("res://scenes/ui/choice_item_cinema.tscn") as PackedScene).instantiate() as Control).get_theme_stylebox("normal") as StyleBoxFlat
	var rows: Array[Button] = game._choice_buttons
	var tones: Array[String] = ["loud", "", "tired"]
	for index: int in range(3):
		var marker: Label = rows[index].get_node("%Tone") as Label
		var tone: String = tones[index]
		_expect(rows[index].text == POV_LABELS[index] and rows[index].name == "Choice_%d" % index, "row %d is %s, named Choice_%d" % [index, POV_LABELS[index], index])
		if tone.is_empty():
			var scene_index: Control = ((load("res://scenes/ui/choice_item_cinema.tscn") as PackedScene).instantiate() as Control).get_node("%Index") as Control
			var row_index: Control = rows[index].get_node("%Index") as Control
			_expect(not marker.visible and rows[index].get_theme_stylebox("normal") == base
				and is_equal_approx(row_index.offset_left, scene_index.offset_left) and is_equal_approx(row_index.offset_right, scene_index.offset_right),
				"row %d has no tone: no marker and the row is exactly the scene's" % index)
		else:
			var style: StyleBoxFlat = rows[index].get_theme_stylebox("normal") as StyleBoxFlat
			_expect(marker.visible and marker.text == GLYPHS[tone], "row %d shows the marker %s" % [index, GLYPHS[tone]])
			_expect(style != base and style.content_margin_left > base.content_margin_left and is_equal_approx(base.content_margin_left, 141.23077),
				"row %d has a style of its own that starts its label after the marker (%.1f > %.1f)" % [index, style.content_margin_left, base.content_margin_left])
			_expect(marker.get_global_rect().end.x <= rows[index].get_global_rect().position.x + style.content_margin_left * game._panel_scale + 0.5
				and rows[index].get_global_rect().encloses(marker.get_global_rect()),
				"row %d: the marker %s is inside the row %s, before its label (margin %.1f)" % [index, marker.get_global_rect(), rows[index].get_global_rect(), style.content_margin_left])
	_expect(game._font.has_char("！".unicode_at(0)) and game._font.has_char("？".unicode_at(0)) and game._font.has_char("…".unicode_at(0)),
		"the embedded font draws ！ ？ … (no tofu)")
	_expect(game._choice_qa_state(game._runner_current()) == {"perspective": "pov", "pov": "gintoki", "note": "", "sheet": "cinema", "tones": tones},
		"the QA choice field: %s" % [game._choice_qa_state(game._runner_current())])
	var logged: Array = game._history.filter(func(entry: Dictionary) -> bool: return entry.get("text") == "這句要怎麼吐槽才好……？")
	_expect(logged.size() == 1 and logged[0]["speaker"] == "gintoki" and logged[0]["thought"] == true,
		"the prompt is in the log as that character's thought: %s" % [logged])
	await _free(game)


func _test_director_choice() -> void:
	var game: Control = await _new_game()
	await _to_director(game)
	var sheet: Control = game._choice_sheet
	_expect(sheet.get("perspective") == "director" and sheet.scene_file_path == DIRECTOR_SHEET, "the director's own sheet is mounted")
	_expect(sheet.get_node("%Banner").text == "── 導演選擇 ──" and sheet.get_node("%Prompt").text == DIRECTOR_PROMPT
		and sheet.get_node("%Note").text == DIRECTOR_NOTE and sheet.get_node("%Note").visible and sheet.get_node("%Count").text == "三選一",
		"heading, question, footnote and count: %s | %s | %s" % [sheet.get_node("%Banner").text, sheet.get_node("%Prompt").text, sheet.get_node("%Note").text])
	_expect(sheet.visible and not game._dialog_panel.visible, "the sheet stands in for the reading box")
	var rows: Array[Button] = game._choice_buttons
	_expect(rows.size() == 3 and rows.all(func(row: Button) -> bool: return row.get_parent() == sheet.choices), "three cards")
	for index: int in range(3):
		_expect(rows[index].text == DIRECTOR_LABELS[index] and rows[index].name == "Choice_%d" % index
			and (rows[index].get_node("%Index") as Label).text == "SCENE %02d" % (index + 1) and rows[index].get_node_or_null("%Tone") == null,
			"card %d: %s, SCENE %02d, named Choice_%d" % [index, DIRECTOR_LABELS[index], index + 1, index])
	_expect(game._current_speaker == "" and game._dialog_panel.speaker_name.text == "旁白", "nobody speaks: the question is narration (%s)" % game._dialog_panel.speaker_name.text)
	var logged: Array = game._history.filter(func(entry: Dictionary) -> bool: return entry.get("text") == DIRECTOR_PROMPT)
	_expect(logged.size() == 1 and logged[0]["speaker"] == "narrator" and logged[0]["thought"] == false, "the question is in the log as narration, not a thought: %s" % [logged])
	_expect(game._choice_qa_state(game._runner_current()) == {"perspective": "director", "pov": "", "note": DIRECTOR_NOTE, "sheet": "director", "tones": ["", "", ""]},
		"the QA choice field: %s" % [game._choice_qa_state(game._runner_current())])
	# Nobody came on stage or into focus: the stage is as the last line left it.
	var before: Array = game.get_meta("stage_before")
	_expect(_stage(game) == before, "the stage is untouched by the director's choice: %s vs %s" % [_stage(game), before])
	_expect(game._char_layer.get_children().map(func(node: Node) -> String: return str(node.name)) == game.get_meta("order_before"),
		"nobody moved to the front")
	await _until(func() -> bool: return not sheet.is_popping(), "the sheet settles")
	# Hiding the UI (a long press) hides the sheet as well, and showing it brings the same cards back.
	game._set_ui_hidden(true)
	_expect(not sheet.visible and not game._dialog_panel.visible and game._choice_buttons.size() == 3, "hiding the UI hides the director's sheet")
	game._set_ui_hidden(false)
	_expect(sheet.visible and not game._dialog_panel.visible and game._choice_buttons.size() == 3, "showing the UI brings the cards back")
	# A real tap on the card's clapper stick (the top edge) chooses it too.
	var card: Rect2 = rows[0].get_global_rect()
	await _tap(card.position + Vector2(card.size.x * 0.5, 14.0))
	await _until(func() -> bool: return game._screen_mode != "choice", "tapping the stick chooses the card")
	_expect(game._runner.flags.get("ep00_ending") == "debt" and game._runner.node_id == "ending_tose", "that was card 1: the flag and the branch follow")
	await _free(game)

	# A director choice without a note has no footnote.
	var story: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAMPLE))
	var location: Array = _find_choice(story, "choices_director")
	((story["nodes"][location[0]]["steps"]) as Array)[location[1]].erase("note")
	_write(NO_NOTE_STORY, story)
	game = await _new_game(NO_NOTE_STORY)
	await _to_director(game)
	_expect(not game._choice_sheet.get_node("%Note").visible and game._choice_qa_state(game._runner_current())["note"] == "",
		"without a note the footnote is hidden")
	await _press(game._choice_buttons[2])
	await _until(func() -> bool: return game._runner.node_id == "ending_sadaharu", "pressing card 3 goes to its branch")
	_expect(game._runner.flags.get("ep00_ending") == "unknown", "and sets its flag")
	game._set_skip(true)
	await _until(func() -> bool: return game._screen_mode == "end", "the branch ends")
	await _free(game)


func _test_every_edition_and_kind() -> void:
	for style: String in STYLES:
		var game: Control = await _new_game(SAMPLE, style)
		await _to_choice(game, "%s: the POV choice" % style)
		var sheet: Control = game._choice_sheet
		_expect(sheet.get("perspective") == "pov" and sheet.style_id == style and sheet.scene_file_path == "res://scenes/ui/choice_sheet_%s.tscn" % style,
			"%s: the POV choice is in the %s sheet" % [style, style])
		var markers: Array = game._choice_buttons.map(func(row: Button) -> String: return (row.get_node("%Tone") as Label).text if (row.get_node("%Tone") as Label).visible else "")
		_expect(markers == ["！", "？", "…"], "%s: each row shows its tone marker: %s" % [style, markers])
		await _press(game._choice_buttons[0])
		_expect(game._runner.flags.get("reply") == "loud", "%s: choosing the first row sets its flag" % style)
		await _to_choice(game, "%s: the director's choice" % style)
		sheet = game._choice_sheet
		_expect(sheet.get("perspective") == "director" and sheet.scene_file_path == DIRECTOR_SHEET and game._choice_qa_state(game._runner_current())["sheet"] == "director",
			"%s: the director's choice is in the director's sheet, which every edition shares" % style)
		await _until(func() -> bool: return not sheet.is_popping(), "%s: the sheet settles" % style)
		await _press(game._choice_buttons[1])
		await _until(func() -> bool: return game._runner.node_id == "ending_phone", "%s: choosing a card goes to its branch" % style)
		game._set_skip(true)
		await _until(func() -> bool: return game._screen_mode == "end", "%s: the branch ends" % style)
		_expect(game._runner.flags.get("ep00_ending") == "request" and game._runner.flags.get("reply") == "loud", "%s: both flags are set" % style)
		await _free(game)


func _test_switching_edition() -> void:
	var game: Control = await _new_game()
	await _to_director(game)
	var shown: Array[String] = []
	for row: Button in game._choice_buttons:
		shown.append(row.text)
	for style: String in ["ledger", "manga", "cinema", "gintama"]:
		game._effects._se_player.stop()
		game._effects._se_player.stream = null
		game._set_ui_style(style, false)
		await _frames(3)
		var sheet: Control = game._choice_sheet
		var labels: Array[String] = []
		for row: Button in game._choice_buttons:
			labels.append(row.text)
		_expect(sheet.get("perspective") == "director" and sheet.scene_file_path == DIRECTOR_SHEET and game._dialog_panel.style_id == style,
			"after switching to %s the director's choice is still in the director's sheet" % style)
		_expect(labels == shown and sheet.get_node("%Note").text == DIRECTOR_NOTE and sheet.get_node("%Prompt").text == DIRECTOR_PROMPT
			and sheet.visible and not game._dialog_panel.visible and game._choice_buttons.all(func(row: Button) -> bool: return row.get_parent() == sheet.choices),
			"%s: the same question, footnote and cards are on it" % style)
		_expect(not sheet.is_popping() and (sheet.get_node("%Panel") as Control).scale == Vector2.ONE and game._effects._se_player.stream == null,
			"%s: the new sheet is at rest, no new pop and no new clap" % style)
	# With 目錄 open on top, the edition is picked there.
	game._open_menu()
	await _frames(2)
	game._on_ui_style_selected("gintama")
	await _frames(3)
	_expect(game._screen_mode == "menu" and game._ui_style_id == "gintama" and
		preload("res://scripts/ui_styles.gd").load_preference(game.ui_preference_path) == "gintama" and
		game._choice_sheet.get("perspective") == "director" and game._choice_qa_state(game._runner_current())["sheet"] == "director",
		"switching to the paper edition from 目錄 saves it and keeps the director's sheet under it")
	game._close_menu()
	await _frames(2)
	_expect(game._choice_buttons.size() == 3 and game._choice_sheet.visible, "closing 目錄 shows the cards again")
	await _press(game._choice_buttons[0])
	await _until(func() -> bool: return game._runner.node_id == "ending_tose", "and one can still be chosen")
	await _free(game)

	# A POV choice follows the edition too, tones and all.
	game = await _new_game()
	await _to_choice(game, "the POV choice")
	game._set_ui_style("gintama", false)
	await _frames(3)
	var markers: Array = game._choice_buttons.map(func(row: Button) -> String: return (row.get_node("%Tone") as Label).text if (row.get_node("%Tone") as Label).visible else "")
	_expect(game._choice_sheet.style_id == "gintama" and game._choice_sheet.get("perspective") == "pov" and markers == ["！", "？", "…"],
		"the POV choice is rebuilt in the paper sheet with its tones: %s" % [markers])
	await _free(game)


## Which sheet is mounted follows the choice that is up: the director's after a POV choice, the edition's
## again after it, and the edition's for a timed tsukkomi.
func _test_sheet_follows_the_choice() -> void:
	var phase3: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PHASE3_STORY))
	var nodes: Dictionary = (phase3["nodes"] as Dictionary).duplicate(true)
	nodes["d1"] = {"title": "d1", "steps": [_choice_step("director", "第一個導演選擇", ["gintoki_round", "gintoki_round"])]}
	nodes["p1"] = {"title": "p1", "steps": [_choice_step("pov", "接著是想法", ["d2", "d2"])]}
	nodes["d2"] = {"title": "d2", "steps": [_choice_step("director", "第二個導演選擇", ["gintoki_round", "gintoki_round"])]}
	((nodes["d1"]["steps"] as Array)[0]["options"] as Array)[0]["next"] = "p1"
	((nodes["d1"]["steps"] as Array)[0]["options"] as Array)[1]["next"] = "p1"
	var story: Dictionary = {"id": "choices_chain_check", "version": "t1", "title": "check", "entry": "d1", "initial_flags": phase3["initial_flags"], "nodes": nodes}
	_write(CHAIN_STORY, story)
	_expect(bool(_load_story(story).get("_loaded")), "the chain story loads")
	var game: Control = await _new_game(CHAIN_STORY, "ledger")
	await _to_choice(game, "the first director choice")
	_expect(game._choice_sheet.get("perspective") == "director", "d1 is a director choice")
	await _press(game._choice_buttons[0])
	await _until(func() -> bool: return game._screen_mode == "choice" and game._runner.node_id == "p1", "the POV choice follows")
	await _frames(2)
	_expect(game._choice_sheet.get("perspective") == "pov" and game._choice_sheet.style_id == "ledger" and game._choice_sheet.scene_file_path.ends_with("choice_sheet_ledger.tscn"),
		"after a director choice the next POV choice is back in the ledger sheet")
	await _press(game._choice_buttons[1])
	await _until(func() -> bool: return game._screen_mode == "choice" and game._runner.node_id == "d2", "the second director choice follows")
	await _until(func() -> bool: return not game._choice_sheet.is_popping(), "it settles")
	_expect(game._choice_sheet.get("perspective") == "director" and game._choice_sheet.scene_file_path == DIRECTOR_SHEET, "and takes the director's sheet again")
	await _press(game._choice_buttons[0])
	await _until(func() -> bool: return game._screen_mode == "boke_round", "the timed round starts")
	_expect(game._choice_buttons.is_empty() and not game._choice_sheet.visible and game._dialog_panel.visible, "the round reads in the reading box first")
	game._on_boke_tsukkomi_pressed()
	await _until(func() -> bool: return game._screen_mode == "tsukkomi", "the options come up")
	await _frames(2)
	var sheet: Control = game._choice_sheet
	_expect(sheet.get("perspective") == "pov" and sheet.style_id == "ledger" and sheet.scene_file_path.ends_with("choice_sheet_ledger.tscn") and sheet.timer_row.visible
		and game._choice_buttons.size() > 0 and game._choice_qa_state(game._runner_current()).is_empty(),
		"a timed tsukkomi after a director choice is in the edition's sheet with its countdown")
	await _free(game)


func _test_saves() -> void:
	var game: Control = await _new_game(SAMPLE, "manga")
	await _to_director(game)
	_expect(game._save_game(), "the director's choice is saved")
	var payload: Dictionary = game._build_save_payload("")
	await _free(game)

	game = await _new_game(SAMPLE, "manga")
	game._on_continue_pressed()
	await _frames(4)
	_expect(_is_director_choice(game), "継 from the save lands on the director's choice, in the director's sheet: %s" % game._screen_mode)
	await _free(game)

	game = await _new_game(SAMPLE, "ledger")
	_expect(game._validate_save_payload(payload), "the slot payload is valid")
	game._load_payload_from_picker(payload, "已讀取")
	await _frames(4)
	_expect(_is_director_choice(game), "loading it into another edition restores the same director choice")
	await _until(func() -> bool: return not game._choice_sheet.is_popping(), "it settles")
	await _free(game)


func _is_director_choice(game: Control) -> bool:
	var sheet: Control = game._choice_sheet
	var labels: Array[String] = []
	for row: Button in game._choice_buttons:
		labels.append(row.text)
	return game._screen_mode == "choice" and sheet.get("perspective") == "director" and sheet.scene_file_path == DIRECTOR_SHEET \
		and sheet.get_node("%Note").text == DIRECTOR_NOTE and sheet.get_node("%Prompt").text == DIRECTOR_PROMPT and labels == DIRECTOR_LABELS \
		and game._choice_qa_state(game._runner_current()) == {"perspective": "director", "pov": "", "note": DIRECTOR_NOTE, "sheet": "director", "tones": ["", "", ""]}


func _test_pop_in() -> void:
	var game: Control = await _new_game()
	await _to_director_and_watch(game)
	var sheet: Control = game._choice_sheet
	var panel: Control = sheet.get_node("%Panel") as Control
	_expect(game.get_meta("popped") and float(game.get_meta("pop_seconds")) <= 0.35,
		"the panel springs in and is done within 0.25 s (+ a frame or two): %s s" % game.get_meta("pop_seconds"))
	_expect(float(game.get_meta("pop_min_scale")) < 0.95 and float(game.get_meta("pop_min_alpha")) < 0.5, "it starts small and see-through (%s, %s)" % [game.get_meta("pop_min_scale"), game.get_meta("pop_min_alpha")])
	_expect(game.get_meta("sheet_scale_held"), "the sheet's own scale (for narrow phones) was not touched by the animation")
	_expect(panel.scale == Vector2.ONE and is_equal_approx(panel.modulate.a, 1.0) and not sheet.is_popping(), "afterwards it is at rest")
	await _free(game)


func _to_director_and_watch(game: Control) -> void:
	game._on_begin_pressed()
	await _until(func() -> bool: return game._screen_mode == "story", "story starts")
	game._set_skip(true)
	await _until(func() -> bool: return game._screen_mode == "choice", "the POV choice")
	game._on_choice_pressed("reply_loud")
	game._set_skip(true)
	var started: Array[int] = [0]
	var seen_min_scale: Array[float] = [1.0]
	var seen_min_alpha: Array[float] = [1.0]
	var scale_held: Array[bool] = [true]
	var expected_scale: Vector2 = Vector2.ONE * game._panel_scale
	await _until(func() -> bool:
		if game._screen_mode == "choice" and game._choice_sheet.get("perspective") == "director" and started[0] == 0:
			started[0] = Time.get_ticks_msec()
		return started[0] != 0, "the director's choice comes up")
	var panel: Control = game._choice_sheet.get_node("%Panel") as Control
	while game._choice_sheet.is_popping() and Time.get_ticks_msec() - started[0] < 3000:
		seen_min_scale[0] = minf(seen_min_scale[0], panel.scale.x)
		seen_min_alpha[0] = minf(seen_min_alpha[0], panel.modulate.a)
		scale_held[0] = scale_held[0] and game._choice_sheet.scale.is_equal_approx(expected_scale)
		await process_frame
	game.set_meta("popped", not game._choice_sheet.is_popping())
	game.set_meta("pop_seconds", float(Time.get_ticks_msec() - started[0]) / 1000.0)
	game.set_meta("pop_min_scale", seen_min_scale[0])
	game.set_meta("pop_min_alpha", seen_min_alpha[0])
	game.set_meta("sheet_scale_held", scale_held[0])
	await _frames(2)


func _test_sound() -> void:
	var game: Control = await _new_game()
	game._effects._se_player.stream = null
	await _to_choice(game, "the POV choice")
	_expect(game._effects._se_player.stream == null, "a POV choice makes no clap")
	await _to_director(game)
	var clap: AudioStream = game._effects.call("_stream", "sounds", "director_clap") as AudioStream
	_expect(clap != null and game._effects._se_player.stream == clap and game._effects._se_player.playing,
		"the director's choice claps (a placeholder sound while the catalog gives it no file)")
	_expect(((game._catalog["sounds"] as Dictionary).has("director_clap")), "director_clap is in the asset catalog's sounds")
	await _free(game)

	game = await _new_game()
	game._toggle_mute()
	_expect(game._audio_muted, "the game is muted")
	game._effects._se_player.stream = null
	await _to_director(game)
	_expect(game._effects._se_player.stream == null and not game._effects._se_player.playing, "while muted the director's choice plays nothing")
	await _free(game)


func _test_narrow_phones() -> void:
	var original: Vector2i = root.size
	# Six options each, for the director's sheet to scroll; the POV choice has tones on all of them.
	_write(MANY_STORY, _many_options_story())
	for phone: Vector2i in [Vector2i(390, 844), Vector2i(320, 568)]:
		root.size = phone
		await _frames(3)
		# The POV sheet is each edition's own (the manga one has the least room: the slash at the right and the marker
		# at the left); the director's is the same in all of them, so it is measured once.
		for kind: String in ["pov", "director"]:
			for style: String in (STYLES if kind == "pov" else ["cinema"]):
				for count: int in [3, 6]:
					var game: Control = await _game_with_choice(kind, count, phone.x, style)
					await _until(func() -> bool: return not game._choice_sheet.is_popping(), "the sheet settles")
					await _frames(3)
					await _check_layout(game, phone.x, "%d px / %s / %s / %d options" % [phone.x, style, kind, count], kind, count)
					await _free(game)
	root.size = original
	await _frames(2)


func _game_with_choice(kind: String, count: int, width: int, style: String) -> Control:
	var label: String = "%d px, %s, %s, %d options" % [width, style, kind, count]
	var game: Control
	if count == 3:
		game = await _new_game(SAMPLE, style)
		if kind == "pov":
			await _to_choice(game, label)
		else:
			await _to_director(game)
	else:
		game = await _new_game(MANY_STORY, style)
		await _to_choice(game, label)
		if kind == "director":
			game._on_choice_pressed("pov_0")
			game._set_skip(true)
			await _until(func() -> bool: return game._screen_mode == "choice" and game._runner.node_id == "dir", label)
			await _frames(2)
	return game


## Every text of the sheet is whole and inside the game area, every row is at least 48 CSS px tall, whole,
## and (scrolled into view where the list scrolls) inside the game area with its number and marker.
func _check_layout(game: Control, css_width: int, label: String, kind: String, count: int) -> void:
	var area: Rect2 = game._game.get_global_rect()
	var sheet: Control = game._choice_sheet
	var scroll: ScrollContainer = sheet.choices_scroll
	var css: float = 1080.0 / float(css_width)  # logical px of one CSS px
	var scrolling: bool = scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO
	_expect(game._panel_scale > 1.2 if css_width < 390 else game._panel_scale < 1.01, "%s: the panels scale by %.3f" % [label, game._panel_scale])
	_expect(sheet.get("perspective") == kind and game._choice_buttons.size() == count and (kind == "director" or sheet.style_id == game._ui_style_id),
		"%s: the %s sheet with %d rows" % [label, kind, count])
	_expect(area.grow(0.5).encloses(sheet.get_global_rect()), "%s: the sheet is inside the game area: %s in %s" % [label, sheet.get_global_rect(), area])
	if kind == "director" and count == 6 and css_width < 390:
		_expect(scrolling, "%s: six cards do not fit, so the director's sheet scrolls" % label)
	if count == 3:
		_expect(not scrolling, "%s: three rows fit without scrolling" % label)
	for node: Node in _descendants(sheet):
		if not node is Control or not (node as Control).is_visible_in_tree() or sheet.choices.is_ancestor_of(node):
			continue  # the rows are checked one by one below
		var control: Control = node as Control
		var rect: Rect2 = control.get_global_rect()
		if control is Label:
			var text: Label = control as Label
			_expect(text.text.is_empty() or (text.get_line_count() <= text.get_visible_line_count() and area.grow(0.5).encloses(rect)),
				"%s: the text '%s' is whole (%d of %d lines) and inside the game area (%s)" % [label, text.text, text.get_visible_line_count(), text.get_line_count(), rect])
		elif control is Button:
			var button: Button = control as Button
			_expect(area.grow(0.5).encloses(rect) and button.get_combined_minimum_size().x <= button.size.x + 0.5 and button.get_combined_minimum_size().y <= button.size.y + 0.5
				and rect.size.y / css >= 48.0 - 0.05,
				"%s: '%s' is whole, inside the game area and at least 48 CSS px tall (%.1f)" % [label, button.text, rect.size.y / css])
	for row: Button in game._choice_buttons:
		if scrolling:
			scroll.ensure_control_visible(row)
			await _frames(2)
		var rect: Rect2 = row.get_global_rect()
		var window: Rect2 = scroll.get_global_rect() if scrolling else area
		_expect(window.grow(2.0).encloses(rect) and area.grow(0.5).encloses(rect),  # a scroll position is a whole pixel of the unscaled sheet
			"%s: the card '%s' is inside its window %s (%s)" % [label, row.text, window, rect])
		_expect(rect.size.y / css >= 48.0 - 0.05 and row.get_combined_minimum_size().y <= row.size.y + 0.5 and row.get_combined_minimum_size().x <= row.size.x + 0.5,
			"%s: the card '%s' is whole and at least 48 CSS px tall (%.1f)" % [label, row.text, rect.size.y / css])
		var parts: Array[Control] = [row.get_node("%Index") as Control]
		if row.get_node_or_null("%Tone") != null and (row.get_node("%Tone") as Control).visible:
			parts.append(row.get_node("%Tone") as Control)
		for part: Control in parts:
			_expect(rect.grow(0.5).encloses(part.get_global_rect()), "%s: %s of '%s' is inside the card" % [label, part.name, row.text])
		var label_width: float = row.size.x - (row.get_theme_stylebox("normal") as StyleBoxFlat).get_minimum_size().x
		_expect(label_width > 0.0 and row.get_combined_minimum_size().x <= row.size.x + 0.5, "%s: the card's text has room (%.0f px)" % [label, label_width])
	if scrolling:
		scroll.scroll_vertical = 0


# ---------------------------------------------------------------- helpers

func _new_game(story: String = SAMPLE, style: String = "cinema") -> Control:
	var game: Control = MAIN_SCENE.instantiate() as Control
	game.story_path = story
	game.save_path = TEST_SAVE
	game.ui_preference_path = TEST_UI
	game.settings_path = TEST_SETTINGS
	root.add_child(game)
	await _frames(3)
	_expect(game._story_ready, "the story loads: %s" % game._story_error)
	if style != game._ui_style_id:
		game._set_ui_style(style, false)
		await _frames(2)
	return game


func _free(game: Control) -> void:
	game.queue_free()
	await _frames(2)


## Skips from the start (or from where it is) to the next choice.
func _to_choice(game: Control, label: String) -> void:
	if game._screen_mode == "title":
		game._on_begin_pressed()
		await _until(func() -> bool: return game._screen_mode == "story" or game._screen_mode == "choice", "%s: the story starts" % label)
	game._set_skip(true)
	await _until(func() -> bool: return game._screen_mode == "choice", "%s: a choice shows" % label, 8.0)
	await _frames(2)


## The sample's first (POV) choice answered with the loud row, then on to the director's choice. The stage
## as the line before it left it is kept in the game's meta, for comparing with the stage after.
func _to_director(game: Control) -> void:
	await _to_choice(game, "the POV choice")
	game._on_choice_pressed("reply_loud")
	game._set_skip(true)
	await _until(func() -> bool: return game._screen_mode == "story" and game._full_text == "阿銀，接下來要演什麼阿魯？", "the line before the director's choice", 8.0)
	game._set_skip(false)
	await _until(func() -> bool: return game._text_complete, "that line is typed out")
	game.set_meta("stage_before", _stage(game))
	game.set_meta("order_before", game._char_layer.get_children().map(func(node: Node) -> String: return str(node.name)))
	game._advance_current_line()
	await _until(func() -> bool: return game._screen_mode == "choice", "the director's choice shows")
	await _frames(2)


## Who is on stage, how lit, with which face.
func _stage(game: Control) -> Array:
	var state: Array = []
	for actor_id: String in game._sprites.keys():
		var sprite: Control = game._sprites[actor_id]
		state.append([actor_id, sprite.visible, sprite.modulate, str(sprite.get("expression")), game._actor_slots.get(actor_id)])
	state.sort()
	return state


func _find_choice(story: Dictionary, node_id: String) -> Array:
	var steps: Array = story["nodes"][node_id]["steps"]
	for index: int in range(steps.size()):
		if steps[index]["op"] == "choice":
			return [node_id, index]
	return []


func _load_story(story: Dictionary) -> RefCounted:
	_write(BAD_STORY, story)
	var runner: RefCounted = StoryRunner.new()
	runner.call("load_story", BAD_STORY)
	return runner


func _write(path: String, story: Dictionary) -> void:
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(story))


func _choice_step(perspective: String, prompt: String, targets: Array) -> Dictionary:
	var options: Array = []
	for index: int in range(targets.size()):
		var option: Dictionary = {"id": "o%d" % index, "label": "選項 %d" % (index + 1), "next": targets[index]}
		if perspective == "pov":
			option["tone"] = ["loud", "calm", "tired"][index % 3]
		options.append(option)
	var step: Dictionary = {"op": "choice", "prompt": prompt, "options": options}
	if perspective == "director":
		step["perspective"] = "director"
		step["note"] = "※這是第 %d 次" % (targets.size())
	return step


## A POV choice with six toned rows, then a director choice with six cards, then the end.
func _many_options_story() -> Dictionary:
	var pov_options: Array = []
	var director_options: Array = []
	for index: int in range(6):
		pov_options.append({"id": "pov_%d" % index, "label": "第 %d 句：這是一句比較長的回應，用來確認窄螢幕上文字不會被裁掉" % (index + 1), "next": "dir", "tone": ["loud", "calm", "tired"][index % 3]})
		director_options.append({"id": "dir_%d" % index, "label": "第 %d 個發展：突然發生了一件需要換行的事情" % (index + 1), "next": "finish"})
	return {"id": "choices_many_check", "version": "t1", "title": "check", "entry": "pov", "initial_flags": {}, "nodes": {
		"pov": {"title": "pov", "steps": [{"op": "choice", "prompt": "這句要怎麼吐槽才好，這是一個比較長的提問用來測試換行……？", "options": pov_options}]},
		"dir": {"title": "dir", "steps": [{"op": "choice", "perspective": "director", "note": "※製作組經費有限，這一行註腳也要完整顯示不被裁掉",
			"prompt": "接下來發生什麼？這是一個比較長的提問用來測試換行", "options": director_options}]},
		"finish": {"title": "finish", "steps": [{"op": "end", "text": "結束"}]}}}


func _descendants(node: Node) -> Array[Node]:
	var nodes: Array[Node] = [node]
	for child: Node in node.get_children():
		nodes.append_array(_descendants(child))
	return nodes


func _cleanup() -> void:
	for path: String in [TEST_SAVE, TEST_SAVE + ".bak", TEST_SAVE + ".old", TEST_SAVE + ".tmp", TEST_SAVE + ".bak.tmp", TEST_UI, TEST_SETTINGS,
			BAD_STORY, MIXED_STORY, NO_NOTE_STORY, MANY_STORY, CHAIN_STORY]:
		var absolute: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute):
			DirAccess.remove_absolute(absolute)
