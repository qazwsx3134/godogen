extends "res://addons/proto_kit/test_kit.gd"
## The writer workflow behind Project > Tools: stories without a blocks file, the default output
## path, build_and_write, and the preview scene playing a built story.

const StoryBuilder = preload("res://tools/story_build/story_builder.gd")
const PREVIEW_SCENE: PackedScene = preload("res://tools/story_build/preview.tscn")
const PREVIEW_STORY_FILE: String = "user://story_preview_path.txt"
const PREVIEW_SAVE: String = "user://story_preview.save"
const WRITTEN: String = "user://story_tools_test.json"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_story_without_blocks_file()
	_test_build_and_write()
	await _test_preview_plays_the_built_story()
	_cleanup()
	_finish("STORY TOOLS TESTS")


func _test_story_without_blocks_file() -> void:
	var text: String = "~ start\n新八: 只有台詞的故事不需要 blocks 檔。\ndo end(\"完\")\n"
	var built: Dictionary = StoryBuilder.build_text(text, "res://story_src/dialogue_only.dialogue")
	_expect(String(built["error"]).is_empty(), "a story without a blocks file builds: %s" % built["error"])
	_expect(String(built["story"].get("id", "")) == "dialogue_only", "its id defaults to the file name")
	var gameplay: Dictionary = StoryBuilder.build_text("~ start\ndo investigate(\"x\")\ndo end(\"完\")\n", "res://story_src/dialogue_only.dialogue")
	_expect(String(gameplay["error"]).contains("unknown block 'x'"), "gameplay blocks still need a blocks file")


func _test_build_and_write() -> void:
	_expect(StoryBuilder.output_path_for("res://story_src/phase4.ds") == "res://data/phase4_story.json",
		"story_src/<name>.ds builds to data/<name>_story.json")
	var result: Dictionary = StoryBuilder.build_and_write("res://story_src/phase4.ds", WRITTEN)
	_expect(String(result["error"]).is_empty() and String(result["version"]).begins_with("s-"), "build_and_write succeeds")
	var written: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(WRITTEN))
	var committed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/phase4_story.json"))
	_expect(String(written.get("generated_from", "")) == "story_src/phase4.ds", "the written story records its source")
	written.erase("generated_from")
	committed.erase("generated_from")
	_expect(written == committed, "the written story equals the committed build (Parley and .dialogue agree)")
	var broken: Dictionary = StoryBuilder.build_and_write("res://story_src/missing.ds", WRITTEN)
	_expect(String(broken["error"]).contains("file not found"), "a missing source reports an error instead of writing")


func _test_preview_plays_the_built_story() -> void:
	root.size = Vector2i(540, 960)
	var file: FileAccess = FileAccess.open(PREVIEW_STORY_FILE, FileAccess.WRITE)
	file.store_string("res://data/phase4_story.json")
	file.close()
	var preview: Node = PREVIEW_SCENE.instantiate()
	root.add_child(preview)
	await _frames(3)
	var game: Control = preview.get_child(0) as Control
	_expect(game != null and game._story_ready, "the preview loads the built story")
	_expect(game != null and game.save_path == PREVIEW_SAVE, "the preview uses its own save file")
	if game != null:
		game._on_begin_pressed()
		game._set_skip(true)
		await _until(func() -> bool: return game._screen_mode == "investigate", "the preview plays into the investigation")
	preview.queue_free()
	await _frames(2)


func _cleanup() -> void:
	for path: String in [WRITTEN, PREVIEW_STORY_FILE, PREVIEW_SAVE, PREVIEW_SAVE + ".bak", PREVIEW_SAVE + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
