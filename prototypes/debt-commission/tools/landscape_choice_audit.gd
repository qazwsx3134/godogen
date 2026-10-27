extends SceneTree
## Captures both landscape choice sheets and their scroll geometry with isolated player data.

var _game: Control
var _out: String

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if not args.is_empty() else "user://landscape_choice_audit"
	DirAccess.make_dir_recursive_absolute(_out)
	_game = (load("res://main.tscn") as PackedScene).instantiate()
	_game.story_path = "res://data/choices_story.json"
	_game.save_path = "user://landscape_choice_audit.save"
	_game.settings_path = "user://landscape_choice_audit.cfg"
	_game.progress_path = "user://landscape_choice_audit_progress.cfg"
	_game.tutorials_enabled = false
	root.add_child(_game)
	await _frames(6)
	_game._on_begin_pressed()
	_game._set_skip(true)
	if not await _until_choice("pov"):
		quit(1)
		return
	await _capture("pov")
	_game._on_choice_pressed("reply_loud")
	_game._set_skip(true)
	if not await _until_choice("director"):
		quit(1)
		return
	await create_timer(0.5).timeout
	await _capture("director")
	_game.queue_free()
	await _frames(2)
	print("LANDSCAPE CHOICE AUDIT OK ", _out)
	quit(0)

func _until_choice(kind: String) -> bool:
	for i: int in range(1000):
		if _game._screen_mode == "choice" and _game._choice_sheet.perspective == kind:
			await _frames(12)
			return true
		await process_frame
	printerr("choice not reached: ", kind, " ", _game._screen_mode)
	return false

func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out.path_join(name + ".png"))
	var sheet: Control = _game._choice_sheet
	var scroll: ScrollContainer = sheet.choices_scroll
	print("CHOICE METRICS ", name, " sheet=", sheet.get_global_rect(), " max=", sheet.max_height,
		" scroll=", scroll.get_global_rect(), " content=", sheet.choices.get_combined_minimum_size(),
		" mode=", scroll.vertical_scroll_mode, " fixed=", sheet.get_combined_minimum_size().y - scroll.get_combined_minimum_size().y)

func _frames(count: int) -> void:
	for i: int in range(count):
		await process_frame
