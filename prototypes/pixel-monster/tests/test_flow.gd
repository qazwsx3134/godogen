extends SceneTree
## Exercises the real scene, button routes, coordinator, save/reload and a whole upbringing.

const Scene = preload("res://scenes/main.tscn")
const Saves = preload("res://domain/save_service.gd")
var main: Control
var save_path: String = ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if "--expect-packed" in OS.get_cmdline_user_args():
		for asset in ["res://data/balance.json", "res://data/opponents.json", "res://assets/fonts/OFL.txt"]:
			_expect(FileAccess.file_exists(asset), "Export includes " + asset)
	create_timer(80.0).timeout.connect(func() -> void:
		push_error("Integration flow exceeded 80 seconds")
		quit(2)
	)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--save-path="):
			save_path = argument.trim_prefix("--save-path=")
	if not save_path.begins_with("/tmp/pixel-monster-test-"):
		push_error("Supply an isolated --save-path=/tmp/pixel-monster-test-NAME.json")
		quit(2)
		return
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(save_path + suffix):
			DirAccess.remove_absolute(save_path + suffix)
	root.size = Vector2i(480, 900)
	main = Scene.instantiate()
	root.add_child(main)
	await _frames()
	_check(main.session.state.pet.is_empty(), "New game must begin with one egg")
	_check(FileAccess.file_exists(save_path), "New egg persisted")
	_check(root.gui_get_focus_owner() == main.find_child("EggActivity", true, false), "Egg activity receives initial keyboard focus")
	var egg_locked_hint: Label = main.find_child("EggLockedHint", true, false) as Label
	_check(egg_locked_hint != null and egg_locked_hint.is_visible_in_tree() and egg_locked_hint.text.contains("孵化後"), "Egg home visibly explains locked navigation")
	_assert_touch_targets(["Settings", "EggActivity", "Scale", "Food", "Battle", "Heal", "Steps", "Collection"], "new egg home")
	_assert_pet_navigation(true, "new egg home")
	if not main.session.debug_enabled:
		await _release_flow()
		_finish_flow()
		return
	main.session.setting("auto_lights", false)
	# A CI run can start at any local hour. Test sleep scheduling separately in
	# the domain suite; keep this interactive journey awake at its starting time.
	main.session.setting("sleep_hour", 0)
	main.session.setting("wake_hour", 0)
	await _capture("01-egg")
	await _click("Steps")
	await _click("Mock100")
	_expect(int(main.session.state.egg.credited_steps) == 100, "UI mock credit reaches 100")
	var credited: int = int(main.session.state.egg.credited_steps)
	await _click("SyncSteps")
	_expect(int(main.session.state.egg.credited_steps) == credited, "Repeated sync cannot double count")
	await _click("Mock1000")
	_expect(not main.session.state.pet.is_empty(), "Mock UI hatches pet")
	var pet_id: String = str(main.session.state.pet.get("id", ""))
	_expect(Saves.load_state(save_path).pet.get("id", "") == pet_id, "Hatch saved before presentation")
	await _click("MilestoneContinue")
	await _capture("02-companion")
	_assert_touch_targets(["Settings", "Train", "Clean", "Lights", "Scale", "Food", "Battle", "Heal", "Steps", "Collection"], "companion home")
	_assert_pet_navigation(false, "companion home")
	_check(not main.find_child("EggLockedHint", true, false).is_visible_in_tree(), "Egg navigation explanation hides after hatching")
	await _click("Food")
	_check(main.find_child("Food", true, false).focus_mode == Control.FOCUS_NONE, "Open modal removes background controls from keyboard focus")
	_check(root.gui_get_focus_owner() == main.find_child("CloseModal", true, false), "Open modal places keyboard focus inside the dialog")
	var fullness_before_meal: float = float(main.session.state.pet.fullness)
	await _click("Meal")
	var fullness_after_meal: float = float(main.session.state.pet.fullness)
	_check(fullness_after_meal > fullness_before_meal, "Meal increases fullness")
	_check(is_equal_approx(float(Saves.load_state(save_path).pet.fullness), fullness_after_meal), "Meal result persists")
	_check(root.gui_get_focus_owner() == main.find_child("Food", true, false), "Care modal returns focus to its launcher")
	await _click("Scale")
	await _capture("03-diary")
	await _click("CloseModal")
	# Open every care panel. Disabled controls must carry a visible explanation.
	for control_name in ["Clean", "Lights", "Heal"]:
		await _click(control_name)
		_expect(is_instance_valid(main.overlay), control_name + " panel opens")
		await _click("CloseModal")
	await _click("Train")
	await _click("TrainPower")
	await _capture("04-training")
	for delay in [1.0, 5.0, 5.0]:
		await create_timer(delay).timeout
		await _click("TimingHit")
	await create_timer(4.5).timeout
	_expect(int(main.session.state.pet.training_count) == 1, "Real 15-second training completes exactly once")
	_expect(int(main.session.state.pet.training.power) > 0, "Timing game delivers growth")
	await _click("TrainingDone")
	_check(root.gui_get_focus_owner() == main.find_child("Train", true, false), "Chained training modals return focus to their launcher")
	await _click("Battle")
	await _click("Battle_moss_scout")
	_expect(not main.session.state.pending_battle.is_empty(), "NPC battle starts from UI")
	var frozen: Dictionary = main.session.state.pending_battle.duplicate(true)
	var saved: Dictionary = Saves.load_state(save_path)
	_expect(saved.pending_battle == JSON.parse_string(JSON.stringify(frozen)), "Full frozen battle persisted before animation")
	await _reopen_scene()
	_expect(main.session.state.pending_battle == JSON.parse_string(JSON.stringify(frozen)), "Restart resumes the same frozen battle")
	_expect(main.session.state.pet.id == pet_id, "Restart keeps the same individual")
	await _capture("05-battle")
	await _click("SkipBattle")
	_expect(int(main.session.state.pet.battles) == 1, "Skip settles one battle")
	var count: int = int(main.session.state.pet.battles)
	main.session.finish_battle()
	_expect(int(main.session.state.pet.battles) == count, "Second finish gives no second result")
	await _click("BattleDone")
	if main.session.state.pet.conditions.get("injured", false):
		await _click("Heal")
		await _click("Heal_injury")
	# Coordinator clock is the actual debug clock, so persistence sees each transition.
	main.session.fast_forward(7200)
	await _frames(3)
	_expect(main.session.state.pet.stage == "growing", "Baby grows after two hours")
	main._close()
	main.session.train("power", 2)
	main.session.fast_forward(1801)
	main.session.train("power", 2)
	_expect(int(main.session.state.pet.training_count) == 3, "Three training records available for maturity")
	main.session.fast_forward(86400)
	await _frames(3)
	_expect(main.session.state.pet.stage == "mature", "Matures after growing duration and three trainings")
	_expect(main.session.state.pet.species == "ember", "Highest training selects power branch")
	_expect(bool(main.session.state.pet.conditions.hibernating), "Long absence enters protective hibernation")
	main._close()
	main.session.act("wake")
	await _capture("06-mature")
	var individual: Dictionary = main.session.state.pet.duplicate(true)
	main.session.save()
	_expect(Saves.load_state(save_path).pet == JSON.parse_string(JSON.stringify(individual)), "Complete individual survives JSON reload")
	await _click("Collection")
	# The collection action is the first non-close button below the title.
	var archive_button: Button = _find_text_button(main.overlay, "珍藏這段日記")
	_expect(archive_button != null, "Mature individual can be archived")
	if archive_button != null:
		await _press(archive_button)
		await _click("ConfirmArchive")
	_expect(main.session.state.collection.size() == 1, "Collection retains one individual")
	_expect(main.session.state.pet.is_empty(), "Archive vacates the only pet slot")
	_expect(int(main.session.state.egg.credited_steps) == 0, "New egg starts without carried steps")
	_expect(not str(main.session.state.egg.id).is_empty(), "New egg is identifiable")
	var next_egg_id: String = str(main.session.state.egg.id)
	await _reopen_scene()
	_expect(main.session.state.collection.size() == 1, "Restart retains the archived individual")
	_expect(main.session.state.egg.id == next_egg_id, "Restart retains the next egg identity")
	await _click("Steps")
	await _capture("07-next-egg")
	await _click("CloseModal")
	# Smaller and taller phone sizes: main actions remain reachable via scrolling.
	for viewport_size in [Vector2i(390, 844), Vector2i(402, 874), Vector2i(430, 932), Vector2i(375, 667)]:
		root.size = viewport_size
		await _frames()
		_assert_touch_targets(["Settings", "EggActivity", "Scale", "Food", "Battle", "Heal", "Steps", "Collection"], str(viewport_size))
		_assert_readable_text(str(viewport_size))
		_check(main.room.is_visible_in_tree(), "Room visible at " + str(viewport_size))
		_check(main.room.get_global_rect().size.y >= 208.0, "Room remains prominent at " + str(viewport_size))
		var room_rect: Rect2 = _screen_rect(main.room)
		_check(room_rect.position.x >= -0.5 and room_rect.end.x <= float(root.size.x) + 0.5, "Room has no horizontal overflow at " + str(viewport_size))
		await _click("Steps")
		_check(is_instance_valid(main.overlay), "Touch route reachable at " + str(viewport_size))
		_assert_touch_targets(["CloseModal"], "Steps modal " + str(viewport_size))
		await _click("CloseModal")
	await _capture("08-phone")
	_finish_flow()

func _release_flow() -> void:
	_expect(not main.session.provider.capabilities().available, "Unconnected native provider is unavailable")
	await _click("Steps")
	_expect(main.find_child("Mock100", true, false) == null, "Release simulation has no fake-step controls")
	await _click("SyncSteps")
	_expect(main.session.state.step_sync.today_steps == null, "Unavailable data remains unknown")
	await _click("TimeHatch")
	_expect(main.session.state.egg.mode == "time", "Time hatch works without steps")
	main.session.add_mock_steps(1000)
	_expect(main.session.state.pet.is_empty(), "Release coordinator rejects debug step injection")
	main.session.fast_forward(86400)
	_expect(main.session.state.pet.is_empty(), "Release coordinator rejects debug fast forward")
	await _capture("09-release-fallback")

func _click(node_name: String) -> void:
	var button: Button = main.find_child(node_name, true, false) as Button
	_expect(button != null, "Button exists: " + node_name)
	if button != null: await _press(button)

func _press(button: Button) -> void:
	_check(not button.disabled, "Button enabled: " + button.name)
	if button.disabled: return
	var ancestor: Node = button.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(button)
		ancestor = ancestor.get_parent()
	await _frames()
	# OS-level pointer injection is intermittent when the native test window is
	# resized repeatedly. Exercise the actual Button route deterministically;
	# target geometry and focus behavior are asserted separately below.
	button.grab_focus()
	button.pressed.emit()
	await _frames()

func _frames() -> void:
	await process_frame
	await process_frame
	await process_frame

func _reopen_scene() -> void:
	main.queue_free()
	await _frames(3)
	main = Scene.instantiate()
	root.add_child(main)
	await _frames(3)

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	RenderingServer.force_draw()
	var directory: String = ProjectSettings.globalize_path("res://docs/evidence")
	DirAccess.make_dir_recursive_absolute(directory)
	var screenshot: Image = root.get_texture().get_image()
	var error: Error = screenshot.save_png(directory.path_join(label + ".png"))
	_expect(error == OK, "Capture " + label)

func _find_text_button(node: Node, starts_with: String) -> Button:
	if node is Button and str(node.text).begins_with(starts_with): return node
	for child in node.get_children():
		var found: Button = _find_text_button(child, starts_with)
		if found != null: return found
	return null

func _assert_touch_targets(node_names: Array, context: String) -> void:
	for node_name in node_names:
		var button: Button = main.find_child(str(node_name), true, false) as Button
		_check(button != null, "Touch target exists in %s: %s" % [context, node_name])
		if button == null:
			continue
		_check(button.is_visible_in_tree(), "Touch target visible in %s: %s" % [context, node_name])
		var target_rect: Rect2 = _screen_rect(button)
		var target_size: Vector2 = target_rect.size
		_check(target_size.x >= 44.0 and target_size.y >= 44.0, "Touch target is at least 44 × 44 in %s: %s" % [context, node_name])
		var inside_viewport: bool = target_rect.position.x >= -0.5 and target_rect.position.y >= -0.5 and target_rect.end.x <= float(root.size.x) + 0.5 and target_rect.end.y <= float(root.size.y) + 0.5
		_check(inside_viewport, "Touch target stays inside viewport in %s: %s" % [context, node_name])
		if not button.disabled:
			_check(button.focus_mode == Control.FOCUS_ALL, "Enabled touch target is keyboard focusable in %s: %s" % [context, node_name])

func _assert_pet_navigation(expect_disabled: bool, context: String) -> void:
	for node_name in ["Scale", "Food", "Battle", "Heal"]:
		var button: Button = main.find_child(node_name, true, false) as Button
		_check(button != null and button.disabled == expect_disabled, "Pet navigation state in %s: %s" % [context, node_name])

func _assert_readable_text(context: String) -> void:
	var smallest_size: int = 1000
	for node in main.find_children("*", "Label", true, false):
		var label: Label = node as Label
		if label != null and label.is_visible_in_tree():
			smallest_size = mini(smallest_size, label.get_theme_font_size("font_size"))
	var screen_scale: float = root.get_final_transform().get_scale().x
	_check(float(smallest_size) * screen_scale >= 14.0, "Visible text remains at least 14 points in %s (%d × %.3f)" % [context, smallest_size, screen_scale])

func _screen_rect(control: Control) -> Rect2:
	var global_rect: Rect2 = control.get_global_rect()
	var final_transform: Transform2D = root.get_final_transform()
	var top_left: Vector2 = final_transform * global_rect.position
	var bottom_right: Vector2 = final_transform * global_rect.end
	return Rect2(top_left, bottom_right - top_left)

func _finish() -> void:
	print("FLOW CHECKS: %d; FAILURES: %d" % [checks, failures.size()])
	for failure in failures: print("FAIL: " + failure)
	if is_instance_valid(main):
		main.queue_free()
	await _frames(2)
	_finish("FLOW")
