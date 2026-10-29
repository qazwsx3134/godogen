extends "res://addons/proto_kit/test_kit.gd"

const STORY: String = "res://stories/katsura_dog_ears/dog_ears_story.json"
const CATALOG: String = "res://stories/katsura_dog_ears/catalog.json"
const RUNNER = preload("res://scripts/story_runner.gd")
const ROUND_VIEW = preload("res://scripts/round_view.gd")
var game: Control

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var story: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(STORY)) as Dictionary
	var opening: Array = story.nodes.opening.steps
	_expect(opening.any(func(s: Dictionary) -> bool: return s.get("speaker") == "gintoki" and s.get("text") == "你腦袋被撞到嗎"), "Gintoki uses the author's revised line")
	var first: int = -1
	for i: int in range(opening.size()):
		if opening[i].get("text") == "頭痛賈奈。":
			first = i
	_expect(first >= 0 and opening[first].get("expression") == "serious", "first half is its own serious line")
	_expect(first >= 0 and opening[first + 1].get("op") == "freeze" and float(opening[first + 1].duration) >= 0.5, "a distinct hold separates the two halves")
	_expect(story.nodes.timing.steps[0].lines[0].text == "咖紫拉打。", "second half is independent")
	for timing: Array in [[true, -0.5, "early"], [true, 0.5, "late"], [false, 0.0, "late"], [true, 0.0, "perfect"]]:
		var runner: RefCounted = RUNNER.new()
		_expect(runner.call("load_story", STORY), "story loads")
		_advance_runner(runner, "boke_round")
		var command: Dictionary = runner.call("current")
		_expect(ROUND_VIEW.line(command).get("expression") == "serious", "round preserves the earnest expression")
		var result: Dictionary = runner.call("resolve_qte", timing[0], timing[1])
		_expect(not result.has("error") and runner.get("node_id") == timing[2], "timing routes correctly: %s" % [timing])
		if timing[2] == "perfect":
			_expect((runner.call("current") as Dictionary).get("text") == "到底是怎樣啦！！那你手舉個屁啊！！！", "success keeps the author's exact retort")
			_advance_runner(runner, "end")
			_expect(runner.get("node_id") == "finish", "success reaches the ending")
		else:
			_advance_runner(runner, "boke_round")
			_expect(runner.get("node_id") == "timing", "early and late can retry without replaying the opening")
	var broken: Dictionary = story.duplicate(true)
	broken.nodes.timing.steps[0]["expression"] = "invented_expression"
	FileAccess.open("user://katsura-invalid.json", FileAccess.WRITE).store_string(JSON.stringify(broken))
	_expect(not RUNNER.new().load_story("user://katsura-invalid.json", CATALOG), "invalid round expression is rejected")
	broken = story.duplicate(true)
	broken.nodes.timing.steps[0].lines[0]["expression"] = "smug"
	FileAccess.open("user://katsura-override.json", FileAccess.WRITE).store_string(JSON.stringify(broken))
	var custom: RefCounted = RUNNER.new()
	_expect(custom.call("load_story", "user://katsura-override.json", CATALOG), "per-line expression override loads")
	_advance_runner(custom, "boke_round")
	_expect(ROUND_VIEW.line(custom.call("current")).get("expression") == "smug", "per-line expression overrides the round default")
	game = (load("res://main.tscn") as PackedScene).instantiate() as Control
	game.story_path = STORY
	game.save_path = "user://katsura-test.save"
	game.settings_path = "user://katsura-test-settings.cfg"
	game.progress_path = "user://katsura-test-progress.cfg"
	game.tutorials_enabled = false
	root.add_child(game)
	await _frames(3)
	_expect(game._story_ready, "actual reading shell loads the pack")
	game._on_begin_pressed()
	await _read_until(func() -> bool: return game._runner.node_id == "opening" and game._screen_mode == "story", "opening")
	_expect(game._sprites.katsura.has_node("Art") and game._sprites.katsura.has_node("PosePlaceholder"), "editable actor scene is instantiated")
	var portrait: TextureRect = game._sprites.katsura.get_node("Art") as TextureRect
	_expect(portrait.texture != null and not game._sprites.katsura.get_node("PosePlaceholder").visible, "the generated portrait is visible and the placeholder is hidden")
	_expect(game._sprites.elisabeth.placard_text() == "頭痛？", "Elisabeth's board displays the author's line")
	await _shot("opening")
	await _read_until(func() -> bool: return game._screen_mode == "qte", "timing challenge")
	_expect(game._sprites.katsura.expression == "serious", "Katsura stays serious while the player times the retort")
	_expect(game._sprites.katsura.visible and game._sprites.elisabeth.visible, "the pose and board remain on stage")
	await _shot("timing")
	game._qte._start_usec = Time.get_ticks_usec() - int(game._qte.duration * 1000000.0)
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	game._qte._gui_input(press)
	await _until(func() -> bool: return game._comedy_layer.is_active(), "manga retort")
	_expect(game._comedy_layer.get_child_count() > 0, "a real timed tap plays the manga retort")
	await create_timer(0.2).timeout
	await _shot("retort")
	await _read_until(func() -> bool: return game._screen_mode == "end", "short story ending")
	game.queue_free()
	await _frames(2)
	_finish("KATSURA DOG EARS")

func _advance_runner(runner: RefCounted, op: String) -> void:
	for _i: int in range(80):
		if str((runner.call("current") as Dictionary).get("op")) == op:
			return
		runner.call("advance")
	_expect(false, "runner reaches %s" % op)

func _read_until(done: Callable, label: String) -> void:
	var deadline: int = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		if done.call():
			return
		if game._screen_mode == "story":
			if game._story_busy:
				game._on_screen_tap()
			elif game._text_complete:
				game._advance_current_line()
			else:
				game._complete_current_line()
		await _frames(1)
	_expect(false, "timed out before %s" % label)

func _expect(value: bool, label: String) -> void:
	if not value:
		failures.append(label)

func _shot(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			var directory: String = arg.trim_prefix("--shots=")
			DirAccess.make_dir_recursive_absolute(directory)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(directory.path_join(label + ".png"))
