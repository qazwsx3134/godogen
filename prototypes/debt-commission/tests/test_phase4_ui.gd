extends "res://addons/proto_kit/test_kit.gd"
## The Phase 4 four-clue sample plays in the existing VN shell: four hotspots (the footprints
## play their own scene), 對話 and 移動 topics in the reading box, the kitchen with its own
## picture and fridge (Gintoki answers from off stage), a choice, the tsukkomi round with every
## clue option, and the ending; the gameplay HUD and Game Over retry turn on from the story's
## content; the title screen switches between stories.

const MAIN_SCENE: PackedScene = preload("../main.tscn")
const STORY_PATH: String = "res://data/phase4_story.json"
const TEST_SAVE: String = "user://phase4_ui_test.save"
const RETRY_SAVE: String = "user://phase4_ui_retry.save"
const HOTSPOTS: Array[String] = ["empty_milk_bottle", "gintoki_mouth", "kombu_wrapper", "floor_paw_print"]


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_cleanup_saves()
	await _test_title_story_switch()
	await _test_game_over_retry()
	await _test_talk_and_move()
	var game: Control = _new_game(TEST_SAVE)
	await _frames(3)
	_expect(game._story_ready, "phase4_story.json loads in the VN shell: %s" % game._story_error)
	game._on_begin_pressed()
	game._set_skip(true)
	await _until(func() -> bool: return game._screen_mode == "investigate", "reach the four-clue investigation")

	_expect(game._hotspots.size() == 4, "four spots lie on the picture")
	_expect(game._sprites.values().all(func(sprite: Control) -> bool: return not sprite.visible),
		"nobody is on stage while searching")
	for hotspot_id: String in HOTSPOTS:
		var spot: Control = game._hotspots.get(hotspot_id) as Control
		_expect(spot != null and spot.get_parent() == game._hotspot_layer, "spot '%s' lies on the picture" % hotspot_id)
	await _search_all(game)
	game._collect_hotspot("empty_milk_bottle")
	_expect(game._runner.items.size() == 4, "each clue is granted once: %s" % [game._runner.items])
	game._on_investigation_continue_pressed()
	game._set_skip(true)  # SKIP stops at the investigation; the next line needs it again
	await _until(func() -> bool: return game._screen_mode == "choice", "reach the ask-first choice")

	game._on_choice_pressed("ask_kagura")
	game._set_skip(true)
	await _until(func() -> bool: return game._screen_mode == "boke_round", "reach the tsukkomi round")
	await _check_case_file(game)
	game._on_boke_tsukkomi_pressed()
	_expect(game._screen_mode == "tsukkomi" and game._choice_buttons.size() == 6,
		"all four clue options plus two plain ones are offered (%d)" % game._choice_buttons.size())
	game._open_menu()
	_expect(game._phase3_timer_label.text.begins_with("暫停") and game._choice_sheet.timer_value.text == "暫停",
		"目錄 during the timed choice shows the countdown as paused in the HUD and on the sheet")
	game._close_menu()
	var remaining: float = game._boke_time_remaining
	game._open_case_file("materials")
	await _frames(10)
	_expect(game._screen_mode == "case_file" and is_equal_approx(game._boke_time_remaining, remaining),
		"opening the materials during the timed choice pauses the countdown")
	var panel: Panel = game._case_file_panel
	panel._select(1)
	var use: Button = panel.find_child("CaseFileUse", true, false)
	_expect(use.visible, "a material that backs a visible option offers 拿來吐槽")
	await _press(use)
	game._set_skip(true)
	await _until(func() -> bool: return game._runner.node_id == "perfect_end", "perfect result via Kagura's line", 10.0)
	_expect(str(game._runner.flags.get("round_result", "")) == "perfect", "round result is recorded")

	game.queue_free()
	await _frames(2)
	_cleanup_saves()
	_finish("PHASE 4 UI TESTS")


func _check_case_file(game: Control) -> void:
	game._open_case_file("materials")
	var panel: Panel = game._case_file_panel
	var grid: GridContainer = panel.find_child("CaseFileGrid", true, false)
	_expect(game._screen_mode == "case_file" and panel.visible, "the materials screen opens")
	_expect(grid.get_child_count() == 4 and grid.columns == 4, "four materials fill one row of the four-column grid")
	_expect(grid.get_child(0).get_node("Content/Picture").texture == null
		and (grid.get_child(0).get_node("Content/Picture") as Control).is_visible_in_tree()
		and panel.find_child("CaseFilePicture", true, false).visible,
		"a material without art shows the placeholder picture in its card and in the detail")
	_expect(panel.find_child("CaseFileName", true, false).text == "空的草莓牛奶瓶", "the first material is selected with its name")
	_expect(not panel.find_child("CaseFileUse", true, false).visible, "拿來吐槽 is hidden outside the timed choice")
	await _press(panel.find_child("CaseFileTab_profiles", true, false))
	_expect(grid.get_child_count() == 3 and panel.find_child("CaseFileText", true, false).text.contains("嗜甜"),
		"the profiles tab lists Gintoki, Sadaharu and Kagura with profile text")
	await _frames(1)
	_expect(grid.get_child(0).get_node("Content/Picture").texture != null,
		"a character with art shows its picture instead of the placeholder")
	await _press(panel.find_child("CaseFileClose", true, false))
	_expect(game._screen_mode == "boke_round" and not panel.visible, "closing returns to the round")


func _test_title_story_switch() -> void:
	var game: Control = MAIN_SCENE.instantiate() as Control
	game.save_path = TEST_SAVE
	root.add_child(game)
	await _frames(3)
	_expect(game._story_switch.text.contains("請幫我向你老闆討債"), "the title shows the scene's default story by its own title")
	_expect(not game._phase3_enabled, "a story without investigation or rounds keeps the gameplay HUD off")
	game._on_story_switch_pressed()
	var rows: Dictionary = game._chapter_select.call("rows")
	_expect(game._screen_mode == "chapter_select" and game._chapter_select.visible and rows.size() == game._story_choices.size(),
		"the story label opens 章節選擇 with every story")
	_expect(rows.keys() == ["debt", "phase2", "phase3", "phase4", "phase4_rounds"]
		and (rows["debt"] as Button).text.contains("請幫我向你老闆討債") and (rows["phase4"] as Button).text.contains("試玩片段"),
		"rows list each story by its own title, samples marked as such: %s" % [rows.keys()])
	_expect(game._chapter_select.find_child("ChaptersEmpty", true, false).visible, "with no chapters yet, 本篇 says so")
	await _press(rows["phase4"])
	_expect(game._screen_mode == "title" and not game._chapter_select.visible and game._story_ready,
		"picking a story returns to the title with it loaded")
	_expect(game._phase3_enabled and game.save_path == "user://strawberry_phase4.save",
		"Phase 4 turns the gameplay HUD on and uses its own save file")
	_expect(game._story_switch.text.contains("Phase 4") and game._story_switch.text.contains("章節選擇"),
		"the title shows the picked story and leads back to 章節選擇")
	_expect(game._menu_items["material"].visible and game._menu_items["profile"].visible,
		"picking Phase 4 on the title shows the materials and profiles menu entries")
	_expect(game._dialog_panel.chapter.text == "Phase 4 技術試片", "the speaker row shows the story's chapter")
	var config: ConfigFile = ConfigFile.new()
	_expect(config.load(game.STORY_CHOICE_PATH) == OK and config.get_value("story", "id", "") == "phase4",
		"the choice is remembered for the next run")
	var choice_path: String = game.STORY_CHOICE_PATH
	game.queue_free()
	await _frames(2)
	DirAccess.remove_absolute(choice_path)


func _test_game_over_retry() -> void:
	var game: Control = _new_game(RETRY_SAVE)
	await _frames(3)
	_expect(game._phase3_enabled, "the Phase 4 story enables the gameplay HUD")
	game._on_begin_pressed()
	game._set_skip(true)
	await _until(func() -> bool: return game._screen_mode == "investigate", "retry run reaches the investigation")
	_expect(game._phase3_hud.visible and game._menu_items["material"].visible, "HUD and the materials menu entry are available")
	await _search_all(game)
	game._on_investigation_continue_pressed()
	game._set_skip(true)
	await _until(func() -> bool: return game._screen_mode == "choice", "retry run reaches the choice")
	game._on_choice_pressed("ask_gintoki")
	await _until(func() -> bool: return game._screen_mode == "boke_round", "retry run reaches the round")
	for failure: int in range(5):
		game._on_boke_tsukkomi_pressed()
		game._on_boke_option_pressed("missed_comeback")
		var target: String = "cold" if failure < 4 else "game_over"
		await _until(func() -> bool: return game._screen_mode == "story" and game._runner.node_id == target,
			"fail %d reaches %s" % [failure + 1, target])
		if failure < 4:
			game._complete_current_line()
			game._advance_current_line()
			await _until(func() -> bool: return game._screen_mode == "boke_round", "cold loops back to the round")
	game._complete_current_line()
	game._advance_current_line()
	await _until(func() -> bool: return game._screen_mode == "end", "Game Over end controls")
	_expect(game._game_over_retry_button.visible, "Game Over shows the retry button")
	game._on_game_over_retry_pressed()
	_expect(game._screen_mode == "boke_round" and int(game._runner.gameplay["glasses"]) == 5,
		"retry returns to the round with full glasses")
	_expect(game._runner.items.size() == 4 and game._runner.profiles == ["gintoki", "sadaharu"],
		"retry keeps the clues and profiles collected before the round (%s)" % [game._runner.profiles])
	game.queue_free()
	await _frames(2)


## Collects every living-room spot; a spot with a scene (the footprints) plays it under SKIP and
## the search comes back.
func _search_all(game: Control) -> void:
	for hotspot_id: String in HOTSPOTS:
		game._collect_hotspot(hotspot_id)
		if game._screen_mode != "investigate":
			game._set_skip(true)
			await _until(func() -> bool: return game._screen_mode == "investigate", "back from the scene of %s" % hotspot_id)


## 對話 and 移動 in the reading box: a topic plays its scene once and the search comes back with
## the picture where it was left; the kitchen has its own picture and fridge, whose scene has
## Gintoki speak from off stage and then returns home; a style switch keeps the topics; Continue
## in the kitchen reopens the kitchen.
func _test_talk_and_move() -> void:
	var game: Control = _new_game(TEST_SAVE)
	await _frames(3)
	game._on_begin_pressed()
	game._set_skip(true)
	await _until(func() -> bool: return game._screen_mode == "investigate", "reach the search")
	var box: Control = game._dialog_panel
	_expect(box.investigation_topics.visible and box.talk_list.get_child_count() == 2 and box.move_list.get_child_count() == 1,
		"the reading box shows two talk topics and one move")
	var kagura_topic: Button = game._topic_buttons.get("talk:kagura_dinner") as Button
	var kitchen_move: Button = game._topic_buttons.get("move:kitchen") as Button
	_expect(kagura_topic != null and kagura_topic.text == "神樂：昨晚吃了什麼？" and kitchen_move.text == "廚房"
		and kagura_topic.custom_minimum_size.y >= 48.0 * game.CSS_PX - 0.5, "topic buttons carry their labels and a 48 CSS px height")
	game._set_pan(game._pan_range.x * 0.5)
	var pan: float = game._pan
	await _press(kagura_topic)
	await _read_until(game, func() -> bool: return game._current_speaker == "kagura", "Kagura answers")
	_expect(game._sprites["kagura"].visible and not box.investigation_topics.visible, "Kagura comes on to answer; the topics give way")
	game._set_skip(true)
	await _until(func() -> bool: return game._screen_mode == "investigate", "back to the search")
	_expect(not game._topic_buttons.has("talk:kagura_dinner") and box.talk_list.get_child_count() == 1,
		"the played topic is gone")
	_expect(is_equal_approx(game._pan, pan) and not game._sprites["kagura"].visible, "the picture is where it was left; the stage is clear again")

	game._set_ui_style("ledger", false)
	await _frames(2)
	_expect(game._dialog_panel.style_id == "ledger" and game._topic_buttons.has("move:kitchen")
		and game._dialog_panel.move_list.get_child_count() == 1, "switching edition moves the topics into the new box")
	await _press(game._topic_buttons["move:kitchen"])
	_expect(game._current_bg_id == "yorozuya_kitchen" and game._hotspots.keys() == ["fridge"] and game._place_tag.text == "萬事屋廚房"
		and game._topic_buttons.keys() == ["move:home"] and (game._topic_buttons["move:home"] as Button).text == "客廳",
		"the kitchen has its own picture, its fridge and the way back (%s)" % [game._topic_buttons.keys()])
	_expect(game._investigation_continue_button.disabled, "繼續 still waits for the living-room clues")
	game._save_game()
	var resumed: Control = _new_game(TEST_SAVE)
	await _frames(3)
	resumed._on_continue_pressed()
	await _frames(3)
	_expect(resumed._screen_mode == "investigate" and resumed._current_bg_id == "yorozuya_kitchen" and resumed._hotspots.has("fridge"),
		"Continue reopens the search in the kitchen")
	resumed.queue_free()
	await _frames(2)

	game._collect_hotspot("fridge")
	await _read_until(game, func() -> bool: return game._current_speaker == "gintoki", "Gintoki's line")
	_expect(not game._sprites["gintoki"].visible and game._dialog_panel.speaker_name.text == "銀時",
		"Gintoki speaks from off stage: named, not on stage")
	game._set_skip(true)
	await _until(func() -> bool: return game._screen_mode == "investigate", "back to the search")
	_expect(game._current_bg_id == "yorozuya_living_room" and game._hotspots.size() == 4 and game._runner.items.is_empty(),
		"the searched-out kitchen sends the player home; the fridge gave no material")
	game._set_ui_style("cinema", false)
	game.queue_free()
	await _frames(2)
	_cleanup_saves()


## Reads lines (completing, then advancing) until done() holds.
func _read_until(game: Control, done: Callable, label: String) -> void:
	var deadline: int = Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < deadline:
		if done.call():
			return
		if game._screen_mode == "story" and not game._story_busy:
			if game._text_complete:
				game._advance_current_line()
			else:
				game._complete_current_line()
		await _frames(1)
	failures.append("timed out before %s (at %s)" % [label, game._runner.node_id])


func _new_game(save_path: String) -> Control:
	var game: Control = MAIN_SCENE.instantiate() as Control
	game.story_path = STORY_PATH
	game.save_path = save_path
	root.add_child(game)
	return game


func _cleanup_saves() -> void:
	for base: String in [TEST_SAVE, RETRY_SAVE]:
		for suffix: String in ["", ".bak", ".bak.old", ".old", ".tmp", ".bak.tmp"]:
			if FileAccess.file_exists(base + suffix):
				DirAccess.remove_absolute(base + suffix)
