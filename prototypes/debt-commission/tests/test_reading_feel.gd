extends "res://addons/proto_kit/test_kit.gd"
## Reading feedback must not change the hit area, block input, or ignore reduced motion.

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var game: Control = (load("res://main.tscn") as PackedScene).instantiate()
	game.story_path = "res://data/phase3_story.json"
	game.save_path = "user://reading_feel_test.save"
	game.settings_path = "user://reading_feel_test.cfg"
	game.progress_path = "user://reading_feel_test_progress.cfg"
	game.tutorials_enabled = false
	root.add_child(game)
	await _frames(3)
	game._on_begin_pressed()
	await _until(func() -> bool: return game._screen_mode == "story", "story starts")
	await _frames(4)
	var button: Button = game._log_button
	var surface: Control = button.get_node("Surface")
	var hit_rect: Rect2 = button.get_global_rect()
	button.button_down.emit()
	await create_timer(0.09).timeout
	_expect(surface.scale.x < 0.99 and button.get_global_rect().is_equal_approx(hit_rect),
		"press animates the visible surface without shrinking the touch target")
	button.button_up.emit()
	await create_timer(0.16).timeout
	_expect(surface.scale.is_equal_approx(Vector2.ONE), "the reading button returns to its resting size")
	button.button_down.emit()
	await create_timer(0.08).timeout
	button.disabled = true
	button.call("refresh_state")
	_expect(surface.scale.is_equal_approx(Vector2.ONE), "disabling a pressed button clears its feedback")
	button.disabled = false
	button.call("refresh_state")

	var sprite: Control = game._sprites["shinpachi"]
	var art: Control = sprite.get_node("Art")
	game._motion.cancel_characters()
	var rest: Vector2 = art.position
	game._motion.character(sprite, "speak", false)
	await create_timer(0.04).timeout
	_expect(art.position.y < rest.y, "a speaking character receives a small motion cue")
	game._motion.character(sprite, "speak", false)
	await create_timer(0.25).timeout
	_expect(art.position.is_equal_approx(rest), "rapid lines cancel old motion and restore the authored art position")

	button.button_down.emit()
	game._motion.character(sprite, "speak", false)
	await create_timer(0.04).timeout
	game._on_setting_changed("motion", 1)
	_expect(surface.scale.is_equal_approx(Vector2.ONE) and art.position.is_equal_approx(rest),
		"enabling reduced motion immediately settles active feedback")
	button.button_down.emit()
	game._motion.character(sprite, "speak", false)
	await create_timer(0.08).timeout
	_expect(surface.scale.is_equal_approx(Vector2.ONE) and art.position.is_equal_approx(rest),
		"reduced motion disables new button and character movement")
	game._motion.character(sprite, "leave", false)
	_expect(not sprite.visible, "reduced motion still completes a character exit immediately")
	_expect(game._motion.fade("out", 0.3, false) == 0.0 and is_equal_approx(game._motion.veil.modulate.a, 1.0),
		"reduced motion applies a story fade without a wait")
	_expect(game._motion.fade("in", 0.3, false) == 0.0 and is_zero_approx(game._motion.veil.modulate.a),
		"the following fade restores the view")

	await _press(button)
	_expect(game._screen_mode == "log", "the same reading button remains clickable")
	game.queue_free()
	await _frames(2)
	for path: String in ["user://reading_feel_test.save", "user://reading_feel_test.cfg", "user://reading_feel_test_progress.cfg"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_finish("READING FEEL")
