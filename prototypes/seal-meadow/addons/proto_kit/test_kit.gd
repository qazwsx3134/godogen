extends SceneTree
## Base for headless test scripts: `godot --headless --path . --script res://tests/test_x.gd`.
## `extends "res://addons/proto_kit/test_kit.gd"`, run the suite from _init (or a deferred
## _run for UI tests that need the tree), then call _finish("SUITE NAME").
##
## A SCRIPT ERROR anywhere during the run (a null access in the game or the test) counts as a failure, so a
## suite whose test function died halfway never prints PASSED. Parse errors stop the script before it runs at
## all, so a runner should still grep the log for "Parse Error".

var failures: Array[String] = []
var checks: int = 0
## Registered from the member initializer: subclasses define their own _init without calling super().
var _script_errors: _ScriptErrors = _listen()


class _ScriptErrors extends Logger:
	var lines: Array[String] = []
	var _lock := Mutex.new()

	func _log_error(function: String, file: String, line: int, _code: String, rationale: String,
			_editor_notify: bool, error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_SCRIPT:
			_lock.lock()
			lines.append("%s (%s:%d %s)" % [rationale, file, line, function])
			_lock.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


static func _listen() -> _ScriptErrors:
	var errors := _ScriptErrors.new()
	OS.add_logger(errors)
	return errors


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		print("FAIL: ", label)


func _finish(suite: String) -> void:
	OS.remove_logger(_script_errors)
	for line: String in _script_errors.lines:
		failures.append("SCRIPT ERROR: " + line)
	if failures.is_empty():
		print("%s PASSED" % suite)
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		print("%s FAILED: %d" % [suite, failures.size()])
		quit(1)


func _frames(count: int = 1) -> void:
	for _frame: int in range(count):
		await process_frame


## Records a failure on timeout instead of hanging the suite.
func _until(condition: Callable, label: String, timeout: float = 5.0) -> void:
	var deadline: int = Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return
		await process_frame
	failures.append("timed out: " + label)


## _mouse, _move, _tap and _drag push events straight into the root viewport, at
## viewport coordinates. Use them for gestures on arbitrary points.
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


## Press at from, move to to in six steps, hold, release. Covers long-press, swipe and drag.
func _drag(from: Vector2, to: Vector2, hold: float) -> void:
	_mouse(from, true)
	await _frames(1)
	for step: int in range(1, 7):
		_move(from.lerp(to, step / 6.0))
		await _frames(1)
	await create_timer(hold).timeout
	_mouse(to, false)
	await _frames(3)


## Clicks a button the way a player does: scrolls it into view, then sends hover, down and
## up through Input, so hover, focus and ScrollContainer handling all run.
func _press(button: BaseButton) -> void:
	_expect(not button.disabled, "Button enabled: " + button.name)
	if button.disabled:
		return
	var ancestor: Node = button.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(button)
		ancestor = ancestor.get_parent()
	await _frames(3)
	await create_timer(0.05).timeout
	var position: Vector2 = root.get_final_transform() * button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	Input.parse_input_event(motion)
	await process_frame
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = position
		Input.parse_input_event(event)
		await process_frame
	await _frames(2)
