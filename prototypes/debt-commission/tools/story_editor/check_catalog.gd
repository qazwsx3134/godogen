extends SceneTree
## Checks an edited catalog before the story editor saves it: the catalog itself (as the game
## validates it) and every story that reads it, directly or through `extends`.
##   godot --headless --path . --script res://tools/story_editor/check_catalog.gd -- \
##       --candidate=<edited file> --replaces=res://<catalog it replaces> [<story>=<its catalog> …]
## The candidate sits in the replaced catalog's folder, so its relative paths resolve the same.
## Prints OK and exits 0, or every problem (ERROR …) and exits 1.

const StoryRunner = preload("res://scripts/story_runner.gd")


func _init() -> void:
	var candidate: String = ""
	var replaces: String = ""
	var pairs: Array[PackedStringArray] = []
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--candidate="):
			candidate = arg.trim_prefix("--candidate=")
		elif arg.begins_with("--replaces="):
			replaces = arg.trim_prefix("--replaces=")
		elif arg.contains("="):
			pairs.append(arg.split("=", true, 1))
	if candidate.is_empty() or replaces.is_empty():
		printerr("usage: check_catalog.gd -- --candidate=<file> --replaces=<res://…catalog.json> [<story>=<catalog> …]")
		quit(2)
		return
	var redirect: Dictionary = {replaces: candidate}
	var runner: RefCounted = StoryRunner.new()
	var problems: Array[String] = []
	var own: Dictionary = StoryRunner.read_catalog(replaces, redirect)
	if own.has("error"):
		problems.append("素材設定讀不了：%s" % own["error"])
	else:
		var error: String = runner.call("_validate_asset_catalog", own["catalog"])
		if not error.is_empty():
			problems.append("素材設定不合法：%s" % error)
	for pair: PackedStringArray in pairs:
		var read: Dictionary = StoryRunner.read_catalog(pair[1], redirect)
		var story: Variant = JSON.parse_string(FileAccess.get_file_as_string(pair[0])) if FileAccess.file_exists(pair[0]) else null
		if read.has("error") or not story is Dictionary:
			problems.append("%s：%s" % [pair[0].get_file(), read.get("error", "劇本讀不了")])
			continue
		var catalog_error: String = runner.call("_validate_asset_catalog", read["catalog"])
		var error: String = catalog_error if not catalog_error.is_empty() else runner.call("_validate_story", story, read["catalog"])
		if not error.is_empty():
			problems.append("%s 用這份素材設定會出錯：%s" % [pair[0].get_file(), error])
	for problem: String in problems:
		printerr("ERROR ", problem)
	if not problems.is_empty():
		quit(1)
		return
	print("OK %s (%d stories)" % [replaces, pairs.size()])
	quit(0)
