extends SceneTree
## Build StoryRunner JSON from an authoring source:
##   godot --headless --path . --script res://tools/story_build/build_story.gd -- \
##       story_src/phase4.dialogue [data/phase4_story.json] [--check]
## The output defaults to data/<name>_story.json.
## --check writes nothing and exits 1 when the output file differs from a fresh build.

const StoryBuilder = preload("res://tools/story_build/story_builder.gd")


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var check: bool = args.has("--check")
	var paths: Array = Array(args).filter(func(a: String) -> bool: return not a.begins_with("--"))
	if paths.size() < 1 or paths.size() > 2:
		printerr("usage: build_story.gd -- <source.dialogue|.ds> [output.json] [--check]")
		quit(2)
		return
	var source: String = _project_path(paths[0])
	var output: String = _project_path(paths[1]) if paths.size() == 2 else StoryBuilder.output_path_for(source)
	if check:
		var built: Dictionary = StoryBuilder.build(source)
		var current: String = FileAccess.get_file_as_string(output) if FileAccess.file_exists(output) else ""
		if not String(built["error"]).is_empty() or current != StoryBuilder.to_json(built["story"]):
			printerr("STORY BUILD DRIFT: %s differs from a fresh build of %s %s" % [output, source, built["error"]])
			quit(1)
			return
		print("STORY BUILD UP TO DATE: ", output)
		quit(0)
		return
	var result: Dictionary = StoryBuilder.build_and_write(source, output)
	if not String(result["error"]).is_empty():
		printerr("STORY BUILD FAILED: ", result["error"])
		quit(1)
		return
	print("STORY BUILT: %s -> %s (version %s)" % [source, result["output"], result["version"]])
	quit(0)


## Relative paths are relative to the project; absolute and user:// paths are kept.
func _project_path(path: String) -> String:
	if path.begins_with("/") or path.contains("://"):
		return path
	return "res://" + path
