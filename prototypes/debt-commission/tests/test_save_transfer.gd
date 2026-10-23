extends "res://addons/proto_kit/test_kit.gd"
## 存檔備份 (save_transfer.gd and 設定's 匯出／匯入): a backup holds every save, progress and setting
## file, round-trips byte for byte, replaces the whole set (keeping .before_import copies), and a
## bad file changes nothing. From the title an import brings back 繼續; inside a story it is off.

const Transfer = preload("res://scripts/save_transfer.gd")
const REGISTRY: String = "res://tests/fixtures/stories_chapters.json"
const STORIES: Array = [{"save": "user://transfer_a.save"}, {"save": "user://transfer_b.save"}, {"save": "res://not_ours.save"}]
const SHARED: Array = ["user://transfer_progress.cfg"]
const GAME_FILES: Array[String] = ["user://fixture_chapter_a.save", "user://fixture_chapter_b.save", "user://fixture_sample.save",
	"user://transfer_game_progress.cfg", "user://transfer_game_settings.cfg", "user://transfer_game_ui.cfg", "user://story_choice.cfg"]


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_cleanup()
	_paths()
	_round_trip()
	_rejections()
	await _from_the_title()
	_cleanup()
	_finish("SAVE TRANSFER TESTS")


func _paths() -> void:
	var paths: Array[String] = Transfer.backup_paths(STORIES, SHARED)
	_expect(paths.size() == 2 * 20 + 1, "each story contributes its save, quick slot and 18 manual slots: %d" % paths.size())
	_expect(paths.has("user://transfer_a.manual_18.save") and paths.has("user://transfer_b.quick.save")
		and paths.has("user://transfer_progress.cfg") and not paths.has("res://not_ours.save"),
		"only user:// files are in a backup")


func _round_trip() -> void:
	var allowed: Array[String] = Transfer.backup_paths(STORIES, SHARED)
	_write_var("user://transfer_a.save", {"runner": {"node": "a"}})
	_write_var("user://transfer_a.manual_03.save", {"runner": {"node": "slot3"}})
	_write_text("user://transfer_progress.cfg", "[cleared]\nchapter_a=\"S\"\n")
	var originals: Dictionary = {}
	for path: String in ["user://transfer_a.save", "user://transfer_a.manual_03.save", "user://transfer_progress.cfg"]:
		originals[path] = FileAccess.get_file_as_bytes(path)
	var text: String = Transfer.export_text(allowed, "2026-10-23T12:00:00")
	# Later play on this device: the autosave moves on, a new slot and its .bak appear.
	_write_var("user://transfer_a.save", {"runner": {"node": "later"}})
	_write_var("user://transfer_b.save", {"runner": {"node": "b"}})
	_write_var("user://transfer_b.save.bak", {"runner": {"node": "b-old"}})
	var parsed: Dictionary = Transfer.parse_import(text, allowed)
	_expect(str(parsed["error"]).is_empty() and parsed["files"].size() == 3, "the backup parses: %s" % parsed["error"])
	_expect(Transfer.apply_import(parsed["files"], allowed).is_empty(), "the import applies")
	for path: String in originals:
		_expect(FileAccess.get_file_as_bytes(path) == originals[path], "%s comes back byte for byte" % path)
	_expect(not FileAccess.file_exists("user://transfer_b.save") and not FileAccess.file_exists("user://transfer_b.save.bak"),
		"saves the backup does not have are removed")
	_expect(_read_var("user://transfer_b.save.before_import") == {"runner": {"node": "b"}}
		and _read_var("user://transfer_a.save.before_import") == {"runner": {"node": "later"}},
		"whatever was replaced or removed is kept as .before_import")


func _rejections() -> void:
	var allowed: Array[String] = Transfer.backup_paths(STORIES, SHARED)
	var before: PackedByteArray = FileAccess.get_file_as_bytes("user://transfer_a.save")
	var good: Dictionary = JSON.parse_string(Transfer.export_text(allowed, "now"))
	var cases: Dictionary = {
		"not JSON": "這不是 JSON",
		"another format": JSON.stringify({"format": "other", "version": 1, "files": {}}),
		"a newer version": JSON.stringify({"format": Transfer.FORMAT, "version": 2, "files": good["files"]}),
		"an unknown file": JSON.stringify({"format": Transfer.FORMAT, "version": 1, "files": {"../../escape.save": good["files"]["transfer_a.save"]}}),
		"a save that is not a dictionary": JSON.stringify({"format": Transfer.FORMAT, "version": 1,
			"files": {"transfer_a.save": Marshalls.raw_to_base64(PackedByteArray([1, 2, 3, 4, 5, 6]))}}),
		"a save whose length header is zero": _save_with_header(0),
		"a save whose length header is too large": _save_with_header(1 << 20),
		"a save cut short": _save_with_header(-1, 3),
		"a broken cfg": JSON.stringify({"format": Transfer.FORMAT, "version": 1,
			"files": {"transfer_progress.cfg": Marshalls.utf8_to_base64("[unclosed\n=")}}),
		"no files": JSON.stringify({"format": Transfer.FORMAT, "version": 1, "files": {}}),
	}
	for label: String in cases:
		var parsed: Dictionary = Transfer.parse_import(cases[label], allowed)
		_expect(not str(parsed["error"]).is_empty() and parsed["files"].is_empty(), "%s is refused: %s" % [label, parsed["error"]])
	_expect(FileAccess.get_file_as_bytes("user://transfer_a.save") == before, "a refused backup changes nothing")


## A backup holding transfer_a.save as a store_var of a Dictionary with a wrong length header
## (header < 0: the right length) and `cut` bytes missing from the end. get_var would not read it.
func _save_with_header(header: int, cut: int = 0) -> String:
	var value: PackedByteArray = var_to_bytes({"runner": {"node": "start"}})
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(4)
	bytes.encode_u32(0, value.size() if header < 0 else header)
	bytes.append_array(value.slice(0, value.size() - cut))
	return JSON.stringify({"format": Transfer.FORMAT, "version": 1, "files": {"transfer_a.save": Marshalls.raw_to_base64(bytes)}})


func _from_the_title() -> void:
	var game: Control = _new_game()
	await _frames(3)
	game._on_begin_pressed()
	await _frames(30)
	game._save_game()
	_expect(FileAccess.file_exists("user://fixture_chapter_a.save"), "playing made an autosave")
	game._show_title()
	await _frames(2)
	game._open_settings()
	await _frames(2)
	_expect(not game._settings_panel.import_button.disabled, "from the title 匯入存檔 is offered")
	var text: String = Transfer.export_text(game._backup_paths(), "now")
	_expect(JSON.parse_string(text)["files"].has("fixture_chapter_a.save"), "the export holds the autosave")
	for suffix: String in ["", ".bak"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://fixture_chapter_a.save" + suffix))
	game._refresh_title()
	_expect(game._continue_button.disabled, "without the save there is nothing to continue")
	_expect(not game._import_backup_text("{}") and game._screen_mode == "settings" and game._toast.text == "這不是這個遊戲的存檔備份檔。",
		"a bad file is refused with a reason and 設定 stays open")
	_expect(game._import_backup_text(text) and game._screen_mode == "title", "a good backup imports and returns to the title")
	_expect(not game._continue_button.disabled and game._toast.text == "已匯入存檔", "繼續 is back after the import")
	game._close_settings()
	game.queue_free()
	await _frames(2)
	var in_story: Control = _new_game()
	await _frames(3)
	in_story._on_begin_pressed()
	await _frames(10)
	in_story._screen_mode = "menu"
	in_story._open_settings()
	await _frames(2)
	_expect(in_story._settings_panel.import_button.disabled, "inside a story (目錄) 匯入存檔 is off")
	in_story.queue_free()
	await _frames(2)


func _new_game() -> Control:
	var game: Control = (load("res://main.tscn") as PackedScene).instantiate() as Control
	game.stories_path = REGISTRY
	game.story_path = "res://tests/fixtures/chapter_a_story.json"
	game.save_path = GAME_FILES[0]
	game.progress_path = GAME_FILES[3]
	game.settings_path = GAME_FILES[4]
	root.add_child(game)
	return game


func _write_var(path: String, value: Variant) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_var(value)
	file.close()


func _read_var(path: String) -> Variant:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var value: Variant = file.get_var()
	file.close()
	return value


func _write_text(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _cleanup() -> void:
	var paths: Array[String] = Transfer.backup_paths(STORIES, SHARED)
	paths.append_array(GAME_FILES)
	for path: String in paths:
		for suffix: String in ["", ".bak", ".before_import", ".bak.before_import"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
