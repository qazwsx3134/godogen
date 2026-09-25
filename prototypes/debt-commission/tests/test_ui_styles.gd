extends "res://addons/proto_kit/test_kit.gd"
## Checks live style switching, preference isolation, and readable generated choices.

const UI_STYLES_SCRIPT: Script = preload("res://scripts/ui_styles.gd")
const TEST_PREFERENCE: String = "user://ui_styles_test_preferences.cfg"
const INVALID_PREFERENCE: String = "user://ui_styles_test_invalid.cfg"
const TEST_SAVE: String = "user://ui_styles_test.save"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_cleanup_files()
	_expect(UI_STYLES_SCRIPT.load_preference(TEST_PREFERENCE) == "cinema",
		"missing preference falls back to cinema")
	_expect(UI_STYLES_SCRIPT.save_preference("manga", TEST_PREFERENCE) == OK,
		"style preference saves to its isolated ConfigFile")
	_expect(UI_STYLES_SCRIPT.load_preference(TEST_PREFERENCE) == "manga",
		"saved style preference reloads")
	var saved_config: ConfigFile = ConfigFile.new()
	_expect(saved_config.load(TEST_PREFERENCE) == OK, "style preference file is readable")
	var saved_keys: PackedStringArray = saved_config.get_section_keys("ui")
	_expect(saved_config.get_sections() == PackedStringArray(["ui"]) and
		saved_keys.size() == 1 and saved_keys[0] == "style",
		"preference file contains only the UI style key")
	var invalid_config: ConfigFile = ConfigFile.new()
	invalid_config.set_value("ui", "style", "retired-style")
	_expect(invalid_config.save(INVALID_PREFERENCE) == OK, "invalid preference fixture saves")
	_expect(UI_STYLES_SCRIPT.load_preference(INVALID_PREFERENCE) == "cinema",
		"unknown saved style falls back to cinema")
	_expect(UI_STYLES_SCRIPT.normalize_id("unknown") == "cinema",
		"runtime style requests also fall back to cinema")
	_cleanup_files()

	var game: Control = _new_game()
	await _frames(3)
	_expect(game._ui_style_id == "cinema", "new game uses the default cinema style")
	_expect(game._title_style_buttons.size() == 3 and game._menu_style_buttons.size() == 3,
		"title and in-game menu expose all three named styles")
	game._on_begin_pressed()
	await _until(func() -> bool: return game._screen_mode == "story", "opening line")
	game._set_skip(true)
	await _until(func() -> bool: return game._screen_mode == "choice", "first generated choice", 12.0)
	game._set_skip(false)
	_expect(game._choice_buttons.size() >= 2, "story creates selectable choice buttons")
	var story_before: Dictionary = game._runner.call("snapshot") as Dictionary
	var position_before: String = "%s:%d" % [game._runner.node_id, game._runner.step_index]
	var text_before: String = game._visible_text

	for style_id: String in UI_STYLES_SCRIPT.style_ids():
		game._set_ui_style(style_id)
		var story_after: Dictionary = game._runner.call("snapshot") as Dictionary
		var position_after: String = "%s:%d" % [game._runner.node_id, game._runner.step_index]
		_expect(game._screen_mode == "choice" and position_after == position_before and
			story_after == story_before and game._visible_text == text_before,
			"switching to %s preserves the live story position" % style_id)
		_expect(game._ui_style_id == style_id and
			UI_STYLES_SCRIPT.load_preference(TEST_PREFERENCE) == style_id,
			"%s applies live and persists" % style_id)
		_expect(_choices_match_style(game, style_id),
			"existing dynamic choices use %s button states" % style_id)
		_expect(_dialogue_is_readable(game, style_id),
			"%s dialogue text clears 4.5:1 contrast" % style_id)
		_expect(_selector_has_focus_and_disabled_states(game, style_id),
			"%s selector exposes focus and disabled button treatments" % style_id)

	game.queue_free()
	await _frames(2)
	var restored: Control = _new_game(TEST_PREFERENCE)
	await _frames(3)
	_expect(restored._ui_style_id == "manga", "new instance restores the last style preference")
	_expect(restored._screen_mode == "title" and restored._visible_text.is_empty() and
		not restored._dialog_layer.visible,
		"style persistence leaves the story at its title entry point")
	restored.queue_free()
	await _frames(2)
	var invalid_game: Control = _new_game(INVALID_PREFERENCE)
	await _frames(2)
	_expect(invalid_game._ui_style_id == "cinema", "main applies the fallback for an invalid preference")
	invalid_game.queue_free()
	await _frames(2)
	_cleanup_files()
	_finish("UI STYLE TESTS")


func _new_game(preference_path: String = TEST_PREFERENCE) -> Control:
	var game: Control = (load("res://main.tscn") as PackedScene).instantiate() as Control
	game.story_path = "res://data/debt_story.json"
	game.save_path = TEST_SAVE
	game.ui_preference_path = preference_path
	root.add_child(game)
	return game


func _choices_match_style(game: Control, style_id: String) -> bool:
	if game._choice_buttons.is_empty():
		return false
	for button: Button in game._choice_buttons:
		var normal: StyleBoxFlat = button.get_theme_stylebox("normal") as StyleBoxFlat
		var disabled: StyleBoxFlat = button.get_theme_stylebox("disabled") as StyleBoxFlat
		var focus: StyleBoxFlat = button.get_theme_stylebox("focus") as StyleBoxFlat
		var expected: StyleBoxFlat = UI_STYLES_SCRIPT.button_style(style_id, "choice", "normal")
		if normal == null or disabled == null or focus == null or normal.bg_color != expected.bg_color:
			return false
		if disabled.border_color == normal.border_color or focus.border_color == normal.border_color:
			return false
		if UI_STYLES_SCRIPT.contrast_ratio(button.get_theme_color("font_color"), normal.bg_color) < 4.5:
			return false
	return true


func _dialogue_is_readable(game: Control, style_id: String) -> bool:
	var panel: StyleBoxFlat = game._dialog_panel.get_theme_stylebox("panel") as StyleBoxFlat
	var text_color: Color = game._text_label.get_theme_color("font_color")
	return panel != null and UI_STYLES_SCRIPT.contrast_ratio(text_color, panel.bg_color) >= 4.5


func _selector_has_focus_and_disabled_states(game: Control, style_id: String) -> bool:
	var button: Button = game._title_style_buttons[style_id] as Button
	var focus: StyleBoxFlat = button.get_theme_stylebox("focus") as StyleBoxFlat
	var disabled: StyleBoxFlat = button.get_theme_stylebox("disabled") as StyleBoxFlat
	var normal: StyleBoxFlat = button.get_theme_stylebox("normal") as StyleBoxFlat
	return button.focus_mode == Control.FOCUS_ALL and focus != null and disabled != null and \
		normal != null and focus.border_color == UI_STYLES_SCRIPT.palette(style_id)["focus"] and \
		UI_STYLES_SCRIPT.contrast_ratio(button.get_theme_color("font_color"), normal.bg_color) >= 4.5


func _cleanup_files() -> void:
	for path: String in [TEST_PREFERENCE, INVALID_PREFERENCE, TEST_SAVE, TEST_SAVE + ".bak",
		TEST_SAVE + ".old", TEST_SAVE + ".tmp", TEST_SAVE + ".bak.tmp"]:
		var absolute_path: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)
