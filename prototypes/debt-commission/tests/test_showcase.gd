extends "res://addons/proto_kit/test_kit.gd"
## 功能展示 (data/showcase_story.json): the shipped list is the showcase plus the dog-ears work; every
## branch of the showcase plays to its end in the runner, and the presentation branches (畫面、角色)
## play in the actual reading shell without engine errors.

const STORY: String = "res://data/showcase_story.json"
const RUNNER = preload("res://scripts/story_runner.gd")
var game: Control


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	_test_branches()
	await _test_shell()
	_finish("SHOWCASE")


func _test_branches() -> void:
	var cases: Array = [
		[["screen", "back", "finish"], ["screen_transitions", "screen_effects", "finish"]],
		[["cast", "back", "finish"], ["cast_portraits", "cast_text", "finish"]],
		[["play", "gin", "bottle", "back", "finish"], ["play_suspect_gin", "play_investigate", "play_round_done"]],
		[["play", "kagura", "blank", "fridge", "back", "finish"], ["play_suspect_other", "play_round_retry", "play_round_done"]],
		# 再看一次: the same investigation and round play again the second time.
		[["play", "gin", "bottle", "again", "kagura", "fridge", "back", "finish"], ["play_suspect_gin", "play_suspect_other", "play_round_done"]],
	]
	for case: Array in cases:
		var runner: RefCounted = RUNNER.new()
		_expect(runner.call("load_story", STORY), "the showcase loads")
		var visited: Array = _play(runner, (case[0] as Array).duplicate())
		for node: String in case[1]:
			_expect(visited.has(node), "%s passes %s: %s" % [case[0], node, visited])
		_expect(str(runner.call("current").get("op")) == "end" and runner.get("node_id") == "finish", "%s ends at 結局" % [case[0]])
	# Five cold retorts break every pair of glasses: Game Over ends at its own card, and 重試 restarts the round.
	var over: RefCounted = RUNNER.new()
	over.call("load_story", STORY)
	var visited: Array = _play(over, ["play", "gin", "blank", "blank", "blank", "blank", "blank"])
	_expect(visited.back() == "play_round_over" and str(over.call("current").get("op")) == "end", "the fifth cold retort is Game Over: %s" % [visited])
	_expect(over.call("retry_checkpoint") and str(over.call("current").get("op")) == "boke_round", "重試 goes back to the round")
	_play(over, ["bottle", "back", "finish"])
	_expect(over.get("node_id") == "finish", "after the retry the round can be won and the tour finished")


## Plays the runner: each choice and tsukkomi takes the next planned id; investigations inspect every hotspot.
func _play(runner: RefCounted, plan: Array) -> Array:
	var visited: Array = []
	for _i: int in range(400):
		var node: String = str(runner.get("node_id"))
		if visited.is_empty() or visited.back() != node:
			visited.append(node)
		var command: Dictionary = runner.call("current")
		match str(command.get("op")):
			"end":
				return visited
			"choice":
				_expect(not plan.is_empty() and runner.call("choose", plan.pop_front()), "choice at %s" % node)
			"boke_round":
				_expect(not plan.is_empty() and not (runner.call("resolve_boke", plan.pop_front()) as Dictionary).is_empty(), "tsukkomi at %s" % node)
			"investigate":
				for spot: Dictionary in command.get("hotspots", []):
					runner.call("inspect_hotspot", str(spot["id"]))
				runner.call("advance")
			_:
				runner.call("advance")
	_expect(false, "the plan reaches an end: %s" % [visited])
	return visited


func _test_shell() -> void:
	game = (load("res://main.tscn") as PackedScene).instantiate() as Control
	game.save_path = "user://showcase-test.save"
	game.settings_path = "user://showcase-test-settings.cfg"
	game.progress_path = "user://showcase-test-progress.cfg"
	game.tutorials_enabled = false
	root.add_child(game)
	await _frames(3)
	var ids: Array = game._story_choices.map(func(choice: Dictionary) -> String: return str(choice["id"]))
	var fixtures: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/stories.json"))
	var leaked: Array = (fixtures["stories"] as Array).filter(func(entry: Dictionary) -> bool: return ids.has(entry["id"]))
	_expect(ids.has("showcase") and ids.has("katsura_dog_ears") and leaked.is_empty(),
		"the shipped list has the showcase and the dog-ears work, no test fixture: %s" % [ids])
	_expect(game.story_path == STORY and game._story_ready, "the showcase is the default story")
	game._on_begin_pressed()
	for option: String in ["screen", "back", "cast", "back"]:
		await _read_until(func() -> bool: return game._screen_mode == "choice", "choice before %s" % option)
		game._on_choice_pressed(option)
	await _read_until(func() -> bool: return game._screen_mode == "choice" and game._runner.node_id == "menu", "back at the menu")
	game.queue_free()
	await _frames(2)
	for path: String in ["user://showcase-test.save", "user://showcase-test-settings.cfg", "user://showcase-test-progress.cfg"]:
		for suffix: String in ["", ".bak"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))


func _read_until(done: Callable, label: String) -> void:
	var deadline: int = Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		if done.call():
			return
		if game._screen_mode == "story":
			if game._story_busy:
				game._on_screen_tap()
			elif game._text_complete:
				game._advance_current_line()
			else:
				game._complete_current_line()
		await _frames(1)
	_expect(false, "timed out before %s" % label)
