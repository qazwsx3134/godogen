extends "res://addons/proto_kit/test_kit.gd"
## The Phase 4 four-clue sample plays in the existing VN shell: four hotspots, a choice,
## the tsukkomi round with every clue option, and the ending.

const MAIN_SCENE: PackedScene = preload("../main.tscn")
const STORY_PATH: String = "res://data/phase4_story.json"
const TEST_SAVE: String = "user://phase4_ui_test.save"
const HOTSPOTS: Array[String] = ["empty_milk_bottle", "gintoki_mouth", "kombu_wrapper", "floor_paw_print"]


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_cleanup_saves()
	var game: Control = MAIN_SCENE.instantiate() as Control
	game.story_path = STORY_PATH
	game.save_path = TEST_SAVE
	root.add_child(game)
	await _frames(3)
	_expect(game._story_ready, "phase4_story.json loads in the VN shell: %s" % game._story_error)
	game._on_begin_pressed()
	game._set_skip(true)
	await _until(func() -> bool: return game._screen_mode == "investigate", "reach the four-clue investigation")

	_expect(game._hotspot_buttons.size() == 4, "four hotspot buttons are shown")
	for hotspot_id: String in HOTSPOTS:
		var button: Button = game._hotspot_buttons.get(hotspot_id) as Button
		_expect(button != null and button.get_global_rect().end.y < game._dialog_panel.position.y,
			"hotspot '%s' sits above the dialogue" % hotspot_id)
		game._on_hotspot_pressed(hotspot_id)
	game._on_hotspot_pressed("empty_milk_bottle")
	_expect(game._runner.items.size() == 4, "each clue is granted once: %s" % [game._runner.items])
	game._on_investigation_continue_pressed()
	game._set_skip(true)  # SKIP stops at the investigation; the next line needs it again
	await _until(func() -> bool: return game._screen_mode == "choice", "reach the ask-first choice")

	game._on_choice_pressed("ask_kagura")
	game._set_skip(true)
	await _until(func() -> bool: return game._screen_mode == "boke_round", "reach the tsukkomi round")
	game._on_boke_tsukkomi_pressed()
	_expect(game._screen_mode == "tsukkomi" and game._choice_buttons.size() == 6,
		"all four clue options plus two plain ones are offered (%d)" % game._choice_buttons.size())
	game._on_boke_option_pressed("point_to_trace")
	game._set_skip(true)
	await _until(func() -> bool: return game._runner.node_id == "perfect_end", "perfect result via Kagura's line", 10.0)
	_expect(str(game._runner.flags.get("round_result", "")) == "perfect", "round result is recorded")

	game.queue_free()
	await _frames(2)
	_cleanup_saves()
	_finish("PHASE 4 UI TESTS")


func _cleanup_saves() -> void:
	for suffix: String in ["", ".bak", ".bak.old", ".old", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(TEST_SAVE + suffix):
			DirAccess.remove_absolute(TEST_SAVE + suffix)
