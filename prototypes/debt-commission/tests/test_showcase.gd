extends "res://addons/proto_kit/test_kit.gd"
## 功能展示 (data/showcase_story.json): the shipped list is the showcase (landscape and its portrait entry) plus the dog-ears work; every
## branch of the showcase plays to its end in the runner, and the presentation branches (畫面、角色)
## play in the actual reading shell without engine errors.

const STORY: String = "res://data/showcase_story.json"
const RUNNER = preload("res://scripts/story_runner.gd")
var game: Control
var _tried: Array = []  # talk topics and places already played by _play


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
		# 進階: talk and move topics, a testimony round (censor bar, placard), a combo round with its QTE, a director choice.
		[["advanced", "phone_rings", "back", "finish"], ["adv_talk_sleep", "adv_fridge", "adv_inspect_mouth", "adv_t2_censor",
			"adv_t3_placard", "adv_c_hit", "adv_qte_perfect", "adv_combo_clear", "adv_director", "adv_director_done"]],
		# The director's third card ends the tour on a graded result card.
		[["advanced", "wrap_up"], ["adv_director", "adv_result"]],
	]
	for case: Array in cases:
		var runner: RefCounted = RUNNER.new()
		_expect(runner.call("load_story", STORY), "the showcase loads")
		var visited: Array = _play(runner, (case[0] as Array).duplicate())
		for node: String in case[1]:
			_expect(visited.has(node), "%s passes %s: %s" % [case[0], node, visited])
		var last: String = "adv_result" if case[0].has("wrap_up") else "finish"
		_expect(str(runner.call("current").get("op")) in ["end", "result"] and runner.get("node_id") == last, "%s ends at %s" % [case[0], last])
	# Five cold retorts break every pair of glasses: Game Over ends at its own card, and 重試 restarts the round.
	var over: RefCounted = RUNNER.new()
	over.call("load_story", STORY)
	var visited: Array = _play(over, ["play", "gin", "blank", "blank", "blank", "blank", "blank"])
	_expect(visited.back() == "play_round_over" and str(over.call("current").get("op")) == "end", "the fifth cold retort is Game Over: %s" % [visited])
	_expect(over.call("retry_checkpoint") and str(over.call("current").get("op")) == "boke_round", "重試 goes back to the round")
	_play(over, ["bottle", "back", "finish"])
	_expect(over.get("node_id") == "finish", "after the retry the round can be won and the tour finished")


## Plays one talk topic, or the spots of one other place, not tried yet; false when none is left.
func _topic_left(runner: RefCounted, command: Dictionary) -> bool:
	for topic: Dictionary in command.get("talk", []):
		if not _tried.has(topic["id"]):
			_tried.append(topic["id"])
			return runner.call("talk_topic", str(topic["id"]))
	for place: Dictionary in command.get("moves", []):
		if not _tried.has(place["id"]):
			_tried.append(place["id"])
			if not runner.call("move_to", str(place["id"])):
				return false
			for spot: Dictionary in (runner.call("current") as Dictionary).get("hotspots", []):
				runner.call("inspect_hotspot", str(spot["id"]))
				return true
	return false


## The next catch in a testimony or combo round, played as a player who knows the answers.
func _catch_line(runner: RefCounted, command: Dictionary) -> bool:
	var lines: Array = command.get("lines", []) as Array
	if str(command["mode"]) == "testimony":
		for i: int in lines.size():
			if not (command.get("caught_line_ids", []) as Array).has(lines[i]["id"]) and lines[i].has("slot"):
				runner.call("set_boke_line", i)
				break
		command = runner.call("current")
	var line: Dictionary = command.get("current_line", {}) as Dictionary
	if not (line.get("qte", {}) as Dictionary).is_empty():
		return not (runner.call("resolve_qte", true, 0.0) as Dictionary).is_empty()
	if not (line.get("censor", {}) as Dictionary).is_empty():
		return not (runner.call("resolve_censor") as Dictionary).is_empty()
	if not (line.get("placard", {}) as Dictionary).is_empty():
		return not (runner.call("resolve_placard") as Dictionary).is_empty()
	var slot: Dictionary = (lines[int(command.get("line_index", 0))] as Dictionary).get("slot", {}) as Dictionary
	for option: Dictionary in slot.get("options", []):
		if option["result"] == "perfect":
			return not (runner.call("resolve_boke", str(option["id"])) as Dictionary).is_empty()
	return false


## Plays the runner: each choice and tsukkomi takes the next planned id; investigations inspect every hotspot.
func _play(runner: RefCounted, plan: Array) -> Array:
	_tried.clear()
	var visited: Array = []
	for _i: int in range(400):
		var node: String = str(runner.get("node_id"))
		if visited.is_empty() or visited.back() != node:
			visited.append(node)
		var command: Dictionary = runner.call("current")
		match str(command.get("op")):
			"end", "result":
				return visited
			"choice":
				_expect(not plan.is_empty() and runner.call("choose", plan.pop_front()), "choice at %s" % node)
			"boke_round" when command.has("mode"):
				_expect(_catch_line(runner, command), "a %s round moves on at %s" % [command["mode"], node])
			"boke_round":
				_expect(not plan.is_empty() and not (runner.call("resolve_boke", plan.pop_front()) as Dictionary).is_empty(), "tsukkomi at %s" % node)
			"investigate" when _topic_left(runner, command):
				pass  # a talk topic or a move played; its reaction comes back here
			"investigate":
				for spot: Dictionary in command.get("hotspots", []):
					if spot.has("character") and not (runner.get("cast") as Array).has(spot["character"]):
						(runner.get("cast") as Array).append(spot["character"])  # the shell keeps the cast in sync
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
	_expect(ids.has("showcase") and ids.has("showcase_portrait") and ids.has("katsura_dog_ears") and leaked.is_empty(),
		"the shipped list has the showcase (both screens) and the dog-ears work, no test fixture: %s" % [ids])
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
