extends "res://addons/proto_kit/test_kit.gd"
## 劇本：建置 for a work: stories/<作品>/<name>.dialogue builds beside itself with the work's
## catalog and is listed in its pack.json once; a taken story id is refused before anything is
## written; story_src/ still builds into data/. The preview plays a work's story with its skin and cast.

const Builder = preload("res://tools/story_build/story_builder.gd")
const WORK: String = "res://stories/_build_test/"
const SOURCE: String = "~ start\n秋: 又沒趕上。\ndo end(\"完\")\n"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_remove_work()
	_paths()
	_build_into_work()
	_example_unchanged()
	await _preview()
	_remove_work()
	_finish("BUILD PACKS TESTS")


func _paths() -> void:
	_expect(Builder.output_path_for("res://story_src/chapter1.dialogue") == "res://data/chapter1_story.json", "story_src builds into data/")
	_expect(Builder.output_path_for("res://stories/example/ch1.dialogue") == "res://stories/example/ch1_story.json",
		"a work's source builds beside itself")
	_expect(Builder.output_path_for("res://stories/no_pack_here/ch1.dialogue") == "res://data/ch1_story.json",
		"a folder without pack.json is not a work")


func _build_into_work() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORK))
	_write(WORK + "pack.json", JSON.stringify({"id": "_build_test", "title": "建置測試", "stories": []}))
	_write(WORK + "catalog.json", FileAccess.get_file_as_string("res://stories/example/catalog.json"))
	_write(WORK + "late.dialogue", SOURCE)
	_write(WORK + "late.blocks.json", JSON.stringify({"story": {"id": "build_test_late", "title": "晚班"}, "titles": {}, "blocks": {}}))
	var result: Dictionary = Builder.build_and_write(WORK + "late.dialogue")
	_expect(str(result["error"]).is_empty() and result["output"] == WORK + "late_story.json" and result["registered"],
		"built beside the source with the work's 秋, and listed: %s" % [result])
	var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(WORK + "pack.json"))
	_expect(pack["stories"] == [{"id": "build_test_late", "kind": "chapter", "path": "late_story.json"}], "pack.json row: %s" % [pack["stories"]])
	result = Builder.build_and_write(WORK + "late.dialogue")
	pack = JSON.parse_string(FileAccess.get_file_as_string(WORK + "pack.json"))
	_expect(not result["registered"] and (pack["stories"] as Array).size() == 1, "building again does not list it twice")
	_write(WORK + "taken.dialogue", SOURCE)
	_write(WORK + "taken.blocks.json", JSON.stringify({"story": {"id": "example_ch1", "title": "撞名"}, "titles": {}, "blocks": {}}))
	result = Builder.build_and_write(WORK + "taken.dialogue")
	_expect(str(result["error"]).contains("example_ch1") and not FileAccess.file_exists(WORK + "taken_story.json"),
		"an id another work has is refused and nothing is written: %s" % result["error"])


func _example_unchanged() -> void:
	var built: Dictionary = Builder.build("res://stories/example/ch1.dialogue")
	_expect(Builder.to_json(built["story"]) == FileAccess.get_file_as_string("res://stories/example/ch1_story.json"),
		"rebuilding the example's chapter gives the committed file byte for byte")


func _preview() -> void:
	var game: Control = (load("res://main.tscn") as PackedScene).instantiate() as Control
	game.story_path = WORK + "late_story.json"
	game.save_path = "user://build_packs_preview.save"
	game.progress_path = "user://build_packs_progress.cfg"
	game.settings_path = "user://build_packs_settings.cfg"
	root.add_child(game)
	await _frames(3)
	_expect(game._sprites.has("aki") and not game._sprites.has("shinpachi"), "the preview plays it with the work's cast")
	game.queue_free()
	await _frames(2)
	for path: String in ["user://build_packs_preview.save", "user://build_packs_progress.cfg", "user://build_packs_settings.cfg"]:
		for suffix: String in ["", ".bak"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _remove_work() -> void:
	var folder: String = ProjectSettings.globalize_path(WORK)
	if not DirAccess.dir_exists_absolute(folder):
		return
	for file: String in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)
