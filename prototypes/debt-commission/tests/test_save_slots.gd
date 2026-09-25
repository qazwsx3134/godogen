extends "res://addons/proto_kit/test_kit.gd"
## Persistence and picker integration checks for autosave plus 18 manual slots.

const SAVE_SLOTS_SCRIPT: Script = preload("../scripts/save_slots.gd")
const MAIN_SCENE: PackedScene = preload("../main.tscn")
const DEBT_SAVE: String = "user://save_slots_test_debt.save"
const PHASE2_SAVE: String = "user://save_slots_test_phase2.save"
const LEGACY_SAVE: String = "user://save_slots_test_legacy.save"
const ATOMIC_SAVE: String = "user://save_slots_test_atomic.save"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_cleanup_all()
	_test_atomic_backup_refresh()
	await _test_manual_slots_and_autosave()
	await _test_legacy_schema_three()
	await _test_phase2_isolation()
	_cleanup_all()
	_finish("SAVE SLOT TESTS")


func _test_atomic_backup_refresh() -> void:
	_expect(SAVE_SLOTS_SCRIPT.write_atomic(ATOMIC_SAVE, {"revision": 1}), "first atomic snapshot writes")
	_expect(SAVE_SLOTS_SCRIPT.write_atomic(ATOMIC_SAVE, {"revision": 2}), "second atomic snapshot writes")
	_expect(int(SAVE_SLOTS_SCRIPT._read_dictionary(ATOMIC_SAVE).get("revision", -1)) == 2,
		"atomic primary contains the newest snapshot")
	_expect(int(SAVE_SLOTS_SCRIPT._read_dictionary(ATOMIC_SAVE + ".bak").get("revision", -1)) == 1,
		"first overwrite keeps the prior snapshot in .bak")
	_expect(SAVE_SLOTS_SCRIPT.write_atomic(ATOMIC_SAVE, {"revision": 3}), "third atomic snapshot writes")
	_expect(int(SAVE_SLOTS_SCRIPT._read_dictionary(ATOMIC_SAVE).get("revision", -1)) == 3,
		"second overwrite updates the atomic primary")
	_expect(int(SAVE_SLOTS_SCRIPT._read_dictionary(ATOMIC_SAVE + ".bak").get("revision", -1)) == 2,
		"second overwrite refreshes .bak to the immediately previous snapshot")


func _test_manual_slots_and_autosave() -> void:
	var game: Control = _new_game("res://data/debt_story.json", DEBT_SAVE)
	await _frames(3)
	_expect(game._screen_mode == "title", "debt story opens on title")
	_expect(not game._title_load_button.disabled, "title Load is available before starting a new game")
	game._on_begin_pressed()
	await _until(func() -> bool: return game._screen_mode == "story", "debt story opening line")
	if not game._text_complete:
		game._complete_current_line()
	await _frames(2)
	var first_progress: Dictionary = game._runner.call("snapshot") as Dictionary
	await _open_picker(game, "save")
	_expect(game._screen_mode == "save_slots" and game._slot_page == 0, "save picker opens on page zero")
	_expect(game._slot_visible_entries.size() == SAVE_SLOTS_SCRIPT.PAGE_SIZE, "picker displays six manual slots per page")
	_expect(int(game._slot_visible_entries[0]["index"]) == 1 and int(game._slot_visible_entries[5]["index"]) == 6,
		"first picker page maps to slots 1 through 6")
	game._on_slot_card_pressed(0)
	await _frames(3)
	var slot_one_path: String = SAVE_SLOTS_SCRIPT.manual_path(DEBT_SAVE, 1)
	var slot_one: Dictionary = game._read_save_payload(slot_one_path)
	_expect(not slot_one.is_empty(), "first manual slot saves a valid snapshot")
	_expect((slot_one.get("runner", {}) as Dictionary).get("node_id", "") == first_progress.get("node_id", ""),
		"slot one captures its own story position")
	_expect(int(slot_one.get("schema", -1)) == 3 and int(slot_one.get("version", -1)) == 3,
		"manual save includes schema and version")
	_expect(slot_one.has("saved_at") and slot_one.has("preview_png"), "manual save includes local timestamp and scene preview field")

	game._set_skip(true)
	await _until(func() -> bool: return game._screen_mode == "choice", "debt route reaches first choice", 20.0)
	var second_progress: Dictionary = game._runner.call("snapshot") as Dictionary
	_expect(first_progress.get("node_id") != second_progress.get("node_id") or
		int(first_progress.get("step_index", -1)) != int(second_progress.get("step_index", -1)),
		"story advances between manual snapshots")
	game._open_menu()
	await _frames(2)
	game._open_slot_picker("save")
	await _frames(3)
	game._close_slot_picker()
	_expect(game._screen_mode == "menu" and game._menu_overlay.visible, "closing a picker opened from Menu restores Menu")
	game._close_menu()
	await _open_picker(game, "save")
	game._on_slot_card_pressed(1)
	await _frames(3)
	var slot_two_path: String = SAVE_SLOTS_SCRIPT.manual_path(DEBT_SAVE, 2)
	var slot_two: Dictionary = game._read_save_payload(slot_two_path)
	_expect(not slot_two.is_empty(), "second manual slot saves a valid snapshot")
	_expect((slot_two.get("runner", {}) as Dictionary).get("node_id", "") == second_progress.get("node_id", ""),
		"slot two retains distinct branch progress")

	await _open_picker(game, "save")
	game._on_slot_card_pressed(1)
	_expect(game._screen_mode == "slot_confirm" and game._slot_pending_index == 2,
		"overwriting an occupied slot requires confirmation")
	game._cancel_slot_confirmation()
	_expect(game._screen_mode == "save_slots", "overwrite cancel returns to the picker")
	game._on_slot_card_pressed(1)
	game._confirm_slot_overwrite()
	await _frames(3)
	_expect(FileAccess.file_exists(slot_two_path + ".bak"), "overwrite keeps the previous good snapshot in .bak")
	var corrupt: FileAccess = FileAccess.open(slot_two_path, FileAccess.WRITE)
	if corrupt != null:
		corrupt.store_var({"schema": 99}, false)
		corrupt.close()
	var recovered_slot_two: Dictionary = game._read_save_payload(slot_two_path)
	_expect(not recovered_slot_two.is_empty(), "reader falls back to a valid backup when the primary is corrupt")
	_expect((recovered_slot_two.get("runner", {}) as Dictionary).get("node_id", "") == second_progress.get("node_id", ""),
		"backup fallback preserves the most recent valid branch")

	await _open_picker(game, "load")
	game._on_slot_card_pressed(0)
	await _until(func() -> bool: return game._screen_mode == "story", "manual slot one loads")
	_expect(game._runner.node_id == first_progress.get("node_id", "") and
		game._runner.step_index == first_progress.get("step_index", -1), "selected manual slot restores its own position")
	game._show_title()
	_expect(not game._continue_button.disabled, "manual load leaves a valid Continue autosave")
	game._on_continue_pressed()
	await _until(func() -> bool: return game._screen_mode == "story", "Continue after manual load")
	_expect(game._runner.node_id == first_progress.get("node_id", "") and
		game._runner.step_index == first_progress.get("step_index", -1),
		"Continue follows the most recently loaded manual slot")
	game.queue_free()
	await _frames(2)

	var fresh: Control = _new_game("res://data/debt_story.json", DEBT_SAVE)
	await _frames(3)
	_expect(not fresh._continue_button.disabled, "autosave and manual slots persist into a fresh scene")
	await _open_picker(fresh, "load")
	_expect(fresh._slot_auto_button.visible, "load picker offers a valid autosave")
	_expect(fresh._slot_visible_entries[0]["valid"] and fresh._slot_visible_entries[1]["valid"],
		"two saved manual slots remain selectable in a fresh scene")
	fresh._on_slot_card_pressed(1)
	await _until(func() -> bool: return fresh._screen_mode in ["story", "choice", "end"], "manual slot two loads from title")
	_expect(fresh._runner.node_id == second_progress.get("node_id", "") and
		fresh._runner.step_index == second_progress.get("step_index", -1),
		"title Load restores the selected manual slot without New Game")
	fresh._start_new_story()
	await _until(func() -> bool: return fresh._screen_mode == "story", "New Game starts after manual load")
	_expect(FileAccess.file_exists(SAVE_SLOTS_SCRIPT.manual_path(DEBT_SAVE, 1)) and
		FileAccess.file_exists(SAVE_SLOTS_SCRIPT.manual_path(DEBT_SAVE, 2)), "New Game preserves manual slots")
	_expect(not fresh._read_save_payload(slot_two_path).is_empty(), "manual slot remains readable after New Game")

	var invalid_path: String = SAVE_SLOTS_SCRIPT.manual_path(DEBT_SAVE, 3)
	var invalid_file: FileAccess = FileAccess.open(invalid_path, FileAccess.WRITE)
	if invalid_file != null:
		invalid_file.store_var("not a Godot save", false)
		invalid_file.close()
	await _open_picker(fresh, "load")
	_expect(fresh._slot_card_buttons[2].disabled, "invalid occupied load slot is visually unavailable")
	_expect(fresh._read_save_payload(invalid_path).is_empty(), "invalid slot data is rejected")
	var unchanged: Dictionary = fresh._runner.call("snapshot") as Dictionary
	fresh._on_slot_card_pressed(2)
	_expect(fresh._screen_mode == "load_slots" and fresh._runner.node_id == unchanged.get("node_id", ""),
		"selecting invalid data leaves the current story untouched")
	_expect(fresh._slot_card_buttons[3].disabled, "empty load slot is unavailable")
	fresh._close_slot_picker()
	fresh.queue_free()
	await _frames(2)


func _test_legacy_schema_three() -> void:
	var source: Control = _new_game("res://data/debt_story.json", DEBT_SAVE)
	await _frames(2)
	var legacy: Dictionary = source._read_save_payload(SAVE_SLOTS_SCRIPT.manual_path(DEBT_SAVE, 1))
	_expect(not legacy.is_empty(), "source manual snapshot is available for migration fixture")
	if legacy.is_empty():
		source.queue_free()
		await _frames(2)
		return
	legacy.erase("version")
	legacy.erase("background")
	legacy.erase("saved_at")
	legacy.erase("preview_png")
	legacy.erase("chapter")
	legacy.erase("node_id")
	var legacy_sprites: Dictionary = legacy["sprites"]
	for actor_id: String in legacy_sprites.keys():
		(legacy_sprites[actor_id] as Dictionary).erase("position")
	_expect(bool(SAVE_SLOTS_SCRIPT.write_atomic(LEGACY_SAVE, legacy)), "legacy schema three fixture writes")
	source.queue_free()
	await _frames(2)
	var migrated: Control = _new_game("res://data/debt_story.json", LEGACY_SAVE)
	await _frames(3)
	_expect(not migrated._continue_button.disabled, "old schema-three autosave remains readable")
	migrated._on_continue_pressed()
	await _until(func() -> bool: return migrated._screen_mode == "story", "legacy schema-three Continue")
	_expect(migrated._current_bg_id == "yorozuya_living_room", "legacy load supplies the original background default")
	var first_actor: String = str(migrated._actors.keys()[0])
	_expect(migrated._actor_slots[first_actor] == str((migrated._actors[first_actor] as Dictionary).get("slot", "center")),
		"legacy load supplies catalog character positions")
	migrated.queue_free()
	await _frames(2)


func _test_phase2_isolation() -> void:
	var phase2: Control = _new_game("res://data/phase2_story.json", PHASE2_SAVE)
	await _frames(3)
	phase2._on_begin_pressed()
	await _until(func() -> bool: return phase2._screen_mode == "story", "Phase 2 opening line")
	if not phase2._text_complete:
		phase2._complete_current_line()
	await _frames(2)
	await _open_picker(phase2, "save")
	phase2._on_slot_card_pressed(0)
	await _frames(3)
	var debt_slot: String = SAVE_SLOTS_SCRIPT.manual_path(DEBT_SAVE, 1)
	var phase2_slot: String = SAVE_SLOTS_SCRIPT.manual_path(PHASE2_SAVE, 1)
	_expect(debt_slot != phase2_slot, "manual filenames derive from story-specific autosave paths")
	var phase2_payload: Dictionary = phase2._read_save_payload(phase2_slot)
	_expect(str(phase2_payload.get("story_id", "")) == "strawberry_phase2", "Phase 2 manual slot retains its story identity")
	_expect(phase2._read_save_payload(debt_slot).is_empty(), "debt save is incompatible with the Phase 2 runner")
	phase2.queue_free()
	await _frames(2)


func _new_game(story: String, save: String) -> Control:
	var game: Control = MAIN_SCENE.instantiate() as Control
	game.story_path = story
	game.save_path = save
	root.add_child(game)
	return game


func _open_picker(game: Control, mode: String) -> void:
	game._open_slot_picker(mode)
	await _frames(3)


func _cleanup_all() -> void:
	for path: String in [DEBT_SAVE, PHASE2_SAVE, LEGACY_SAVE, ATOMIC_SAVE]:
		for suffix: String in ["", ".bak", ".old", ".tmp", ".bak.tmp", ".bak.old"]:
			_remove(path + suffix)
		for slot_index: int in range(1, SAVE_SLOTS_SCRIPT.SLOT_COUNT + 1):
			var slot_path: String = SAVE_SLOTS_SCRIPT.manual_path(path, slot_index)
			for suffix: String in ["", ".bak", ".old", ".tmp", ".bak.tmp", ".bak.old"]:
				_remove(slot_path + suffix)


func _remove(path: String) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)
