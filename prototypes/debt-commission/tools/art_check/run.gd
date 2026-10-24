extends SceneTree
## 投稿檢查 from the command line: one report per work, written to build/art_check/<作品>.md.
##   godot --headless --path . --script res://tools/art_check/run.gd [-- stories/<作品> …]
## With no folder: the base work (data/) and every stories/<作品>/. Exits 1 when a work has 錯誤.

const ArtCheck = preload("res://tools/art_check/art_check.gd")
const OUT: String = "res://build/art_check/"


func _init() -> void:
	var folders: Array[String] = []
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			folders.append(arg if arg.begins_with("res://") else "res://" + arg)
	if folders.is_empty():
		folders = ArtCheck.works()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var errors: int = 0
	for folder: String in folders:
		var report: Dictionary = ArtCheck.check(folder)
		var name: String = "base" if folder.trim_suffix("/") + "/" == ArtCheck.BASE_FOLDER else folder.trim_suffix("/").get_file()
		var path: String = OUT + name + ".md"
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(ArtCheck.to_markdown(report))
		file.close()
		errors += ArtCheck.error_count(report)
		print("ART CHECK %s: %d 錯誤, %d 待辦, %d 建議, %d 缺授權 -> %s" % [report["title"], (report["errors"] as Array).size(),
			(report["todo"] as Array).size(), (report["suggestions"] as Array).size(), (report["no_license"] as Array).size(),
			ProjectSettings.globalize_path(path)])
	quit(1 if errors > 0 else 0)
