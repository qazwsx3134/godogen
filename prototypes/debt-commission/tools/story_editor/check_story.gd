extends SceneTree
## Checks a story JSON the way the game and the build do, and keeps its `version` right. Run it on
## every file the story editor exports:
##   godot --headless --path . --script res://tools/story_editor/check_story.gd -- <story.json> [--write]
##
## 1. StoryRunner.load_story() accepts it (the validation the game runs).
## 2. Every node can be reached from `entry` (story_builder.gd's check; the editor's red cards mirror it).
## 3. `version` equals StoryBuilder.fingerprint(story). A stale one is reported; with --write it is fixed
##    in place and the file is rewritten in the build's format (sorted keys), but only when 1 and 2 pass.
## Prints OK and exits 0, or prints every problem and exits 1. Without --write the file is not touched.
## --reach-all prints, for each node taken as the start, the nodes it cannot reach (test_core.mjs compares
## that table with the editor's own reachability).
## A relative path is relative to the project; absolute and user:// paths are kept.

const StoryBuilder = preload("res://tools/story_build/story_builder.gd")
const StoryRunner = preload("res://scripts/story_runner.gd")
const AtomicFile = preload("res://addons/proto_kit/atomic_file.gd")


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var paths: Array = Array(args).filter(func(a: String) -> bool: return not a.begins_with("--"))
	if paths.size() != 1:
		printerr("usage: check_story.gd -- <story.json> [--write] [--reach-all]")
		quit(2)
		return
	var path: String = _project_path(paths[0])
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if not parsed is Dictionary:
		printerr("FAILED %s: not found, or not a JSON object" % path)
		quit(1)
		return
	var story: Dictionary = parsed
	var shape_error: String = _shape_error(story)
	if not shape_error.is_empty():
		printerr("FAILED %s: %s" % [path, shape_error])
		quit(1)
		return
	var nodes: Dictionary = story["nodes"]
	var entry: String = String(story.get("entry", ""))

	if args.has("--reach-all"):
		var table: Dictionary = {}
		for start: String in nodes.keys():
			table[start] = StoryBuilder._unreachable(start, nodes)
		print("REACHALL ", JSON.stringify(table))
		quit(0)
		return

	var problems: Array[String] = []
	var runner: RefCounted = StoryRunner.new()
	if not runner.call("load_story", path):
		problems.append("StoryRunner rejects it: %s" % runner.get("error_message"))
	var unreachable: Array[String] = StoryBuilder._unreachable(entry, nodes)
	if not unreachable.is_empty():
		problems.append("unreachable from '%s' (%d): %s" % [entry, unreachable.size(), ", ".join(unreachable)])
	var expected: String = StoryBuilder.fingerprint(story)
	var stale: bool = String(story.get("version", "")) != expected
	var wrote: bool = false
	if stale and args.has("--write") and problems.is_empty():
		story["version"] = expected
		if AtomicFile.write_text(path, StoryBuilder.to_json(story)) != OK:
			problems.append("cannot write %s" % path)
		else:
			wrote = true
			if not runner.call("load_story", path):
				problems.append("StoryRunner rejects the rewritten file: %s" % runner.get("error_message"))
	elif stale:
		var how: String = "run again with --write to fix it" if problems.is_empty() else "--write fixes it once the errors above are gone"
		problems.append("version is '%s' but this structure's is '%s' (%s)" % [story.get("version", ""), expected, how])

	if not problems.is_empty():
		for problem: String in problems:
			printerr("ERROR ", problem)
		printerr("FAILED %s: %d problem(s)" % [path, problems.size()])
		quit(1)
		return
	print("%s: %d nodes, %d endings, entry '%s', version %s%s" % [path.get_file(), nodes.size(), _endings(nodes), entry, expected, " (written)" if wrote else ""])
	print("OK ", path)
	quit(0)


## Relative paths are relative to the project; absolute and user:// paths are kept.
func _project_path(path: String) -> String:
	if path.begins_with("/") or path.contains("://"):
		return path
	return "res://" + path


## StoryBuilder walks nodes, steps and options with typed loops; give it only what it can walk.
func _shape_error(story: Dictionary) -> String:
	if not story.get("nodes") is Dictionary or (story["nodes"] as Dictionary).is_empty():
		return "nodes must be a non-empty object"
	for node_id: Variant in (story["nodes"] as Dictionary).keys():
		var node: Variant = story["nodes"][node_id]
		if not node is Dictionary or not (node as Dictionary).get("steps") is Array:
			return "node '%s' must be an object with a steps array" % node_id
		for step: Variant in (node as Dictionary)["steps"]:
			if not step is Dictionary:
				return "node '%s' has a step that is not an object" % node_id
	return ""


func _endings(nodes: Dictionary) -> int:
	var count: int = 0
	for node: Dictionary in nodes.values():
		for step: Dictionary in node["steps"]:
			if ["end", "result"].has(String(step.get("op", ""))):
				count += 1
				break
	return count
