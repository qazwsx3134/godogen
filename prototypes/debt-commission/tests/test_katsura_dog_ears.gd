extends "res://addons/proto_kit/test_kit.gd"

const STORY: String = "res://stories/katsura_dog_ears/dog_ears_story.json"
const CATALOG: String = "res://stories/katsura_dog_ears/catalog.json"
const BACKGROUND: String = "res://stories/katsura_dog_ears/art/yorozuya_anime_bg_v2.png"
const RUNNER = preload("res://scripts/story_runner.gd")
var game: Control

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var pack_catalog: Dictionary = RUNNER.read_catalog(CATALOG).get("catalog", {})
	var base_catalog: Dictionary = RUNNER.read_catalog(RUNNER.ASSET_CATALOG_PATH).get("catalog", {})
	_expect(pack_catalog.get("backgrounds", {}).get("yorozuya_living_room", {}).get("path", "") == BACKGROUND,
		"the short story resolves its own background")
	_expect(base_catalog.get("backgrounds", {}).get("yorozuya_living_room", {}).get("path", "") != BACKGROUND,
		"the base game's background remains separate")
	var story: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(STORY)) as Dictionary
	var opening: Array = story.nodes.opening.steps
	var serious: Array = opening.filter(func(s: Dictionary) -> bool: return s.get("text") == "頭痛賈奈。")
	_expect(serious.size() == 1 and serious[0].get("expression") == "serious", "Katsura delivers 頭痛賈奈 with a serious face")
	# 一本正經的咖紫拉打: the player picks the next line; every option reaches an ending.
	var options: Array = story.nodes.timing.steps[0].get("options", [])
	_expect(story.nodes.timing.steps[0].op == "choice" and not options.is_empty(), "the retort is a choice")
	# The option whose card plays a manga retort (the author is still writing the others).
	var retort: Array = options.filter(func(option: Dictionary) -> bool:
		return (story.nodes[option.next].steps as Array).any(func(s: Dictionary) -> bool: return s.op == "comedy"))
	_expect(not retort.is_empty(), "one option plays a manga retort")
	for option: Dictionary in options:
		var runner: RefCounted = RUNNER.new()
		_expect(runner.call("load_story", STORY), "story loads with the work's catalog")
		_advance_runner(runner, "choice")
		_expect(runner.call("choose", str(option.id)), "option %s can be chosen" % option.id)
		_expect(runner.get("node_id") == option.next, "option %s routes to %s" % [option.id, option.next])
		_advance_runner(runner, "end")
	var broken: Dictionary = story.duplicate(true)
	var with_face: Dictionary = (broken.nodes.opening.steps as Array).filter(func(s: Dictionary) -> bool: return s.has("expression"))[0]
	with_face["expression"] = "invented_expression"
	FileAccess.open("user://katsura-invalid.json", FileAccess.WRITE).store_string(JSON.stringify(broken))
	_expect(not RUNNER.new().load_story("user://katsura-invalid.json", CATALOG), "an unknown expression is rejected")
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
	var background: TextureRect = game.get("_background_rect") as TextureRect
	_expect(background != null and background.visible and background.texture != null
		and background.texture.resource_path == BACKGROUND, "the actual reading scene displays the story background")
	_expect(game._sprites.katsura.has_node("Art") and game._sprites.katsura.has_node("PosePlaceholder"), "editable actor scene is instantiated")
	var portrait: TextureRect = game._sprites.katsura.get_node("Art") as TextureRect
	_expect(portrait.texture != null and not game._sprites.katsura.get_node("PosePlaceholder").visible, "the generated portrait is visible and the placeholder is hidden")
	await _shot("opening")
	await _read_until(func() -> bool: return game._screen_mode == "choice", "the retort choice")
	_expect(game._sprites.katsura.expression == "serious", "Katsura stays serious while the player picks the retort")
	_expect(game._sprites.elisabeth.placard_text() == "頭痛？", "Elisabeth's board displays the author's line")
	await _shot("choice")
	game._on_choice_pressed(str(retort[0].id) if not retort.is_empty() else "")
	await _read_until(func() -> bool: return game._comedy_layer.is_active(), "manga retort")
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
