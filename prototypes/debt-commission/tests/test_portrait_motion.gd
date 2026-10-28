extends "res://addons/proto_kit/test_kit.gd"
## Authoring -> validation -> real reading shell, including animation interruption and reduced motion.

const BUILDER = preload("res://tools/story_build/story_builder.gd")
const RUNNER = preload("res://scripts/story_runner.gd")
const TEST_STORY: String = "user://portrait_motion_story.json"
const TEST_BAD: String = "user://portrait_motion_bad.json"
const TEST_SAVE: String = "user://portrait_motion_test.save"
const SOURCE: String = """~ start
do enter("shinpachi", "shout", "right", "slide_left")
do portrait_effect("shinpachi", "shake")
新八: 這是我的第一句。
do hide("shinpachi", "slide_right")
角色離開了。
do end("完成")
"""

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var built: Dictionary = BUILDER.build_text(SOURCE, "res://story_src/__portrait_motion_test.dialogue")
	_expect(str(built.get("error", "")).is_empty(), "portrait animation source builds: %s" % built.get("error"))
	if not str(built.get("error", "")).is_empty():
		_finish("PORTRAIT MOTION")
		return
	var story: Dictionary = built["story"]
	var steps: Array = story["nodes"]["start"]["steps"]
	_expect(steps[0].get("transition") == "slide_left" and steps[1].get("op") == "portrait_effect"
		and steps[1].get("effect") == "shake" and steps[3].get("transition") == "slide_right",
		"text authoring keeps the entrance, reaction and exit settings")
	for invalid: Array in [[0, "transition", "wrong"], [1, "effect", "wrong"], [1, "id", "missing"]]:
		var broken: Dictionary = story.duplicate(true)
		(broken["nodes"]["start"]["steps"] as Array)[invalid[0]][invalid[1]] = invalid[2]
		FileAccess.open(TEST_BAD, FileAccess.WRITE).store_string(JSON.stringify(broken))
		var runner: RefCounted = RUNNER.new()
		_expect(not runner.call("load_story", TEST_BAD), "invalid portrait step is rejected: %s" % [invalid])
	FileAccess.open(TEST_STORY, FileAccess.WRITE).store_string(BUILDER.to_json(story))
	var game: Control = (load("res://main.tscn") as PackedScene).instantiate() as Control
	game.story_path = TEST_STORY
	game.save_path = TEST_SAVE
	game.settings_path = "user://portrait_motion_settings.cfg"
	game.progress_path = "user://portrait_motion_progress.cfg"
	game.tutorials_enabled = false
	root.add_child(game)
	await _frames(3)
	_expect(game._story_ready, "the authored story loads in the game: %s" % game._story_error)
	game._on_begin_pressed()
	await _until(func() -> bool: return game._screen_mode == "story", "the first line shows")
	var sprite: Control = game._sprites["shinpachi"] as Control
	var art: Control = sprite.get_node("Art") as Control
	var motion: Node = game._motion
	var state: Dictionary = motion._characters.get(sprite, {})
	var rest: Vector2 = state.get("position", art.position)
	var standing: Vector2 = sprite.position
	_expect(state.get("kind") == "enter" and state.get("queued") == "shake",
		"the reaction waits for the entrance even when the dialogue follows immediately")
	_expect(sprite.visible and art.modulate.a < 0.9 and art.position.x < rest.x,
		"the character fades and slides in from the selected side")
	var saw_shake: bool = false
	var deadline: int = Time.get_ticks_msec() + 1000
	while Time.get_ticks_msec() < deadline and (not saw_shake or motion.character_kind(sprite) != ""):
		if motion.character_kind(sprite) == "shake" and absf(art.position.x - rest.x) > 2.0:
			saw_shake = true
		await process_frame
	_expect(saw_shake, "the queued shake visibly moves the portrait")
	_expect(art.position.distance_to(rest) < 0.1 and sprite.position.distance_to(standing) < 0.1,
		"the portrait returns to its authored position without moving its standing box")
	game._complete_current_line()
	game._on_screen_tap()
	await _until(func() -> bool: return game._screen_mode == "story" and game._current_speaker == "narrator", "the next line shows")
	_expect(motion.character_kind(sprite) == "leave" and sprite.visible, "exit begins while the next line is readable")
	_expect(game._actor_slots["shinpachi"] == "right" and sprite.expression == "shout",
		"exit retains the current slot and expression instead of snapping to defaults")
	var during_exit: Dictionary = game._read_save_payload()
	_expect(not bool(during_exit.get("sprites", {}).get("shinpachi", {}).get("visible", true)),
		"the next line's autosave records a departing character as off stage")
	await create_timer(0.1).timeout
	_expect(art.modulate.a < 1.0 and art.position.x > rest.x, "exit fades and slides toward the selected side")
	await create_timer(0.2).timeout
	_expect(not sprite.visible and art.position.distance_to(rest) < 0.1 and is_equal_approx(art.modulate.a, 1.0),
		"the completed exit hides the character and restores its art")
	var resumed: Control = (load("res://main.tscn") as PackedScene).instantiate() as Control
	resumed.story_path = TEST_STORY
	resumed.save_path = TEST_SAVE
	resumed.settings_path = "user://portrait_motion_settings.cfg"
	resumed.progress_path = "user://portrait_motion_progress.cfg"
	resumed.tutorials_enabled = false
	root.add_child(resumed)
	await _frames(3)
	resumed._on_continue_pressed()
	await _until(func() -> bool: return resumed._screen_mode == "story", "the exit autosave restores")
	_expect(not (resumed._sprites["shinpachi"] as Control).visible, "loading during the next line does not bring the departed character back")
	resumed.queue_free()
	await _frames(2)

	game._apply_character({"id": "shinpachi", "enter": true, "transition": "slide_right"})
	_expect(sprite.visible and art.position.x > rest.x and is_zero_approx(art.modulate.a),
		"the opposite entrance starts to the right and transparent")
	await create_timer(0.3).timeout
	motion.character(sprite, "leave", true, "fade")
	game._apply_character({"id": "shinpachi", "enter": true, "transition": "fade"})
	_expect(sprite.visible and is_zero_approx(art.modulate.a), "fade-in starts transparent")
	await create_timer(0.35).timeout
	_expect(is_equal_approx(art.modulate.a, 1.0), "fade-in finishes visible")
	motion.reaction(sprite, "bounce", false)
	await create_timer(0.08).timeout
	_expect(art.position.y < rest.y, "bounce lifts only the portrait")
	await create_timer(0.35).timeout
	_expect(art.position.distance_to(rest) < 0.1, "bounce settles at the original position")

	motion.character(sprite, "leave", false, "slide_left")
	await create_timer(0.05).timeout
	game._focus_speaker("shinpachi", "")
	await create_timer(0.3).timeout
	_expect(sprite.visible and art.position.distance_to(rest) < 0.1, "a new line cancels an old exit without hiding the speaker")
	motion.reaction(sprite, "shake", false)
	await create_timer(0.03).timeout
	game._focus_speaker("shinpachi", "angry")
	await create_timer(0.4).timeout
	var after_expression: Vector2 = art.position
	sprite.call("set_expression", "angry")
	_expect(art.position.distance_to(after_expression) < 0.1, "changing expression during a reaction retains the new face's framing")

	motion.character(sprite, "leave", false, "slide_right")
	await create_timer(0.05).timeout
	motion.set_reduce_motion(true)
	_expect(not sprite.visible and motion.character_kind(sprite).is_empty(), "reduced motion completes an active exit immediately")
	game._apply_character({"id": "shinpachi", "enter": true, "transition": "slide_left"})
	var reduced_rest: Vector2 = art.position
	motion.reaction(sprite, "shake", false)
	_expect(sprite.visible and motion.character_kind(sprite).is_empty() and art.position.is_equal_approx(reduced_rest),
		"reduced motion shows the character without moving it")
	motion.set_reduce_motion(false)
	motion.character(sprite, "leave", false, "fade")
	await create_timer(0.05).timeout
	motion.reset()
	_expect(not sprite.visible, "resetting animations for skip finishes a departing character's exit")
	game._apply_character({"id": "shinpachi", "enter": true, "transition": "instant"})
	_expect(sprite.visible and motion.character_kind(sprite).is_empty(), "instant entrance shows the character without animation")
	motion.character(sprite, "leave", true, "fade")
	_expect(not sprite.visible, "skipping completes an exit immediately")
	game.queue_free()
	await _frames(2)
	for path: String in [TEST_STORY, TEST_BAD, TEST_SAVE, TEST_SAVE + ".bak", "user://portrait_motion_settings.cfg", "user://portrait_motion_progress.cfg"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_finish("PORTRAIT MOTION")
