extends "res://addons/proto_kit/test_kit.gd"
## Integration check for the Phase 2 JSON sample and the VN presentation/save layer.

const SAMPLE_STORY: String = "res://data/phase2_story.json"
const TEST_SAVE: String = "user://phase2_ui_test.save"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var game: Control = _new_game()
	await _frames(3)
	_expect(game._story_ready, "sample story loads")
	game._on_begin_pressed()
	await _until(func() -> bool: return game._screen_mode == "story", "opening line")
	_expect(game._current_bg_id == "yorozuya_living_room", "JSON sets the opening background")
	_expect(game._sprites["shinpachi"].visible, "JSON shows Shinpachi")
	_expect(str(game._sprites["shinpachi"].get("expression")) == "neutral", "omitted expression uses the default")

	game._set_skip(true)
	await _until(func() -> bool: return game._screen_mode == "choice", "sample choice", 10.0)
	_expect(game._runner.items.has("milk_bottle"), "item command grants material")
	_expect(bool(game._runner.flags.get("test_started", false)), "flag command writes state")
	_expect(str(game._actor_slots["gintoki"]) == "right", "JSON overrides a character position")
	_expect(game._current_options.size() == 2, "owned material unlocks the required choice")
	game._on_choice_pressed("inspect_milk")
	await _until(func() -> bool: return game._screen_mode == "story" and game._current_bg_id == "yorozuya_kitchen", "kitchen branch")
	_expect(game._sprites["kagura"].visible, "JSON shows Kagura on the branch")
	_expect(str(game._sprites["kagura"].get("expression")) == "smile", "JSON sets an expression")
	_expect(game._save_game(), "branch can be saved")
	var saved_node: String = game._runner.node_id
	var saved_step: int = game._runner.step_index
	var saved_items: Array = game._runner.items.duplicate()
	game.queue_free()
	await _frames(2)

	var resumed: Control = _new_game()
	await _frames(3)
	_expect(not resumed._continue_button.disabled, "saved branch enables Continue")
	resumed._on_continue_pressed()
	await _until(func() -> bool: return resumed._screen_mode == "story", "restored branch")
	_expect(resumed._runner.node_id == saved_node and resumed._runner.step_index == saved_step, "Continue restores the reading point")
	_expect(resumed._current_bg_id == "yorozuya_kitchen", "Continue restores the background")
	_expect(resumed._sprites["kagura"].visible, "Continue restores the sprite")
	_expect(resumed._runner.items == saved_items, "Continue restores materials once")
	resumed.queue_free()
	await _frames(2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))

	_finish("PHASE 2 UI TESTS")


func _new_game() -> Control:
	var game: Control = (load("res://main.tscn") as PackedScene).instantiate() as Control
	game.story_path = SAMPLE_STORY
	game.save_path = TEST_SAVE
	root.add_child(game)
	return game
