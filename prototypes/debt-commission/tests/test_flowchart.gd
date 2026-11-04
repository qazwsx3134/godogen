extends "res://addons/proto_kit/test_kit.gd"
## 流程圖: stories fold into scene boxes (flow_graph.gd), the runner reports the nodes it passes,
## progress.cfg keeps them, and the panel from 章節選擇 shows reached boxes and ？？？ for the rest.

const FlowGraph = preload("res://scripts/flow_graph.gd")
const StoryRunner = preload("res://scripts/story_runner.gd")
const StoryLibrary = preload("res://scripts/story_library.gd")
const PATHS: Array[String] = ["user://flowchart_test.save", "user://flowchart_test.cfg", "user://flowchart_test_progress.cfg"]


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_clean()
	_test_boxes()
	_test_runner_visits()
	_test_library()
	await _test_panel()
	_clean()
	_finish("FLOWCHART")


func _story(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary


func _test_boxes() -> void:
	var chapter: Dictionary = _story("res://data/chapter1_story.json")
	var boxes: Array[Dictionary] = FlowGraph.boxes(chapter)
	_expect(boxes.size() >= 6 and boxes.size() <= 20, "chapter 1 folds its %d nodes into a readable chart (%d boxes)" % [(chapter["nodes"] as Dictionary).size(), boxes.size()])
	_expect(boxes[0]["id"] == chapter["entry"] and int(boxes[0]["column"]) == 0, "the entry is the first box, in column 0")
	var ending_titles: Array = boxes.filter(func(box: Dictionary) -> bool: return not str(box["ending"]).is_empty()).map(
		func(box: Dictionary) -> String: return str(box["ending"]))
	var expected: Array = StoryRunner.endings_of(chapter).map(func(ending: Dictionary) -> String: return str(ending["title"]))
	ending_titles.sort()
	expected.sort()
	_expect(ending_titles == expected, "the ending boxes carry the 結局收集 titles: %s" % [ending_titles])
	var folded: Array = []
	for box: Dictionary in boxes:
		folded.append_array(box["nodes"])
	_expect(not folded.has("ch1_game_over") and not folded.has("ch1_r1_retry"), "Game Over and retries are not routes of their own")
	var by_id: Dictionary = {}
	for box: Dictionary in boxes:
		by_id[box["id"]] = box
	var forward: bool = true
	for box: Dictionary in boxes:
		for target: String in box["to"]:
			forward = forward and by_id.has(target)
	_expect(forward, "every line leads to a box on the chart")
	var episode: Array[Dictionary] = FlowGraph.boxes(_story("res://data/ep00_story.json"))
	var branch: Array = episode.filter(func(box: Dictionary) -> bool: return (box["to"] as Array).size() == 3)
	_expect(branch.size() == 2, "EP00's POV choice and director choice each open three routes")
	_expect(FlowGraph.boxes({}).is_empty(), "an empty story draws nothing")
	var looped: Array[Dictionary] = FlowGraph.boxes({"entry": "a", "nodes": {
		"a": {"steps": [{"op": "say", "text": "x"}], "next": "b"},
		"b": {"steps": [{"op": "choice", "options": [{"id": "1", "next": "a"}, {"id": "2", "next": "c"}]}]},
		"c": {"steps": [{"op": "end", "text": "終"}]}}})
	_expect(looped.size() == 2 and looped[0]["nodes"] == ["a", "b"] and int(looped[0]["column"]) == 0
		and (looped[0]["to"] as Array).has("a") and int(looped[1]["column"]) == 1,
		"a straight run is one box; a choice looping back keeps the entry in column 0")


func _test_runner_visits() -> void:
	var runner: RefCounted = StoryRunner.new()
	_expect(bool(runner.call("load_story", "res://data/debt_story.json")), "the debt sample loads")
	var first: Array[String] = runner.call("take_visits")
	_expect(first.has(str(_story("res://data/debt_story.json")["entry"])), "loading reports the entry node: %s" % [first])
	_expect((runner.call("take_visits") as Array).is_empty(), "a node is reported once")


func _test_library() -> void:
	var library: RefCounted = StoryLibrary.new("res://data/stories.json", PATHS[2])
	_expect((library.call("visited", "debt") as Array).is_empty(), "nothing is visited in a fresh progress file")
	var nodes: Array[String] = ["a", "b"]
	library.call("record_visits", "debt", nodes)
	var again: Array[String] = ["b", "c"]
	library.call("record_visits", "debt", again)
	_expect(library.call("visited", "debt") == ["a", "b", "c"], "visits merge in order without repeats")
	_expect((library.call("visited", "chapter1") as Array).is_empty(), "each story keeps its own visits")
	# Every story the player can pick, packs included: each `ending` 結局收集 counts sits in a box.
	var missing: Array[String] = []
	for entry: Dictionary in library.get("stories"):
		var story: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(entry["path"])))
		if not story is Dictionary:
			continue
		var charted: Dictionary = {}
		for box: Dictionary in FlowGraph.boxes(story):
			for node_id: String in box["nodes"]:
				charted[node_id] = true
		for node_id: String in (story["nodes"] as Dictionary).keys():
			for step: Variant in story["nodes"][node_id].get("steps", []):
				if step is Dictionary and not str((step as Dictionary).get("ending", "")).is_empty() and not charted.has(node_id):
					missing.append("%s/%s" % [entry["id"], node_id])
	_expect(missing.is_empty() and library.get("stories").size() > 10, "every story's endings are on its chart: %s" % [missing])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATHS[2]))


func _test_panel() -> void:
	var game: Control = (load("res://main.tscn") as PackedScene).instantiate()
	game.story_path = "res://data/ep00_story.json"
	game.save_path = PATHS[0]
	game.settings_path = PATHS[1]
	game.progress_path = PATHS[2]
	game.tutorials_enabled = false
	root.add_child(game)
	await _frames(3)
	game._open_chapter_select()
	await _frames(2)
	await _press(game._chapter_select.get_node("%Flowchart"))
	await _frames(2)
	var panel: Control = game._flowchart
	_expect(game._screen_mode == "flowchart" and panel.visible, "流程圖 opens from 章節選擇")
	_expect(str(panel.get_node("%StoryName").text) == game._story_title(game._story_choices[game._story_choice_index()]),
		"it starts at the current story")
	var shown: Dictionary = panel.call("shown")
	_expect(not shown.is_empty() and shown.values().all(func(text: String) -> bool: return text == "？？？"), "nothing reached yet: every box is ？？？")
	_expect(str(panel.get_node("%Progress").text).begins_with("已走過 0/"), "the progress line counts none")
	await _press(panel.get_node("%Close"))
	_expect(game._screen_mode == "chapter_select" and not panel.visible, "× goes back to 章節選擇")
	game._close_chapter_select()
	await _frames(2)

	game._on_begin_pressed()
	await _until(func() -> bool: return game._screen_mode == "story", "the story starts")
	var entry: String = str(_story("res://data/ep00_story.json")["entry"])
	_expect((game._library.visited(game._progress_id()) as Array).has(entry), "playing records the entry in progress.cfg")
	game._show_title()
	await _frames(2)
	game._open_chapter_select()
	await _frames(2)
	game._open_flowchart()
	await _frames(2)
	shown = panel.call("shown")
	_expect(shown.get(entry, "") != "？？？" and not str(shown.get(entry, "")).is_empty(), "the reached box shows its title: %s" % shown.get(entry, ""))
	_expect(shown.values().count("？？？") == shown.size() - 1, "the boxes ahead stay ？？？")
	var first_story: String = str(panel.get_node("%StoryName").text)
	await _press(panel.get_node("%Next"))
	_expect(str(panel.get_node("%StoryName").text) != first_story, "› shows another story")
	game._unhandled_input(_cancel())
	_expect(game._screen_mode == "chapter_select", "the back key closes 流程圖")
	game.queue_free()
	await _frames(2)


func _cancel() -> InputEventAction:
	var event: InputEventAction = InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	return event


func _clean() -> void:
	for path: String in PATHS:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
