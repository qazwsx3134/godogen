extends "res://addons/proto_kit/test_kit.gd"
## A character hotspot's `spot` names a node Art/Spots/<spot> in the character's scene (scenes/characters/
## gintoki.tscn has Spots/mouth): the tap area is that node on screen, and moving the node moves the area.
## The validator rejects a spot the scene does not have, a spot without a character, and spot with art_region.

const STORY: String = "res://data/showcase_story.json"
const StoryValidator = preload("res://scripts/story_validator.gd")
const FILES: Array[String] = ["user://portrait-spots.save", "user://portrait-spots.cfg", "user://portrait-spots-progress.cfg"]
var game: Control


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_validation()
	await _test_shell()
	for path: String in FILES:
		for suffix: String in ["", ".bak"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	_finish("PORTRAIT SPOTS")


func _test_validation() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/asset_catalog.json"))
	_expect(StoryValidator.character_has_spot(catalog, "gintoki", "mouth"), "gintoki.tscn has Art/Spots/mouth")
	_expect(not StoryValidator.character_has_spot(catalog, "gintoki", "ear"), "a spot the scene lacks is not found")
	var cases: Dictionary = {
		"ok": [{"spot": "mouth"}, ""],
		"unknown spot": [{"spot": "ear"}, "spot 'ear'"],
		"both": [{"spot": "mouth", "art_region": [0.3, 0.1, 0.2, 0.1]}, "both spot and art_region"],
		"no character": [{"spot": "mouth", "character": null, "pos": [0.5, 0.5]}, "require a character"],
	}
	for label: String in cases.keys():
		var story: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(STORY))
		var spot: Dictionary = _mouth_hotspot(story)
		spot.erase("spot")
		for key: String in (cases[label][0] as Dictionary).keys():
			if cases[label][0][key] == null:
				spot.erase(key)
			else:
				spot[key] = cases[label][0][key]
		var error: String = StoryValidator.validate_story(story, catalog)
		var wanted: String = cases[label][1]
		_expect(error.is_empty() if wanted.is_empty() else error.contains(wanted), "%s: '%s'" % [label, error])


func _mouth_hotspot(story: Dictionary) -> Dictionary:
	for step: Dictionary in story["nodes"]["adv_investigate"]["steps"]:
		if step["op"] == "investigate":
			for hotspot: Dictionary in step["hotspots"]:
				if hotspot["id"] == "adv_gintoki_mouth":
					return hotspot
	return {}


func _test_shell() -> void:
	game = (load("res://main.tscn") as PackedScene).instantiate() as Control
	game.story_path = STORY
	game.save_path = FILES[0]
	game.settings_path = FILES[1]
	game.progress_path = FILES[2]
	game.tutorials_enabled = false
	root.add_child(game)
	await _frames(3)
	game._on_begin_pressed()
	await _read_until(func() -> bool: return game._screen_mode == "choice", "the menu")
	game._on_choice_pressed("advanced")
	await _read_until(func() -> bool: return game._screen_mode == "investigate", "the advanced investigation")
	await _frames(4)
	var gintoki: Control = game._sprites["gintoki"]
	var mark: Control = gintoki.get_node("Art/Spots/mouth")
	var target: Control = game._hotspots["adv_gintoki_mouth"]
	var screen: Rect2 = game._game.get_global_rect()
	var mouth: Rect2 = (gintoki.call("spot_rect", "mouth") as Rect2).intersection(screen)
	_expect(not mark.visible or (mark as ReferenceRect).editor_only, "the spot's frame is drawn only in the editor")
	_expect(target.visible and target.get_global_rect().is_equal_approx(mouth), "the tap area is the scene's mouth node: %s vs %s" % [target.get_global_rect(), mouth])
	_expect(mouth.get_area() < (gintoki.call("art_rect") as Rect2).get_area() * 0.05, "the mouth is a small part of the portrait")
	# An author dragging the node in the editor: the area follows.
	mark.anchor_left += 0.1
	mark.anchor_right += 0.1
	await _frames(1)
	game._place_cast_hotspots()
	_expect(target.global_position.x > mouth.position.x + 1.0, "moving Spots/mouth moves the tap area")
	game.queue_free()
	await _frames(2)


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
