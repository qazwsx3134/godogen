extends SceneTree
## Base for headless test scripts: `godot --headless --path . --script res://tests/test_x.gd`.
## `extends "res://addons/proto_kit/test_kit.gd"`, run the suite from _init (or a deferred
## _run for UI tests that need the tree), then call _finish("SUITE NAME").
##
## Godot exits 0 even after a SCRIPT ERROR, so a runner must also grep the log for
## "SCRIPT ERROR|Parse Error"; the exit code alone can show a broken suite as green.

var failures: Array[String] = []
var checks: int = 0


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		print("FAIL: ", label)


func _finish(suite: String) -> void:
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
