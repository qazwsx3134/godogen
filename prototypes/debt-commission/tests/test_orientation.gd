extends "res://addons/proto_kit/test_kit.gd"
## A story's `orientation` (or its stories.json entry's) turns the canvas: portrait is 1080×1920 with each
## node's metadata/portrait_layout, and a landscape story puts the authored layout back.

const STORY: String = "res://data/showcase_story.json"
const StoryValidator = preload("res://scripts/story_validator.gd")
const PORTRAIT_FILE: String = "user://orientation-portrait-story.json"
const FILES: Array[String] = ["user://orientation-test.save", "user://orientation-test.cfg", "user://orientation-test-progress.cfg",
	"user://orientation-portrait.save", PORTRAIT_FILE]
var game: Control


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var story: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(STORY))
	story["orientation"] = "sideways"
	_expect(StoryValidator.validate_story(story, {}).contains("orientation"), "an unknown orientation is rejected")
	story["orientation"] = "portrait"
	var file: FileAccess = FileAccess.open(PORTRAIT_FILE, FileAccess.WRITE)
	file.store_string(JSON.stringify(story))
	file.close()

	game = (load("res://main.tscn") as PackedScene).instantiate() as Control
	game.story_path = STORY
	game.save_path = FILES[0]
	game.settings_path = FILES[1]
	game.progress_path = FILES[2]
	game.tutorials_enabled = false
	root.add_child(game)
	await _frames(4)
	_expect(root.content_scale_size == Vector2i(1920, 1080), "the showcase is landscape")
	var landscape_card: float = (game._title_screen.find_child("CardArea") as Control).anchor_left

	var entry: Dictionary = game._story_choices.filter(func(c: Dictionary) -> bool: return c["id"] == "showcase_portrait").front()
	_expect(entry["path"] == STORY and str(entry.get("orientation")) == "portrait", "stories.json lists the showcase's portrait edition")
	game._choose_story(entry)
	await _frames(4)
	_check_portrait("the portrait entry")
	_expect(game._story_title(entry) == "功能展示（直式）", "the entry names its edition")

	game._choose_story(game._story_choices[0])
	await _frames(4)
	_expect(root.content_scale_size == Vector2i(1920, 1080) and game._game.size.x > game._game.size.y, "a landscape story turns the canvas back")
	_expect(is_equal_approx((game._title_screen.find_child("CardArea") as Control).anchor_left, landscape_card)
		and is_equal_approx((game._slot_markers["left"] as Control).anchor_top, 0.16), "the authored landscape layout comes back")

	# The story's own field, without an entry.
	game._choose_story({"id": "own", "path": PORTRAIT_FILE, "save": FILES[3]})
	await _frames(4)
	_check_portrait("a story with orientation portrait")
	game._on_begin_pressed()
	await _until(func() -> bool: return game._screen_mode in ["story", "choice"], "the portrait story starts", 10.0)
	await _frames(8)
	var area: Rect2 = game._game.get_global_rect().grow(1.0)
	_expect(area.encloses(game._phase3_hud.get_global_rect()), "the HUD fits the portrait canvas")
	_expect(area.encloses(game._dialog_panel.get_global_rect()), "the reading box fits the portrait canvas: %s in %s" % [game._dialog_panel.get_global_rect(), area])
	var shinpachi: Rect2 = (game._sprites["shinpachi"] as Control).get_global_rect()
	_expect(shinpachi.size.x < area.size.x * 0.5 and shinpachi.position.y > area.size.y * 0.2,
		"a portrait stands in a portrait slot: %s" % shinpachi)
	game.queue_free()
	await _frames(2)
	root.content_scale_size = Vector2i(1920, 1080)

	# Cold start (web ?sample=showcase_portrait, or the desktop reopening it): portrait before the UI is built.
	game = (load("res://main.tscn") as PackedScene).instantiate() as Control
	game.story_path = STORY
	game.save_path = "user://showcase_portrait.save"
	game.settings_path = FILES[1]
	game.progress_path = FILES[2]
	game.tutorials_enabled = false
	root.add_child(game)
	await _frames(4)
	_check_portrait("a cold start on the portrait entry")
	# The milk bottle sits at x=0.11 of a 16:9 picture, outside the portrait crop: dragging brings it in.
	game._on_begin_pressed()
	for option: String in ["play", "gin"]:
		await _read_until(func() -> bool: return game._screen_mode == "choice", "choice " + option)
		game._on_choice_pressed(option)
	await _read_until(func() -> bool: return game._screen_mode == "investigate", "the portrait investigation")
	await _frames(6)
	var bottle: Control = game._hotspots["empty_milk_bottle"]
	var screen: Rect2 = game._game.get_global_rect()
	var arrows: Control = game._investigation.arrows
	var left: Control = arrows.call("arrow", Vector2.LEFT)
	var right: Control = arrows.call("arrow", Vector2.RIGHT)
	_expect(arrows.visible and (left.visible or right.visible), "the portrait search shows an edge arrow toward the cropped part")
	for arrow: Button in [left as Button, right as Button]:
		_expect(arrow.text.is_empty() and arrow.icon != null and arrow.icon_alignment == HORIZONTAL_ALIGNMENT_CENTER
			and arrow.vertical_icon_alignment == VERTICAL_ALIGNMENT_CENTER, arrow.name + " arrow is a centred icon, not a font glyph")
	var collapse: Control = game._dialog_panel.get_node("%InvestigationCollapse")
	_expect(not (collapse.get_node("%CutoutArt") as Control).visible and not (collapse.get_node("Surface/Contents/Icon") as Control).visible,
		"the 收起 tab is caption only: no gear art over its words")
	var before: float = game._pan
	game._investigation.glide(Vector2.LEFT if left.visible else Vector2.RIGHT)
	await create_timer(0.5).timeout
	_expect(not is_equal_approx(game._pan, before), "an arrow glides the view: %s → %s" % [before, game._pan])
	game._investigation.set_pan(game._pan_range.y)
	_expect(not left.visible and right.visible, "at the left end only the right arrow shows")
	var reachable: bool = false
	for edge: float in [game._pan_range.x, game._pan_range.y]:
		game._investigation.set_pan(edge)
		await _frames(2)
		if screen.encloses(bottle.get_global_rect()) and not game._dialog_panel.get_global_rect().intersects(bottle.get_global_rect()):
			reachable = true
			game._investigation.tap_investigation(bottle.get_global_rect().get_center())
			break
	_expect(game._pan_range.y - game._pan_range.x > 100.0, "the portrait crop can be dragged sideways: %s" % game._pan_range)
	_expect(reachable, "dragged to one side, the bottle is on screen and clear of the box")
	await _frames(4)
	_expect(game._runner.items.has("milk_bottle"), "tapping it in portrait collects the bottle")
	game.queue_free()
	await _frames(2)
	for path: String in ["user://showcase_portrait.save"]:
		for suffix: String in ["", ".bak"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	for path: String in FILES:
		for suffix: String in ["", ".bak"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	await _test_phone_text()
	_finish("ORIENTATION")


func _check_portrait(label: String) -> void:
	_expect(root.content_scale_size == Vector2i(1080, 1920), label + " turns the canvas to 1080×1920")
	var area: Rect2 = game._game.get_global_rect().grow(1.0)
	_expect(area.size.y > area.size.x, label + " has a portrait game area")
	for button: String in ["Begin", "Continue", "Load", "Settings", "StorySwitch"]:
		_expect(area.encloses((game._title_screen.find_child(button) as Control).get_global_rect()), "%s: title %s fits" % [label, button])
	var slots: Array = ["left", "center", "right"].map(func(n: String) -> Rect2:
		return game._anchored_rect(game._slot_markers[n], area))
	_expect((slots[0] as Rect2).get_center().x < (slots[1] as Rect2).get_center().x
		and (slots[1] as Rect2).get_center().x < (slots[2] as Rect2).get_center().x
		and area.encloses(Rect2((slots[0] as Rect2).get_center(), Vector2.ZERO))
		and area.encloses(Rect2((slots[2] as Rect2).get_center(), Vector2.ZERO)), label + ": the three slots stand apart on screen")


func _read_until(done: Callable, label: String) -> void:
	var deadline: int = Time.get_ticks_msec() + 20000
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


## A phone-sized window (390×844 CSS px, portrait) reads text 1.25× its authored size; a window as large as
## the canvas gets the scene's sizes back.
func _test_phone_text() -> void:
	root.size = Vector2i(390, 844)
	game = (load("res://main.tscn") as PackedScene).instantiate() as Control
	game.story_path = STORY
	game.save_path = "user://showcase_portrait.save"
	game.settings_path = FILES[1]
	game.progress_path = FILES[2]
	game.tutorials_enabled = false
	root.add_child(game)
	await _frames(4)
	game._on_begin_pressed()
	await _read_until(func() -> bool: return game._screen_mode == "choice", "the menu on a phone")
	await _frames(4)
	_expect(is_equal_approx(game._text_scale, 1.25), "a phone gets text ×1.25: %s" % game._text_scale)
	var caption: Label = game._phase3_hud.find_child("PowerCaption", true, false) as Label
	var authored: int = int(caption.get_meta(&"_authored_font_size"))
	_expect(caption.get_theme_font_size("font_size") == roundi(authored * 1.25), "a HUD caption is scaled from its authored %d" % authored)
	var reading: int = game._dialog_panel.text.get_theme_font_size("normal_font_size")
	_expect(reading == roundi(game._dialog_panel._normal_font_size * 1.25), "the reading text is scaled once: %d" % reading)
	_expect(game._game.get_global_rect().grow(1.0).encloses(game._dialog_panel.get_global_rect()), "the larger text keeps the reading box on screen")
	root.size = Vector2i(1080, 1920)  # a window as large as the canvas: one design px per CSS px
	await _frames(4)
	_expect(is_equal_approx(game._text_scale, 1.0) and caption.get_theme_font_size("font_size") == authored,
		"a desktop window puts the authored sizes back")
	game.queue_free()
	await _frames(2)
	for suffix: String in ["", ".bak"]:
		if FileAccess.file_exists("user://showcase_portrait.save" + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://showcase_portrait.save" + suffix))

