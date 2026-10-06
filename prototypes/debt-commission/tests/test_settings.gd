extends "res://addons/proto_kit/test_kit.gd"
## 設定: opens from the title and from 目錄 (returning to each), the defaults keep the old speeds
## and volumes, choices apply at once and persist, 瞬間 shows a whole line at once, and volumes
## reach the players (目錄's 音效 switch still silences everything).

const SETTINGS_PATH: String = "user://settings_test.cfg"
const SAVE: String = "user://settings_test.save"
const UI: String = "user://settings_test_ui.cfg"
const Settings = preload("res://scripts/settings.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_cleanup()
	var game: Control = _new_game()
	await _frames(3)
	_expect(game._settings == Settings.DEFAULTS and is_equal_approx(game._text_interval(), 0.032),
		"defaults keep the old text speed and full volume")
	await _press(game._title_screen.settings_button)
	var buttons: Dictionary = game._settings_panel.call("buttons")
	_expect(game._screen_mode == "settings" and game._settings_panel.visible and buttons.size() == 4 + 3 + 5 + 5 + 3 + 3,
		"設定 opens from the title with every choice")
	await _press(buttons["text_speed_3"])
	await _press(buttons["bgm_volume_2"])
	await _press(buttons["se_volume_0"])
	_expect(game._settings["text_speed"] == 3 and is_equal_approx(game._effects._bgm_level, 0.5)
		and game._effects._se_level == 0.0, "choices apply at once")
	var saved: Dictionary = Settings.load_settings(SETTINGS_PATH)
	_expect(saved["text_speed"] == 3 and saved["bgm_volume"] == 2 and saved["se_volume"] == 0, "choices persist")
	await _press(game._settings_panel.close_button)
	_expect(game._screen_mode == "title" and not game._settings_panel.visible, "closing returns to the title")

	game._on_begin_pressed()
	await _until(func() -> bool: return game._screen_mode == "story", "story starts")
	await _frames(2)
	_expect(game._text_complete, "瞬間 shows the whole line at once")
	game._open_menu()
	await create_timer(0.4).timeout  # the panel pops in
	await _press(game._menu_items["settings"])
	_expect(game._screen_mode == "settings" and game._menu_overlay.visible, "設定 opens over 目錄")
	await _press(game._settings_panel.call("buttons")["text_speed_1"])
	await _press(game._settings_panel.close_button)
	_expect(game._screen_mode == "menu" and game._menu_overlay.visible, "closing returns to 目錄")
	game._close_menu()
	game.queue_free()
	await _frames(2)

	var reopened: Control = _new_game()
	await _frames(3)
	_expect(reopened._settings["bgm_volume"] == 2 and reopened._settings["text_speed"] == 1
		and is_equal_approx(reopened._effects._bgm_level, 0.5), "settings come back on the next run")
	reopened._audio_muted = false
	reopened._settings["se_volume"] = 4
	reopened._apply_audio_levels()
	var legacy: AudioStreamPlayer = reopened._audio_players.values()[0]
	_expect(is_equal_approx(legacy.volume_db, 0.0), "full sound volume keeps the old level")
	reopened._toggle_mute()
	_expect(legacy.volume_db <= -79.0, "目錄's 音效 switch silences sound whatever the volume")
	reopened.queue_free()
	await _frames(2)
	_cleanup()
	_finish("settings")


func _new_game() -> Control:
	var game: Control = (load("res://main.tscn") as PackedScene).instantiate() as Control
	game.settings_path = SETTINGS_PATH
	game.save_path = SAVE
	game.ui_preference_path = UI
	root.add_child(game)
	return game


func _cleanup() -> void:
	for path: String in [SETTINGS_PATH, SAVE, UI]:
		for suffix: String in ["", ".bak", ".old", ".tmp", ".bak.tmp"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
