extends "res://addons/proto_kit/test_kit.gd"
## The Phase 4 rounds sample in the shell: stage effects (music survives a save, a cut-in never
## eats the next tap, shake settles, freeze holds only when not skipping); the testimony round
## (round bar, listening for a material, a whiff, catching with a material, the censor bar
## while reading, the give-up that waits for two catches); the combo round (lines open by
## themselves, shrinking timers, the super once the gauge is full, the QTE with a real early
## tap, the combo bonus); the censor bar on the timed sheet; a combo save reopens the sheet.

const MAIN_SCENE: PackedScene = preload("res://main.tscn")
const SAMPLE: String = "res://data/phase4_rounds_story.json"
const TEST_SAVE: String = "user://phase4_rounds_ui_test.save"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1080, 1920)
	await _test_effects()
	await _test_testimony_and_combo()
	await _test_censor_on_the_sheet_and_combo_save()
	await _test_game_over_screen()
	await _test_material_as_evidence()
	_finish("PHASE 4 ROUNDS UI TESTS")


func _test_effects() -> void:
	var game: Control = _new_game()
	await _frames(3)
	game._on_begin_pressed()
	await _until(func() -> bool: return game._screen_mode == "story", "the sample opens on a line")
	_expect(game._effects.current_bgm == "bgm_meeting", "the opening starts the meeting music")
	game._toggle_mute()
	_expect(not game._effects._bgm_player.playing, "muting stops the music outright (Web ignores volume on a playing stream)")
	game._toggle_mute()
	_expect(game._effects._bgm_player.playing and game._effects.current_bgm == "bgm_meeting", "unmuting plays it again")

	var before: String = _key(game)
	game._effects.play({"op": "cutin", "text": "你在說什麼啊！！", "speaker": "shinpachi"}, false)
	await _frames(2)
	var cutin: Control = game._overlay_layer.get_child(game._overlay_layer.get_child_count() - 1)
	_expect(cutin.visible and cutin.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the cut-in shows and ignores the pointer")
	var stage: Vector2 = game._game.position + Vector2(game._game.size.x * 0.5, game._game.size.y * 0.34)
	await _tap(stage)
	_expect(game._text_complete or _key(game) != before, "a tap during the cut-in still reaches the story")

	game._effects.play({"op": "shake", "strength": "big", "duration": 0.2}, false)
	await create_timer(0.1).timeout
	var moved: bool = game._dialog_layer.position != Vector2.ZERO or game._bg_layer.position != Vector2.ZERO
	await create_timer(0.4).timeout
	_expect(moved and game._dialog_layer.position == Vector2.ZERO and game._bg_layer.position == Vector2.ZERO,
		"a shake moves the stage and settles back")
	_expect(game._effects.play({"op": "freeze", "duration": 0.5}, false) == 0.5 and
		game._effects.play({"op": "freeze"}, true) == 0.0, "freeze holds the story, except while skipping")

	game._save_game()
	game.queue_free()
	await _frames(2)
	var resumed: Control = _new_game()
	await _frames(3)
	resumed._on_continue_pressed()
	await _frames(2)
	_expect(resumed._effects.current_bgm == "bgm_meeting", "Continue restores the music")
	resumed.queue_free()
	await _frames(2)
	_cleanup()


func _test_testimony_and_combo() -> void:
	var game: Control = _new_game()
	await _frames(3)
	game._on_begin_pressed()
	await _play_until(game, func() -> bool: return game._screen_mode == "boke_round", "the testimony round")
	_expect(game._boke_previous_button.visible and game._boke_line_label.text.ends_with("·○○○") and
		game._boke_listen_button.visible and not game._boke_tsukkomi_button.disabled and not game._dialog_panel.censor_bar.visible,
		"line 1: browsable, four marks, can be heard out, 吐槽！ whiffs (%s)" % game._boke_line_label.text)

	await _press(game._boke_listen_button)
	await _play_until(game, func() -> bool: return game._screen_mode == "boke_round", "back from listening")
	_expect(game._runner.items.has("gin_sleep_testimony") and game._boke_listen_button.disabled and
		game._boke_listen_button.text == "已聽過", "listening plays its scene, grants the testimony and marks the line")

	await _press(game._boke_tsukkomi_button)
	await _play_until(game, func() -> bool: return game._screen_mode == "boke_round", "back from the whiff")
	_expect(game._runner.gameplay["glasses"] == 4, "a whiff on a line without a slot costs a glass")

	await _press(game._boke_next_button)
	await _press(game._boke_tsukkomi_button)
	_expect(game._screen_mode == "tsukkomi" and game._choice_sheet.visible and game._choice_buttons.size() == 3 and
		not game._choice_sheet.super_button.visible, "line 2: 吐槽！ opens the timed sheet with its three options")
	await _press(game._choice_buttons[0])
	await _play_until(game, func() -> bool: return game._screen_mode == "boke_round", "back from line 2")
	_expect(game._runner.gameplay["power"] == 30 and game._boke_tsukkomi_button.disabled and
		game._boke_tsukkomi_button.text == "已接住" and game._boke_line_label.text.ends_with("·●○○"),
		"the material option catches line 2 (%s)" % game._boke_line_label.text)

	await _press(game._boke_next_button)
	_expect(game._current_speaker == "kagura" and game._dialog_panel.censor_bar.visible, "line 3 shows its censor bar while reading")
	await _press(game._dialog_panel.censor_bar)
	await _play_until(game, func() -> bool: return game._screen_mode == "boke_round", "back from the censor bar")
	_expect(game._runner.gameplay["power"] == 60 and game._runner.stats["perfect"] == 2, "tearing off the bar is a perfect catch, untimed")

	await _press(game._boke_next_button)
	await _press(game._boke_tsukkomi_button)
	var labels: Array = game._current_options.map(func(option: Dictionary) -> String: return option["id"])
	_expect(labels == ["a", "b", "c", "d"], "with lines 2 and 3 caught the give-up is offered on line 4 (%s)" % [labels])
	await _press(game._choice_buttons[0])

	await _play_until(game, func() -> bool: return game._screen_mode == "tsukkomi", "the combo round")
	_expect(game._runner.node_id == "r2_round" and not game._boke_controls.visible and
		is_equal_approx(float(game._current_command["timer_seconds"]), 8.0) and not game._choice_sheet.super_button.visible,
		"combo line 1 opens by itself at 8 s; 90 power is not enough for the super")
	await _press(game._choice_buttons[0])
	await _play_until(game, func() -> bool: return game._screen_mode == "tsukkomi", "combo line 2")
	_expect(is_equal_approx(float(game._current_command["timer_seconds"]), 6.0) and game._choice_sheet.super_button.visible,
		"after a catch the timer drops to 6 s and the full gauge lights the super")
	game._set_ui_style("ledger", false)
	await _frames(2)
	_expect(game._choice_sheet.style_id == "ledger" and game._choice_sheet.super_button.visible and
		game._screen_mode == "tsukkomi", "switching edition keeps the super on the new sheet")
	await _press(game._choice_sheet.super_button)
	await _play_until(game, func() -> bool: return game._screen_mode == "qte", "the QTE")
	_expect(game._qte != null and game._runner.stats["perfect"] == 6, "the super catches both remaining option lines")

	var stage: Vector2 = game._game.position + Vector2(game._game.size.x * 0.5, game._game.size.y * 0.34)
	await _tap(stage)
	_expect(game._runner.node_id == "r2_qte_early" and game._runner.gameplay["glasses"] == 3,
		"tapping at once is early: a fail, and the same tap does not advance the reaction")
	await _play_until(game, func() -> bool: return game._screen_mode == "qte", "the QTE again")
	game._qte._finish(true, 0.05)
	await _play_until(game, func() -> bool: return game._screen_mode == "end", "the ending")
	var bonus_played: bool = game._history.any(func(entry: Dictionary) -> bool:
		return str(entry.get("text", "")).contains("眼鏡今天有點帥"))
	_expect(game._runner.stats["perfect"] == 7 and game._runner.node_id == "r2_clear" and not bonus_played,
		"a well-timed tap catches the QTE and the round ends; the early miss broke the combo, so no bonus scene")
	game.queue_free()
	await _frames(2)
	_cleanup()


func _test_censor_on_the_sheet_and_combo_save() -> void:
	var game: Control = _new_game()
	await _frames(3)
	game._on_begin_pressed()
	await _play_until(game, func() -> bool: return game._screen_mode == "boke_round", "the testimony round")
	game._set_boke_line(2)
	await _press(game._boke_tsukkomi_button)
	_expect(game._screen_mode == "tsukkomi" and game._choice_sheet.censor_bar.visible and game._choice_buttons.size() == 2,
		"on the timed sheet the censor bar stays tappable next to the two options")
	await _press(game._choice_sheet.censor_bar)
	await _play_until(game, func() -> bool: return game._screen_mode == "boke_round", "back from the censor bar")
	_expect(game._runner.round_state["caught"].has("l3"), "the bar on the sheet catches the line")
	game.queue_free()
	await _frames(2)

	# A save during a combo line brings the timed sheet back, never a reading screen.
	var combo: Control = _new_game()
	await _frames(3)
	combo._on_begin_pressed()
	await _play_until(combo, func() -> bool: return combo._screen_mode == "boke_round", "the testimony round")
	for step: Array in [[1, 0], [3, 0]]:
		combo._set_boke_line(step[0])
		await _press(combo._boke_tsukkomi_button)
		await _press(combo._choice_buttons[step[1]])
		await _play_until(combo, func() -> bool: return combo._screen_mode in ["boke_round", "tsukkomi"], "next line")
	combo._set_boke_line(2)
	await _press(combo._dialog_panel.censor_bar)
	await _play_until(combo, func() -> bool: return combo._screen_mode == "tsukkomi", "the combo round")
	combo._save_game()
	combo.queue_free()
	await _frames(2)
	var resumed: Control = _new_game()
	await _frames(3)
	resumed._on_continue_pressed()
	await _frames(3)
	_expect(resumed._screen_mode == "tsukkomi" and resumed._runner.node_id == "r2_round" and resumed._choice_sheet.visible,
		"Continue during a combo line reopens its timed sheet")
	resumed.queue_free()
	await _frames(2)
	_cleanup()


## Five whiffs empty the glasses: the Game Over screen shows, and its retry brings the round back
## at its checkpoint with the glasses refilled.
func _test_game_over_screen() -> void:
	var game: Control = _new_game()
	await _frames(3)
	game._on_begin_pressed()
	await _play_until(game, func() -> bool: return game._screen_mode == "boke_round", "the testimony round")
	for whiff: int in range(5):
		await _press(game._boke_tsukkomi_button)
		await _play_until(game, func() -> bool: return game._screen_mode in ["boke_round", "end"], "after whiff %d" % (whiff + 1))
	_expect(game._screen_mode == "end" and game._game_over.visible and game._game_over_retry_button.is_visible_in_tree() and
		not game._end_box.visible and game._game_over.message.text.begins_with("眼鏡耗盡"),
		"the fifth whiff ends on the Game Over screen instead of the ending buttons")
	await _press(game._game_over_retry_button)
	await _frames(3)
	_expect(not game._game_over.visible and game._screen_mode == "boke_round" and game._runner.gameplay["glasses"] == 5,
		"retry closes it and restarts the round from its checkpoint")
	game.queue_free()
	await _frames(2)
	_cleanup()


## During a v2 sheet the materials offer 拿來吐槽 for the option they back (here the bottle).
func _test_material_as_evidence() -> void:
	var game: Control = _new_game()
	await _frames(3)
	game._on_begin_pressed()
	await _play_until(game, func() -> bool: return game._screen_mode == "boke_round", "the testimony round")
	game._set_boke_line(1)
	await _press(game._boke_tsukkomi_button)
	game._open_case_file("materials")
	await _frames(2)
	var panel: Control = game._case_file_panel
	panel.call("_select", 0)
	var use: Button = panel.find_child("CaseFileUse", true, false)
	_expect(game._screen_mode == "case_file" and use.visible, "the bottle offers 拿來吐槽 on line 2's sheet")
	await _press(use)
	await _play_until(game, func() -> bool: return game._screen_mode == "boke_round", "back from the material")
	_expect(game._runner.round_state["caught"].get("l2") == "perfect", "using the material answers with the option it backs")
	game.queue_free()
	await _frames(2)
	_cleanup()


## Reads through lines and effects (completing, then advancing) until done() holds.
func _play_until(game: Control, done: Callable, label: String, seconds: float = 12.0) -> void:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if done.call():
			return
		if game._screen_mode == "story" and not game._story_busy:
			if game._text_complete:
				game._advance_current_line()
			else:
				game._complete_current_line()
		await _frames(1)
	failures.append("timed out before %s (at %s, %s)" % [label, game._runner.node_id, game._screen_mode])


func _new_game() -> Control:
	var game: Control = MAIN_SCENE.instantiate() as Control
	game.story_path = SAMPLE
	game.save_path = TEST_SAVE
	game.ui_preference_path = "user://phase4_rounds_ui_test.cfg"
	root.add_child(game)
	return game


func _key(game: Control) -> String:
	return "%s:%s:%s" % [game._screen_mode, game._runner.node_id, game._runner.step_index]


func _cleanup() -> void:
	for suffix: String in ["", ".bak", ".old", ".tmp", ".bak.tmp"]:
		var path: String = ProjectSettings.globalize_path(TEST_SAVE + suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
