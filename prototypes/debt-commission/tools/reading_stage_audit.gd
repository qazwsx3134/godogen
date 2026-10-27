extends SceneTree
## Capture the real reading stage at the requested window size without touching player saves.
## Godot --path . --resolution 780x1688 --script res://tools/reading_stage_audit.gd -- <out_dir>

const MAIN: PackedScene = preload("res://main.tscn")

var _game: Control
var _out: String


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if not args.is_empty() else "user://reading_stage_audit"
	DirAccess.make_dir_recursive_absolute(_out)
	_game = MAIN.instantiate() as Control
	_game.story_path = "res://data/phase3_story.json"
	_game.save_path = "user://reading_stage_audit.save"
	_game.settings_path = "user://reading_stage_audit_settings.cfg"
	_game.progress_path = "user://reading_stage_audit_progress.cfg"
	_game.tutorials_enabled = false
	root.add_child(_game)
	await _frames(8)
	await _capture("title")
	_game._on_begin_pressed()
	for i: int in range(240):
		if _game._screen_mode == "story" and not _game._story_busy:
			break
		await process_frame
	if _game._screen_mode != "story":
		printerr("READING STAGE AUDIT FAILED: story did not start")
		quit(1)
		return
	_game._complete_current_line()
	await _frames(24)
	await _capture("single")
	_game._focus_speaker("gintoki", "")
	await _frames(24)
	await _capture("two_speakers")
	# Give each character a separate slot before reviewing a three-person composition.
	_game._apply_character({"id": "gintoki", "position": "center", "visible": true})
	_game._apply_character({"id": "kagura", "position": "right", "visible": true})
	_game._focus_speaker("kagura", "")
	await _frames(24)
	await _capture("three_speakers")
	_game._motion.cancel_characters()
	var portrait_before: Rect2 = (_game._sprites["shinpachi"] as Control).get_global_rect()
	var dialogue_before: Rect2 = _game._dialog_panel.get_global_rect()
	var long_line: String = "這是一段檢查固定閱讀框的測試文字，請繼續閱讀下一頁。".repeat(12)
	_game._full_text = long_line
	_game._line_plan = {}
	_game._set_visible_text(long_line, true)
	await _frames(16)
	if not _game._dialog_panel.has_next_page() or not _game._dialog_panel.page_hint.visible \
			or not dialogue_before.is_equal_approx(_game._dialog_panel.get_global_rect()) \
			or not portrait_before.is_equal_approx((_game._sprites["shinpachi"] as Control).get_global_rect()):
		printerr("READING STAGE AUDIT FAILED: long line or fixed layout")
		quit(1)
		return
	await _capture("long_page_1")
	var scroll: VScrollBar = _game._text_label.get_v_scroll_bar()
	_game._on_screen_tap()
	await _frames(6)
	if scroll.value <= 0.0:
		printerr("READING STAGE AUDIT FAILED: page did not advance")
		quit(1)
		return
	await _capture("long_page_2")
	print("READING STAGE AUDIT OK ", _out)
	_game.queue_free()
	await _frames(2)
	quit(0)


func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out.path_join(label + ".png"))
	var info: Dictionary = {
		"screen": label,
		"viewport": str(root.get_visible_rect()),
		"dialog": str(_game._dialog_panel.get_global_rect()),
		"hud": str(_game._phase3_hud.get_global_rect()),
		"stage": str(_game._stage_area.get_global_rect()),
		"portraits": {},
	}
	for actor_id: String in _game._sprites:
		var actor: Control = _game._sprites[actor_id]
		if actor.visible:
			info["portraits"][actor_id] = str(actor.call("art_rect"))
	print("STAGE_METRICS ", JSON.stringify(info))


func _frames(count: int) -> void:
	for i: int in range(count):
		await process_frame
