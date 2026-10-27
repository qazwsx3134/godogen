extends Node
## Plays main.tscn with the story the Story Tools menu just built, on a separate save file so
## previews never touch the real game's saves. Editor-only (tools/ is excluded from export).

const MAIN_SCENE: PackedScene = preload("res://main.tscn")
const PREVIEW_STORY_FILE: String = "user://story_preview_path.txt"
const PREVIEW_SAVE: String = "user://story_preview.save"


func _ready() -> void:
	var request_path: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--editor-preview="):
			request_path = arg.trim_prefix("--editor-preview=")
	if not request_path.is_empty():
		_start_editor_preview(request_path)
		return
	var game: Control = MAIN_SCENE.instantiate() as Control
	game.story_path = FileAccess.get_file_as_string(PREVIEW_STORY_FILE).strip_edges()
	game.save_path = PREVIEW_SAVE
	add_child(game)


func _start_editor_preview(request_path: String) -> void:
	var request: Variant = JSON.parse_string(FileAccess.get_file_as_string(request_path))
	if not request is Dictionary:
		push_error("Invalid story editor preview request")
		get_tree().quit(1)
		return
	var config: Dictionary = request as Dictionary
	var status_path: String = str(config.get("status", ""))
	var game: Control = MAIN_SCENE.instantiate() as Control
	game.story_path = str(config.get("story", ""))
	game.story_catalog_override = str(config.get("catalog", ""))
	game.story_skin_override = str(config.get("skin", ""))
	game.save_path = "user://editor_preview.save"
	game.progress_path = "user://editor_preview_progress.cfg"
	game.settings_path = "user://editor_preview_settings.cfg"
	game.tutorials_enabled = false
	add_child(game)
	if not game._story_ready:
		_write_status(status_path, {"ok": false, "error": game._story_error})
		get_tree().quit(1)
		return
	game._start_new_story()
	_write_status(status_path, {"ok": true, "snapshot": game._runner.call("snapshot"),
		"user_dir": OS.get_user_data_dir(), "skin": game._ui_style_id})


func _write_status(path: String, status: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot report story preview status")
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(status))
	file.close()
