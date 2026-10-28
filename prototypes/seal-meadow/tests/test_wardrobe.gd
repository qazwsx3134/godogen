extends "res://addons/proto_kit/test_kit.gd"
## S35: real wardrobe UI, eligibility, preview rollback, equipment and save migration.

const SaveSlots = preload("res://addons/proto_kit/save_slots.gd")
const SAVE := "user://test_wardrobe/save.json"
const BAD_SAVE := "user://test_wardrobe/bad.json"

var main: Node3D
var player: Node3D
var hud: CanvasLayer


func _init() -> void:
	_run.call_deferred()


func _open() -> void:
	if main:
		main.queue_free()
		await _frames(2)
	main = load("res://scenes/main.tscn").instantiate()
	main.save_path = SAVE
	root.add_child(main)
	await _frames(4)
	player = main.player
	hud = main.hud


func _run() -> void:
	for path: String in [SAVE, SAVE + ".bak"]:
		DirAccess.remove_absolute(path)
	SaveSlots.save(SAVE, {"level": 3, "gold": 75, "collection": {"kills": {}, "claimed": []}}, 5)
	await _open()
	_expect(player.level == 3 and player.gold == 75 and player.appearance == {"outfit": "", "aura": ""},
		"v5 loads with progress intact and the default appearance")
	main.save_game()
	_expect(SaveSlots.restore(SAVE, 5).error == "newer", "a v5 reader rejects the newer wardrobe schema")
	await _test_locked_preview()
	await _test_unlocked_and_save()
	await _test_layout()
	await _test_scene_edit()
	await _test_invalid_save()
	main.queue_free()
	await _frames(2)
	_finish("SEAL MEADOW WARDROBE TESTS")


func _test_locked_preview() -> void:
	var hp: int = player.max_hp
	var attack: int = player.attack_power
	var original_gear: Dictionary = player.gear.duplicate(true)
	await _press(hud.wardrobe_button)
	var window: Control = hud.wardrobe_window
	_expect(window.visible, "wardrobe opens from the HUD")
	await _press(window.outfit_meadow)
	await _press(window.aura_meadow)
	_expect(player.actor.layer_sheets[0] != null and player.aura.visible, "locked options can be previewed on the player")
	_expect(window.apply_button.disabled and window.status.text.contains("解鎖") and window.status.text.contains("草原布衣"),
		"locked selection identifies the preview and explains why it cannot be applied")
	_expect(player.apply_appearance("meadow_tunic", "meadow_ring") == "locked" and player.appearance.outfit == "",
		"the rules reject a direct unowned appearance command")
	_expect(player.apply_appearance("unknown", "") == "unknown" and player.appearance.aura == "",
		"an unknown appearance is rejected without changing either field")
	_expect(player.save_data().appearance == {"outfit": "", "aura": ""}, "preview is excluded from save snapshots")
	_expect(player.max_hp == hp and player.attack_power == attack and player.gear == original_gear,
		"preview changes neither stats nor equipment")
	await _press(window.close_button)
	_expect(not window.visible and player.actor.layer_sheets[0] == null and not player.aura.visible,
		"closing cancels both previews and restores the real appearance")


func _test_unlocked_and_save() -> void:
	player.quests.index = 1
	player.collection.record_kill("slime")
	_expect(player.collection.claim(player, "first_quest") == "" and player.collection.claim(player, "first_slime") == "",
		"the two achievement rewards unlock the wardrobe choices")
	var hp: int = player.max_hp
	var attack: int = player.attack_power
	await _press(hud.wardrobe_button)
	var window: Control = hud.wardrobe_window
	await _press(window.outfit_meadow)
	await _press(window.aura_meadow)
	_expect(not window.apply_button.disabled, "owned appearance and aura can be applied together")
	await _press(window.apply_button)
	_expect(not window.visible and player.appearance == {"outfit": "meadow_tunic", "aura": "meadow_ring"}
		and player.aura.visible, "apply commits both cosmetic choices")
	_expect(player.max_hp == hp and player.attack_power == attack and player.equipped.body == "",
		"applied cosmetics confer no equipment or stat bonus")
	await _open()
	_expect(player.appearance == {"outfit": "meadow_tunic", "aura": "meadow_ring"} and player.aura.visible
		and player.actor.layer_sheets[0] != null, "applied appearance and unlocks survive restart")
	player.bag.add("cloth_tunic", 1)
	_expect(player.equip("cloth_tunic") == "", "body equipment remains wearable with an outfit override")
	var equipped_hp: int = player.max_hp
	_expect(player.apply_appearance("", "") == "" and player.actor.layer_sheets[0] != null and not player.aura.visible,
		"returning to equipment visuals keeps the actual tunic and hides the aura")
	_expect(player.max_hp == equipped_hp, "removing the visual override keeps the equipment bonus")
	await _press(hud.wardrobe_button)
	await _press(hud.wardrobe_window.aura_meadow)
	_expect(player.aura.visible, "aura is visible during preview")
	hud.open_world_map()
	_expect(not hud.wardrobe_window.visible and not player.aura.visible, "opening another window cancels a preview")
	hud.close_top_window()


func _test_layout() -> void:
	main.update_setting("large_text", true)
	for viewport_size: Vector2i in [Vector2i(1280, 720), Vector2i(1558, 720)]:
		root.size = viewport_size
		hud.open_wardrobe()
		await _frames(3)
		var window: Control = hud.wardrobe_window
		var safe: Rect2 = hud.get_node("Root").get_global_rect().grow(0.5)
		_expect(safe.encloses(window.apply_button.get_global_rect()) and safe.encloses(window.close_button.get_global_rect()),
			"wardrobe controls stay inside the safe HUD at %s" % viewport_size)
		var player_screen: Vector2 = main.rig.camera.unproject_position(player.global_position + Vector3.UP)
		_expect(not window.get_node("Window").get_global_rect().has_point(player_screen),
			"the player preview remains outside the wardrobe panel at %s" % viewport_size)
		hud.close_top_window()
	root.size = Vector2i(1280, 720)


func _test_scene_edit() -> void:
	var source := "res://ui/wardrobe_window.tscn"
	var before_hash := FileAccess.get_sha256(source)
	var edited: Control = (load(source) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	edited.scene_file_path = ""
	edited.get_node("Window/Contents/Hint").text = "編輯器自訂衣櫥說明"
	edited.get_node("Window/Contents").add_theme_constant_override("separation", 11)
	var packed := PackedScene.new()
	_expect(packed.pack(edited) == OK, "edited wardrobe scene packs")
	var copy_path := "user://test_wardrobe/edited.tscn"
	_expect(ResourceSaver.save(packed, copy_path) == OK, "edited wardrobe scene saves")
	edited.free()
	var restored: Control = (load(copy_path) as PackedScene).instantiate()
	root.add_child(restored)
	restored.bind(player, main)
	restored.show_wardrobe()
	await _frames(2)
	_expect(restored.get_node("Window/Contents/Hint").text == "編輯器自訂衣櫥說明"
		and restored.get_node("Window/Contents").get_theme_constant("separation") == 11,
		"runtime preserves editor changes to wardrobe text and spacing")
	_expect(FileAccess.get_sha256(source) == before_hash, "preview never writes runtime state into the source scene")
	restored.dismiss()
	restored.queue_free()
	await _frames(1)


func _test_invalid_save() -> void:
	main.queue_free()
	await _frames(2)
	for path: String in [BAD_SAVE, BAD_SAVE + ".bak"]:
		DirAccess.remove_absolute(path)
	SaveSlots.save(BAD_SAVE, {"level": 4, "appearance": {"outfit": "", "aura": ""}}, 6)
	SaveSlots.save(BAD_SAVE, {"level": 8, "appearance": {"outfit": "meadow_tunic", "aura": ""},
		"collection": {"claimed": []}}, 6)
	main = load("res://scenes/main.tscn").instantiate()
	main.save_path = BAD_SAVE
	root.add_child(main)
	await _frames(3)
	_expect(main.player.level == 4 and main.player.appearance.outfit == "",
		"an unowned saved appearance restores a valid backup")
	main.queue_free()
	await _frames(2)
	for path: String in [BAD_SAVE, BAD_SAVE + ".bak"]:
		DirAccess.remove_absolute(path)
	SaveSlots.save(BAD_SAVE, {"level": 8, "appearance": {"outfit": "unknown", "aura": ""}}, 6)
	var original := FileAccess.get_file_as_bytes(BAD_SAVE)
	main = load("res://scenes/main.tscn").instantiate()
	main.save_path = BAD_SAVE
	root.add_child(main)
	await _frames(3)
	main.save_game()
	_expect(main.save_blocked_reason == "corrupt" and FileAccess.get_file_as_bytes(BAD_SAVE) == original,
		"an unknown saved appearance without a backup is not overwritten")
