extends "res://addons/proto_kit/test_kit.gd"
## The `comedy` op and the ComedyLayer: the data (validation, both build adapters), the three
## preset scenes, and the shell around them: it waits for the preset, a tap on it only ends it
## (the next line is not advanced and shows whole), skipping never plays it, leaving the screen
## clears it and puts the stage back, a save never brings it back, every preset runs in every UI
## style, and on a narrow phone the balloon and its line stay inside the game area.

const MAIN_SCENE: PackedScene = preload("../main.tscn")
const StoryRunner = preload("res://scripts/story_runner.gd")
const StoryBuilder = preload("res://tools/story_build/story_builder.gd")
const STORY: String = "res://data/comedy_story.json"
const DM_SOURCE: String = "res://story_src/comedy.dialogue"
const DS_SOURCE: String = "res://story_src/comedy.ds"
const BAD_STORY: String = "user://comedy_bad_story.json"
const TEST_SAVE: String = "user://comedy_test.save"
const TEST_UI: String = "user://comedy_test_ui.cfg"
const TEST_SETTINGS: String = "user://comedy_test_settings.cfg"
const SCENE_DIR: String = "res://scenes/comedy/"
const PRESETS: Array[String] = ["tsukkomi_impact", "small_reaction", "full_manga_panel"]
const AFTER_IMPACT_LINE: String = "……嗯？剛剛是不是有什麼東西在吵？"
const SAVED_NODES: Array[String] = ["res://scenes/comedy/tsukkomi_impact.tscn", "res://scenes/comedy/small_reaction.tscn",
	"res://scenes/comedy/full_manga_panel.tscn", "res://main.tscn"]


## Collects every error the engine logs (script errors, push_error) while a check runs.
class ErrorCatcher extends Logger:
	var messages: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
			_error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		messages.append("%s (%s:%d) %s %s" % [function, file, line, code, rationale])


var catcher: ErrorCatcher = ErrorCatcher.new()
var impact_index: int = -1
var scene_sources: Dictionary = {}


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	OS.add_logger(catcher)
	for path: String in SAVED_NODES:
		scene_sources[path] = FileAccess.get_file_as_string(path)
	_cleanup()
	var story: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(STORY))
	var steps: Array = story["nodes"]["comedy_open"]["steps"]
	for index: int in range(steps.size()):
		if steps[index]["op"] == "comedy":
			impact_index = index
			break
	_expect(impact_index > 0 and steps[impact_index]["preset"] == "tsukkomi_impact"
		and steps[impact_index + 1]["op"] == "say" and steps[impact_index + 1]["text"] == AFTER_IMPACT_LINE,
		"the sample's tsukkomi_impact is followed at once by an ordinary line")
	_test_validation(story)
	_test_adapters()
	_test_scenes()
	await _test_story_waits()
	await _test_tap_fast_forward()
	await _test_skip_plays_nothing()
	await _test_leaving_clears()
	await _test_saves()
	await _test_presets_in_every_style()
	await _test_small_reaction_place()
	await _test_narrow_phone()
	for path: String in SAVED_NODES:
		_expect(FileAccess.get_file_as_string(path) == scene_sources[path], "playing never rewrites %s" % path)
	_expect(catcher.messages.is_empty(), "no engine errors were logged: %s" % [catcher.messages.slice(0, 3)])
	OS.remove_logger(catcher)
	_cleanup()
	_finish("COMEDY TESTS")


# ---------------------------------------------------------------- data

func _test_validation(story: Dictionary) -> void:
	var fields: Array[Array] = [
		["preset", "bad_preset", "comedy preset 'bad_preset' is not one of"],
		["text", null, "comedy needs text"],
		["speaker", "nobody", "comedy speaker 'nobody' is not a character in the asset catalog"],
		["expression", "bogus", "comedy expression is invalid"],
	]
	for case: Array in fields:
		var broken: Dictionary = story.duplicate(true)
		var step: Dictionary = (broken["nodes"]["comedy_open"]["steps"] as Array)[impact_index]
		if case[1] == null:
			step.erase(case[0])
		else:
			step[case[0]] = case[1]
		FileAccess.open(BAD_STORY, FileAccess.WRITE).store_string(JSON.stringify(broken))
		var runner: RefCounted = StoryRunner.new()
		var loaded: bool = runner.call("load_story", BAD_STORY)
		var message: String = str(runner.get("error_message"))
		_expect(not loaded and message.contains("node 'comedy_open' step %d" % impact_index) and message.contains(case[2]),
			"a comedy with a bad %s is rejected with its node and step: %s" % [case[0], message])
	var valid: RefCounted = StoryRunner.new()
	_expect(valid.call("load_story", STORY), "the sample story loads")
	var with_face: Dictionary = story.duplicate(true)
	((with_face["nodes"]["comedy_open"]["steps"] as Array)[impact_index] as Dictionary)["expression"] = "angry"
	FileAccess.open(BAD_STORY, FileAccess.WRITE).store_string(JSON.stringify(with_face))
	_expect(StoryRunner.new().call("load_story", BAD_STORY), "a comedy may name a valid expression")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(BAD_STORY))


func _test_adapters() -> void:
	var from_dm: Dictionary = StoryBuilder.build(DM_SOURCE)
	var from_ds: Dictionary = StoryBuilder.build(DS_SOURCE)
	_expect(String(from_dm["error"]).is_empty() and String(from_ds["error"]).is_empty(),
		"comedy.dialogue and comedy.ds build: %s %s" % [from_dm["error"], from_ds["error"]])
	var dm_story: Dictionary = (from_dm["story"] as Dictionary).duplicate(true)
	var ds_story: Dictionary = (from_ds["story"] as Dictionary).duplicate(true)
	dm_story.erase("generated_from")
	ds_story.erase("generated_from")
	_expect(dm_story == ds_story, "the Parley graph and the .dialogue build the same story")
	var kinds: Array[String] = []
	var steps_of_both: Array = []
	for story: Dictionary in [dm_story, ds_story]:
		var comedies: Array = []
		for node: Dictionary in (story["nodes"] as Dictionary).values():
			comedies.append_array((node["steps"] as Array).filter(func(step: Dictionary) -> bool: return step["op"] == "comedy"))
		steps_of_both.append(comedies)
	_expect(steps_of_both[0] == steps_of_both[1] and steps_of_both[0].size() == 4, "both adapters give the same four comedy steps")
	for step: Dictionary in steps_of_both[0]:
		kinds.append(str(step["preset"]))
		_expect(step["speaker"] in ["shinpachi", "gintoki"], "a speaker given by name or id is stored as the catalog id (%s)" % step["speaker"])
	kinds.sort()
	_expect(kinds == ["full_manga_panel", "small_reaction", "tsukkomi_impact", "tsukkomi_impact"], "the sample uses every preset, the impact twice")
	var on_disk: String = FileAccess.get_file_as_string(STORY)
	_expect(on_disk == StoryBuilder.to_json(from_dm["story"]), "data/comedy_story.json is a fresh build of comedy.dialogue")
	# The optional fourth argument and a display name through both adapters, built from text.
	var with_face: Dictionary = StoryBuilder.build_text(
		'~ a\ndo comedy("small_reaction", "新八", "咦？", "angry")\n新八: x\ndo end("e")\n', "res://story_src/__comedy_check.dialogue")
	var step: Dictionary = ((with_face["story"]["nodes"]["a"]["steps"]) as Array)[0] if with_face["error"] == "" else {}
	_expect(step.get("speaker") == "shinpachi" and step.get("expression") == "angry" and step.get("preset") == "small_reaction",
		"the fourth argument is the expression and a display name becomes the id: %s %s" % [step, with_face["error"]])


# ---------------------------------------------------------------- scenes

func _test_scenes() -> void:
	var timelines: Dictionary = {"tsukkomi_impact": 1.35, "small_reaction": 0.9, "full_manga_panel": 1.8}
	for preset: String in PRESETS:
		var packed: PackedScene = load(SCENE_DIR + preset + ".tscn") as PackedScene
		_expect(packed != null, "%s is a scene" % preset)
		if packed == null:
			continue
		var root: Control = packed.instantiate() as Control
		_expect(is_equal_approx(float(root.get("end_at")), float(timelines[preset])),
			"%s: the root's end_at export is %s" % [preset, timelines[preset]])
		_expect(float(root.get("burst_at")) >= 0.0 and float(root.get("fade_at")) < float(root.get("end_at")),
			"%s: the timeline is exported on the root" % preset)
		for name: String in ["Burst", "TextArea", "Text"]:
			_expect(root.get_node_or_null("%" + name) != null, "%s has %s" % [preset, name])
		var text: RichTextLabel = root.get_node("%Text") as RichTextLabel
		_expect(text.text.length() > 0 and text.get_parsed_text().length() > 1, "%s shows a line in the editor: %s" % [preset, text.get_parsed_text()])
		_expect(text.text.contains("d7191c") and text.text.contains("141414") or preset == "small_reaction",
			"%s: its line is set in red and black" % preset)
		if preset != "small_reaction":
			var face: TextureRect = root.get_node("%Portrait") as TextureRect
			_expect(face.texture != null and root.get_node_or_null("%SpeedLines") != null and root.get_node_or_null("%CutInPanel") != null,
				"%s shows a speed-line layer and the cut-in with a face in the editor" % preset)
		var every: Array[Node] = _descendants(root)
		_expect(every.filter(func(node: Node) -> bool: return node is Control and (node as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE).is_empty(),
			"%s: every node ignores the mouse" % preset)
		_expect(every.all(func(node: Node) -> bool: return node == root or node.owner == root),
			"%s: every node belongs to the scene" % preset)
		root.free()
	var colored: String = (load("res://scripts/comedy_preset.gd") as Script).call("colored", "現在是工作時間吧！！！")
	_expect(colored.contains("#d7191c") and colored.contains("#141414"), "a shout is set in both red and black: %s" % colored)
	var clauses: String = (load("res://scripts/comedy_preset.gd") as Script).call("colored", "工作，沒有，錢")
	_expect(clauses.count("#141414") == 2 and clauses.count("#d7191c") == 1, "clauses alternate black and red: %s" % clauses)


# ---------------------------------------------------------------- playing

func _test_story_waits() -> void:
	var game: Control = await _new_game()
	game._on_begin_pressed()
	await _read_to(game, "tsukkomi_impact")
	var layer: Control = game._comedy_layer
	var started: int = Time.get_ticks_msec()
	_expect(layer.visible and layer.get_child_count() == 1 and layer.get_child(0).name == "TsukkomiImpact",
		"the layer shows the preset's scene while it plays")
	_expect(layer.get_index() == game._dialog_layer.get_index() + 1 and layer.get_index() < game._overlay_layer.get_index(),
		"the layer sits above the dialogue layer and below the overlays")
	var current: Dictionary = game._runner_current()
	_expect(game._story_busy and game._screen_mode == "busy" and current["op"] == "comedy" and current["step_index"] == impact_index,
		"the story waits on the comedy step")
	_expect(_all_ignore_mouse(layer), "every node of the layer ignores the mouse, so taps reach the tap catcher")
	_expect(game._effects.call("_stream", "sounds", "comedy_don") != null and game._effects.call("_stream", "sounds", "comedy_pop") != null,
		"both comedy sounds have a placeholder")
	var zoomed: float = 1.0
	var shook: bool = false
	var held: bool = true
	while layer.is_active() and Time.get_ticks_msec() - started < 4000:
		await process_frame
		zoomed = maxf(zoomed, game._bg_layer.scale.x)
		shook = shook or (game._effects._shake_tween != null and game._effects._shake_tween.is_valid())
		held = held and game._runner_current()["step_index"] == impact_index
	var length: float = float(Time.get_ticks_msec() - started) / 1000.0
	_expect(length > 1.2 and length < 1.8, "tsukkomi_impact lasts about 1.35 s (%.2f)" % length)
	_expect(zoomed > 1.03 and zoomed <= 1.0501, "the stage zooms toward 1.05 (%.3f)" % zoomed)
	_expect(shook, "it shakes the stage")
	_expect(held, "the story did not move while it played")
	await _until(func() -> bool: return game._screen_mode == "story" and game._runner_current().get("step_index") == impact_index + 1,
		"the next line appears when it ends")
	_expect(not layer.visible and layer.get_child_count() == 0 and not layer.is_active(), "the layer is empty and hidden afterwards")
	_expect(_stage_at_rest(game), "the stage layers are back at rest: %s" % _stage_report(game))
	await _until(func() -> bool: return game._text_complete, "the line types out")
	_expect(game._full_text == AFTER_IMPACT_LINE and game._visible_text == AFTER_IMPACT_LINE, "the ordinary line follows whole")
	var logged: Array = game._history.filter(func(entry: Dictionary) -> bool: return str(entry["key"]).begins_with("comedy:"))
	_expect(logged.size() == 1 and logged[0]["speaker"] == "shinpachi" and logged[0]["text"] == "問題是你有工作的時候也在休息啊！！",
		"the comedy line is in the log, said by the speaker: %s" % [logged])
	await _free(game)


func _test_tap_fast_forward() -> void:
	var game: Control = await _new_game()
	game._on_begin_pressed()
	await _read_to(game, "tsukkomi_impact")
	await create_timer(0.45).timeout
	_expect(game._comedy_layer.is_active(), "still playing 0.45 s in")
	var stage: Vector2 = game._game.position + Vector2(game._game.size.x * 0.5, game._game.size.y * 0.34)
	_mouse(stage, true)
	await _frames(1)
	var tapped: int = Time.get_ticks_msec()
	_mouse(stage, false)
	while game._comedy_layer.is_active() and Time.get_ticks_msec() - tapped < 2000:
		await process_frame
	var took: float = float(Time.get_ticks_msec() - tapped) / 1000.0
	_expect(not game._comedy_layer.is_active() and took <= 0.15, "a tap ends the overlay within 0.15 s (%.3f)" % took)
	await _until(func() -> bool: return game._screen_mode == "story", "the story goes on")
	await _frames(4)
	_expect(game._runner_current()["step_index"] == impact_index + 1 and game._screen_mode == "story",
		"the tap did not also advance: the next line is current (step %s)" % game._runner_current()["step_index"])
	await _until(func() -> bool: return game._text_complete, "the next line types out whole")
	_expect(game._visible_text == AFTER_IMPACT_LINE and game._full_text == AFTER_IMPACT_LINE and game._runner_current()["step_index"] == impact_index + 1,
		"the next line shows in full and was not skipped")
	_expect(_stage_at_rest(game), "fast-forward leaves the stage at rest: %s" % _stage_report(game))
	await _free(game)

	# A press that began over the overlay and is released after it ended must not advance (instant text).
	game = await _new_game()
	game._settings["text_speed"] = 3
	game._on_begin_pressed()
	await _read_to(game, "tsukkomi_impact")
	_mouse(stage, true)
	await _until(func() -> bool: return not game._comedy_layer.is_active(), "the overlay ends by itself", 4.0)
	await _until(func() -> bool: return game._screen_mode == "story", "the line appears")
	_mouse(stage, false)
	await _frames(4)
	_expect(game._runner_current()["step_index"] == impact_index + 1 and game._visible_text == AFTER_IMPACT_LINE,
		"the release of a press that began during the overlay does not advance the next line")
	_tap_one(game)
	await _frames(4)
	_expect(game._full_text != AFTER_IMPACT_LINE, "a fresh tap advances normally afterwards (%s)" % game._full_text)
	await _free(game)

	# Fast-forward by key and by the 續 button go through the same path.
	game = await _new_game()
	game._on_begin_pressed()
	await _read_to(game, "tsukkomi_impact")
	game._on_screen_tap()
	await _until(func() -> bool: return not game._comedy_layer.is_active(), "the 續 path also ends it", 1.0)
	await _until(func() -> bool: return game._screen_mode == "story", "the story goes on")
	_expect(game._runner_current()["step_index"] == impact_index + 1, "the 續 tap did not advance either")
	await _free(game)


func _test_skip_plays_nothing() -> void:
	var game: Control = await _new_game()
	game._on_begin_pressed()
	await _until(func() -> bool: return game._screen_mode == "story", "story starts")
	game._set_skip(true)
	var seen: Array[bool] = [false]  # a lambda copies plain locals, so the flag lives in an array
	var started: int = Time.get_ticks_msec()
	await _until(func() -> bool:
		seen[0] = seen[0] or game._comedy_layer.is_active() or game._comedy_layer.get_child_count() > 0
		return game._screen_mode == "end", "SKIP runs to the end", 20.0)
	var took: float = float(Time.get_ticks_msec() - started) / 1000.0
	_expect(not seen[0], "skipping never builds a preset")
	_expect(took < 8.0, "skipping does not wait for the comedy steps (%.1f s)" % took)
	var logged: Array = game._history.filter(func(entry: Dictionary) -> bool: return str(entry["key"]).begins_with("comedy:"))
	_expect(logged.size() == 4, "the skipped comedy lines are still in the log (%d)" % logged.size())
	await _free(game)

	game = await _new_game()
	game._on_begin_pressed()
	await _read_to(game, "tsukkomi_impact")
	game._set_skip(true)  # switching skip on during a preset ends it
	await _until(func() -> bool: return not game._comedy_layer.is_active(), "skip ends a playing preset", 1.0)
	game._set_skip(false)
	await _free(game)

	# Auto-play waits for a preset like any other step.
	game = await _new_game()
	game._on_begin_pressed()
	await _until(func() -> bool: return game._screen_mode == "story", "story starts")
	game._set_auto(true)
	var played: Array[bool] = [false]
	await _until(func() -> bool:
		played[0] = played[0] or game._comedy_layer.is_active()
		return played[0] and not game._comedy_layer.is_active() and game._screen_mode == "story", "AUTO plays the preset and goes on", 40.0)
	_expect(played[0] and game._runner_current().get("step_index") == impact_index + 1, "AUTO reached the overlay, waited for it and went on")
	game._set_auto(false)
	await _free(game)


func _test_leaving_clears() -> void:
	var exits: Dictionary = {
		"回標題": func(game: Control) -> void: game._show_title(),
		"讀欄位": func(game: Control) -> void: game._load_payload_from_picker(game.get_meta("early_payload"), "已讀取"),
		"換 UI 風格": func(game: Control) -> void: game._set_ui_style("ledger", false),
		"重試／續讀": func(game: Control) -> void: game._render_restored_current(),
		"重新開始": func(game: Control) -> void: game._start_new_story(),
	}
	for label: String in exits.keys():
		var game: Control = await _new_game()
		game._on_begin_pressed()
		await _until(func() -> bool: return game._screen_mode == "story", "story starts")
		game.set_meta("early_payload", game._build_save_payload(""))
		await _read_to(game, "tsukkomi_impact")
		await create_timer(0.55).timeout  # zoom and shake are under way
		_expect(game._comedy_layer.is_active() and game._bg_layer.scale.x > 1.0, "%s: the stage is zoomed when leaving" % label)
		(exits[label] as Callable).call(game)
		_expect(not game._comedy_layer.is_active() and not game._comedy_layer.visible and game._comedy_layer.get_child_count() == 0,
			"%s: the layer is emptied and hidden at once" % label)
		_expect(_stage_at_rest(game), "%s: the stage layers are back at rest: %s" % [label, _stage_report(game)])
		await create_timer(0.5).timeout
		_expect(_stage_at_rest(game) and game._comedy_layer.get_child_count() == 0,
			"%s: nothing moves the stage afterwards: %s" % [label, _stage_report(game)])
		_expect(not game._comedy_layer.is_active(), "%s: it does not start again" % label)
		if label == "回標題":
			_expect(game._screen_mode == "title", "回標題: the title shows and the drive stopped")
		await _free(game)


func _test_saves() -> void:
	var game: Control = await _new_game()
	game._on_begin_pressed()
	await _read_to(game, "tsukkomi_impact")
	var during: Dictionary = game._build_save_payload("")  # taken while the runner is on the comedy step
	await _until(func() -> bool: return game._screen_mode == "story" and game._runner_current().get("step_index") == impact_index + 1,
		"the line after the comedy shows", 4.0)
	await _until(func() -> bool: return game._text_complete, "the line types out")
	_expect(game._save_game(), "the line after the comedy is saved")
	await _free(game)

	game = await _new_game()
	game._on_continue_pressed()
	await _frames(6)
	_expect(not game._comedy_layer.is_active() and not game._comedy_layer.visible and game._screen_mode == "story"
		and game._runner_current().get("step_index") == impact_index + 1 and game._full_text == AFTER_IMPACT_LINE,
		"続 from the save lands on the line after the comedy, which does not play again")
	var loaded_during: bool = game._validate_save_payload(during)
	_expect(loaded_during, "a save whose runner stands on a comedy step is valid")
	game._load_payload_from_picker(during, "已讀取")
	await _frames(6)
	_expect(not game._comedy_layer.is_active() and game._runner_current().get("step_index") == impact_index + 1
		and game._screen_mode == "story", "a save that points at a comedy step skips it instead of playing it")
	await create_timer(1.6).timeout
	_expect(not game._comedy_layer.is_active() and game._comedy_layer.get_child_count() == 0, "and no comedy appears afterwards")
	await _free(game)


func _test_presets_in_every_style() -> void:
	for style: String in ["cinema", "ledger", "manga"]:
		var game: Control = await _new_game()
		game._set_ui_style(style, false)
		await _frames(2)
		game._on_begin_pressed()
		await _until(func() -> bool: return game._screen_mode == "story", "story starts (%s)" % style)
		await _complete_line(game)
		var errors_before: int = catcher.messages.size()
		for preset: String in PRESETS:
			var step: Dictionary = {"op": "comedy", "preset": preset, "speaker": "kagura", "text": "阿魯！！這個月的房租也還沒付"}
			var seconds: float = game._comedy_layer.play(step)
			_expect(seconds > 0.8 and game._comedy_layer.is_active() and game._comedy_layer.current_preset() == preset,
				"%s/%s: plays (%.2f s)" % [style, preset, seconds])
			var started: int = Time.get_ticks_msec()
			await _until(func() -> bool: return not game._comedy_layer.is_active(), "%s/%s ends" % [style, preset], seconds + 2.0)
			var took: float = float(Time.get_ticks_msec() - started) / 1000.0
			_expect(absf(took - seconds) < 0.4 and game._comedy_layer.get_child_count() == 0 and not game._comedy_layer.visible
				and _stage_at_rest(game), "%s/%s: ran to its end (%.2f of %.2f s) and left nothing behind" % [style, preset, took, seconds])
		_expect(catcher.messages.size() == errors_before, "%s: no errors while the presets played" % style)
		await _free(game)


func _test_small_reaction_place() -> void:
	var game: Control = await _new_game()
	game._on_begin_pressed()
	await _until(func() -> bool: return game._screen_mode == "story", "story starts")
	await _complete_line(game)  # Gintoki speaks first, so he is on stage
	var layer: Control = game._comedy_layer
	var origin: Vector2 = layer.get_global_transform().origin
	var game_rect: Rect2 = game._game.get_global_rect()
	layer.play({"op": "comedy", "preset": "small_reaction", "speaker": "gintoki", "text": "咦？"})
	await _frames(3)
	var burst: Control = layer.get_child(0).get_node("%Burst") as Control
	var art: Rect2 = game._sprites["gintoki"].call("art_rect")
	var box: Rect2 = burst.get_global_rect()
	_expect(box.get_center().x > art.position.x and box.get_center().x < art.end.x and box.end.y < art.position.y + art.size.y * 0.4,
		"the reaction hangs above the speaker's head: balloon %s, picture %s" % [box, art])
	_expect(game_rect.encloses(box), "and stays inside the game area: %s in %s" % [box, game_rect])
	var dialog: Rect2 = game._dialog_panel.get_global_rect()
	_expect(box.end.y <= dialog.position.y + 1.0 or not box.intersects(dialog), "it does not cover the dialogue box")
	_expect(game._dialog_panel.visible and layer.get_child(0).get_node_or_null("%Dim") == null, "small_reaction dims nothing")
	layer.stop()
	# A speaker who is not on stage: above the middle of the reading box.
	layer.play({"op": "comedy", "preset": "small_reaction", "speaker": "otose", "text": "喂"})
	await _frames(3)
	burst = layer.get_child(0).get_node("%Burst") as Control
	box = burst.get_global_rect()
	_expect(absf(box.get_center().x - dialog.get_center().x) < 2.0 and box.end.y <= dialog.position.y + 2.0 and game_rect.encloses(box),
		"with the speaker off stage it hangs above the middle of the reading box: %s over %s" % [box, dialog])
	layer.stop()
	_expect(origin == layer.get_global_transform().origin, "the layer itself never moved")
	await _free(game)


func _test_narrow_phone() -> void:
	var original: Vector2i = root.size
	for phone: Vector2i in [Vector2i(390, 844), Vector2i(320, 568)]:
		root.size = phone
		await _frames(3)
		var game: Control = await _new_game()
		await _frames(3)
		var narrow: bool = phone.x < 390
		_expect(game._panel_scale > 1.2 if narrow else game._panel_scale < 1.01,
			"%d px wide: the panels scale by %.3f" % [phone.x, game._panel_scale])
		game._on_begin_pressed()
		await _until(func() -> bool: return game._screen_mode == "story", "story starts")
		await _complete_line(game)
		var game_rect: Rect2 = game._game.get_global_rect()
		for preset: String in PRESETS:
			var layer: Control = game._comedy_layer
			var label: String = "%d px / %s" % [phone.x, preset]
			layer.play({"op": "comedy", "preset": preset, "speaker": "shinpachi",
				"text": "問題是你有工作的時候也在休息啊！！而且還是三個月都沒有委託"})
			await create_timer(0.5).timeout
			var root_node: Control = layer.get_child(0) as Control
			var burst: Control = root_node.get_node("%Burst") as Control
			var text: RichTextLabel = root_node.get_node("%Text") as RichTextLabel
			var area: Control = root_node.get_node("%TextArea") as Control
			_expect(game_rect.grow(0.5).encloses(burst.get_global_rect()), "%s: the balloon is inside the game area: %s in %s" % [label, burst.get_global_rect(), game_rect])
			_expect(game_rect.grow(0.5).encloses(text.get_global_rect()) and area.get_global_rect().grow(1.0).encloses(text.get_global_rect()),
				"%s: the big line is inside the balloon and the game area: %s" % [label, text.get_global_rect()])
			_expect(float(text.get_content_height()) <= text.size.y + 1.0 and layer.qa_state().get("text_fits", false),
				"%s: the whole line is laid out inside its box, none of it clipped (%d of %.0f px)" % [label, text.get_content_height(), text.size.y])
			_expect(text.size.y <= area.size.y + 1.0 and text.get_theme_font_size("normal_font_size") >= 24,
				"%s: the line is sized to fit (font %d, %.0f of %.0f px)" % [label, text.get_theme_font_size("normal_font_size"), text.size.y, area.size.y])
			var panel: Control = root_node.get_node_or_null("%CutInPanel") as Control
			if panel != null:
				var tilted: Rect2 = panel.get_global_rect()  # it bleeds a little off the edge it slides in from
				_expect(tilted.position.x >= game_rect.position.x - 90.0 and tilted.end.x <= game_rect.end.x + 0.5
					and tilted.position.y >= game_rect.position.y and tilted.end.y <= game_rect.end.y,
					"%s: the cut-in panel is in the game area (%s)" % [label, tilted])
			layer.stop()
		await _free(game)
	root.size = original
	await _frames(2)


# ---------------------------------------------------------------- helpers

func _new_game() -> Control:
	var game: Control = MAIN_SCENE.instantiate() as Control
	game.story_path = STORY
	game.save_path = TEST_SAVE
	game.ui_preference_path = TEST_UI
	game.settings_path = TEST_SETTINGS
	root.add_child(game)
	await _frames(3)
	_expect(game._story_ready, "the comedy sample loads: %s" % game._story_error)
	return game


func _free(game: Control) -> void:
	game.queue_free()
	await _frames(2)


## Advances line by line until the layer plays that preset.
func _read_to(game: Control, preset: String) -> void:
	for attempt: int in range(60):
		if game._comedy_layer.is_active() and game._comedy_layer.current_preset() == preset:
			return
		if game._screen_mode == "story":
			if not game._text_complete:
				game._complete_current_line()
			else:
				game._advance_current_line()
		await _frames(2)
	failures.append("timed out: reaching the %s preset" % preset)


func _complete_line(game: Control) -> void:
	await _until(func() -> bool: return game._screen_mode == "story", "a line shows")
	if not game._text_complete:
		game._complete_current_line()
	await _frames(1)


func _tap_one(game: Control) -> void:
	_mouse(game._game.position + Vector2(game._game.size.x * 0.5, game._game.size.y * 0.34), true)
	_mouse(game._game.position + Vector2(game._game.size.x * 0.5, game._game.size.y * 0.34), false)


func _stage_at_rest(game: Control) -> bool:
	for layer: Control in [game._bg_layer, game._char_layer]:
		if layer.scale != Vector2.ONE or layer.pivot_offset != Vector2.ZERO:
			return false
	for layer: Control in [game._bg_layer, game._char_layer, game._interaction_layer, game._fx_layer, game._dialog_layer]:
		if layer.position != Vector2.ZERO:
			return false
	return not (game._effects._shake_tween != null and game._effects._shake_tween.is_valid() and game._effects._shake_tween.is_running()) \
		or game._effects._shake_layers.all(func(layer: Control) -> bool: return layer.position == Vector2.ZERO)


func _stage_report(game: Control) -> String:
	var report: Array[String] = []
	for layer: Control in [game._bg_layer, game._char_layer, game._interaction_layer, game._fx_layer, game._dialog_layer]:
		report.append("%s scale %s pivot %s position %s" % [layer.name, layer.scale, layer.pivot_offset, layer.position])
	return "; ".join(report)


func _all_ignore_mouse(node: Node) -> bool:
	return _descendants(node).all(func(child: Node) -> bool: return not child is Control or (child as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE)


func _descendants(node: Node) -> Array[Node]:
	var nodes: Array[Node] = [node]
	for child: Node in node.get_children():
		nodes.append_array(_descendants(child))
	return nodes


func _cleanup() -> void:
	for path: String in [TEST_SAVE, TEST_SAVE + ".bak", TEST_SAVE + ".old", TEST_SAVE + ".tmp", TEST_SAVE + ".bak.tmp", TEST_UI, TEST_SETTINGS]:
		var absolute: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute):
			DirAccess.remove_absolute(absolute)
