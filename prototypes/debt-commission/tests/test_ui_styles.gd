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
	_expect(UI_STYLES_SCRIPT.load_preference(TEST_PREFERENCE) == "gintama",
		"missing preference falls back to gintama")
	_expect(UI_STYLES_SCRIPT.style_ids() == ["cinema", "ledger", "manga", "gintama"] and
		UI_STYLES_SCRIPT.style_label("gintama") == "銀魂和紙",
		"the four editions include the named gintama paper style")
	_expect(UI_STYLES_SCRIPT.save_preference("gintama", TEST_PREFERENCE) == OK,
		"style preference saves to its isolated ConfigFile")
	_expect(UI_STYLES_SCRIPT.load_preference(TEST_PREFERENCE) == "gintama",
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
	_expect(UI_STYLES_SCRIPT.load_preference(INVALID_PREFERENCE) == "gintama",
		"unknown saved style falls back to gintama")
	_expect(UI_STYLES_SCRIPT.normalize_id("unknown") == "gintama",
		"runtime style requests also fall back to cinema")
	_cleanup_files()

	var game: Control = _new_game()
	await _frames(3)
	_expect(game._ui_style_id == "gintama", "new game uses the default gintama style")
	_expect(game._title_style_buttons.size() == 4 and game._menu_style_buttons.size() == 4 and
		(game._title_screen.find_child("Styles", true, false) as GridContainer).columns == 2 and
		(game._menu_overlay.find_child("Styles", true, false) as GridContainer).columns == 2,
		"title and in-game menu expose four named styles in two columns")
	await _press(game._title_style_buttons["gintama"] as Button)
	await _frames(2)
	_expect(game._ui_style_id == "gintama" and UI_STYLES_SCRIPT.load_preference(TEST_PREFERENCE) == "gintama",
		"the title's gintama button selects the paper edition and saves it")
	game._set_ui_style("cinema", false)
	await _frames(2)
	game._on_begin_pressed()
	await _until(func() -> bool: return game._screen_mode == "story", "opening line")
	game._set_ui_style("gintama", false)
	await _frames(3)
	var toolbar_order: Array[String] = []
	for button: Node in game._dialog_panel.toolbar.get_children():
		toolbar_order.append(str(button.name))
	_expect(toolbar_order == ["Log", "Auto", "Skip", "Menu"],
		"reference toolbar exposes LOG AUTO SKIP MENU in that order")
	var name_rect: Rect2 = game._name_plate.get_global_rect()
	var paper_rect: Rect2 = game._dialog_panel.get_node("PaperAndToolbar/Panel").get_global_rect()
	_expect(name_rect.position.y < paper_rect.position.y and name_rect.end.y > paper_rect.position.y,
		"the cloud nameplate overlaps the paper's top edge")
	game._dialog_panel.skip_button.pressed.emit()
	_expect(game._skip and game._dialog_panel.skip_button.button_pressed and not game._auto,
		"the reference SKIP button starts skipping and shows its active state")
	game._set_auto(true)
	_expect(game._auto and not game._skip and not game._dialog_panel.skip_button.button_pressed,
		"AUTO stops SKIP and clears its active state")
	game._set_auto(false)
	game._set_ui_style("cinema", false)
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

	game._on_choice_pressed("no_such_option")
	_expect(game._dialog_panel.visible and not game._choice_sheet.visible and not game._story_error.is_empty() and
		game._visible_text == game._story_error, "a refused pick closes the sheet and shows its error in the dialogue box")

	game.queue_free()
	await _frames(2)
	var restored: Control = _new_game(TEST_PREFERENCE)
	await _frames(3)
	_expect(restored._ui_style_id == "gintama", "new instance restores the last style preference")
	_expect(restored._screen_mode == "title" and restored._visible_text.is_empty() and
		not restored._dialog_layer.visible,
		"style persistence leaves the story at its title entry point")
	restored.queue_free()
	await _frames(2)
	var invalid_game: Control = _new_game(INVALID_PREFERENCE)
	await _frames(2)
	_expect(invalid_game._ui_style_id == "gintama", "main applies the fallback for an invalid preference")
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


## The edition's own choice sheet holds the rows, a focused row looks different from a resting one,
## and row text clears contrast against the row colour laid over the sheet's paper.
func _choices_match_style(game: Control, style_id: String) -> bool:
	if game._choice_buttons.is_empty() or game._choice_sheet.style_id != style_id or not game._choice_sheet.visible \
			or game._dialog_panel.visible:
		return false
	var paper: Color = {"cinema": Color8(8, 17, 26), "ledger": Color("#f2e8d2"), "manga": Color("#f5f3e9"), "gintama": Color("#f4eddf")}[style_id]
	for button: Button in game._choice_buttons:
		var normal: StyleBoxFlat = button.get_theme_stylebox("normal") as StyleBoxFlat
		var focus: StyleBoxFlat = button.get_theme_stylebox("focus") as StyleBoxFlat
		if button.get_parent() != game._choice_sheet.choices or normal == null or focus == null:
			return false
		if focus.border_color == normal.border_color and focus.bg_color == normal.bg_color:
			return false
		if UI_STYLES_SCRIPT.contrast_ratio(button.get_theme_color("font_color"), paper.blend(normal.bg_color)) < 4.5:
			return false
	return true


## The edition's own box scene is mounted, and its text clears contrast against the paper the
## ornament paints (cinema: the navy gradient at full strength).
func _dialogue_is_readable(game: Control, style_id: String) -> bool:
	var paper: Color = {"cinema": Color(0.03, 0.07, 0.1), "ledger": Color("#f2e8d2"), "manga": Color(0.965, 0.96, 0.93), "gintama": Color("#f4eddf")}[style_id]
	var text_color: Color = game._text_label.get_theme_color("font_color")
	var readable: bool = game._dialog_panel.style_id == style_id and UI_STYLES_SCRIPT.contrast_ratio(text_color, paper) >= 4.5
	if style_id != "gintama":
		return readable
	var paper_cutout: NinePatchRect = game._dialog_panel.find_child("PaperCutout", true, false) as NinePatchRect
	var plaque: TextureRect = game._dialog_panel.find_child("CloudPlaque", true, false) as TextureRect
	if paper_cutout == null or paper_cutout.texture == null or plaque == null or plaque.texture == null:
		return false
	var image: Image = paper_cutout.texture.get_image()
	if image == null or image.detect_alpha() == Image.ALPHA_NONE:
		return false
	for corner: Vector2i in [Vector2i.ZERO, Vector2i(image.get_width() - 1, 0),
		Vector2i(0, image.get_height() - 1), image.get_size() - Vector2i.ONE]:
		if image.get_pixelv(corner).a > 0.1:
			return false
	return readable and (paper_cutout.get_parent() as Control).clip_contents and \
		game._dialog_panel.find_child("Seigaiha", true, false) == null and \
		game._dialog_panel.find_child("Sakura", true, false) == null and \
		game._name_label.get_theme_color("font_color") == Color("#f8f3e9")


## The title's edition picker belongs to that edition's title scene, shows a focus ring and a
## disabled look, and its text clears contrast on the card.
func _selector_has_focus_and_disabled_states(game: Control, style_id: String) -> bool:
	var button: Button = game._title_style_buttons[style_id] as Button
	var focus: StyleBoxFlat = button.get_theme_stylebox("focus") as StyleBoxFlat
	var disabled: StyleBoxFlat = button.get_theme_stylebox("disabled") as StyleBoxFlat
	var normal: StyleBoxFlat = button.get_theme_stylebox("normal") as StyleBoxFlat
	var card: Color = {"cinema": Color8(5, 10, 14), "ledger": Color("#f2e8d2"), "manga": Color("#f5f3e9"), "gintama": Color("#f4eddf")}[style_id]
	return game._title_screen.style_id == style_id and button.focus_mode == Control.FOCUS_ALL and \
		focus != null and disabled != null and normal != null and focus.border_color.a > 0.0 and focus.border_width_top > 0 and \
		UI_STYLES_SCRIPT.contrast_ratio(button.get_theme_color("font_color"), card.blend(normal.bg_color)) >= 4.5


func _cleanup_files() -> void:
	for path: String in [TEST_PREFERENCE, INVALID_PREFERENCE, TEST_SAVE, TEST_SAVE + ".bak",
		TEST_SAVE + ".old", TEST_SAVE + ".tmp", TEST_SAVE + ".bak.tmp"]:
		var absolute_path: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)
