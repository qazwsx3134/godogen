extends "res://addons/proto_kit/test_kit.gd"
## Actual main-scene paths for the touch and self-defense feedback in REVIEW.md.

const SAVE := "user://review_interactions/save.json"

var main: Node3D
var player: Node3D


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for f in [SAVE, SAVE + ".bak"]:
		DirAccess.remove_absolute(f)
	main = load("res://scenes/main.tscn").instantiate()
	main.save_path = SAVE
	root.add_child(main)
	await _frames(5)
	main.set_process(false)
	player = main.get_node("%Player")
	player.set_process(false)
	var monsters := get_nodes_in_group("monster")
	for m: Node3D in monsters:
		m.set_process(false)
		m.position += Vector3(30, 0, 30)
	var cam: Camera3D = main.get_node("%CameraRig").camera
	var pile: Node3D = load("res://scenes/loot_drop.tscn").instantiate()
	pile.setup("apple", 1)
	main.add_child(pile)
	pile.position = player.position + Vector3(3, 0, 0)
	main._click(cam.unproject_position(pile.global_position + Vector3.UP * 0.35), true)
	_expect(main._loot_goal == pile, "tap selects the ground item")
	main._holding = true
	main._repeat = 0.0
	main._process(0.13)
	_expect(main._loot_goal == pile, "holding a ground-item tap keeps the pickup goal")
	player.blockers.clear()
	for i in 20:
		if pile.taken:
			break
		player._process(0.05)
		main._process(0.05)
	_expect(pile.taken and player.bag.count("apple") == 1, "held item tap walks over and picks it up")
	_expect(main._flat_distance(player, pile) > 1.1, "the item is collected without walking directly over it")
	main._holding = false
	await _frames(2)
	var portal: Node3D = get_nodes_in_group("portal").filter(func(p: Node3D) -> bool: return p.zone == "town")[0]
	portal.global_position = player.global_position + Vector3(4, 0, 0)
	main._click(cam.unproject_position(portal.global_position), true)
	_expect(main._portal_goal == portal, "tap selects the portal")
	main._holding = true
	main._repeat = 0.0
	main._process(0.13)
	_expect(main._portal_goal == portal, "holding a portal tap keeps the travel goal")
	main._holding = false
	var second: Node3D = load("res://scenes/loot_drop.tscn").instantiate()
	second.setup("apple", 1)
	main.add_child(second)
	second.global_position = portal.global_position + Vector3(1.1, 0, 0)
	main._click(cam.unproject_position(second.global_position + Vector3.UP * 0.85), true)
	_expect(main._loot_goal == second, "an item's label wins over a nearby portal")
	main._click(cam.unproject_position(portal.global_position + Vector3.UP * 1.4), true)
	_expect(main._portal_goal == portal, "the portal's label is tappable near an item")
	player.global_position = portal.global_position + Vector3(1.0, 0, 0)
	main._process(0.01)
	await create_timer(0.7).timeout
	_expect(main.zone == portal.zone and not main._travelling, "portal tap reaches the destination and finishes its fade")
	second.queue_free()
	main._portal_goal = null
	player._has_goal = false
	player.target = null
	var attacker: Node3D = monsters[0]
	attacker.global_position = player.global_position + Vector3(1, 0, 0)
	var attacker_hp: int = attacker.hp
	main.combat.attack(attacker, player, 1, 1.0, false)
	_expect(player.target == attacker, "an idle player automatically targets the attacking monster")
	player._process(0.01)
	await create_timer(0.25).timeout
	_expect(attacker.hp < attacker_hp, "the automatic target is actually attacked")
	var other: Node3D = monsters[1]
	player.set_target(other)
	main.combat.attack(attacker, player, 1, 1.0, false)
	_expect(player.target == other, "a hit does not replace a valid player-selected target")
	player.target = null
	player.move_to(player.position + Vector3(3, 0, 0))
	main.combat.attack(attacker, player, 1, 1.0, false)
	_expect(player.target == null and player._has_goal, "damage does not interrupt a manual move")
	player._has_goal = false
	player.pointer_moving = true
	main.combat.attack(attacker, player, 1, 1.0, false)
	_expect(player.target == null, "damage does not interrupt a held ground steering press")
	player.pointer_moving = false
	Input.action_press("move_left")
	main.combat.attack(attacker, player, 1, 1.0, false)
	_expect(player.target == null, "damage does not interrupt keyboard movement")
	main._portal_goal = portal
	main._process(0.01)
	_expect(main._portal_goal == null, "keyboard movement cancels a pending portal")
	Input.action_release("move_left")
	player.set_target(attacker)
	player._cooldown = 0.0
	attacker_hp = attacker.hp
	player._try_attack()
	player.move_to(player.position + Vector3(3, 0, 0))
	await create_timer(0.25).timeout
	_expect(attacker.hp == attacker_hp, "starting a manual move cancels a pending auto-attack")
	await _test_map()
	_test_log_bound()
	await _test_map_editor()
	main.queue_free()
	await _frames(2)
	_finish("SEAL MEADOW REVIEW INTERACTIONS")


func _test_map() -> void:
	var hud: CanvasLayer = main.get_node("%HUD")
	await _press(hud.map_button)
	_expect(hud.world_map.visible and hud.world_map.town_here.visible and not hud.world_map.meadow_here.visible,
		"world-map button opens the map at the current town")
	await _press(hud.world_map.close_button)
	_expect(not hud.world_map.visible, "world map close button closes it")
	main.zone = "meadow"
	await _tap(hud.minimap.get_global_rect().get_center())
	_expect(hud.world_map.visible and hud.world_map.meadow_here.visible and not hud.world_map.town_here.visible,
		"tapping the minimap opens the map at the current meadow")
	await _press(hud.world_map.close_button)
	_expect(hud.pet_button.anchor_top == 0.0 and hud.pet_button.anchor_right == 1.0,
		"pet button is anchored to the upper right")


func _test_log_bound() -> void:
	var hud: CanvasLayer = main.get_node("%HUD")
	for i in 1000:
		hud.log_line("訊息 %d" % i)
	_expect(hud.log_box.get_paragraph_count() <= 60, "one thousand messages leave at most 60 log paragraphs")
	_expect(hud.log_box.get_parsed_text().contains("訊息 999"), "the bounded log retains the newest message")


func _test_map_editor() -> void:
	var original: PackedScene = load("res://ui/world_map.tscn")
	var edited: Control = original.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	edited.scene_file_path = ""
	edited.get_node("Window/Contents/Header/Title").text = "我的地圖"
	var packed := PackedScene.new()
	_expect(packed.pack(edited) == OK, "edited world map scene packs successfully")
	var path := "user://review_interactions/edited_map.tscn"
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	_expect(ResourceSaver.save(packed, path) == OK, "edited world map scene saves successfully")
	edited.free()
	var restored: Control = (load(path) as PackedScene).instantiate()
	root.add_child(restored)
	await _frames(1)
	restored.show_zone("town")
	_expect(restored.get_node("Window/Contents/Header/Title").text == "我的地圖",
		"a saved editor text change survives runtime setup")
	restored.queue_free()
