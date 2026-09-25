extends "res://addons/proto_kit/test_kit.gd"
## Phase 3 VN-shell flow, overlay timer, and save/restore integration.

const MAIN_SCENE: PackedScene = preload("../main.tscn")
const SAVE_SLOTS_SCRIPT: Script = preload("../scripts/save_slots.gd")
const STORY_PATH: String = "res://data/phase3_story.json"
const TEST_SAVE: String = "user://phase3_ui_test.save"
const WEAK_SAVE: String = "user://phase3_ui_weak.save"
const HIDDEN_SAVE: String = "user://phase3_ui_hidden.save"
const RETRY_SAVE: String = "user://phase3_ui_retry.save"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_cleanup_saves()
	await _test_investigation_save_boke_load_and_perfect()
	await _test_weak_and_hidden_feedback()
	await _test_zero_timer_restore()
	await _test_timeout_five_fails_and_checkpoint_retry()
	_cleanup_saves()
	_finish("PHASE 3 UI TESTS")


func _test_investigation_save_boke_load_and_perfect() -> void:
	var game: Control = _new_game(TEST_SAVE)
	await _frames(3)
	_expect(game._story_ready and game._phase3_enabled, "Phase 3 sample loads in the presentation shell")
	_expect(game.PHASE3_SAVE_PATH == "user://strawberry_phase3.save", "Phase 3 variant has a separate autosave path")
	await _start_to_investigation(game)
	var investigation_snapshot: Dictionary = game._runner.call("snapshot") as Dictionary
	_expect(game._save_game(), "investigation state saves to autosave")
	_expect(game._saveable_current_state(), "stable investigation state is saveable")
	var hotspot: Button = game._hotspot_buttons.get("empty_milk_bottle") as Button
	_expect(hotspot != null and not hotspot.disabled, "uninspected hotspot is tappable")
	if hotspot != null:
		var hotspot_rect: Rect2 = hotspot.get_global_rect()
		_expect(hotspot_rect.position.y >= 0.0 and hotspot_rect.end.y < game._dialog_panel.position.y,
			"hotspot target remains in the visible stage above dialogue")
		_expect(hotspot.size.y >= 120.0, "hotspot keeps a touch-sized target")
	_expect(game._investigation_continue_button.disabled, "investigation cannot continue before inspection")

	game.queue_free()
	await _frames(2)
	var resumed: Control = _new_game(TEST_SAVE)
	await _frames(3)
	_expect(not resumed._continue_button.disabled, "investigation autosave enables Continue")
	resumed._on_continue_pressed()
	await _until(func() -> bool: return resumed._screen_mode == "investigate", "restore investigation state")
	_expect(resumed._runner.call("snapshot").get("node_id", "") == investigation_snapshot.get("node_id", ""),
		"Continue restores the investigation reading point")
	_expect(resumed._runner.items.is_empty(), "Continue preserves the unchecked clue state")
	_expect(resumed._investigation_continue_button.disabled, "restored unchecked investigation still blocks continuation")
	resumed._on_hotspot_pressed("empty_milk_bottle")
	_expect(resumed._runner.items == ["milk_bottle"], "hotspot grants the clue item")
	_expect(resumed._hotspot_buttons["empty_milk_bottle"].disabled, "inspected hotspot displays checked state")
	_expect(resumed._phase3_inventory_label.text.contains("草莓牛奶瓶"), "HUD reflects acquired clue")
	_expect(resumed._investigation_continue_button.disabled == false, "clue enables investigation continuation")
	_expect(resumed._save_game(), "checked investigation state saves")
	resumed._on_investigation_continue_pressed()
	await _until(func() -> bool: return resumed._screen_mode == "boke_round", "enter boke round")
	_expect(is_zero_approx(resumed._boke_time_remaining), "statement-reading stage has no active countdown")
	_expect(resumed._choice_buttons.is_empty(), "statement-reading stage hides all tsukkomi options")
	_expect(resumed._boke_tsukkomi_button.visible and resumed._boke_tsukkomi_button.text == "吐槽！",
		"statement-reading stage exposes a distinct Tsukkomi action")
	_expect(resumed._boke_tsukkomi_button.size.x >= 200.0 and resumed._boke_tsukkomi_button.size.y >= 120.0,
		"Tsukkomi action keeps a touch-sized target")
	var reading_autosave: Dictionary = resumed._read_save_payload(TEST_SAVE)
	_expect(String(reading_autosave.get("boke_ui_screen", "")) == "boke_round" and
		not reading_autosave.has("boke_timer_remaining"), "reading autosave preserves the untimed stage")
	_expect(resumed._saveable_current_state(), "statement-reading stage is saveable")
	await resumed._open_slot_picker("save")
	_expect(resumed._screen_mode == "save_slots" and not resumed._slot_card_buttons[0].disabled,
		"statement-reading stage can be saved to a manual slot")
	resumed._on_slot_card_pressed(0)
	await _frames(2)
	var reading_slot_path: String = SAVE_SLOTS_SCRIPT.manual_path(TEST_SAVE, 1)
	var reading_slot_payload: Dictionary = resumed._read_save_payload(reading_slot_path)
	_expect(String(reading_slot_payload.get("boke_ui_screen", "")) == "boke_round" and
		not reading_slot_payload.has("boke_timer_remaining"), "manual reading save stores its screen without a timer")
	resumed.queue_free()
	await _frames(2)

	var loaded: Control = _new_game(TEST_SAVE)
	await _frames(3)
	await loaded._open_slot_picker("load")
	loaded._on_slot_card_pressed(0)
	_expect(loaded._screen_mode == "boke_round" and loaded._choice_buttons.is_empty(),
		"manual reading load restores statement controls without options")
	loaded.queue_free()
	await _frames(2)

	loaded = _new_game(TEST_SAVE)
	await _frames(3)
	loaded._on_continue_pressed()
	_expect(loaded._screen_mode == "boke_round" and loaded._choice_buttons.is_empty(),
		"autosave Continue restores the statement-reading stage")
	await create_timer(8.1).timeout
	_expect(loaded._screen_mode == "boke_round" and int(loaded._runner.gameplay["glasses"]) == 5,
		"statement reading can exceed eight seconds without a timeout")
	_expect(is_zero_approx(loaded._boke_time_remaining), "untimed statement reading leaves the timer unstarted")
	loaded._on_boke_next_pressed()
	_expect(int(loaded._current_command.get("line_index", -1)) == 1, "line navigation moves to second boke line")
	loaded._on_boke_listen_pressed()
	_expect(bool(loaded._current_command.get("listened", false)), "Listen action reveals follow-up line")
	_expect(loaded._visible_text.contains("自動幫忙喝牛奶"), "Listen follow-up appears in dialogue panel")
	loaded._on_boke_tsukkomi_pressed()
	_expect(loaded._screen_mode == "tsukkomi", "吐槽！ enters the timed option screen")
	_expect(loaded._boke_time_remaining > 7.0 and loaded._boke_time_remaining <= 8.0,
		"eight-second countdown starts on the option screen")
	_expect(loaded._choice_buttons.size() == 4, "option screen presents all four outcome choices")
	_expect(not loaded._boke_controls.visible, "option screen hides statement navigation controls")
	_expect(loaded._saveable_current_state(), "tsukkomi option screen is saveable")
	var choice_autosave: Dictionary = loaded._read_save_payload(TEST_SAVE)
	_expect(String(choice_autosave.get("boke_ui_screen", "")) == "tsukkomi" and
		choice_autosave.has("boke_timer_remaining"), "choice autosave stores active stage and countdown")
	var autosaved_timer: float = float(choice_autosave.get("boke_timer_remaining", -1.0))
	loaded.queue_free()
	await _frames(2)

	loaded = _new_game(TEST_SAVE)
	await _frames(3)
	loaded._on_continue_pressed()
	_expect(loaded._screen_mode == "tsukkomi" and loaded._choice_buttons.size() == 4,
		"autosave Continue restores the timed option screen")
	_expect(is_equal_approx(loaded._boke_time_remaining, autosaved_timer),
		"autosave Continue restores the remaining countdown")
	_expect(int(loaded._runner.call("snapshot")["boke"]["line_index"]) == 1,
		"choice restore retains the selected statement line")
	_expect(loaded._runner.call("snapshot")["boke"]["listened_line_ids"].has("sleep_excuse"),
		"choice restore retains Listen state")
	var remaining_before_menu: float = loaded._boke_time_remaining
	loaded._open_menu()
	await _frames(18)
	_expect(loaded._screen_mode == "menu", "menu overlay opens during the option screen")
	_expect(is_equal_approx(loaded._boke_time_remaining, remaining_before_menu), "countdown pauses while Menu is open")
	loaded._close_menu()
	await _frames(6)
	_expect(loaded._boke_time_remaining < remaining_before_menu, "countdown resumes after Menu closes")
	var remaining_before_log: float = loaded._boke_time_remaining
	loaded._open_log()
	await _frames(18)
	_expect(loaded._screen_mode == "log" and is_equal_approx(loaded._boke_time_remaining, remaining_before_log),
		"countdown pauses while the log overlay is open")
	loaded._close_log()
	await _frames(6)
	_expect(loaded._boke_time_remaining < remaining_before_log, "countdown resumes after the log closes")
	# Hold a known remainder for the serialization check; the pause/resume behavior
	# above already exercises the real countdown without relying on wall-clock speed.
	loaded._boke_time_remaining = 5.25
	var timer_at_save: float = loaded._boke_time_remaining
	await loaded._open_slot_picker("save")
	_expect(loaded._screen_mode == "save_slots" and not loaded._slot_card_buttons[1].disabled,
		"stable tsukkomi screen can save to a manual slot")
	await _frames(4)
	_expect(is_equal_approx(loaded._boke_time_remaining, timer_at_save),
		"countdown remains paused while the slot picker is open")
	loaded._on_slot_card_pressed(1)
	await _frames(2)
	var boke_slot_path: String = SAVE_SLOTS_SCRIPT.manual_path(TEST_SAVE, 2)
	var boke_payload: Dictionary = loaded._read_save_payload(boke_slot_path)
	_expect(not boke_payload.is_empty(), "manual slot stores valid boke snapshot")
	_expect(String(boke_payload.get("boke_ui_screen", "")) == "tsukkomi",
		"manual choice save preserves the option screen")
	var saved_timer: float = float(boke_payload.get("boke_timer_remaining", -1.0))
	_expect(is_equal_approx(saved_timer, timer_at_save),
		"manual boke save includes paused countdown remainder (saved %.3f, expected %.3f)" % [saved_timer, timer_at_save])
	var legacy_choice_payload: Dictionary = boke_payload.duplicate(true)
	legacy_choice_payload.erase("boke_ui_screen")
	_expect(loaded._validate_save_payload(legacy_choice_payload), "legacy combined-screen boke save remains valid")
	_expect(loaded._apply_save_payload(legacy_choice_payload), "legacy boke save restores")
	loaded._render_restored_current()
	_expect(loaded._screen_mode == "tsukkomi", "legacy boke save with a timer migrates to the option screen")
	var boke_snapshot: Dictionary = boke_payload.get("runner", {}) as Dictionary
	_expect(int((boke_snapshot.get("boke", {}) as Dictionary).get("line_index", -1)) == 1,
		"manual boke save retains selected line")
	_expect(((boke_snapshot.get("boke", {}) as Dictionary).get("listened_line_ids", []) as Array).has("sleep_excuse"),
		"manual boke save retains Listen state")

	loaded.queue_free()
	await _frames(2)
	loaded = _new_game(TEST_SAVE)
	await _frames(3)
	await loaded._open_slot_picker("load")
	loaded._on_slot_card_pressed(1)
	await _until(func() -> bool: return loaded._screen_mode == "tsukkomi", "load manual boke snapshot")
	_expect(loaded._choice_buttons.size() == 4 and loaded._boke_time_remaining > 0.0,
		"manual choice load restores options and remaining time")
	_expect(int(loaded._runner.call("snapshot")["boke"]["line_index"]) == 1, "loaded boke returns to saved line")
	_expect(bool(loaded._runner.call("snapshot")["boke"]["listened_line_ids"].has("sleep_excuse")), "loaded boke retains Listen state")
	_expect(loaded._runner.items.has("milk_bottle"), "loaded boke retains acquired item")
	_expect(is_equal_approx(loaded._boke_time_remaining, float(boke_payload["boke_timer_remaining"])),
		"loaded boke resumes from the saved countdown remainder")
	loaded._on_boke_option_pressed("point_to_bottle")
	await _until(func() -> bool: return loaded._screen_mode == "story" and loaded._runner.node_id == "perfect", "perfect result feedback")
	_expect(String(loaded._last_boke_result) == "perfect", "perfect choice reports result feedback")
	_expect(int(loaded._runner.gameplay["power"]) == 30, "perfect result updates power HUD state")
	_expect(loaded._phase3_stats_label.text.contains("30/100"), "HUD visibly reflects perfect power increase")
	_expect(loaded._toast.text.contains("完美吐槽"), "perfect outcome displays result feedback")
	loaded.queue_free()
	await _frames(2)


func _test_weak_and_hidden_feedback() -> void:
	var weak: Control = _new_game(WEAK_SAVE)
	await _start_to_round(weak)
	weak._on_boke_tsukkomi_pressed()
	weak._on_boke_option_pressed("weak_comeback")
	await _until(func() -> bool: return weak._screen_mode == "story" and weak._runner.node_id == "weak", "weak result feedback")
	_expect(String(weak._last_boke_result) == "weak" and int(weak._runner.gameplay["power"]) == 10,
		"weak outcome gives power and exposes its result")
	_expect(weak._toast.text.contains("力量 +10"), "weak outcome feedback is visible")
	weak.queue_free()
	await _frames(2)

	var hidden: Control = _new_game(HIDDEN_SAVE)
	await _start_to_round(hidden)
	hidden._on_boke_tsukkomi_pressed()
	hidden._on_boke_option_pressed("secret_comeback")
	await _until(func() -> bool: return hidden._screen_mode == "story" and hidden._runner.node_id == "hidden", "hidden result feedback")
	_expect(String(hidden._last_boke_result) == "hidden", "give-up route reports hidden result")
	_expect(int(hidden._runner.gameplay["glasses"]) == 5 and int(hidden._runner.gameplay["power"]) == 0,
		"hidden outcome leaves stats unchanged")
	_expect(hidden._toast.text.contains("放棄吐槽"), "give-up outcome feedback is visible")
	hidden.queue_free()
	await _frames(2)


func _test_zero_timer_restore() -> void:
	var game: Control = _new_game(RETRY_SAVE)
	await _start_to_round(game)
	game._on_boke_tsukkomi_pressed()
	var payload: Dictionary = game._build_save_payload("")
	payload["boke_timer_remaining"] = 0.0
	_expect(game._validate_save_payload(payload), "zero-second boke snapshot remains a valid save")
	_expect(game._apply_save_payload(payload), "zero-second boke snapshot restores")
	game._render_restored_current()
	await _until(func() -> bool: return game._screen_mode == "story" and game._runner.node_id == "cold",
		"restored zero countdown immediately times out")
	_expect(int(game._runner.gameplay["glasses"]) == 4, "restored zero countdown applies one fail")
	game.queue_free()
	await _frames(2)


func _test_timeout_five_fails_and_checkpoint_retry() -> void:
	var game: Control = _new_game(RETRY_SAVE)
	await _start_to_round(game)
	game._on_boke_tsukkomi_pressed()
	game._boke_time_remaining = 0.02
	await _until(func() -> bool: return game._screen_mode == "story" and game._runner.node_id == "cold", "UI countdown triggers timeout", 3.0)
	_expect(String(game._last_boke_result) == "fail" and int(game._runner.gameplay["glasses"]) == 4,
		"timeout applies fail feedback and consumes one glass")

	for failure_index: int in range(4):
		await _continue_cold_to_round(game)
		game._on_boke_option_pressed("missed_comeback")
		if failure_index < 3:
			await _until(func() -> bool: return game._screen_mode == "story" and game._runner.node_id == "cold",
				"fail %d reaches cold dialogue" % (failure_index + 2))
		else:
			await _until(func() -> bool: return game._screen_mode == "story" and game._runner.node_id == "game_over",
				"fifth fail reaches Game Over")
	_expect(int(game._runner.gameplay["glasses"]) == 0, "five failed rounds exhaust glasses")
	_expect(bool((game._runner.call("snapshot") as Dictionary).get("game_over_active", false)), "Game Over marks retry state active")
	game._complete_current_line()
	game._advance_current_line()
	await _until(func() -> bool: return game._screen_mode == "end", "Game Over end controls")
	_expect(game._game_over_retry_button.visible, "Game Over exposes checkpoint retry control")
	game._on_game_over_retry_pressed()
	_expect(game._screen_mode == "boke_round", "retry_checkpoint returns to boke round")
	_expect(int(game._runner.gameplay["glasses"]) == 5 and int(game._runner.gameplay["power"]) == 0,
		"checkpoint retry restores pre-round stats")
	_expect(game._runner.items.has("milk_bottle"), "checkpoint retry keeps pre-round clue")
	game.queue_free()
	await _frames(2)


func _new_game(save_path: String) -> Control:
	var game: Control = MAIN_SCENE.instantiate() as Control
	game.story_path = STORY_PATH
	game.save_path = save_path
	root.add_child(game)
	return game


func _start_to_investigation(game: Control) -> void:
	game._on_begin_pressed()
	game._set_skip(true)
	await _until(func() -> bool: return game._screen_mode == "investigate", "reach investigation")


func _start_to_round(game: Control) -> void:
	await _frames(3)
	await _start_to_investigation(game)
	game._on_hotspot_pressed("empty_milk_bottle")
	game._on_investigation_continue_pressed()
	await _until(func() -> bool: return game._screen_mode == "boke_round", "reach boke round")


func _continue_cold_to_round(game: Control) -> void:
	_expect(game._screen_mode == "story" and game._runner.node_id == "cold", "failure loop waits at cold dialogue")
	if not game._text_complete:
		game._complete_current_line()
	game._advance_current_line()
	await _until(func() -> bool: return game._screen_mode == "boke_round", "cold route loops into boke round")
	game._on_boke_tsukkomi_pressed()


func _cleanup_saves() -> void:
	for base: String in [TEST_SAVE, WEAK_SAVE, HIDDEN_SAVE, RETRY_SAVE]:
		var paths: Array[String] = [base, base + ".bak", base + ".bak.old", base + ".old", base + ".tmp"]
		for slot_index: int in [1, 2]:
			var manual_path: String = SAVE_SLOTS_SCRIPT.manual_path(base, slot_index)
			paths.append_array([manual_path, manual_path + ".bak", manual_path + ".bak.old",
				manual_path + ".old", manual_path + ".tmp"])
		for path: String in paths:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
