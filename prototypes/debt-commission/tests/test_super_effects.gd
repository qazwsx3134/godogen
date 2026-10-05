extends "res://addons/proto_kit/test_kit.gd"
## B acceptance: full-gauge notification/aura, custom super label, consumption/QTE, restore and beam input/cleanup.
const MAIN = preload("res://main.tscn")
const RUNNER = preload("res://scripts/story_runner.gd")
const BUILDER = preload("res://tools/story_build/story_builder.gd")
const SAMPLE: String = "res://data/phase4_rounds_story.json"
func _init() -> void:
	_run.call_deferred()
func _game() -> Control:
	var game: Control = MAIN.instantiate() as Control
	game.story_path = SAMPLE
	game.save_path = "user://super_effects_test.save"
	game.ui_preference_path = "user://super_effects_test.cfg"
	root.add_child(game)
	return game
func _run() -> void:
	root.size = Vector2i(1080, 1920)
	var built: Dictionary = BUILDER.build("res://story_src/phase4_rounds.dialogue")
	_expect(str(built.error).is_empty(), "source builds with beam(): %s" % built.error)
	_expect(BUILDER.to_json(built.story) == FileAccess.get_file_as_string(SAMPLE), "generated story matches authoring source")
	var game: Control = _game()
	await _frames(3)
	game._on_begin_pressed()
	await _until(func() -> bool: return game._screen_mode == "story", "sample starts")
	var saved: Dictionary = game._runner.snapshot()
	saved.node_id = "r2_round"
	saved.step_index = 0
	saved.gameplay.power = 90
	_expect(game._runner.restore(saved), "start combo below full power")
	game._previous_power = 90
	game._render_restored_current()
	await _frames(2)
	_expect(game._screen_mode == "tsukkomi" and not game._choice_sheet.super_button.visible, "no super below full power")
	_expect(_charged(game) == 0, "no aura below full power")
	await _press(game._choice_buttons[0])
	_expect(game._runner.gameplay.power == 100 and _charged(game) == 5, "perfect caps power and lights the living glasses")
	var notifications: int = _notifications(game)
	_expect(notifications == 1, "crossing full power emits one cut-in")
	await _until_combo(game)
	_expect(game._choice_sheet.super_button.visible and game._choice_sheet.super_button.text == "龜派氣功！", "custom label on the super button")
	game._set_ui_style("gintama", false)
	await _frames(2)
	_expect(game._choice_sheet.super_button.text == "龜派氣功！" and _charged(game) == 5, "edition switch keeps super label and aura")
	var payload: Dictionary = game._build_save_payload("")
	var resumed: Control = _game()
	await _frames(3)
	_expect(resumed._apply_save_payload(payload), "full-power save restores")
	resumed._show_story_screen()
	resumed._render_restored_current()
	await _frames(2)
	_expect(_charged(resumed) == 5 and resumed._previous_power == 100 and _notifications(resumed) == 0, "restore brings back aura without replaying notification")
	resumed.queue_free()
	await _frames(2)
	await _press(game._choice_sheet.super_button)
	_expect(game._runner.gameplay.power == 0 and _charged(game) == 0, "super consumes power and extinguishes the aura immediately")
	await _until(func() -> bool: return game._screen_mode == "story", "super begins its spoken scene")
	game._complete_current_line()
	game._on_screen_tap()
	await _until(func() -> bool: return _beam(game) != null, "the super spawns its beam")
	var beam: Control = _beam(game)
	_expect(_ignores_input(beam), "every beam node ignores pointer input")
	var logical_point: Vector2 = game._game.position + Vector2(game._game.size.x * 0.5, game._game.size.y * 0.42)
	await _tap(logical_point)
	_expect(game._text_complete, "tap through the beam completes the current line")
	await _until(func() -> bool: return _beam(game) == null, "beam cleans itself up")
	await _until_qte(game)
	_expect(game._runner.round_state.caught.size() == 3 and game._screen_mode == "qte", "super catches the sample’s three option lines and preserves QTE")
	_expect(game._runner.use_super().is_empty(), "super cannot be used again")
	var count: int = game._overlay_layer.get_child_count()
	game._effects.play({"op": "beam"}, true)
	_expect(game._overlay_layer.get_child_count() == count, "skip creates no beam")
	game._toggle_mute()
	game._effects.play({"op": "se", "id": "power_up"}, false)
	_expect(not game._effects._charge_player.playing, "power-up sound respects mute")
	game._toggle_mute()
	game._settings.se_volume = 0
	game._apply_audio_levels()
	game._effects.play({"op": "se", "id": "power_up"}, false)
	_expect(not game._effects._charge_player.playing, "power-up sound respects zero volume")
	game.queue_free()
	await _frames(2)
	await _test_scene_edits()
	_test_invalid_data()
	_finish("SUPER EFFECTS")
func _charged(game: Control) -> int:
	var count: int = 0
	for icon: Node in game._phase3_hud.glasses.get_children():
		if icon.charged and not icon.broken: count += 1
	return count
func _notifications(game: Control) -> int:
	var count: int = 0
	for child: Node in game._overlay_layer.get_children():
		if child.get_node_or_null("%Text") != null and child.get_node("%Text").text == "吐槽之力全滿！": count += 1
	return count
func _beam(game: Control) -> Control:
	for child: Node in game._overlay_layer.get_children():
		if child.get_script() == load("res://scripts/beam.gd"): return child as Control
	return null
func _ignores_input(node: Node) -> bool:
	if node is Control and node.mouse_filter != Control.MOUSE_FILTER_IGNORE: return false
	for child: Node in node.get_children():
		if not _ignores_input(child): return false
	return true
func _until_combo(game: Control) -> void:
	for index: int in range(80):
		if game._screen_mode == "tsukkomi": return
		if game._screen_mode == "story": game._complete_current_line(); game._on_screen_tap()
		await _frames(2)
	_expect(false, "combo returns after reaction")
func _until_qte(game: Control) -> void:
	for index: int in range(100):
		if game._screen_mode == "qte": return
		if game._screen_mode == "story": game._complete_current_line(); game._on_screen_tap()
		await _frames(2)
	_expect(false, "super returns to QTE")
func _test_invalid_data() -> void:
	for value: Variant in [-0.1, "fast", 8.0]:
		var story: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAMPLE))
		story.nodes.r2_super.steps.insert(0, {"op": "beam", "duration": value})
		var file := FileAccess.open("user://bad_super.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(story)); file.close()
		var runner = RUNNER.new()
		_expect(not runner.load_story("user://bad_super.json") and runner.error_message.contains("beam duration"), "invalid beam duration rejected: %s" % str(value))
	DirAccess.remove_absolute("user://bad_super.json")

func _test_scene_edits() -> void:
	var source: String = FileAccess.get_file_as_string("res://scenes/ui/beam.tscn")
	var editable: Control = (load("res://scenes/ui/beam.tscn") as PackedScene).instantiate() as Control
	var strip: Control = editable.get_node("%Strip") as Control
	strip.anchor_top = 0.27
	strip.offset_top = 21.0
	var packed := PackedScene.new()
	_expect(packed.pack(editable) == OK and ResourceSaver.save(packed, "user://edited_beam.tscn") == OK, "editor placement serializes")
	editable.free()
	var reloaded: Control = (load("user://edited_beam.tscn") as PackedScene).instantiate() as Control
	root.add_child(reloaded)
	reloaded.play(0.12)
	await _frames(2)
	_expect(is_equal_approx(reloaded.strip.anchor_top, 0.27) and is_equal_approx(reloaded.strip.offset_top, 21.0), "beam animation preserves edited placement")
	await create_timer(0.2).timeout
	_expect(not is_instance_valid(reloaded), "edited scene also cleans up")
	_expect(FileAccess.get_file_as_string("res://scenes/ui/beam.tscn") == source, "runtime animation never writes into the source scene")
	DirAccess.remove_absolute("user://edited_beam.tscn")
