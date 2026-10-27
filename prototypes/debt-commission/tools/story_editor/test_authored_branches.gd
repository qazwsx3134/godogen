extends SceneTree
## Run against the temporary story built by preview_smoke.mjs, using the game's actual runner.

const StoryRunner: Script = preload("res://scripts/story_runner.gd")


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		printerr("Expected the authored story path")
		quit(1)
		return
	for option_id: String in ["a", "b", "opt3"]:
		var runner: RefCounted = StoryRunner.new()
		if not runner.load_story(args[0]):
			_fail("Story could not load: %s" % runner.error_message)
			return
		if runner.current().get("op") != "say" or runner.advance().get("op") != "choice":
			_fail("The first line did not lead to the choice")
			return
		if not runner.choose(option_id):
			_fail("The option '%s' could not be chosen" % option_id)
			return
		var expected: String = {"a": "node_1", "b": "node_2", "opt3": "node_3"}[option_id]
		if runner.current().get("node_id") != expected or runner.advance().get("op") != "end":
			_fail("The option '%s' did not reach its ending" % option_id)
			return
	print("AUTHORED BRANCHES PASSED")
	quit(0)


func _fail(message: String) -> void:
	printerr("FAIL ", message)
	quit(1)
