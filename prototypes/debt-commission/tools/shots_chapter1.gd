extends SceneTree
## Screenshots of chapter 1's in-play screens: investigation (open and folded to its
## bar), the clue toast, the round HUD, the tsukkomi sheet with the placard, the QTE ring.
## Needs a window (not --headless):
##   Godot --path . --resolution 585x1266 --script res://tools/shots_chapter1.gd -- <out_dir>
## Saves go to user://shots_*; run with an isolated HOME so real saves are untouched.

const MAIN: PackedScene = preload("res://main.tscn")
const CLUES: Array[String] = ["desk_underside", "gintoki_mouth", "sofa_underside", "floor_prints"]

var _out: String = ""
var _game: Control = null


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://shots"
	var prefix: String = "chapter1"
	DirAccess.make_dir_recursive_absolute(_out)
	_game = MAIN.instantiate() as Control
	_game.story_path = "res://data/chapter1_story.json"
	_game.save_path = "user://shots_chapter1.save"
	_game.settings_path = "user://shots_settings.cfg"
	_game.progress_path = "user://shots_progress.cfg"
	root.add_child(_game)
	await _frames(5)
	_game.call("_on_begin_pressed")
	if not await _play_until(func() -> bool: return _game._screen_mode == "investigate", "investigation"):
		return _quit(1)
	await _shot(prefix + "_investigate")
	_game.call("_set_investigation_collapsed", true)
	await _shot(prefix + "_investigate_bar")
	_game.call("_set_investigation_collapsed", false)
	for i: int in range(CLUES.size()):
		_game.call("_collect_hotspot", CLUES[i])
		if i == 0:
			await _shot(prefix + "_toast", 6)
		if not await _play_until(func() -> bool: return _game._screen_mode == "investigate", "back to search"):
			return _quit(1)
	_game.call("_on_investigation_continue_pressed")
	if not await _play_until(func() -> bool: return _game._screen_mode == "boke_round", "round 1"):
		return _quit(1)
	await _shot(prefix + "_round")
	_game.call("_on_boke_tsukkomi_pressed")
	await _shot(prefix + "_tsukkomi")
	# The QTE ring as the chapter's finale draws it, over the current stage.
	_game.call("_start_qte", {"qte": {"duration": 2.0, "window": 0.18}})
	await _shot(prefix + "_qte", 30)
	print("SHOTS OK ", _out)
	_quit(0)


func _play_until(done: Callable, label: String, limit: int = 4000) -> bool:
	for i: int in range(limit):
		if done.call():
			await _frames(10)
			return true
		if _game._screen_mode == "story" and not _game._story_busy:
			if _game._text_complete:
				_game.call("_advance_current_line")
			else:
				_game.call("_complete_current_line")
		await process_frame
	printerr("SHOTS FAILED: never reached %s (at %s, %s)" % [label, _game._runner.node_id, _game._screen_mode])
	return false


func _shot(file_name: String, settle: int = 20) -> void:
	await _frames(settle)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out.path_join(file_name + ".png"))


func _frames(count: int) -> void:
	for i: int in range(count):
		await process_frame


func _quit(code: int) -> void:
	_game.queue_free()
	quit(code)
