extends "res://addons/proto_kit/test_kit.gd"
## First-time guides (docs/PLAN-LOG-AVATAR-TUTORIAL.md B, data/tutorials.json): shown once when investigation and
## the boke round first open, framing the control each step explains; 略過 and 知道了 both count as seen; 重看教學
## and the 教學提示 setting work. Headless runs skip guides unless DEBT_TUTORIAL=1, which this suite sets.

const MAIN_SCENE: PackedScene = preload("../main.tscn")
const STORY_PATH: String = "res://data/phase3_story.json"
const SAVE: String = "user://tutorial_test.save"
const PROGRESS: String = "user://tutorial_test_progress.cfg"
const SETTINGS: String = "user://tutorial_test_settings.cfg"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	OS.set_environment("DEBT_TUTORIAL", "1")
	_cleanup()
	await test_tutorial_shows_once_and_frames_each_control()
	await test_tutorial_seen_guides_stay_quiet_until_replayed()
	await test_tutorial_setting_off_shows_nothing()
	_cleanup()
	OS.unset_environment("DEBT_TUTORIAL")
	_finish("TUTORIAL TESTS")


func test_tutorial_shows_once_and_frames_each_control() -> void:
	# Arrange
	var game: Control = await _new_game()
	var guide: Control = game._tutorial
	# Act: reach the search
	await _to_investigation(game)
	await _frames(3)
	# Assert
	_expect(guide.visible and guide.tutorial_id == "investigate", "tutorial: the first search opens its guide")
	var card: Control = guide.get_node("%Card")
	_expect(Rect2(Vector2.ZERO, guide.size).encloses(card.get_rect()), "tutorial: the card stays on screen (%s in %s)" % [
		card.get_rect(), guide.size])
	for i: int in 3:
		var target: Control = game._tutorial_target(str(game._tutorials[1].steps[i].target))
		await _frames(2)
		if target != null and target.is_visible_in_tree():
			var framed: Rect2 = guide.get_node("%Focus").get_global_rect()
			_expect(framed.has_point(target.get_global_rect().get_center()), "tutorial: step %d frames its control (%s vs %s)" % [
				i + 1, framed, target.get_global_rect()])
		else:
			print("step %d target hidden: %s" % [i + 1, target])
		guide.get_node("%Next").emit_signal("pressed")
	_expect(not guide.visible and "investigate" in game._tutorials_seen(), "tutorial: 知道了 closes it and records it")
	# Act: on to the boke round, then skip its guide
	game._collect_hotspot("empty_milk_bottle")
	game._on_investigation_continue_pressed()
	await _until(func() -> bool: return game._screen_mode == "boke_round", "reach boke round")
	await _frames(3)
	_expect(guide.visible and guide.tutorial_id == "boke", "tutorial: the first boke round opens its guide")
	var tsukkomi_before: bool = game._screen_mode == "boke_round"
	guide.get_node("%Skip").emit_signal("pressed")
	# Assert
	_expect(tsukkomi_before and game._screen_mode == "boke_round" and not guide.visible, "tutorial: 略過 hands the round back untouched")
	_expect("boke" in game._tutorials_seen(), "tutorial: a skipped guide counts as seen")
	game.queue_free()
	await _frames(2)


func test_tutorial_seen_guides_stay_quiet_until_replayed() -> void:
	# Arrange: the progress file from the first test has both guides seen.
	var game: Control = await _new_game()
	# Act
	await _to_investigation(game)
	await _frames(3)
	# Assert
	_expect(not game._tutorial.visible, "tutorial: a seen guide does not show again")
	game._replay_tutorials()
	_expect(game._tutorials_seen().is_empty(), "tutorial: 重看教學 clears the seen list")
	var config := ConfigFile.new()
	config.load(PROGRESS)
	_expect(config.has_section_key("tutorial", "seen"), "tutorial: the list lives in progress.cfg [tutorial]")
	game.queue_free()
	await _frames(2)


func test_tutorial_setting_off_shows_nothing() -> void:
	# Arrange
	var game: Control = await _new_game()
	game._on_setting_changed("tutorial", 1)
	# Act
	await _to_investigation(game)
	await _frames(3)
	# Assert
	_expect(not game._tutorial.visible, "tutorial: 教學提示 不顯示 turns every guide off")
	game.queue_free()
	await _frames(2)


func _new_game() -> Control:
	var game: Control = MAIN_SCENE.instantiate() as Control
	game.story_path = STORY_PATH
	game.save_path = SAVE
	game.progress_path = PROGRESS
	game.settings_path = SETTINGS
	root.add_child(game)
	await _frames(3)
	return game


func _to_investigation(game: Control) -> void:
	game._on_begin_pressed()
	game._set_skip(true)
	await _until(func() -> bool: return game._screen_mode == "investigate", "reach investigation")


func _cleanup() -> void:
	for path: String in [SAVE, PROGRESS, SETTINGS]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
