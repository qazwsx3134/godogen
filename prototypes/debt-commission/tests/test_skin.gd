extends "res://addons/proto_kit/test_kit.gd"
## 外觀包: a story's `skin` brings its scenes, look, life icon, title picture and music, and words;
## a skin lists only what it changes. Going to a story with the base skin puts 銀魂和紙 back. A story
## without rounds or searches shows no gameplay UI.

const SkinPack = preload("res://scripts/skin.gd")
const REGISTRY: String = "res://tests/fixtures/stories_skins.json"
const SKINS: String = "res://tests/fixtures/skins/"
const FILES: Array[String] = ["user://skin_chapter_a.save", "user://skin_phase3.save", "user://skin_debt.save",
	"user://skin_progress.cfg", "user://skin_settings.cfg"]


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_cleanup()
	_merging()
	await _the_story_brings_its_skin()
	await _no_gameplay_no_gameplay_ui()
	_cleanup()
	_finish("SKIN TESTS")


func _merging() -> void:
	var base: Dictionary = SkinPack.load_skin("")
	var plain: Dictionary = SkinPack.load_skin("plain", SKINS)
	_expect(base["id"] == "gintama" and plain["id"] == "plain", "the base skin and the test skin load")
	_expect(SkinPack.term(plain, "rebut") == "反駁" and SkinPack.term(base, "rebut") == "吐槽", "terms come from each skin")
	_expect(str(plain["scenes"]["dialogue_box"]) == str(base["scenes"]["dialogue_box"])
		and str(plain["scenes"]["title"]).ends_with("plain/title.tscn"), "what a skin leaves out comes from the base skin")
	_expect(SkinPack.text(plain, "assist_label") == "◆ 反駁輔助", "base texts take the skin's terms")
	_expect(SkinPack.load_skin("no_such_skin", SKINS)["id"] == "gintama", "an unknown skin is the base skin")


func _the_story_brings_its_skin() -> void:
	var game: Control = _new_game("res://tests/fixtures/chapter_a_story.json")
	await _frames(3)
	_expect(game._ui_style_id == "plain" and game._title_screen.scene_file_path.ends_with("plain/title.tscn"),
		"chapter A (skin plain) mounts its title scene")
	var dialogue_box: Node = game._dialog_panel
	game._skin = SkinPack.load_skin("settings_only", SKINS)
	game._apply_ui_style()
	_expect(game._settings_panel.scene_file_path.ends_with("settings_only/settings.tscn")
		and game._dialog_panel.scene_file_path == dialogue_box.scene_file_path,
		"a skin replacing only the settings panel remounts it: %s" % game._settings_panel.scene_file_path)
	game._skin = SkinPack.load_skin("plain", SKINS)
	game._apply_ui_style()
	await _frames(1)
	_expect((game._title_screen.find_child("Logo", true, false) as Label).text == "測試作品\n反駁 ADV"
		and (game._menu_overlay.find_child("HeadingText", true, false).get_node("Heading") as Label).text == "暫停",
		"its texts replace the scene's words: %s / %s" % [(game._title_screen.find_child("Logo", true, false) as Label).text,
			(game._menu_overlay.find_child("HeadingText", true, false).get_node("Heading") as Label).text])
	_expect(game._effects.current_bgm == "bgm_daily", "the title plays its music")
	game._on_begin_pressed()
	for i: int in range(600):
		if game._screen_mode == "boke_round":
			break
		if game._screen_mode == "story" and not game._story_busy:
			if game._text_complete:
				game._advance_current_line()
			else:
				game._complete_current_line()
		await _frames(1)
	_expect(game._screen_mode == "boke_round", "the round starts")
	var icon: Control = game._phase3_hud.glasses.get_child(0) as Control
	_expect(icon.scene_file_path.ends_with("plain/blade_icon.tscn"), "the HUD uses the skin's life icon")
	_expect((game._phase3_hud.find_child("PowerCaption", true, false) as Label).text == "決心"
		and game._boke_tsukkomi_button.text == "反駁！", "the HUD and the round buttons use its words")
	_expect(game._phase3_hud.panel.get_theme_stylebox("panel").resource_path.ends_with("plain/hud_panel.tres")
		and not game._phase3_hud.power_value.has_theme_font_override("font"), "and its HUD resources (no HUD font)")
	var payload: Dictionary = game._build_save_payload("")
	_expect(not payload.is_empty() and str((payload["runner"] as Dictionary)["story_id"]) == "fixture_chapter_a",
		"the save holds the story, not the skin")
	game._show_title()
	await _frames(2)
	game._choose_story(game._story_choices[1])
	await _frames(3)
	_expect(game._ui_style_id == "gintama" and game._title_screen.scene_file_path.ends_with("title_screen_gintama.tscn")
		and (game._title_screen.find_child("Logo", true, false) as Label).text == "萬事屋\n吐槽 ADV",
		"choosing a story with the base skin puts 銀魂和紙 back")
	_expect(game._phase3_hud.glasses.get_child_count() == 0 or
		(game._phase3_hud.glasses.get_child(0) as Control).scene_file_path.ends_with("glasses_icon.tscn"),
		"and the glasses as the life icon")
	game._choose_story(game._story_choices[0])
	await _frames(3)
	_expect(game._ui_style_id == "plain" and FileAccess.file_exists(FILES[0]), "back to chapter A: its skin, its save kept")
	game.queue_free()
	await _frames(2)


func _no_gameplay_no_gameplay_ui() -> void:
	var game: Control = _new_game("res://data/debt_story.json")
	await _frames(3)
	game._open_settings()
	await _frames(2)
	_expect(not (game._settings_panel.find_child("Assist", true, false) as Control).visible
		and not (game._settings_panel.find_child("AssistLabel", true, false) as Control).visible,
		"a story without rounds hides 設定's 輔助 row")
	game._close_settings()
	game._on_begin_pressed()
	await _until(func() -> bool: return game._screen_mode == "story", "the story starts")
	_expect(not game._phase3_hud.visible and not (game._menu_items["material"] as Button).visible
		and not (game._menu_items["profile"] as Button).visible, "nor the HUD, nor 素材／人物檔案 in 目錄")
	game.queue_free()
	await _frames(2)


func _new_game(story: String) -> Control:
	var game: Control = (load("res://main.tscn") as PackedScene).instantiate() as Control
	game.stories_path = REGISTRY
	game.story_path = story
	game.save_path = FILES[0] if story.contains("chapter_a") else FILES[2]
	game.progress_path = FILES[3]
	game.settings_path = FILES[4]
	game.skins_root = SKINS
	root.add_child(game)
	return game


func _cleanup() -> void:
	for path: String in FILES:
		for suffix: String in ["", ".bak"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
