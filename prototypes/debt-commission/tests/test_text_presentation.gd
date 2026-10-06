extends "res://addons/proto_kit/test_kit.gd"
const UI = preload("res://scripts/ui_styles.gd")
func _init() -> void: _run.call_deferred()
func _run() -> void:
	root.size = Vector2i(390,844)
	var game = load("res://main.tscn").instantiate()
	game.story_path = "res://data/text_effects_story.json"
	game.save_path = "user://test_text_presentation.save"
	game.ui_preference_path = "user://test_text_presentation_ui.cfg"
	root.add_child(game)
	await _frames(3)
	game._on_begin_pressed()
	await _until(func() -> bool: return game._screen_mode=="story", "formatted first line")
	_expect(game._text_label is RichTextLabel and game._full_text == "今天的工作是……休息。", "runtime and QA use readable text, not formatting tags")
	_expect(game._text_label.get_parsed_text()==game._full_text, "RichText parses the same readable line as the timeline")
	game._complete_current_line()
	_expect(game._history.back().text==game._full_text and game._text_complete, "tap completion stores plain dialogue in the log")
	var payload=game._build_save_payload("")
	for style in UI.style_ids():
		game._set_ui_style(style,false)
		await _frames(2)
		_expect(game._text_label is RichTextLabel and game._text_label.get_parsed_text()==game._full_text, "formatted dialogue survives %s style switch" % style)
	game._advance_current_line()
	await _until(func() -> bool: return game._screen_mode=="story" and game._current_speaker=="shinpachi", "shaking reply")
	_expect(game._text_label.text.contains("[shake"), "emphasized reply uses RichText's shake effect")
	game._effects._tick_elapsed=1.0
	game._effects.play_type_tick("gintoki","字",false,false)
	var ticks=game._effects.type_ticks
	game._effects._tick_elapsed=1.0
	game._effects.play_type_tick("narrator","字",false,false)
	game._effects.play_type_tick("shinpachi","字",true,false)
	game._effects.play_type_tick("shinpachi","字",false,true)
	_expect(game._effects.type_ticks==ticks, "narration, thoughts and skip are silent")
	game._effects.set_muted(true)
	game._effects.play_type_tick("kagura","字",false,false)
	_expect(game._effects.type_ticks==ticks and not game._effects.play_perfect_voice(1), "mute suppresses typing and optional perfect voice")
	game._motion.fade("out",0.1,false)
	await _frames(2)
	game._apply_save_payload(payload)
	game._render_restored_current()
	_expect(game._motion.veil.modulate.a==0.0 and not game._motion.ghost.visible, "load cancels old fade and background crossfade")
	_expect(game._full_text=="今天的工作是……休息。" and game._text_complete, "formatted line restores without replaying markup as text")
	game._set_skip(true)
	await _until(func() -> bool: return game._screen_mode=="end", "skip through fade and background",10.0)
	_expect(game._current_bg_id=="yorozuya_kitchen" and game._motion.veil.modulate.a==0.0, "skip keeps the final stage without stale fade")
	game.queue_free()
	await _frames(2)
	_finish("TEXT PRESENTATION TESTS")
