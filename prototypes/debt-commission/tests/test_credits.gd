extends "res://addons/proto_kit/test_kit.gd"
## 署名與製作名單: a story's `credits` (validated by the runner, carried over by the builder) show on
## its 章節選擇 row and its result card; 製作名單 rolls every story's credits and data/credits.json
## in game time, stops when dragged, stays still with reduced motion, and closes back to 章節選擇.

const Runner = preload("res://scripts/story_runner.gd")
const Builder = preload("res://tools/story_build/story_builder.gd")
const REGISTRY: String = "res://tests/fixtures/stories_chapters.json"
const FIXTURE: String = "res://tests/fixtures/chapter_a_story.json"
const BAD_STORY: String = "user://credits_bad_story.json"
const SOURCE: String = "user://credits_fixture.dialogue"
const FILES: Array[String] = ["user://credits_test_progress.cfg", "user://credits_test_ui.cfg",
	"user://credits_test_settings.cfg", "user://credits_test.save", BAD_STORY, SOURCE,
	"user://credits_fixture.blocks.json"]


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_cleanup()
	_runner_and_builder()
	await _chapter_select_and_roll(0)
	await _chapter_select_and_roll(1)
	await _result_card()
	_cleanup()
	_finish("CREDITS TESTS")


func _runner_and_builder() -> void:
	var r = Runner.new()
	_expect(r.load_story(FIXTURE), "a story with credits loads: %s" % r.error_message)
	_expect(r.story_info()["credits"] == [{"role": "劇本", "names": ["測試作者"]}, {"role": "繪", "names": ["畫師甲", "畫師乙"]}],
		"story_info carries the credits")
	var story: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	for bad: Variant in ["劇本", [{"role": "", "names": ["甲"]}], [{"role": "劇本", "names": []}], [{"role": "劇本", "names": [""]}]]:
		story["credits"] = bad
		var file: FileAccess = FileAccess.open(BAD_STORY, FileAccess.WRITE)
		file.store_string(JSON.stringify(story))
		file.close()
		_expect(not Runner.new().load_story(BAD_STORY), "malformed credits are rejected: %s" % [bad])
	var game_credits: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/credits.json"))
	_expect(game_credits is Dictionary and Runner.new().validate_credits(game_credits["credits"]).is_empty(),
		"data/credits.json has the same shape")
	var blocks: FileAccess = FileAccess.open("user://credits_fixture.blocks.json", FileAccess.WRITE)
	blocks.store_string(JSON.stringify({"story": {"id": "credits_fixture", "title": "署名測試",
		"credits": [{"role": "劇本", "names": ["測試作者"]}]}, "titles": {}, "blocks": {}}))
	blocks.close()
	var built: Dictionary = Builder.build_text("~ start\n新八: 署名測試。\ndo end(\"完\")\n", SOURCE)
	_expect(String(built["error"]).is_empty() and built["story"].get("credits") == [{"role": "劇本", "names": ["測試作者"]}],
		"the builder carries blocks.json credits into the story: %s" % built["error"])


func _chapter_select_and_roll(motion: int) -> void:
	var game: Control = _new_game(motion)
	await _frames(3)
	game._open_chapter_select()
	await _frames(2)
	var row_text: String = game._chapter_select.row_text("chapter_a")
	_expect(row_text.ends_with("\n劇本 測試作者｜繪 畫師甲、畫師乙"), "the chapter row names who wrote and drew it: %s" % row_text)
	var card: Control = game._chapter_select.find_child("ChapterRow_chapter_a", true, false)
	_expect(card.get_node("%Credit").visible and card.get_node("%Credit").text == "劇本 測試作者｜繪 畫師甲、畫師乙",
		"the chapter card shows the credit under its picture")
	_expect(game._chapter_select.row_text("sample").count("\n") == 1, "a story without credits shows no credit line")
	game._chapter_select.credits_button.pressed.emit()
	await _frames(3)
	var roll: Control = game._credits_roll
	var lines: Array[String] = roll.call("lines")
	_expect(game._screen_mode == "credits" and roll.visible, "製作名單 opens over 章節選擇")
	_expect(lines.slice(0, 5) == ["測試章 A", "劇本", "測試作者", "繪", "畫師甲\n畫師乙"],
		"the story's credits come first: %s" % [lines])
	_expect(lines.has("使用的工具與素材") and lines.has("Godot Engine 4.7（MIT License）") and lines[-1] == "— 完 —",
		"then the tools and assets, and the end")
	_expect(lines.count("劇本") == 1, "only stories with credits get a section")
	if motion == 0:
		_expect(roll.rolling, "the roll moves by itself")
		await _frames(40)
		var moved: int = roll.scroll.scroll_vertical
		_expect(moved > 0, "it rolls upward in game time")
		var touch: InputEventMouseButton = InputEventMouseButton.new()
		touch.button_index = MOUSE_BUTTON_LEFT
		touch.pressed = true
		roll.scroll.gui_input.emit(touch)
		await _frames(10)
		_expect(not roll.rolling and roll.scroll.scroll_vertical == moved, "a tap on the list stops the roll")
		roll.call("open", game._credit_sections(), true)
		await _frames(2)
		roll._process(1000.0)
		await _frames(2)
		var box: Rect2 = roll.scroll.get_global_rect()
		var end: Rect2 = (roll.find_child("End", true, false) as Control).get_global_rect()
		_expect(not roll.rolling and roll.scroll.scroll_vertical > 0 and box.encloses(end),
			"the roll stops with — 完 — in view: box %s, end %s" % [box, end])
	else:
		await _frames(20)
		_expect(not roll.rolling and roll.scroll.scroll_vertical == 0, "with reduced motion it stays still at the top")
	roll.close_button.pressed.emit()
	await _frames(2)
	_expect(game._screen_mode == "chapter_select" and not roll.visible and game._chapter_select.visible,
		"關閉 goes back to 章節選擇")
	game.queue_free()
	await _frames(2)


func _result_card() -> void:
	var game: Control = _new_game(0)
	await _frames(3)
	var screen: Control = game._chapter_result
	screen.call("show_result", {"title": "測試章 A", "grade": "A"}, "", false, "劇本 測試作者")
	_expect(screen.credit.visible and screen.credit.text == "劇本 測試作者", "the result card shows the credit line")
	screen.call("show_result", {"title": "測試章 A", "grade": "A"}, "", false)
	_expect(not screen.credit.visible, "no credits, no line")
	_expect(game._credit_line(game._runner.story_info()["credits"]) == "劇本 測試作者｜繪 畫師甲、畫師乙",
		"the loaded chapter's credits make the result line")
	game.queue_free()
	await _frames(2)


func _new_game(motion: int) -> Control:
	var settings: ConfigFile = ConfigFile.new()
	settings.set_value("settings", "motion", motion)
	settings.save(FILES[2])
	var game: Control = (load("res://main.tscn") as PackedScene).instantiate() as Control
	game.stories_path = REGISTRY
	game.story_path = FIXTURE
	game.save_path = FILES[3]
	game.progress_path = FILES[0]
	game.ui_preference_path = FILES[1]
	game.settings_path = FILES[2]
	root.add_child(game)
	return game


func _cleanup() -> void:
	for path: String in FILES:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
