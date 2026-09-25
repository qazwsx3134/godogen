@tool
extends EditorPlugin
## Project > Tools menu for writers: build the story file selected in the FileSystem dock
## (story_src/*.ds or *.dialogue) into data/<name>_story.json, optionally playing it right away.
## Editor-only: the Web export excludes this folder.

const StoryBuilder = preload("res://tools/story_build/story_builder.gd")
const PREVIEW_SCENE: String = "res://tools/story_build/preview.tscn"
const PREVIEW_STORY_FILE: String = "user://story_preview_path.txt"
const PREVIEW_SAVE: String = "user://story_preview.save"
const MENU_BUILD: String = "劇本：建置選取的檔案"
const MENU_PLAY: String = "劇本：建置並試玩"


func _enter_tree() -> void:
	add_tool_menu_item(MENU_BUILD, _on_build.bind(false))
	add_tool_menu_item(MENU_PLAY, _on_build.bind(true))


func _exit_tree() -> void:
	remove_tool_menu_item(MENU_BUILD)
	remove_tool_menu_item(MENU_PLAY)


func _on_build(play: bool) -> void:
	var sources: Array = Array(EditorInterface.get_selected_paths()).filter(func(path: String) -> bool:
		return path.get_extension() in ["ds", "dialogue"])
	if sources.size() != 1:
		_tell("先在左下的「檔案系統」面板點選一個劇本檔（story_src 資料夾裡的 .ds 或 .dialogue），再選這個選單。\n在 Parley 或 Dialogue 分頁裡改過的話，記得先存檔（Ctrl+S）。")
		return
	var result: Dictionary = StoryBuilder.build_and_write(sources[0])
	if not String(result["error"]).is_empty():
		_tell("劇本有問題，沒有更新遊戲資料：\n\n%s" % result["error"])
		return
	EditorInterface.get_resource_filesystem().scan()
	if not play:
		_tell("建置完成：%s\n版本 %s（版本改變時，這個故事的舊存檔會失效）" % [result["output"], result["version"]])
		return
	var file: FileAccess = FileAccess.open(PREVIEW_STORY_FILE, FileAccess.WRITE)
	file.store_string(String(result["output"]))
	file.close()
	for suffix: String in ["", ".bak", ".old", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(PREVIEW_SAVE + suffix):
			DirAccess.remove_absolute(PREVIEW_SAVE + suffix)
	EditorInterface.play_custom_scene(PREVIEW_SCENE)


func _tell(message: String) -> void:
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.title = "劇本工具"
	dialog.dialog_text = message
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered()
