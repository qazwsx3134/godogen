extends "res://addons/proto_kit/test_kit.gd"
## v2 Interaction Mode on investigations (tests/fixtures/interaction_story.json): `keep_cast` keeps the
## cast on stage; a hotspot with `character` covers that portrait and only exists while they are on stage;
## `lines` play by tap count on every tap; `set` writes flags on the first look; tap counts survive saves
## (old saves have none) and a round's checkpoint; the data errors name node and step.

const StoryRunner = preload("res://scripts/story_runner.gd")
const StoryBuilder = preload("res://tools/story_build/story_builder.gd")
const MAIN_SCENE: PackedScene = preload("res://main.tscn")
const STORY: String = "res://tests/fixtures/interaction_story.json"
const PHASE4: String = "res://data/phase4_story.json"
const BROKEN: String = "user://interaction_broken.json"
const TEST_SAVE: String = "user://interaction_ui_test.save"
const TEST_UI: String = "user://interaction_ui_test.cfg"
const GIN_TEXTS: Array[String] = ["幹嘛？", "別一直戳。", "說了別戳啊。", "說了別戳啊。"]


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_cleanup()
	_test_lines_play_by_tap_count()
	_test_off_stage_character_spots()
	_test_set_flags_and_condition()
	_test_saves_keep_tap_counts()
	_test_checkpoint_keeps_tap_counts()
	_test_validation_errors()
	_test_builder_follows_lines()
	await _test_shell()
	_cleanup()
	_finish("INTERACTION TESTS")


# ---------------------------------------------------------------- runner

func _test_lines_play_by_tap_count() -> void:
	var runner: RefCounted = _at_room(["gintoki"])
	var room: Dictionary = runner.call("current")
	_expect(room["keep_cast"] and _ids(room["hotspots"]) == ["gin", "kagura", "milk", "job"], "the room keeps the cast and lists four spots")
	for tap: int in range(GIN_TEXTS.size()):
		var node: String = ["gin_1", "gin_2", "gin_3", "gin_3"][tap]
		_expect(runner.call("inspect_hotspot", "gin") and runner.get("node_id") == node,
			"tap %d on Gintoki plays %s, the last line repeats (at %s)" % [tap + 1, node, runner.get("node_id")])
		_advance_until(runner, "investigate")
	_expect(runner.get("investigations")["room"]["counts"] == {"gin": 4}, "the taps are counted (%s)" % [runner.get("investigations")])
	room = runner.call("current")
	_expect(room["hotspots"][0]["checked"] and room["progress"] == [0, 1],
		"the first tap counted as searched; his spot is optional, Kagura is away: only the job is required (%s)" % [room["progress"]])


func _test_off_stage_character_spots() -> void:
	var runner: RefCounted = _at_room(["gintoki"])
	var room: Dictionary = runner.call("current")
	_expect(room["hotspots"][0]["present"] and not room["hotspots"][1]["present"], "Kagura's spot is off stage, Gintoki's is not")
	_expect(not runner.call("inspect_hotspot", "kagura") and String(runner.get("error_message")).contains("not on stage"),
		"an off-stage character's spot cannot be inspected (%s)" % runner.get("error_message"))
	runner.call("inspect_hotspot", "job")
	_advance_until(runner, "investigate")
	_expect(runner.call("current")["complete"] and runner.call("advance")["op"] == "say",
		"the job alone completes the search while Kagura is away: she does not hold 繼續 back")

	var both: RefCounted = _at_room(["gintoki", "kagura"])
	_expect(both.call("current")["progress"] == [0, 2], "with Kagura on stage her spot is required")
	both.call("inspect_hotspot", "job")
	_advance_until(both, "investigate")
	_expect(not both.call("current")["complete"] and both.call("advance")["op"] == "investigate",
		"the job is not enough: 繼續 waits for Kagura (%s)" % both.get("error_message"))
	both.call("inspect_hotspot", "kagura")
	_advance_until(both, "investigate")
	_expect(both.call("current")["complete"], "then the search is complete")


func _test_set_flags_and_condition() -> void:
	var runner: RefCounted = _at_room(["gintoki"])
	_expect(runner.get("flags") == {"examined_milk": false, "found_job": false}, "both flags start false")
	runner.call("inspect_hotspot", "milk")
	_advance_until(runner, "investigate")
	_expect(runner.get("flags")["examined_milk"] and not runner.get("flags")["found_job"], "the milk writes only its own flag")
	var flags: Dictionary = runner.get("flags")
	flags["examined_milk"] = false
	runner.call("inspect_hotspot", "milk")
	_expect(not flags["examined_milk"], "a second look writes nothing")
	runner.call("inspect_hotspot", "job")
	_advance_until(runner, "investigate")
	_expect(runner.get("flags")["found_job"], "the job writes its flag")
	runner.call("advance")
	_expect(runner.get("node_id") == "with_job" and runner.call("current")["text"] == "有工作了。",
		"a condition reads the flag the hotspot wrote (at %s)" % runner.get("node_id"))


func _test_saves_keep_tap_counts() -> void:
	var runner: RefCounted = _at_room(["gintoki"])
	for _i: int in range(2):
		runner.call("inspect_hotspot", "gin")
		_advance_until(runner, "investigate")
	var saved: Dictionary = runner.call("snapshot")
	_expect(saved["investigations"]["room"]["counts"] == {"gin": 2}, "the snapshot keeps the tap counts")
	var resumed: RefCounted = _at_room(["gintoki"])
	_expect(resumed.call("restore", saved), "a save with counts restores: %s" % resumed.get("error_message"))
	_expect(resumed.call("inspect_hotspot", "gin") and resumed.get("node_id") == "gin_3", "the third tap after loading plays the third line")

	var legacy: Dictionary = saved.duplicate(true)
	(legacy["investigations"]["room"] as Dictionary).erase("counts")
	_expect(resumed.call("restore", legacy) and resumed.call("inspect_hotspot", "gin") and resumed.get("node_id") == "gin_1",
		"a save from before tap counts loads and counts from the first line")
	legacy.erase("investigations")
	_expect(resumed.call("restore", legacy), "a save from before investigations loads too")

	for counts: Variant in [{"gin": 0}, {"gin": "2"}, {"milk": 1}, {"nobody": 1}, [1]]:
		var bad: Dictionary = saved.duplicate(true)
		bad["investigations"]["room"]["counts"] = counts
		_expect(not resumed.call("restore", bad), "a save with counts %s is rejected" % [counts])


## The round's checkpoint keeps the tap counts of the search before it. Phase 4's floor prints become a
## `lines` spot for this.
func _test_checkpoint_keeps_tap_counts() -> void:
	var story: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PHASE4))
	for spot: Dictionary in story["nodes"]["search"]["steps"][0]["hotspots"]:
		if spot["id"] == "floor_paw_print":
			spot.erase("goto")
			spot["lines"] = ["spot_floor"]
	var runner: RefCounted = _loaded_from(story)
	_advance_until(runner, "investigate")
	for spot: String in ["floor_paw_print", "floor_paw_print", "empty_milk_bottle", "gintoki_mouth", "kombu_wrapper"]:
		runner.call("inspect_hotspot", spot)
		_advance_until(runner, "investigate")
	runner.call("advance")
	_advance_until(runner, "choice")
	runner.call("choose", "ask_gintoki")
	_advance_until(runner, "boke_round")
	var before: Dictionary = runner.call("snapshot")
	_expect((before["checkpoint"]["investigations"]["living_room_search"]["counts"]) == {"floor_paw_print": 2},
		"the round's checkpoint holds the tap counts (%s)" % [before["checkpoint"].get("investigations")])
	for _cold: int in range(5):
		runner.call("resolve_boke", "missed_comeback")
		_advance_until(runner, "boke_round" if runner.get("gameplay")["glasses"] > 0 else "end")
	_expect(runner.get("node_id") == "game_over", "five cold takes end on Game Over")
	var over: Dictionary = runner.call("snapshot")
	_expect(_loaded_from(story).call("restore", over), "a save at Game Over with a checkpoint that has counts restores")
	_expect(runner.call("retry_checkpoint") and runner.get("investigations") == before["investigations"],
		"the retry brings the tap counts back with the rest of the checkpoint")


func _test_validation_errors() -> void:
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(STORY))
	var cases: Array = [
		[func(s: Dictionary) -> void: _put(s, 0, "goto", "milk_react"),
			"node 'room' step 0 hotspot 'gin' has both goto and lines"],
		[func(s: Dictionary) -> void: s["nodes"]["room"]["steps"][0].erase("keep_cast"),
			"node 'room' step 0 hotspot 'gin' has a character, so the investigation needs keep_cast: true"],
		[func(s: Dictionary) -> void: s["nodes"]["room"]["steps"][0]["keep_cast"] = "yes",
			"node 'room' step 0 investigate keep_cast must be boolean"],
		[func(s: Dictionary) -> void: _put(s, 0, "character", "nobody"),
			"node 'room' step 0 hotspot 'gin' character 'nobody' is not in asset catalog"],
		[func(s: Dictionary) -> void: _put(s, 0, "pos", [0.5, 0.5]),
			"node 'room' step 0 hotspot 'gin' has a character, so its area is the portrait: drop pos and size"],
		[func(s: Dictionary) -> void: _drop(s, 2, "pos"),
			"node 'room' step 0 hotspot 'milk' pos must contain normalized x/y coordinates"],
		[func(s: Dictionary) -> void: _put(s, 0, "lines", []),
			"node 'room' step 0 hotspot 'gin' lines must be a non-empty array of existing node ids"],
		[func(s: Dictionary) -> void: _put(s, 0, "lines", ["gin_1", "nowhere"]),
			"node 'room' step 0 hotspot 'gin' lines must be a non-empty array of existing node ids"],
		[func(s: Dictionary) -> void: _put(s, 2, "set", "yes"),
			"node 'room' step 0 hotspot 'milk' set must be an object"],
		[func(s: Dictionary) -> void: _put(s, 2, "set", {"examined_milk": [1]}),
			"node 'room' step 0 hotspot 'milk' set contains an invalid value for 'examined_milk'"],
		[func(s: Dictionary) -> void: _put(s, 2, "set", {"brand_new": true}),
			"node 'room' step 0 hotspot set flag 'brand_new' is not in initial_flags"],
		[func(s: Dictionary) -> void: _put(s, 2, "set", {"examined_milk": "yes"}),
			"flag 'examined_milk' changes value type"],
		[func(s: Dictionary) -> void: (s["nodes"]["room"]["steps"] as Array).push_front({"op": "say", "speaker": "gintoki", "text": "先說一句。"}),
			"node 'room' step 1 investigate 'room' has reactions"],
		[func(s: Dictionary) -> void: _only_lines_react(s),
			"node 'room' step 1 investigate 'room' has reactions"],
	]
	for case: Array in cases:
		var story: Dictionary = base.duplicate(true)
		case[0].call(story)
		var file: FileAccess = FileAccess.open(BROKEN, FileAccess.WRITE)
		file.store_string(JSON.stringify(story))
		file.close()
		var runner: RefCounted = StoryRunner.new()
		_expect(not runner.call("load_story", BROKEN) and String(runner.get("error_message")).contains(case[1]),
			"invalid story is rejected with '%s' (got: %s)" % [case[1], runner.get("error_message")])
	DirAccess.remove_absolute(BROKEN)


## `lines` alone make the search a reaction node: it must be the first step, like `goto` and `talk`.
func _only_lines_react(story: Dictionary) -> void:
	var spots: Array = story["nodes"]["room"]["steps"][0]["hotspots"]
	for index: int in [1, 2, 3]:
		(spots[index] as Dictionary).erase("goto")
		(spots[index] as Dictionary).erase("set")
		(spots[index] as Dictionary)["item"] = "milk_bottle"
	(story["nodes"]["room"]["steps"] as Array).push_front({"op": "say", "speaker": "gintoki", "text": "先說一句。"})


func _test_builder_follows_lines() -> void:
	var nodes: Dictionary = {
		"a": {"steps": [{"op": "investigate", "hotspots": [{"id": "x", "lines": ["b", "c"]}]}], "next": "d"},
		"b": {"steps": [{"op": "goto", "target": "a"}]},
		"c": {"steps": [{"op": "goto", "target": "a"}]},
		"d": {"steps": [{"op": "end"}]},
	}
	_expect(StoryBuilder._unreachable("a", nodes).is_empty(), "the nodes a hotspot's lines play are reachable")
	((nodes["a"]["steps"][0] as Dictionary)["hotspots"][0] as Dictionary).erase("lines")
	_expect(StoryBuilder._unreachable("a", nodes) == ["b", "c"], "and are not once the lines are gone")


# ---------------------------------------------------------------- shell

func _test_shell() -> void:
	var game: Control = _new_game()
	await _frames(3)
	_expect(game._story_ready, "the fixture loads in the shell: %s" % game._story_error)
	game._on_begin_pressed()
	game._set_skip(true)
	await _until(func() -> bool: return game._screen_mode == "investigate", "reach the room search")

	var gintoki: Control = game._sprites["gintoki"]
	_expect(gintoki.visible and gintoki.modulate.r > 0.9 and game._sprites.values().filter(func(s: Control) -> bool: return s.visible).size() == 1,
		"keep_cast: Gintoki, who came on stage in the opening, is still there and lit")
	_expect(game._hotspots.keys() == ["gin", "milk", "job"], "Kagura is off stage: her spot does not exist (%s)" % [game._hotspots.keys()])
	_expect(game._hotspots["gin"].get_parent() == game._interaction_layer and game._hotspots["milk"].get_parent() == game._hotspot_layer,
		"his spot lies on the interaction layer, objects stay on the picture")
	var portrait: Rect2 = gintoki.art_rect()
	_expect(game._hotspots["gin"].get_global_rect().is_equal_approx(portrait.intersection(Rect2(game._game.global_position, game._game.size))),
		"Gintoki's spot is his portrait on screen (%s vs %s)" % [game._hotspots["gin"].get_global_rect(), portrait])
	_expect(game._investigation_continue_button.disabled, "the job is still to do")

	var point: Vector2 = _above_box(game, portrait)
	await _tap(portrait.position - Vector2(30.0, 0.0) + Vector2(0.0, 60.0))
	_expect(game._screen_mode == "investigate", "a tap beside the portrait does nothing")
	for tap: int in range(GIN_TEXTS.size()):
		await _tap(point)
		await _until(func() -> bool: return game._screen_mode == "story", "tap %d on his portrait plays a line" % [tap + 1])
		_expect(game._full_text == GIN_TEXTS[tap], "tap %d says '%s' (got '%s')" % [tap + 1, GIN_TEXTS[tap], game._full_text])
		await _read_back(game)
	_expect(game._runner.investigations["room"]["counts"] == {"gin": 4}, "four taps counted")
	game._save_game()

	# Load it in a second game (the first one waits): the cast, his spot and his count are back.
	var resumed: Control = _new_game()
	await _frames(3)
	resumed._on_continue_pressed()
	await _until(func() -> bool: return resumed._screen_mode == "investigate", "the save comes back to the search")
	await _frames(3)
	_expect(resumed._sprites["gintoki"].visible and resumed._hotspots.has("gin") and resumed._hotspots["gin"].found,
		"Gintoki and his checked spot are back")
	var gintoki_box: Rect2 = resumed._sprites["gintoki"].art_rect()
	await _tap(_above_box(resumed, gintoki_box))
	await _until(func() -> bool: return resumed._screen_mode == "story", "a tap after loading plays a line")
	_expect(resumed._full_text == GIN_TEXTS[3], "the counts went on from four: the last line again (got '%s')" % resumed._full_text)
	await _read_back(resumed)

	# Kagura on stage: her spot covers her portrait and is required. Portraits overlap; the one in front is hit.
	var kagura: Control = resumed._sprites["kagura"]
	kagura.visible = true
	resumed._layout_sprite("kagura")
	resumed._char_layer.move_child(kagura, -1)
	resumed._present_investigation(resumed._runner_current(), true)
	await _frames(3)
	_expect(resumed._hotspots.has("kagura") and resumed._current_command["progress"] == [0, 2] and resumed._investigation_continue_button.disabled,
		"with Kagura on stage her spot exists and is required (%s)" % [resumed._current_command["progress"]])
	var shown: Rect2 = kagura.art_rect().intersection(Rect2(resumed._game.global_position, resumed._game.size))
	_expect(resumed._hotspots["kagura"].get_global_rect().is_equal_approx(shown), "and lies on her portrait on screen")
	var overlap: Vector2 = _above_box(resumed, shown.intersection(gintoki_box))
	_expect(resumed._hotspots["gin"].get_global_rect().has_point(overlap), "the point tapped is on both portraits")
	await _tap(overlap)
	await _until(func() -> bool: return resumed._screen_mode == "story", "a tap on both portraits plays a line")
	_expect(resumed._full_text == "我在這裡喔。", "Kagura, in front, answers (got '%s')" % resumed._full_text)
	await _read_back(resumed)
	_expect(resumed._current_command["progress"] == [1, 2], "her spot is checked")
	resumed._char_layer.move_child(resumed._sprites["gintoki"], -1)
	await _tap(overlap)
	await _until(func() -> bool: return resumed._screen_mode == "story", "the same tap with Gintoki in front plays a line")
	_expect(resumed._full_text == GIN_TEXTS[3], "and now he answers (got '%s')" % resumed._full_text)
	resumed.queue_free()
	await _frames(2)

	# Back in the first game: objects by touch (the reading box folded away), then 繼續 with Kagura still off stage.
	for spot_id: String in ["milk", "job"]:
		game._set_investigation_collapsed(true)
		await _tap(game._hotspot_hit_rect(game._hotspots[spot_id]).get_center())
		await _read_back(game)
	_expect(game._runner.flags == {"examined_milk": true, "found_job": true}, "touching the objects wrote their flags (%s)" % [game._runner.flags])
	game._set_investigation_collapsed(false)
	_expect(not game._investigation_continue_button.disabled, "Kagura is off stage, so 繼續 opens with the job found")
	game._on_investigation_continue_pressed()
	await _until(func() -> bool: return game._screen_mode == "story", "the story goes on after the search")
	_expect(game._full_text == "有工作了。", "the condition read the flag the job wrote (got '%s')" % game._full_text)
	game.queue_free()
	await _frames(2)


## A point on the upper part of the rect, above the reading box.
func _above_box(game: Control, rect: Rect2) -> Vector2:
	var bottom: float = minf(rect.end.y, game._dialog_panel.get_global_rect().position.y)
	return Vector2(rect.get_center().x, rect.position.y + (bottom - rect.position.y) * 0.25)


## Reads a reaction scene through until the search is back.
func _read_back(game: Control) -> void:
	for _i: int in range(600):
		if game._screen_mode == "investigate" and not game._story_busy:
			return
		if game._screen_mode == "story" and not game._story_busy:
			if game._text_complete:
				game._advance_current_line()
			else:
				game._complete_current_line()
		await process_frame
	failures.append("timed out reading back to the search (at %s)" % game._screen_mode)


func _new_game() -> Control:
	var game: Control = MAIN_SCENE.instantiate() as Control
	game.story_path = STORY
	game.save_path = TEST_SAVE
	game.ui_preference_path = TEST_UI
	root.add_child(game)
	return game


# ---------------------------------------------------------------- helpers

func _loaded() -> RefCounted:
	var runner: RefCounted = StoryRunner.new()
	_expect(runner.call("load_story", STORY), "the fixture loads: %s" % runner.get("error_message"))
	return runner


func _loaded_from(story: Dictionary) -> RefCounted:
	var file: FileAccess = FileAccess.open(BROKEN, FileAccess.WRITE)
	file.store_string(JSON.stringify(story))
	file.close()
	var runner: RefCounted = StoryRunner.new()
	_expect(runner.call("load_story", BROKEN), "the patched story loads: %s" % runner.get("error_message"))
	DirAccess.remove_absolute(BROKEN)
	return runner


## The fixture's search with `cast` on stage.
func _at_room(cast: Array) -> RefCounted:
	var runner: RefCounted = _loaded()
	runner.set("cast", cast)
	_advance_until(runner, "investigate")
	return runner


func _advance_until(runner: RefCounted, op: String) -> void:
	for _step: int in range(60):
		if String(runner.call("current").get("op", "")) == op:
			return
		runner.call("advance")
	_expect(false, "reached op '%s' (stopped at %s)" % [op, runner.get("node_id")])


func _put(story: Dictionary, index: int, key: String, value: Variant) -> void:
	story["nodes"]["room"]["steps"][0]["hotspots"][index][key] = value


func _drop(story: Dictionary, index: int, key: String) -> void:
	story["nodes"]["room"]["steps"][0]["hotspots"][index].erase(key)


func _ids(entries: Array) -> Array:
	return entries.map(func(entry: Dictionary) -> String: return str(entry["id"]))


func _cleanup() -> void:
	for base: String in [TEST_SAVE, TEST_UI]:
		for suffix: String in ["", ".bak", ".bak.old", ".old", ".tmp", ".bak.tmp"]:
			if FileAccess.file_exists(base + suffix):
				DirAccess.remove_absolute(base + suffix)
