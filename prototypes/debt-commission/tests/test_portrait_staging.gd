extends "res://addons/proto_kit/test_kit.gd"
## Reproduce dog_ears: a placard, a reaction, dimming, then an entrance with offscreen speech.

const BUILDER = preload("res://tools/story_build/story_builder.gd")
const CATALOG: String = "res://stories/katsura_dog_ears/catalog.json"
const SOURCE: String = """~ start
do enter("elisabeth", "neutral", "right", "instant")
do placard("頭痛？")
伊莉莎白舉牌。
do portrait_effect("elisabeth", "shake")
do portrait_lighting("elisabeth", "dim")
do enter("gintoki", "nosepick", "right", "slide_left")
銀時: 你腦袋又被什麼撞到嗎？
桂: 頭痛賈奈。
do end("完成")
"""

func _init() -> void:
	create_timer(25.0).timeout.connect(func() -> void: quit(2))
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var built: Dictionary = BUILDER.build_text(SOURCE, "res://stories/katsura_dog_ears/__staging_test.dialogue")
	_expect(str(built.get("error", "")).is_empty(), "staging fixture builds")
	if not str(built.get("error", "")).is_empty():
		_finish("PORTRAIT STAGING")
		return
	var story: Dictionary = built["story"]
	story.nodes.start.steps[6]["offscreen"] = true
	FileAccess.open("user://portrait_staging.json", FileAccess.WRITE).store_string(BUILDER.to_json(story))
	var game: Control = (load("res://main.tscn") as PackedScene).instantiate()
	game.story_path = "user://portrait_staging.json"
	game.story_catalog_override = CATALOG
	game.save_path = "user://portrait_staging.save"
	game.settings_path = "user://portrait_staging_settings.cfg"
	game.progress_path = "user://portrait_staging_progress.cfg"
	game.tutorials_enabled = false
	root.add_child(game)
	await _frames(3)
	_expect(game._story_ready, "staging fixture loads: %s" % game._story_error)
	game._on_begin_pressed()
	await _until(func() -> bool: return game._screen_mode == "story", "placard line")
	var elisabeth: Control = game._sprites.elisabeth
	var gintoki: Control = game._sprites.gintoki
	_expect(elisabeth.visible and elisabeth.placard_text() == "頭痛？", "Elisabeth is on stage with her board")
	game._complete_current_line()
	game._on_screen_tap()
	await _until(func() -> bool: return str(elisabeth.get_meta("portrait_lighting", "auto")) == "dim", "the dim step")
	_expect(elisabeth.modulate.r < 0.6 and not gintoki.visible, "the dim step is presented before the following entrance")
	await _until(func() -> bool: return game._screen_mode == "story" and game._current_speaker == "gintoki", "Gintoki's offscreen line")
	_expect(str(elisabeth.get_meta("portrait_lighting")) == "dim", "the dim command has already executed")
	_expect(elisabeth.modulate.r < 0.6, "Elisabeth dims before Gintoki's line, without another action")
	_expect(gintoki.visible and gintoki.get_index() > elisabeth.get_index(), "Gintoki enters in front of the previous right-side character")
	await create_timer(0.3).timeout
	_expect(elisabeth.modulate.r < 0.6, "the visible placard does not relight Elisabeth during the line")
	_expect(gintoki.get_index() > elisabeth.get_index(), "the visible placard does not cover Gintoki during the line")
	game._focus_speaker("elisabeth", "")
	game._apply_character({"id": "gintoki", "expression": "annoyed", "position": "right", "enter": true})
	_expect(gintoki.get_index() > elisabeth.get_index() and gintoki.modulate.is_equal_approx(Color.WHITE),
		"an explicit entrance also fronts and lights a character already on stage")
	game._present_say({"op": "say", "speaker": "gintoki", "text": "沿用登場表情。"}, false)
	_expect(gintoki.expression == "annoyed" and gintoki.get_node("Art").texture.resource_path == game._catalog.characters.gintoki.expressions.annoyed,
		"a line without an expression keeps the entrance expression and its actual image")
	game._present_say({"op": "say", "speaker": "gintoki", "text": "指定本句表情。", "expression": "serious"}, false)
	_expect(gintoki.expression == "serious", "an explicit line expression still overrides the entrance")
	game._cancel_generation()
	game.queue_free()
	await _frames(2)
	_finish("PORTRAIT STAGING")
