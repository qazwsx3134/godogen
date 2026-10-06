extends "res://addons/proto_kit/test_kit.gd"
## Headless gesture checks for the Phase 1 VN shell: one tap = one action, long-press,
## swipe-up, the reading box's toolbar (目錄/回顧/自動) and 續 button, 目錄 actions, menu close.

var main: Control = null
const SAVE_SLOTS_SCRIPT: Script = preload("../scripts/save_slots.gd")
const TEST_SAVE: String = "user://vn_shell_slots_test.save"
const TEST_UI: String = "user://vn_shell_ui_test.cfg"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_cleanup_saves()
	main = (load("res://main.tscn") as PackedScene).instantiate() as Control
	main.save_path = TEST_SAVE
	main.ui_preference_path = TEST_UI
	root.add_child(main)
	await _frames(3)
	_expect(main._screen_mode == "title", "starts on title")
	main._on_begin_pressed()
	await _until(func() -> bool: return main._screen_mode == "story", "story starts")

	var stage: Vector2 = main._game.position + Vector2(main._game.size.x * 0.5, main._game.size.y * 0.34)
	var before: String = _key()
	_expect(not main._text_complete, "opening line is typing")
	var typing_height: float = main._dialog_panel.size.y
	await _tap(stage)
	_expect(_key() == before and main._text_complete, "first tap completes without advancing")
	_expect(is_equal_approx(main._dialog_panel.size.y, typing_height), "the box keeps its height while the line types out")
	await _tap(stage)
	await _until(func() -> bool: return _key() != before and main._screen_mode == "story", "second tap advances")

	_expect(not main._text_complete, "the next line is typing")
	main._open_menu()
	await _until(func() -> bool: return main._text_complete, "the line finishes behind 目錄")
	main._close_menu()
	_expect(main._advance_button.is_visible_in_tree(), "續 is back after 目錄 closes on a line that finished behind it")

	before = _key()
	await _drag(stage, stage, 0.75)
	_expect(main._ui_hidden and _key() == before, "long-press hides UI without advancing")
	_expect(not main._dialog_panel.visible, "dialogue box and its toolbar hidden")
	await _tap(stage)
	_expect(not main._ui_hidden and _key() == before, "tap restores UI without advancing")

	await _drag(stage + Vector2(0, 300), stage, 0.1)
	_expect(main._screen_mode == "log" and _key().ends_with(before.substr(before.find(":"))), "swipe up opens log")
	main._close_log()
	_expect(_key() == before, "closing log returns to the same line")

	var box: Rect2 = main._dialog_panel.get_global_rect()
	_expect(box.end.y <= main._game.get_global_rect().end.y + 0.5, "the box sits on the bottom edge")
	for button: Button in [main._menu_button, main._log_button, main._auto_button, main._advance_button]:
		_expect(button.is_visible_in_tree() and box.encloses(button.get_global_rect()), "%s is inside the box" % button.name)
	await _tap(main._auto_button.get_global_rect().get_center())
	_expect(main._auto and main._auto_button.button_pressed and _key() == before, "自動 turns on without advancing")
	await _tap(main._auto_button.get_global_rect().get_center())
	_expect(not main._auto and not main._auto_button.button_pressed, "自動 turns off again")

	var story_position: String = _progress_key()
	await _tap(main._menu_button.get_global_rect().get_center())
	_expect(main._screen_mode == "menu" and _progress_key() == story_position, "tap 目錄 opens the menu without advancing")
	_expect(main._menu_items["save"].is_visible_in_tree() and not main._menu_items["skip"].disabled,
		"the menu offers 儲存進度 and 略讀")
	await _reveal_menu(main._menu_style_buttons["ledger"])
	await _tap(main._menu_style_buttons["ledger"].get_global_rect().get_center())
	await _frames(2)
	_expect(main._dialog_panel.style_id == "ledger" and main._text_label.text == main._full_text and
		main._dialog_layer.get_children().filter(func(n: Node) -> bool: return n.has_method("set_tone")).size() == 1,
		"B 委託簿 in the menu swaps in the ledger box with the same line")
	await _tap(main._menu_items["save"].get_global_rect().get_center())
	_expect(main._screen_mode == "save_slots", "儲存進度 opens the save-slot picker")
	_expect(not FileAccess.file_exists(SAVE_SLOTS_SCRIPT.manual_path(TEST_SAVE, 1)), "opening the picker does not save a slot")
	main._close_slot_picker()
	await _frames(2)
	_expect(main._screen_mode == "menu", "closing the picker returns to the menu")
	await _tap(main._game.position + Vector2(20, main._game.size.y * 0.5))
	_expect(main._screen_mode == "story" and _key() == before, "tap dim background closes menu without advancing")
	_expect(main._advance_button.is_visible_in_tree(), "續 shows in the new box after the menu closes")

	await _tap(main._advance_button.get_global_rect().get_center())
	await _until(func() -> bool: return _key() != before and main._screen_mode == "story", "tap 續 advances")

	await _tap(main._menu_button.get_global_rect().get_center())
	await _tap(main._menu_items["resume"].get_global_rect().get_center())
	_expect(main._screen_mode == "story" and not main._menu_overlay.visible, "回到故事 closes the menu")
	await _tap(main._menu_button.get_global_rect().get_center())
	await _reveal_menu(main._menu_items["skip"])
	await _tap(main._menu_items["skip"].get_global_rect().get_center())
	_expect(main._skip and main._screen_mode != "menu", "略讀 in the menu starts skipping")
	await _until(func() -> bool: return main._screen_mode == "choice", "SKIP runs to the choice", 20.0)
	_expect(not main._skip, "SKIP stops at the choice")

	await _frames(2)
	_expect(main._choice_sheet.visible and not main._dialog_panel.visible and
		main._choice_sheet.prompt.text == main._full_text and main._choice_buttons.size() == main._current_options.size(),
		"the choice sheet takes the box's place with the prompt and one row per option")
	await _tap(main._choice_sheet.menu_button.get_global_rect().get_center())
	_expect(main._screen_mode == "menu", "目錄 on the sheet opens the menu")
	main._close_menu()
	_expect(main._screen_mode == "choice" and main._choice_sheet.visible, "closing the menu returns to the choice")
	var picked: String = str(main._current_options[0]["label"])
	await _tap(main._choice_buttons[0].get_global_rect().get_center())
	await _until(func() -> bool: return main._screen_mode == "story", "tapping a row answers the choice")
	_expect(main._dialog_panel.visible and not main._choice_sheet.visible and
		main._history.any(func(entry: Dictionary) -> bool: return entry.get("kind") == "choice" and entry.get("text") == picked),
		"the box comes back and the pick is in the log")

	main.queue_free()
	await _frames(2)
	_finish("VN SHELL TESTS")
	_cleanup_saves()


func _reveal_menu(control: Control) -> void:
	await create_timer(0.2).timeout
	main._menu_overlay.rows_scroll.ensure_control_visible(control)
	await _frames(3)


func _key() -> String:
	return "%s:%s:%s" % [main._screen_mode, main._runner.node_id, main._runner.step_index]


func _progress_key() -> String:
	return "%s:%s" % [main._runner.node_id, main._runner.step_index]


func _cleanup_saves() -> void:
	for slot_index: int in range(1, SAVE_SLOTS_SCRIPT.SLOT_COUNT + 1):
		_remove_save_path(SAVE_SLOTS_SCRIPT.manual_path(TEST_SAVE, slot_index))
	for suffix: String in ["", ".bak", ".old", ".tmp", ".bak.tmp"]:
		_remove_save_path(TEST_SAVE + suffix)
	_remove_save_path(TEST_UI)


func _remove_save_path(path: String) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
		print("FAIL: ", label, " [", _key(), "]")
