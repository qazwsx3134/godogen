extends "res://addons/proto_kit/test_kit.gd"

const BUILDER = preload("res://tools/story_build/story_builder.gd")
const RUNNER = preload("res://scripts/story_runner.gd")
const SOURCE: String = """~ start
do char("shinpachi", "shout", "right")
新八: 準備後登場。
do portrait_lighting("shinpachi", "dim")
新八: 說話也維持暗色。
do portrait_lighting("shinpachi", "lit")
旁白也維持亮色。
do portrait_lighting("shinpachi", "auto")
銀時: 換我說。
do portrait_exit("shinpachi", "fade")
退場完成。
do end("完成")
"""

func _init() -> void:
	create_timer(25.0).timeout.connect(func() -> void: quit(2))
	_run.call_deferred()


func _next_line(game: Control) -> void:
	game._complete_current_line()
	game._on_screen_tap()
	await _frames(2)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var built: Dictionary = BUILDER.build_text(SOURCE, "res://tests/fixtures/story_src/__portrait_controls_test.dialogue")
	_expect(str(built.get("error", "")).is_empty(), "independent portrait controls build")
	if not str(built.get("error", "")).is_empty():
		_finish("PORTRAIT CONTROLS")
		return
	var story: Dictionary = built["story"]
	story["nodes"]["start"]["steps"][0]["transition"] = "slide_left"
	for invalid: Array in [[2,"mode","wrong"], [2,"mode",false], [2,"id","missing"], [8,"transition","wrong"], [8,"id","missing"]]:
		var broken: Dictionary = story.duplicate(true)
		broken["nodes"]["start"]["steps"][invalid[0]][invalid[1]] = invalid[2]
		FileAccess.open("user://portrait_controls_bad.json", FileAccess.WRITE).store_string(JSON.stringify(broken))
		var runner: RefCounted = RUNNER.new()
		_expect(not runner.load_story("user://portrait_controls_bad.json"), "invalid portrait control rejected: %s" % [invalid])
	FileAccess.open("user://portrait_controls.json", FileAccess.WRITE).store_string(BUILDER.to_json(story))
	var game: Control = (load("res://main.tscn") as PackedScene).instantiate()
	game.story_path = "user://portrait_controls.json"
	game.save_path = "user://portrait_controls.save"
	game.settings_path = "user://portrait_controls_settings.cfg"
	game.progress_path = "user://portrait_controls_progress.cfg"
	game.tutorials_enabled = false
	root.add_child(game)
	await _frames(3)
	game._on_begin_pressed()
	await _until(func() -> bool: return game._screen_mode == "story", "prepared portrait enters with first line")
	var sprite: Control = game._sprites["shinpachi"]
	var art: Control = sprite.get_node("Art")
	var rest: Vector2 = game._motion._characters.get(sprite, {}).get("position", art.position)
	_expect(sprite.visible and game._actor_slots["shinpachi"] == "right" and sprite.expression == "shout", "prepared placement and expression apply when speaking")
	_expect(game._motion.character_state(sprite).get("transition") == "slide_left" and art.modulate.a < 0.9 and art.position.x < rest.x,
		"prepared entrance preserves the selected slide and fade")
	await create_timer(0.3).timeout
	_expect(is_equal_approx(art.modulate.a, 1.0), "entrance fades to full opacity")
	await _next_line(game)
	_expect(sprite.modulate.r < 0.6 and sprite.visible, "manual dim persists while the same character speaks")
	var saved: Dictionary = game._build_save_payload("")
	_expect(saved["sprites"]["shinpachi"]["lighting"] == "dim", "save records manual lighting")
	game._apply_portrait_lighting({"id":"shinpachi", "mode":"lit"})
	_expect(game._apply_save_payload(saved) and str(sprite.get_meta("portrait_lighting")) == "dim", "loading restores manual lighting")
	game._focus_speaker("shinpachi", "")
	_expect(sprite.modulate.r < 0.6, "restored lighting survives dialogue focus")
	var bad_save: Dictionary = saved.duplicate(true)
	bad_save["sprites"]["shinpachi"]["lighting"] = "wrong"
	_expect(not game._validate_save_payload(bad_save), "invalid saved lighting is rejected")
	await _next_line(game)
	_expect(sprite.modulate.is_equal_approx(Color.WHITE), "explicit lit survives narration")
	await _next_line(game)
	_expect(sprite.modulate.r < 0.6, "auto mode dims the non-speaker")
	game._complete_current_line()
	game._on_screen_tap()
	await create_timer(0.09).timeout
	_expect(sprite.visible and art.modulate.a < 0.9 and art.modulate.a > 0.0, "independent exit visibly fades")
	await _until(func() -> bool: return game._screen_mode == "story", "exit finishes before following line")
	_expect(not sprite.visible and art.position.is_equal_approx(rest), "exit hides portrait and keeps authored pose")
	game._apply_portrait_lighting({"id":"shinpachi", "mode":"dim"})
	_expect(not sprite.visible, "lighting never brings an absent character on stage")
	game._clear_stage()
	_expect(str(sprite.get_meta("portrait_lighting")) == "auto", "scene change resets manual lighting")
	game._apply_character({"id":"shinpachi", "transition":"instant"})
	game._present_say({"op":"say", "speaker":"shinpachi", "text":"畫外音", "offscreen":true}, false)
	_expect(not sprite.visible, "explicit offscreen speech stays off stage after preparation")
	game._present_say({"op":"say", "speaker":"shinpachi", "text":"現在上場"}, false)
	_expect(sprite.visible and game._motion.character_kind(sprite).is_empty(), "prepared instant transition takes effect at speech")
	game.queue_free()
	await _frames(2)
	_finish("PORTRAIT CONTROLS")
