extends SceneTree
## Plays a story in the real shell and saves one picture of every new screen it reaches (each step
## kind, choice, investigation, round, overlay), so a layout can be checked in portrait and in
## landscape without touching player saves. Needs a renderer (xvfb-run on Linux), not --headless.
##
##   godot --path . --resolution 540x960 --script res://tools/screen_audit.gd -- <out dir> [story id] [choice id ...]
##
## The story id is an entry of data/stories.json (default showcase_portrait). Choices take the listed
## ids in order, then the first option; rounds answer with the next listed id that is an option there.
## AUDIT_TUTORIALS=1 keeps the first-run tutorials on; AUDIT_METRICS=1 also prints sizes (see _metrics).
## Prints "SCREEN AUDIT OK <n> shots" and the rects of any title/HUD/toolbar part outside the game area.

## Presentation steps caught while they play, and how many frames after they start.
const EFFECT_OPS: Dictionary = {"comedy": 40, "cutin": 30, "beam": 30, "placard": 30, "shake": 6, "flash": 4,
	"freeze": 10, "fade": 20, "portrait_effect": 10, "portrait_exit": 10, "bg": 30}
const ROOT_SHOTS: Array[String] = ["menu", "log", "settings", "save_slots", "case_file"]

var _game: Control
var _out: String
var _plan: Array = []
var _seen: Dictionary = {}
var _shots: int = 0
var _overlays_done: bool = false
var _busy_frames: int = 0
var _tried: Array = []  # talk topics and places played
var _problems: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: Array = Array(OS.get_cmdline_user_args())
	_out = str(args.pop_front()) if not args.is_empty() else "user://screen_audit"
	var story_id: String = str(args.pop_front()) if not args.is_empty() else "showcase_portrait"
	_plan = args if not args.is_empty() else ["screen", "back", "cast", "back", "play", "gin", "bottle", "back", "advanced", "phone_rings", "back", "finish"]
	DirAccess.make_dir_recursive_absolute(_out)
	var choice: Dictionary = {}
	for entry: Dictionary in (JSON.parse_string(FileAccess.get_file_as_string("res://data/stories.json")) as Dictionary)["stories"]:
		if entry["id"] == story_id:
			choice = entry
	_game = (load("res://main.tscn") as PackedScene).instantiate() as Control
	_game.story_path = choice.get("path", "res://data/showcase_story.json")
	_game.save_path = "user://screen_audit.save"
	_game.settings_path = "user://screen_audit.cfg"
	_game.progress_path = "user://screen_audit_progress.cfg"
	_game.tutorials_enabled = OS.get_environment("AUDIT_TUTORIALS") == "1"  # first-run tutorial overlays
	root.add_child(_game)
	await _frames(4)
	# main is not the current scene here, so pick the entry as 章節選擇 would.
	var index: int = (_game._story_choices as Array).find_custom(func(c: Dictionary) -> bool: return c["id"] == story_id)
	if index >= 0:
		_game._choose_story(_game._story_choices[index])
	await _frames(8)
	await _shot("title")
	_check_inside(_game._title_screen, ["Begin", "Continue", "Load", "Settings", "StorySwitch"])
	_game._open_chapter_select()
	await _frames(12)
	await _shot("chapter_select")
	_game._close_overlays()
	_game._screen_mode = "chapter_select"
	_game._open_credits()
	await _frames(12)
	await _shot("credits")
	_game._close_overlays()
	_game._screen_mode = "chapter_select"
	_game._open_gallery()
	await _frames(12)
	await _shot("gallery")
	_game._close_overlays()
	_game._screen_mode = "chapter_select"
	_game._open_flowchart()
	await _frames(12)
	await _shot("flowchart")
	_game._flowchart.call("close")
	_game._close_overlays()
	_game._screen_mode = "title"
	await _frames(4)
	_game._on_begin_pressed()
	await _play()
	print("SCREEN AUDIT OK %d shots in %s" % [_shots, ProjectSettings.globalize_path(_out)])
	for problem: String in _problems:
		print("OUTSIDE ", problem)
	_game.queue_free()
	await _frames(2)
	for path: String in ["user://screen_audit.save", "user://screen_audit.cfg", "user://screen_audit_progress.cfg"]:
		for suffix: String in ["", ".bak"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	quit(0)


func _play() -> void:
	var deadline: int = Time.get_ticks_msec() + 240000
	while Time.get_ticks_msec() < deadline:
		var mode: String = _game._screen_mode
		var command: Dictionary = _game._current_command
		var live: Dictionary = _game._runner.current()  # presentation steps play before _current_command changes
		if _game._story_busy and EFFECT_OPS.has(str(live.get("op", ""))):
			command = live
		var op: String = str(command.get("op", ""))
		var key: String = mode + "-" + op
		if op == "comedy":
			key += "-" + str(command.get("preset", command.get("id", "")))
		elif op in ["say", "choice", "investigate", "boke_round"]:
			key += "-" + str(_game._runner.node_id)  # each section's first line shows its staging
		var effect: bool = EFFECT_OPS.has(op)
		if mode in ["end", "result"]:
			await create_timer(0.25).timeout
			await _shot("end-darkening")
			await create_timer(1.4).timeout
			await _shot("end")  # the scroll, waiting for the tap
			_game._chapter_result.reveal_buttons()
			await create_timer(0.5).timeout
			await _shot("end-buttons")
			return
		if not _seen.has(key) and (effect or not _game._story_busy):
			_seen[key] = true
			await _frames(EFFECT_OPS.get(op, 20))
			await _shot(key)
			if mode == "story" and not _overlays_done:
				_overlays_done = true
				await _overlays()
				continue
		match mode:
			"story":
				if _game._story_busy:
					_busy_frames += 1
					if _busy_frames > 600:  # let effects play; tap only when stuck
						_busy_frames = 0
						_game._on_screen_tap()
				elif _game._text_complete:
					_game._advance_current_line()
				else:
					_game._complete_current_line()
			"choice":
				var ids: Array = (command.get("options", []) as Array).map(func(o: Dictionary) -> String: return str(o["id"]))
				var pick: String = str(_plan.pop_front()) if not _plan.is_empty() and ids.has(_plan[0]) else str(ids[0])
				_game._on_choice_pressed(pick)
			"investigate":
				if await _topic_left(command):
					await _frames(2)
					continue
				for spot: Dictionary in command.get("hotspots", []):
					_game._investigation.collect_hotspot(str(spot["id"]))
					await _frames(10)
					_finish_reaction()
				await _frames(10)
				await _shot("investigate-found")
				_game._investigation.on_investigation_continue_pressed()
			"boke_round":
				await _round_move(command)
			"qte":
				await _frames(20)
				await _shot("qte")
				_game._round._on_qte_resolved(true, 0.0)
			"tsukkomi":
				var ids: Array = _game._current_options.map(func(o: Dictionary) -> String: return str(o["id"]))
				var pick: String = str(ids[0])
				if not _plan.is_empty() and ids.has(_plan[0]):
					pick = str(_plan.pop_front())
				_game._on_boke_option_pressed(pick)
		await _frames(2)
	_problems.append("timed out at " + _game._screen_mode)


## A testimony round goes to the next line with a catch and answers it the way that line asks
## (censor bar, placard or 吐槽！); other rounds press 吐槽！.
func _round_move(command: Dictionary) -> void:
	if str(command.get("mode", "")) != "testimony":
		_game._on_boke_tsukkomi_pressed()
		return
	var lines: Array = command.get("lines", []) as Array
	for i: int in lines.size():
		var raw: Dictionary = lines[i] as Dictionary
		if (command.get("caught_line_ids", []) as Array).has(raw["id"]) or not raw.has("slot"):
			continue
		if int(command.get("line_index", 0)) != i:
			_game._set_boke_line(i)
			await _frames(20)
			return
		var slot: Dictionary = raw["slot"] as Dictionary
		if slot.has("censor"):
			await _shot("testimony-censor")
			_game._round.on_censor_pressed()
		elif slot.has("placard"):
			await _shot("testimony-placard")
			_game._round.on_placard_pressed()
		else:
			_game._on_boke_tsukkomi_pressed()
		return
	_game._on_boke_tsukkomi_pressed()


## Plays one talk topic, or one other place, not tried yet; false when none is left.
func _topic_left(command: Dictionary) -> bool:
	for topic: Dictionary in command.get("talk", []):
		if not _tried.has(topic["id"]):
			_tried.append(topic["id"])
			_game._investigation.on_talk_pressed(str(topic["id"]))
			return true
	for place: Dictionary in command.get("moves", []):
		if not _tried.has(place["id"]):
			_tried.append(place["id"])
			_game._investigation._on_move_pressed(str(place["id"]))
			await _frames(30)
			await _shot("investigate-" + str(place["id"]))
			for spot: Dictionary in (_game._current_command.get("hotspots", []) as Array):
				_game._investigation.collect_hotspot(str(spot["id"]))
				await _frames(10)
				_finish_reaction()
			return true
	return false


func _finish_reaction() -> void:
	for i: int in range(200):
		if _game._screen_mode == "investigate":
			return
		if _game._screen_mode == "story":
			if _game._text_complete:
				_game._advance_current_line()
			else:
				_game._complete_current_line()
		await process_frame


func _overlays() -> void:
	_check_inside(_game._phase3_hud, [])
	_check_rect("DialogueBox", _game._dialog_panel.get_global_rect())
	for button: Control in [_game._dialog_panel.log_button, _game._dialog_panel.auto_button,
			_game._dialog_panel.skip_button, _game._dialog_panel.menu_button]:
		_check_rect(button.name, button.get_global_rect())
	for name: String in ROOT_SHOTS:
		match name:
			"menu": _game._open_menu()
			"log": _game._open_log()
			"settings":
				_game._open_menu()  # 設定 opens from 目錄's row, as a player does
				await _frames(4)
				_game._on_menu_row_pressed("settings")
			"save_slots": _game._open_slot_picker("save")
			"case_file": _game._open_case_file("items")
		await _frames(30)
		await _shot("overlay-" + name)
		_game._close_overlays()
		_game._screen_mode = "story"
		await _frames(6)


func _check_inside(node: Control, children: Array) -> void:
	if node == null or not node.is_visible_in_tree():
		return
	if children.is_empty():
		_check_rect(node.name, node.get_global_rect())
	for child_name: String in children:
		var child: Control = node.find_child(child_name, true, false) as Control
		if child != null and child.is_visible_in_tree():
			_check_rect(child_name, child.get_global_rect())


func _check_rect(label: String, rect: Rect2) -> void:
	var area: Rect2 = _game._game.get_global_rect().grow(1.0)
	if not area.encloses(rect):
		_problems.append("%s %s not in %s" % [label, rect, area])


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	_shots += 1
	var file: String = "%02d-%s" % [_shots, name.replace("/", "_")]
	root.get_texture().get_image().save_png(_out.path_join(file + ".png"))
	if OS.get_environment("AUDIT_METRICS") == "1":
		_metrics(file)


## AUDIT_METRICS=1: every visible button, slider and text on screen, in window pixels (= CSS px when the
## window is the phone's CSS size): "METRIC <shot> <kind> <path> <w>x<h> font=<px> text=<text>".
func _metrics(file: String) -> void:
	var to_window: Transform2D = root.get_final_transform()
	var screen: Rect2 = Rect2(Vector2.ZERO, Vector2(root.size))
	for node: Node in _game.find_children("*", "Control", true, false):
		var control: Control = node as Control
		if not control.is_visible_in_tree() or control.modulate.a < 0.05:
			continue
		var kind: String = "button" if control is BaseButton else "slider" if control is Range and not control is ProgressBar \
			else "text" if control is Label or control is RichTextLabel else ""
		if kind.is_empty():
			continue
		var rect: Rect2 = to_window * (control.get_global_transform() * Rect2(Vector2.ZERO, control.size))
		if not screen.intersects(rect) or rect.get_area() < 4.0:
			continue
		if kind == "text" and str(control.get("text")).strip_edges().is_empty():
			continue
		var font: float = float(control.get_theme_font_size("normal_font_size" if control is RichTextLabel else "font_size")) \
			* control.get_global_transform().get_scale().y * to_window.get_scale().y
		var label: String = str(control.get("text")).replace("\n", " ").left(16) if "text" in control else ""
		if control is BaseButton and (control as BaseButton).disabled:
			kind += "-disabled"
		print("METRIC %s %s %s %dx%d font=%.1f text=%s" % [file, kind, _game.get_path_to(control), rect.size.x, rect.size.y, font, label])


func _frames(count: int) -> void:
	for i: int in range(count):
		await process_frame
