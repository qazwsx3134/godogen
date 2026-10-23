extends "res://addons/proto_kit/test_kit.gd"
## The game's one UI look, 銀魂和紙: the washi scenes are mounted, the reading toolbar and cloud name
## plate are in place, generated choices and dialogue text are readable on the paper, the reading
## text covers the story's Chinese, and the in-play HUD, search bar and toast use their resources.

const UI_STYLES_SCRIPT: Script = preload("res://scripts/ui_styles.gd")
const TEST_SAVE: String = "user://ui_styles_test.save"
const PAPER: Color = Color("#f4eddf")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_cleanup_files()
	_expect(UI_STYLES_SCRIPT.style_ids() == ["gintama"] and UI_STYLES_SCRIPT.normalize_id("anything") == "gintama",
		"there is one look, 銀魂和紙")
	var game: Control = _new_game()
	await _frames(3)
	_expect(game._dialog_panel.scene_file_path.ends_with("dialogue_box_gintama.tscn")
		and game._title_screen.scene_file_path.ends_with("title_screen_gintama.tscn")
		and game._menu_overlay.scene_file_path.ends_with("menu_panel_gintama.tscn")
		and game._settings_panel.scene_file_path.ends_with("settings_panel_gintama.tscn"),
		"the washi scenes are mounted")
	_expect(game._title_screen.find_child("Styles", true, false) == null
		and game._menu_overlay.find_child("Styles", true, false) == null
		and not game._settings_panel.call("buttons").keys().any(func(k: String) -> bool: return k.begins_with("ui_style")),
		"no screen offers a style switch")
	game._on_begin_pressed()
	await _until(func() -> bool: return game._screen_mode == "story", "opening line")
	var toolbar_order: Array[String] = []
	for button: Node in game._dialog_panel.toolbar.get_children():
		toolbar_order.append(str(button.name))
	_expect(toolbar_order == ["Log", "Auto", "Skip", "Menu"], "the toolbar is LOG AUTO SKIP MENU in that order")
	var name_rect: Rect2 = game._name_plate.get_global_rect()
	var paper_rect: Rect2 = game._dialog_panel.get_node("PaperAndToolbar/Panel").get_global_rect()
	_expect(name_rect.position.y < paper_rect.position.y and name_rect.end.y > paper_rect.position.y,
		"the cloud name plate overlaps the paper's top edge")
	game._dialog_panel.skip_button.pressed.emit()
	_expect(game._skip and game._dialog_panel.skip_button.button_pressed and not game._auto,
		"SKIP starts skipping and shows its active state")
	game._set_auto(true)
	_expect(game._auto and not game._skip and not game._dialog_panel.skip_button.button_pressed,
		"AUTO stops SKIP and clears its active state")
	game._set_auto(false)
	game._set_skip(true)
	await _until(func() -> bool: return game._screen_mode == "choice", "first generated choice", 12.0)
	game._set_skip(false)
	_expect(_choices_are_readable(game), "generated choices sit on the washi sheet, focus differs from rest, text is readable")
	_expect(_dialogue_is_readable(game), "dialogue text clears 4.5:1 contrast on the paper cut-out")
	game._on_choice_pressed("no_such_option")
	_expect(game._dialog_panel.visible and not game._choice_sheet.visible and not game._story_error.is_empty() and
		game._visible_text == game._story_error, "a refused pick closes the sheet and shows its error in the dialogue box")
	game.queue_free()
	await _frames(2)
	var box: Control = load("res://scenes/ui/dialogue_box_gintama.tscn").instantiate() as Control
	var body: RichTextLabel = box.find_child("Text", true, false) as RichTextLabel
	_expect(body != null and _covers(body.get_theme_font("normal_font"), "寫著我吐槽"),
		"the reading text font (with fallbacks) has the story's Chinese glyphs")
	box.free()
	await _hud_uses_its_resources()
	_cleanup_files()
	_finish("UI STYLE TESTS")


## The in-play HUD, clue tag, search bar and toast use assets/ui/gintama_hud/ resources and the serif.
func _hud_uses_its_resources() -> void:
	var game: Control = _new_game()
	await _frames(3)
	var serif: Font = UI_STYLES_SCRIPT.gintama_hud("serif") as Font
	var hud_panel: StyleBox = UI_STYLES_SCRIPT.gintama_hud("hud_panel") as StyleBox
	_expect(game._phase3_hud.panel.get_theme_stylebox("panel") == hud_panel and
		(game._investigate_bar.get("panel") as Control).get_theme_stylebox("panel") == hud_panel,
		"the HUD and the search bar use gintama_hud/hud_panel.tres")
	_expect(game._toast.get_theme_stylebox("normal") == UI_STYLES_SCRIPT.gintama_hud("toast") and
		game._toast.get_theme_font("font") == serif and game._phase3_hud.power_value.get_theme_font("font") == serif,
		"the toast is the navy plaque and HUD text is the serif")
	game.queue_free()
	await _frames(2)


func _covers(font: Font, text: String) -> bool:
	if font == null:
		return false
	for character: String in text:
		if not _font_has(font, character.unicode_at(0)):
			return false
	return true


func _font_has(font: Font, code: int) -> bool:
	if font.has_char(code):
		return true
	for fallback: Font in font.fallbacks:
		if _font_has(fallback, code):
			return true
	return font is FontVariation and (font as FontVariation).base_font != null and \
		_font_has((font as FontVariation).base_font, code)


func _new_game() -> Control:
	var game: Control = (load("res://main.tscn") as PackedScene).instantiate() as Control
	game.story_path = "res://data/debt_story.json"
	game.save_path = TEST_SAVE
	root.add_child(game)
	return game


## The rows sit on the washi choice sheet, a focused row looks different from a resting one, and row
## text clears contrast against the row colour laid over the paper.
func _choices_are_readable(game: Control) -> bool:
	if game._choice_buttons.is_empty() or not game._choice_sheet.visible or game._dialog_panel.visible:
		return false
	for button: Button in game._choice_buttons:
		var normal: StyleBoxFlat = button.get_theme_stylebox("normal") as StyleBoxFlat
		var focus: StyleBoxFlat = button.get_theme_stylebox("focus") as StyleBoxFlat
		if button.get_parent() != game._choice_sheet.choices or normal == null or focus == null:
			return false
		if focus.border_color == normal.border_color and focus.bg_color == normal.bg_color:
			return false
		if UI_STYLES_SCRIPT.contrast_ratio(button.get_theme_color("font_color"), PAPER.blend(normal.bg_color)) < 4.5:
			return false
	return true


## The text clears contrast on the paper; the paper cut-out keeps transparent corners and clips its
## waves and blossoms; the name is light on the navy plate.
func _dialogue_is_readable(game: Control) -> bool:
	var text_color: Color = game._text_label.get_theme_color("font_color")
	var paper_cutout: NinePatchRect = game._dialog_panel.find_child("PaperCutout", true, false) as NinePatchRect
	var plaque: NinePatchRect = game._dialog_panel.find_child("CloudPlaque", true, false) as NinePatchRect
	if paper_cutout == null or paper_cutout.texture == null or plaque == null or plaque.texture == null:
		return false
	var image: Image = paper_cutout.texture.get_image()
	if image == null or image.detect_alpha() == Image.ALPHA_NONE:
		return false
	for corner: Vector2i in [Vector2i.ZERO, Vector2i(image.get_width() - 1, 0),
		Vector2i(0, image.get_height() - 1), image.get_size() - Vector2i.ONE]:
		if image.get_pixelv(corner).a > 0.1:
			return false
	return UI_STYLES_SCRIPT.contrast_ratio(text_color, PAPER) >= 4.5 and \
		(paper_cutout.get_parent() as Control).clip_contents and \
		game._dialog_panel.find_child("Seigaiha", true, false) == null and \
		game._dialog_panel.find_child("Sakura", true, false) == null and \
		game._name_label.get_theme_color("font_color") == Color("#f8f3e9")


func _cleanup_files() -> void:
	for path: String in [TEST_SAVE, TEST_SAVE + ".bak", TEST_SAVE + ".old", TEST_SAVE + ".tmp", TEST_SAVE + ".bak.tmp"]:
		var absolute_path: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)
