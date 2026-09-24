extends SceneTree
## Headless gesture checks for the Phase 1 VN shell: one tap = one action, long-press,
## swipe-up, floating-button drag/snap/long-press, idle alpha, menu close.

var failures: Array[String] = []
var main: Control = null
const SAVE_SLOTS_SCRIPT: Script = preload("../scripts/save_slots.gd")
const TEST_SAVE: String = "user://vn_shell_slots_test.save"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_cleanup_saves()
	main = (load("res://main.tscn") as PackedScene).instantiate() as Control
	main.save_path = TEST_SAVE
	root.add_child(main)
	await _frames(3)
	_expect(main._screen_mode == "title", "starts on title")
	main._on_begin_pressed()
	await _until(func() -> bool: return main._screen_mode == "story", "story starts")

	var stage: Vector2 = main._game.position + Vector2(main._game.size.x * 0.5, main._game.size.y * 0.34)
	var before: String = _key()
	_expect(not main._text_complete, "opening line is typing")
	await _tap(stage)
	_expect(_key() == before and main._text_complete, "first tap completes without advancing")
	await _tap(stage)
	await _until(func() -> bool: return _key() != before and main._screen_mode == "story", "second tap advances")

	before = _key()
	await _press_hold_release(stage, stage, 0.75)
	_expect(main._ui_hidden and _key() == before, "long-press hides UI without advancing")
	_expect(not main._dialog_panel.visible and not main._float_layer.visible, "dialogue and buttons hidden")
	await _tap(stage)
	_expect(not main._ui_hidden and _key() == before, "tap restores UI without advancing")

	await _press_hold_release(stage + Vector2(0, 300), stage, 0.1)
	_expect(main._screen_mode == "log" and _key().ends_with(before.substr(before.find(":"))), "swipe up opens log")
	main._close_log()
	_expect(_key() == before, "closing log returns to the same line")

	var menu_button: Control = main._menu_button
	var bounds: Rect2 = menu_button.get("bounds")
	var start: Vector2 = menu_button.get_global_rect().get_center()
	await _press_hold_release(start, main._game.position + Vector2(300, bounds.position.y + 400), 0.1)
	await create_timer(0.4).timeout
	_expect(is_equal_approx(menu_button.position.x, bounds.position.x),
		"dragged menu button snaps to left edge (x=%s, left=%s)" % [menu_button.position.x, bounds.position.x])
	_expect(menu_button.position.y + menu_button.size.y <= main._dialog_panel.position.y, "button stays above dialogue")
	_expect(_key() == before, "drag does not advance")

	var save_center: Vector2 = main._save_button.get_global_rect().get_center()
	var story_position: String = _progress_key()
	await _press_hold_release(save_center, save_center, 0.8)
	_expect(main._screen_mode == "save_slots", "long-press S opens the save-slot picker")
	_expect(not FileAccess.file_exists(SAVE_SLOTS_SCRIPT.manual_path(TEST_SAVE, 1)), "opening the picker does not save a slot")
	_expect(_progress_key() == story_position, "long-press S does not advance")
	main._close_slot_picker()
	await _frames(2)
	await _tap(save_center)
	_expect(main._screen_mode == "save_slots", "tap S opens the same save-slot picker")
	_expect(_progress_key() == story_position, "tap S does not advance")
	main._close_slot_picker()
	await _frames(2)

	main._last_activity_ms = Time.get_ticks_msec() - 5000
	await create_timer(0.6).timeout
	_expect(main._float_alpha <= main.IDLE_ALPHA + 0.05, "idle buttons fade to 40%%")

	await _tap(menu_button.get_global_rect().get_center())
	_expect(main._screen_mode == "menu", "tap menu button opens menu")
	await _tap(main._game.position + Vector2(160, main._game.size.y - 160))
	_expect(main._screen_mode == "story" and _key() == before, "tap dim background closes menu without advancing")
	await create_timer(0.3).timeout
	_expect(main._float_alpha > 0.9, "interaction restores button opacity")

	main._set_skip(true)
	await _until(func() -> bool: return main._screen_mode == "choice", "SKIP runs to the choice", 20.0)
	_expect(not main._skip, "SKIP stops at the choice")

	if failures.is_empty():
		print("VN SHELL TESTS PASSED")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		print("VN SHELL TESTS FAILED: %d" % failures.size())
		quit(1)
	_cleanup_saves()


func _key() -> String:
	return "%s:%s:%s" % [main._screen_mode, main._runner.node_id, main._runner.step_index]


func _progress_key() -> String:
	return "%s:%s" % [main._runner.node_id, main._runner.step_index]


func _cleanup_saves() -> void:
	for slot_index: int in range(1, SAVE_SLOTS_SCRIPT.SLOT_COUNT + 1):
		_remove_save_path(SAVE_SLOTS_SCRIPT.manual_path(TEST_SAVE, slot_index))
	for suffix: String in ["", ".bak", ".old", ".tmp", ".bak.tmp"]:
		_remove_save_path(TEST_SAVE + suffix)


func _remove_save_path(path: String) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func _mouse(at: Vector2, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	event.global_position = at
	root.push_input(event, true)


func _move(at: Vector2) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.position = at
	event.global_position = at
	root.push_input(event, true)


func _tap(at: Vector2) -> void:
	_mouse(at, true)
	await _frames(1)
	_mouse(at, false)
	await _frames(3)


func _press_hold_release(from: Vector2, to: Vector2, hold: float) -> void:
	_mouse(from, true)
	await _frames(1)
	for step: int in range(1, 7):
		_move(from.lerp(to, step / 6.0))
		await _frames(1)
	await create_timer(hold).timeout
	_mouse(to, false)
	await _frames(3)


func _frames(count: int) -> void:
	for i: int in range(count):
		await process_frame


func _until(condition: Callable, label: String, timeout: float = 5.0) -> void:
	var deadline: int = Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return
		await process_frame
	failures.append("timed out: " + label)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
		print("FAIL: ", label, " [", _key(), "]")
