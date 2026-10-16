extends "res://addons/proto_kit/test_kit.gd"
## Loaded story definitions remain authoritative; save previews never change live state.
const Runner := preload("res://scripts/story_runner.gd")
const MAIN := preload("res://main.tscn")
const SOURCE := "user://studio_save_validation_story.json"
const SAVE := "user://studio_save_validation.save"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var runner := Runner.new()
	_expect(runner.create_validation_probe() == null, "an unloaded runner has no validation probe")
	_expect(runner.load_story("res://data/chapter1_story.json"), "chapter one loads")
	var state: Dictionary = runner.snapshot()
	var probe: RefCounted = runner.create_validation_probe()
	_expect(probe != null and probe.restore(state), "a probe accepts the loaded chapter snapshot")
	probe.flags["probe_only"] = true
	probe.advance()
	_expect(runner.snapshot() == state and not runner.flags.has("probe_only"), "probe navigation and flags cannot mutate the live runner")
	_expect(probe.restore(state) and not probe.flags.has("probe_only"), "each validation starts from the complete supplied save state")
	var bad: Dictionary = state.duplicate(true)
	bad.version = "incompatible-version"
	_expect(not probe.restore(bad), "a probe rejects an incompatible story version")
	_expect(probe.snapshot() == state and runner.snapshot() == state, "failed validation leaves both state machines intact")
	_expect(runner.load_story("res://data/phase2_story.json"), "another story can replace the live chapter")
	_expect(not runner.create_validation_probe().restore(state), "new probes reject saves from the previous story")
	_expect(probe.restore(state), "an existing probe retains its original validated definition")
	await _test_shell_cache()
	_finish("SAVE VALIDATION TESTS")

func _write_source(version: String = "") -> void:
	var story: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/reading_convenience_story.json"))
	if not version.is_empty():
		story.version = version
	var file := FileAccess.open(SOURCE, FileAccess.WRITE)
	file.store_string(JSON.stringify(story))
	file.close()

func _test_shell_cache() -> void:
	_write_source()
	var game := MAIN.instantiate()
	game.story_path = SOURCE
	game.save_path = SAVE
	game.ui_preference_path = "user://studio_save_validation_ui.cfg"
	game.settings_path = "user://studio_save_validation_settings.cfg"
	game.progress_path = "user://studio_save_validation_progress.cfg"
	root.add_child(game)
	await _frames(3)
	_expect(game._story_ready, "shell loads a user story fixture")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SOURCE))
	game._on_begin_pressed()
	await _until(func() -> bool: return game._screen_mode == "story", "fixture opening line")
	game._complete_current_line()
	var payload: Dictionary = game._build_save_payload("")
	var before: Dictionary = game._runner.snapshot()
	_expect(game._validate_save_payload(payload), "validation uses the running story even after its source file is removed")
	_expect(game._save_game(), "autosave needs no story re-read")
	var malformed: Dictionary = payload.duplicate(true)
	malformed.runner.flags["unknown_flag"] = true
	_expect(not game._validate_save_payload(malformed), "a reused probe still rejects malformed flags")
	_expect(game._validate_save_payload(payload) and game._runner.snapshot() == before, "valid-invalid-valid previews cannot contaminate live progress")
	_write_source("studio-reloaded-version")
	game._load_story()
	var reloaded: Dictionary = game._build_save_payload("")
	_expect(game._validate_save_payload(reloaded), "reloading a changed story version refreshes its validator")
	_expect(not game._validate_save_payload(payload), "the replaced version's save cannot be loaded")
	game.queue_free()
	await _frames(2)
	for path: String in [SOURCE, SAVE, SAVE + ".bak", SAVE + ".tmp", SAVE + ".old"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
