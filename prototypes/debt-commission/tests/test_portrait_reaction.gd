extends "res://addons/proto_kit/test_kit.gd"

const BUILDER = preload("res://tools/story_build/story_builder.gd")

func _init() -> void:
	create_timer(20.0).timeout.connect(func() -> void: quit(2))
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	for effect: String in ["shake", "bounce"]:
		var source: String = "~ start\ndo portrait_effect(\"shinpachi\", \"%s\")\n新八: 動作要看得見。\ndo portrait_effect(\"shinpachi\", \"%s\")\ndo comedy(\"tsukkomi_impact\", \"shinpachi\", \"不要把動作蓋掉！\")\n旁白收尾。\ndo end(\"完成\")\n" % [effect, effect]
		var built: Dictionary = BUILDER.build_text(source, "res://story_src/__portrait_reaction_test.dialogue")
		_expect(str(built.get("error", "")).is_empty(), "reaction fixture builds")
		if not str(built.get("error", "")).is_empty():
			continue
		var file: String = "user://reaction_" + effect + ".json"
		FileAccess.open(file, FileAccess.WRITE).store_string(BUILDER.to_json(built["story"]))
		var game: Control = (load("res://main.tscn") as PackedScene).instantiate()
		game.story_path = file
		game.save_path = "user://reaction_" + effect + ".save"
		game.settings_path = "user://reaction_settings.cfg"
		game.progress_path = "user://reaction_progress.cfg"
		game.tutorials_enabled = false
		root.add_child(game)
		await _frames(3)
		game._on_begin_pressed()
		await _until(func() -> bool: return game._screen_mode == "story", "first line")
		var sprite: Control = game._sprites["shinpachi"]
		var art: Control = sprite.get_node("Art")
		var rest: Vector2 = game._motion._characters.get(sprite, {}).get("position", art.position)
		var saw_reaction: bool = false
		var deadline: int = Time.get_ticks_msec() + 900
		while Time.get_ticks_msec() < deadline:
			if game._motion.character_kind(sprite) == effect and art.position.distance_to(rest) > 2.0:
				saw_reaction = true
			await process_frame
		_expect(saw_reaction, effect + " before first speech visibly moves the portrait")
		game._complete_current_line()
		game._on_screen_tap()
		saw_reaction = false
		deadline = Time.get_ticks_msec() + 900
		while Time.get_ticks_msec() < deadline and not game._comedy_layer.is_active():
			if sprite.is_visible_in_tree() and game._motion.character_kind(sprite) == effect and art.position.distance_to(rest) > 2.0:
				saw_reaction = true
			await process_frame
		_expect(saw_reaction, effect + " is visible before the following comedy covers the stage")
		game._cancel_generation()
		await _frames(2)
		game.queue_free()
		await _frames(2)
	_finish("PORTRAIT REACTION")
