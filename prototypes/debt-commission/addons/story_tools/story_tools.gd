@tool
extends EditorPlugin
## Project > Tools menu for writers: build the story file selected in the FileSystem dock
## (story_src/*.ds or *.dialogue) into data/<name>_story.json, optionally playing it right away.
## For artists: 作品：投稿檢查 checks the work of the selected folder or file (tools/art_check/).
## Editor-only: the Web export excludes this folder.

const StoryBuilder = preload("res://tools/story_build/story_builder.gd")
const PREVIEW_SCENE: String = "res://tools/story_build/preview.tscn"
const PREVIEW_STORY_FILE: String = "user://story_preview_path.txt"
const PREVIEW_SAVE: String = "user://story_preview.save"
const MENU_BUILD: String = "劇本：建置選取的檔案"
const MENU_PLAY: String = "劇本：建置並試玩"
const MENU_ART_CHECK: String = "作品：投稿檢查"
const ART_CHECK_SCRIPT: String = "res://tools/art_check/art_check.gd"
const ART_CHECK_OUT: String = "res://build/art_check/"


func _enter_tree() -> void:
	add_tool_menu_item(MENU_BUILD, _on_build.bind(false))
	add_tool_menu_item(MENU_PLAY, _on_build.bind(true))
	add_tool_menu_item(MENU_ART_CHECK, _on_art_check)


func _exit_tree() -> void:
	remove_tool_menu_item(MENU_BUILD)
	remove_tool_menu_item(MENU_PLAY)
	remove_tool_menu_item(MENU_ART_CHECK)


func _on_build(play: bool) -> void:
	var sources: Array = Array(EditorInterface.get_selected_paths()).filter(func(path: String) -> bool:
		return path.get_extension() in ["ds", "dialogue"])
	if sources.size() != 1:
		_tell("先在左下的「檔案系統」面板點選一個劇本檔（story_src 或 stories/<作品> 資料夾裡的 .ds 或 .dialogue），再選這個選單。\n在 Parley 或 Dialogue 分頁裡改過的話，記得先存檔（Ctrl+S）。")
		return
	var result: Dictionary = StoryBuilder.build_and_write(sources[0])
	if not String(result["error"]).is_empty():
		_tell("劇本有問題，沒有更新遊戲資料：\n\n%s" % result["error"])
		return
	EditorInterface.get_resource_filesystem().scan()
	if not play:
		_tell("建置完成：%s\n版本 %s（版本改變時，這個故事的舊存檔會失效）%s" % [result["output"], result["version"],
			"\n第一次建置：已登記進作品的 pack.json（排在最後，本篇章節）。" if result["registered"] else ""])
		return
	var file: FileAccess = FileAccess.open(PREVIEW_STORY_FILE, FileAccess.WRITE)
	file.store_string(String(result["output"]))
	file.close()
	for suffix: String in ["", ".bak", ".old", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(PREVIEW_SAVE + suffix):
			DirAccess.remove_absolute(PREVIEW_SAVE + suffix)
	EditorInterface.play_custom_scene(PREVIEW_SCENE)


## The work of the selected folder or file: stories/<作品>/…, else the base work (data/). Writes
## build/art_check/<作品>.md (not in git) and opens it.
func _on_art_check() -> void:
	var art_check: GDScript = load(ART_CHECK_SCRIPT)
	var selected: Array = Array(EditorInterface.get_selected_paths())
	var folder: String = "res://data/"
	if not selected.is_empty() and String(selected[0]).begins_with("res://stories/"):
		var parts: PackedStringArray = String(selected[0]).trim_prefix("res://stories/").split("/", false)
		if not parts.is_empty():
			folder = "res://stories/%s/" % parts[0]
	var report: Dictionary = art_check.check(folder)
	var name: String = "base" if folder == "res://data/" else folder.trim_suffix("/").get_file()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ART_CHECK_OUT))
	var path: String = ProjectSettings.globalize_path(ART_CHECK_OUT + name + ".md")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(art_check.to_markdown(report))
	file.close()
	OS.shell_open(path)
	_tell("投稿檢查：%s\n錯誤 %d、待辦 %d、建議 %d、缺授權 %d\n\n報告：%s\n（要檢查別的作品，先在「檔案系統」點選 stories 裡那個作品的資料夾）"
		% [report["title"], (report["errors"] as Array).size(), (report["todo"] as Array).size(),
		(report["suggestions"] as Array).size(), (report["no_license"] as Array).size(), path])


func _tell(message: String) -> void:
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.title = "劇本工具"
	dialog.dialog_text = message
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered()
