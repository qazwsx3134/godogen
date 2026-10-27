extends "res://addons/proto_kit/test_kit.gd"
## Save and equipment cases required by the M3 persistence/transaction planning documents.

const SaveSlots = preload("res://addons/proto_kit/save_slots.gd")
const Refine = preload("res://scripts/refine.gd")
const BASE := "user://test_m3_hardening/"

var main: Node3D
var player: Node3D


func _init() -> void:
	_run.call_deferred()


func _open(name: String) -> void:
	if main:
		main.queue_free()
		await _frames(2)
	main = load("res://scenes/main.tscn").instantiate()
	main.save_path = BASE.path_join(name + ".json")
	root.add_child(main)
	await _frames(3)
	player = main.get_node("%Player")


func _clear(name: String) -> String:
	var path := BASE.path_join(name + ".json")
	for p in [path, path + ".bak"]:
		DirAccess.remove_absolute(p)
	return path


func _run() -> void:
	await _test_newer_save()
	await _test_backup_recovery()
	await _test_bad_payload_recovery()
	await _test_quest_checkpoint()
	await _test_equipment_independence()
	await _test_legacy_equipment_migration()
	await _test_refine_retry()
	await _test_settings()
	await _test_pet_confirmation()
	await _test_background_cancels_attack()
	await _test_layout()
	await _test_settings_scene_edit()
	main.queue_free()
	await _frames(2)
	_finish("SEAL MEADOW M3 HARDENING")


func _test_newer_save() -> void:
	var path := _clear("newer")
	SaveSlots.save(path, {"level": 99, "xp": 4}, 999)
	var original := FileAccess.get_file_as_bytes(path)
	await _open("newer")
	player.gain_xp(1, "test")
	main.save_game()
	_expect(FileAccess.get_file_as_bytes(path) == original, "a newer save is never overwritten by gameplay")


func _test_backup_recovery() -> void:
	var path := _clear("backup")
	SaveSlots.save(path, {"level": 3, "xp": 7}, 4)
	SaveSlots.save(path, {"level": 5, "xp": 9}, 4)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string('{"version":4,"data":null}')
	file.close()
	await _open("backup")
	_expect(player.level == 3 and player.xp == 7, "a valid backup is restored when the main envelope is malformed")
	main.save_game()
	var backup: Variant = JSON.parse_string(FileAccess.get_file_as_string(path + ".bak"))
	_expect(backup is Dictionary and backup.get("data") is Dictionary and int(backup.data.level) == 3,
		"saving after recovery preserves a valid backup")


func _test_bad_payload_recovery() -> void:
	var path := _clear("bad_payload")
	SaveSlots.save(path, {"level": 4, "xp": 6}, 4)
	SaveSlots.save(path, {"level": 7, "xp": 2}, 4)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string('{"version":5,"data":{"level":7,"bag":"damaged"}}')
	file.close()
	await _open("bad_payload")
	_expect(player.level == 4 and player.xp == 6, "a malformed payload falls back to the valid backup")
	main.save_game()
	var backup: Variant = JSON.parse_string(FileAccess.get_file_as_string(path + ".bak"))
	_expect(backup is Dictionary and int(backup.data.level) == 4, "payload recovery preserves the valid backup")
	path = _clear("bad_legacy")
	SaveSlots.save(path, {"level": 4, "xp": 6}, 4)
	SaveSlots.save(path, {"level": 7, "bag": "damaged"}, 4)
	await _open("bad_legacy")
	_expect(player.level == 4 and player.xp == 6, "a malformed v4 payload is rejected before migration can discard data")
	path = _clear("bad_collection")
	SaveSlots.save(path, {"level": 4, "xp": 6}, 4)
	SaveSlots.save(path, {"collection": {"claimed": "damaged"}}, 5)
	await _open("bad_collection")
	_expect(player.level == 4 and player.xp == 6, "a damaged achievement ledger falls back to the valid backup")


func _test_quest_checkpoint() -> void:
	var path := _clear("quest")
	await _open("quest")
	player.quests.accept()
	player.quests.progress = 5
	main.save_game()
	var snapshots: Array = []
	player.stats_changed.connect(func() -> void:
		var save: Dictionary = SaveSlots.restore(path, main.SAVE_VERSION)
		if save.error == "":
			snapshots.append(save.data))
	_expect(player.quests.turn_in(player) == "", "the completed quest can be turned in")
	var partial: bool = snapshots.any(func(s: Dictionary) -> bool:
		return int(s.get("gold", 0)) >= 60 and int(s.get("quests", {}).get("index", 0)) == 0)
	_expect(not partial, "an XP checkpoint never saves quest rewards without the completed quest")


func _test_equipment_independence() -> void:
	_clear("equipment")
	await _open("equipment")
	player.bag.add("iron_sword", 2)
	player.bag.add("crystal", 1)
	player.equip("iron_sword")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_expect(Refine.attempt(player, "weapon", rng) == "", "first sword can be refined")
	var improved: int = player.attack_power
	var improved_uid: String = player.gear.weapon.uid
	player.equip("iron_sword")
	_expect(player.attack_power == improved - 2, "a second sword does not inherit the first sword's refinement")
	_expect(player.gear.weapon.uid != improved_uid, "identical swords keep distinct identities")
	_expect(player.equip("iron_sword", improved_uid) == "" and player.refine_level("weapon") == 1,
		"selecting the first sword restores its own refine level")
	main.save_game()
	await _open("equipment")
	_expect(player.gear.weapon.uid == improved_uid and player.refine_level("weapon") == 1,
		"equipment identity and refine level survive restart")


func _test_legacy_equipment_migration() -> void:
	var path := _clear("legacy")
	SaveSlots.save(path, {"equipped": {"weapon": "iron_sword", "body": ""},
		"bag": [{"id": "iron_sword", "count": 1}], "refine": {"iron_sword": 3}}, 4)
	await _open("legacy")
	var worn: Dictionary = player.gear.weapon
	var bag_sword: Dictionary = player.bag.slots[0]
	_expect(worn.get("refine", -1) == 3 and bag_sword.get("refine", -1) == 3,
		"v4's shared refine bonus is preserved on each existing sword")
	_expect(worn.get("uid", "") != "" and worn.uid != bag_sword.get("uid", ""),
		"migrated copies get distinct stable identities")


func _test_refine_retry() -> void:
	_clear("retry")
	await _open("retry")
	player.bag.add("iron_sword", 1)
	player.bag.add("crystal", 2)
	player.equip("iron_sword")
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var first := {}
	_expect(Refine.attempt(player, "weapon", rng, first, 12) == "", "a numbered refine request executes")
	main.save_game()
	await _open("retry")
	var again := {}
	_expect(Refine.attempt(player, "weapon", rng, again, 12) == "" and again == first,
		"a repeated request after restart returns its original result")
	_expect(player.refine_level("weapon") == 1 and player.bag.count("crystal") == 1,
		"a repeated request neither consumes another stone nor refines again")
	_expect(Refine.attempt(player, "weapon", rng, {}, 11) == "stale", "an older request is rejected")


func _test_settings() -> void:
	_clear("settings")
	await _open("settings")
	var hud: CanvasLayer = main.get_node("%HUD")
	var old_size: int = hud.pet_name.get_theme_font_size("font_size")
	await _press(hud.settings_button)
	_expect(hud.settings_window.visible, "settings button opens the settings window")
	await _press(hud.settings_window.sound)
	await _press(hud.settings_window.large_text)
	await _press(hud.settings_window.reduced_motion)
	_expect(not main.settings.sound and not main.sfx.enabled, "sound toggle mutes the SFX bank")
	_expect(main.settings.large_text and hud.pet_name.get_theme_font_size("font_size") > old_size,
		"large text changes the actual HUD font size")
	_expect(main.settings.reduced_motion, "reduced motion is enabled")
	await _press(hud.settings_window.close_button)
	_expect(not hud.settings_window.visible, "the large-text settings close button remains clickable")
	await _open("settings")
	hud = main.get_node("%HUD")
	_expect(not main.settings.sound and main.settings.large_text and main.settings.reduced_motion,
		"settings survive a restart")
	_expect(hud.pet_name.get_theme_font_size("font_size") > old_size, "large text is applied after restart")


func _test_pet_confirmation() -> void:
	_clear("pet_confirm")
	await _open("pet_confirm")
	player.pet.level = 9
	player.pet.xp = player.pet.xp_to_next()
	player.bag.add("clover", 1)
	player.bag.add("boar_tusk", 1)
	var hud: CanvasLayer = main.get_node("%HUD")
	await _press(hud.pet_button)
	await _press(hud.evolve_button)
	_expect(player.bag.count("clover") == 1 and player.bag.count("boar_tusk") == 1,
		"the first evolution press only asks for confirmation")
	await _press(hud.evolve_button)
	_expect(player.bag.count("clover") == 0 and player.bag.count("boar_tusk") == 0,
		"the second evolution press consumes the materials once")


func _test_background_cancels_attack() -> void:
	_clear("background")
	await _open("background")
	player.set_process(false)
	var monster: Node3D = get_nodes_in_group("monster")[0]
	monster.set_process(false)
	monster.global_position = player.global_position + Vector3(1, 0, 0)
	var hp: int = monster.hp
	player.set_target(monster)
	player._try_attack()
	main._holding = true
	main._hold_to_walk = true
	player.pointer_moving = true
	var clock: Node = main.get_node("%GameClock")
	clock.set_away(true)
	_expect(not main._holding and not player.pointer_moving, "backgrounding clears the held movement gesture")
	await create_timer(0.25).timeout
	clock.set_away(false)
	await _frames(clock.resume_frames + 1)
	await create_timer(0.25).timeout
	_expect(monster.hp == hp, "an attack started before backgrounding cannot land after resume")


func _test_layout() -> void:
	var hud: CanvasLayer = main.get_node("%HUD")
	main.update_setting("large_text", true)
	for viewport_size: Vector2i in [Vector2i(1280, 720), Vector2i(1558, 720)]:
		root.size = viewport_size
		await _frames(3)
		hud.open_settings()
		await _frames(2)
		_expect(_inside(hud.settings_window.close_button, hud.get_node("Root")), "settings close is inside the safe HUD at %s" % viewport_size)
		hud.open_world_map()
		await _frames(2)
		_expect(_inside(hud.world_map.close_button, hud.get_node("Root")), "map close is inside the safe HUD at %s" % viewport_size)
		hud.open_collection()
		await _frames(2)
		_expect(_inside(hud.collection_window.close_button, hud.get_node("Root")), "collection close is inside the safe HUD at %s" % viewport_size)
		hud.open_fishing()
		await _frames(2)
		_expect(_inside(hud.fishing_window.close_button, hud.get_node("Root")) and _inside(hud.fishing_window.action_button, hud.get_node("Root")),
			"fishing controls are inside the safe HUD at %s" % viewport_size)
		hud._close_panels()
	root.size = Vector2i(1280, 720)


func _inside(control: Control, area: Control) -> bool:
	var outer: Rect2 = area.get_global_rect().grow(0.5)
	var inner: Rect2 = control.get_global_rect()
	return outer.encloses(inner) and inner.size.x > 0 and inner.size.y > 0


func _test_settings_scene_edit() -> void:
	var scene: PackedScene = load("res://ui/settings_window.tscn")
	var edited: Control = scene.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	edited.scene_file_path = ""
	edited.get_node("Window/Contents/Hint").text = "編輯器修改"
	var packed := PackedScene.new()
	_expect(packed.pack(edited) == OK, "edited settings scene packs")
	var path := BASE.path_join("edited_settings.tscn")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	_expect(ResourceSaver.save(packed, path) == OK, "edited settings scene saves")
	edited.free()
	var restored: Control = (load(path) as PackedScene).instantiate()
	root.add_child(restored)
	await _frames(1)
	restored.show_settings({})
	_expect(restored.get_node("Window/Contents/Hint").text == "編輯器修改", "runtime preserves edited settings text")
	restored.queue_free()
