extends "res://addons/proto_kit/test_kit.gd"
## Scene changes: a bg step's `transition` (fade, brush, ink, glitch) is validated, wipes the old
## picture through scene_transition.gdshader, holds the next line until the wipe ends, and settles
## at once under 畫面效果：減少 or when skipping.

const StoryRunner = preload("res://scripts/story_runner.gd")
const PATHS: Array[String] = ["user://scene_transition_test.save", "user://scene_transition_test.cfg",
	"user://scene_transition_test_progress.cfg"]


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_validation()
	var game: Control = (load("res://main.tscn") as PackedScene).instantiate()
	game.story_path = "res://data/transitions_story.json"
	game.save_path = PATHS[0]
	game.settings_path = PATHS[1]
	game.progress_path = PATHS[2]
	game.tutorials_enabled = false
	root.add_child(game)
	await _frames(3)
	game._on_begin_pressed()
	await _until(func() -> bool: return game._screen_mode == "story", "the sample starts")
	var ghost: TextureRect = game._motion.ghost
	var before: String = game._current_bg_id

	await _advance(game)  # the opening line → bg kitchen, brush
	_expect(game._current_bg_id == "yorozuya_kitchen" and before == "yorozuya_living_room", "the brush step changes the background")
	var material: ShaderMaterial = ghost.material as ShaderMaterial
	_expect(ghost.visible and material != null and material.shader == load("res://shaders/scene_transition.gdshader"),
		"the old picture stays on top with the transition shader")
	_expect(material != null and int(material.get_shader_parameter("style")) == 0, "brush is shader style 0")
	_expect(game._screen_mode == "busy", "the next line waits for the wipe")
	await create_timer(0.35).timeout
	var midway: float = float(material.get_shader_parameter("progress")) if material != null else -1.0
	_expect(midway > 0.05 and midway < 0.95, "the wipe is part way through (%.2f)" % midway)
	await _until(func() -> bool: return game._screen_mode == "story", "the line after the wipe shows")
	_expect(not ghost.visible, "the wipe leaves nothing behind")

	await _advance(game)  # → exterior, ink
	_expect(ghost.material != null and int((ghost.material as ShaderMaterial).get_shader_parameter("style")) == 1, "ink is shader style 1")
	await _until(func() -> bool: return game._screen_mode == "story", "the ink wipe ends")

	game._on_setting_changed("motion", 1)
	await _advance(game)  # → living room, glitch, reduced
	_expect(game._current_bg_id == "yorozuya_living_room" and not ghost.visible, "reduced motion cuts straight to the new scene")
	await _until(func() -> bool: return game._screen_mode == "story", "reduced motion does not hold the line")
	game._on_setting_changed("motion", 0)

	await _advance(game)  # → kitchen, fade (the default)
	var shader_used: bool = ghost.material is ShaderMaterial and (ghost.material as ShaderMaterial).shader == load("res://shaders/scene_transition.gdshader")
	_expect(ghost.visible and not shader_used, "fade crossfades without the transition shader")
	await _until(func() -> bool: return game._screen_mode == "story", "a fade never holds the line")

	# Hardening: starting over in the middle of a wipe leaves no half-wiped picture behind, and the
	# old wipe's wait does not push the new story along.
	await _until(func() -> bool: return game._screen_mode == "story", "the sample is readable")
	game._on_restart_pressed()
	await _until(func() -> bool: return game._screen_mode == "story", "the sample starts over")
	await _advance(game)  # → kitchen, brush again
	_expect(ghost.visible and ghost.material != null, "a wipe is running")
	game._on_restart_pressed()
	await _frames(2)
	_expect(not ghost.visible and ghost.material == null, "starting over clears the wipe at once")
	await _until(func() -> bool: return game._screen_mode == "story", "the new start reads")
	await create_timer(0.9).timeout
	_expect(game._current_bg_id == "yorozuya_living_room" and game._screen_mode == "story",
		"the cancelled wipe's wait does not advance the new start (bg %s)" % game._current_bg_id)

	game.queue_free()
	await _frames(2)
	for path: String in PATHS:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_finish("SCENE TRANSITION")


func _check_validation() -> void:
	var runner: RefCounted = StoryRunner.new()
	var story: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/transitions_story.json"))
	var bad: Dictionary = story.duplicate(true)
	((bad["nodes"]["transitions_demo"]["steps"] as Array)[3] as Dictionary)["transition"] = "spin"
	var path: String = "user://scene_transition_bad.json"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(bad))
	file.close()
	_expect(not bool(runner.call("load_story", path)), "an unknown bg transition is refused")
	_expect(str(runner.get("error_message")).contains("bg transition"), "the error names the bg transition")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_expect(bool(runner.call("load_story", "res://data/transitions_story.json")), "the transitions sample is valid")


## Taps the dialogue on to the next line (finishing the typing first when needed).
func _advance(game: Control) -> void:
	await _until(func() -> bool: return game._screen_mode == "story", "the reading screen is ready")
	var line: String = game._full_text
	game._on_screen_tap()
	await _frames(2)
	if game._screen_mode == "story" and game._full_text == line:
		game._on_screen_tap()
	await _frames(2)
