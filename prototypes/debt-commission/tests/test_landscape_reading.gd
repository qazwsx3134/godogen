extends "res://addons/proto_kit/test_kit.gd"
## Landscape composition, undistorted toolbar, fixed portraits and readable long lines.

const TEST_FILES: Array[String] = ["user://landscape_reading.save", "user://landscape_reading.cfg", "user://landscape_reading_progress.cfg"]

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_expect(ProjectSettings.get_setting("display/window/size/viewport_width") == 1920
		and ProjectSettings.get_setting("display/window/size/viewport_height") == 1080,
		"the default logical canvas is landscape 16:9")
	var game: Control = (load("res://main.tscn") as PackedScene).instantiate()
	game.story_path = "res://data/phase3_story.json"
	game.save_path = TEST_FILES[0]
	game.settings_path = TEST_FILES[1]
	game.progress_path = TEST_FILES[2]
	game.tutorials_enabled = false
	root.add_child(game)
	await _frames(6)
	var game_rect: Rect2 = game._game.get_global_rect()
	_expect(game_rect.size.x > game_rect.size.y, "the playable area is landscape")
	_expect(game_rect.encloses(game._begin_button.get_global_rect()), "the title's start button fits the landscape canvas")
	game._on_begin_pressed()
	await _until(func() -> bool: return game._screen_mode == "story" and not game._story_busy, "story starts")
	game._complete_current_line()
	game._motion.cancel_characters()
	await _frames(8)
	_expect(game._dialog_panel._normal_font_size <= 40, "the default dialogue font stays compact in landscape")
	var bounds: Array[Rect2] = []
	for button: Button in [game._dialog_panel.log_button, game._dialog_panel.auto_button,
			game._dialog_panel.skip_button, game._dialog_panel.menu_button]:
		var surface: Control = button.get_node("Surface")
		var rect: Rect2 = surface.get_global_rect()
		_expect(absf(rect.size.x / rect.size.y - 195.0 / 62.0) < 0.02,
			button.name + " artwork keeps its original aspect ratio")
		_expect(game_rect.encloses(button.get_global_rect()), button.name + " remains inside the playable area")
		for previous: Rect2 in bounds:
			_expect(not previous.intersects(button.get_global_rect()), button.name + " has its own touch area")
		bounds.append(button.get_global_rect())
	_expect(game_rect.encloses(game._phase3_hud.get_global_rect()), "the HUD fits on the landscape canvas")

	var portrait: Control = game._sprites["shinpachi"]
	var portrait_rect: Rect2 = portrait.get_global_rect()
	var dialogue_rect: Rect2 = game._dialog_panel.get_global_rect()
	_expect(dialogue_rect.intersects(portrait_rect), "the fixed dialogue can cover the portrait")
	var long_line: String = "這是用來檢查橫向閱讀框的測試文字，下一頁應該仍然停留在同一句台詞。".repeat(8)
	game._full_text = long_line
	game._line_plan = {}
	game._set_visible_text(long_line, true)
	await _frames(16)
	_expect(game._dialog_panel.get_global_rect().is_equal_approx(dialogue_rect), "long text does not resize the dialogue")
	_expect(portrait.get_global_rect().is_equal_approx(portrait_rect), "long text does not move or resize the portrait")
	_expect(game._dialog_panel.has_next_page() and game._dialog_panel.page_hint.visible,
		"long text exposes a visible continue-reading cue")
	var node_id: String = game._runner.node_id
	var step_index: int = game._runner.step_index
	var scroll: VScrollBar = game._text_label.get_v_scroll_bar()
	var pages: int = 0
	while game._dialog_panel.has_next_page() and pages < 20:
		var before: float = scroll.value
		game._on_screen_tap()
		await _frames(2)
		_expect(scroll.value > before, "a tap advances the reading page")
		if scroll.value < scroll.max_value - scroll.page - 1.0:
			var aligned: bool = false
			for line: int in range(game._text_label.get_line_count()):
				if absf(scroll.value - float(game._text_label.get_line_offset(line))) < 1.0:
					aligned = true
			_expect(aligned, "a new page begins at a wrapped line")
		_expect(game._runner.node_id == node_id and game._runner.step_index == step_index,
			"turning a page does not skip the story line")
		pages += 1
	_expect(pages > 0 and not game._dialog_panel.has_next_page(), "every page can be reached")
	_expect(not game._dialog_panel.page_hint.visible, "the page cue clears at the end")

	game._dialog_panel.reset_reading_page()
	await _frames(2)
	game._set_auto(true)
	Engine.time_scale = 20.0
	await _until(func() -> bool: return scroll.value > 0.0, "auto reading turns the first page", 4.0)
	game._set_auto(false)
	Engine.time_scale = 1.0
	_expect(game._runner.node_id == node_id and game._runner.step_index == step_index,
		"auto reading shows the next page before advancing the story")

	game._dialog_panel.reset_reading_page()
	game._dialog_panel.set_line_advance(false)
	game._screen_mode = "investigate"
	await _frames(2)
	_expect(game._dialog_panel.advance_button.visible and game._dialog_panel.page_hint.visible,
		"an overlong investigation prompt also exposes a page control")
	var before: float = scroll.value
	await _press(game._advance_button)
	_expect(scroll.value > before, "the page control works in investigation mode")
	game.queue_free()
	await _frames(2)
	for path: String in TEST_FILES:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_finish("LANDSCAPE READING")
