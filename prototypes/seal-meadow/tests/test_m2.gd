extends "res://addons/proto_kit/test_kit.gd"
## M2 town rules on the real player: shop, equipment, consumables, the quest chain, save v3.
## godot --headless --path . -s tests/test_m2.gd

const Shop = preload("res://scripts/shop.gd")
const SaveSlots = preload("res://addons/proto_kit/save_slots.gd")
const SAVE := "user://test_m2/save.json"

var main: Node3D
var player: Node3D


func _init() -> void:
	_run.call_deferred()


func _fresh() -> void:
	if main:
		main.queue_free()
		await _frames(2)
	main = load("res://scenes/main.tscn").instantiate()
	main.save_path = SAVE
	root.add_child(main)
	await _frames(3)
	player = main.get_node("%Player")


func _run() -> void:
	for f in [SAVE, SAVE + ".bak"]:
		DirAccess.remove_absolute(f)
	SaveSlots.save(SAVE, {"level": 2, "xp": 1, "x": 0.0, "z": 4.0, "bag": [{"id": "apple", "count": 2}]}, 2)
	await _fresh()
	_expect(player.level == 2 and player.bag.count("apple") == 2 and player.gold == 0 and player.quests.index == 0,
		"v2 save migrates to v3 with defaults")
	_test_shop()
	_test_equip()
	_test_use()
	await _test_quests()
	await _test_sale_confirmation()
	await _test_ui()
	await _test_zone_save()
	await _test_tutorial()
	main.save_game()
	var gold: int = player.gold
	var worn: Dictionary = player.equipped.duplicate()
	var qi: int = player.quests.index
	await _fresh()
	_expect(player.gold == gold and player.equipped == worn and player.quests.index == qi, "gold, gear and quest state survive a restart")
	main.queue_free()
	_finish("SEAL MEADOW M2 TESTS")


func _test_shop() -> void:
	player.gold = 100
	_expect(Shop.buy(player, "iron_sword") == "gold" and player.gold == 100 and player.bag.count("iron_sword") == 0, "not enough gold changes nothing")
	_expect(Shop.buy(player, "jelly_gel") == "not_sold", "shop only sells its list")
	_expect(Shop.buy(player, "apple", 2) == "" and player.gold == 80, "buy takes the price")
	var cap: int = player.bag.capacity
	player.bag.capacity = player.bag.slots.size()
	player.gold = 1000
	_expect(Shop.buy(player, "cloth_tunic") == "bag_full" and player.gold == 1000, "full bag: no item, gold kept")
	player.gold = 80
	player.bag.capacity = cap
	player.bag.add("jelly_gel", 5)
	player.bag.add("boar_tusk", 1)
	_expect(Shop.sell_materials(player) == 5 * 4 + 12 and player.bag.count("jelly_gel") == 0 and player.bag.count("apple") == 4,
		"sell materials keeps consumables")
	_expect(Shop.sell(player, "boar_tusk") == "none", "cannot sell what is not there")


func _test_equip() -> void:
	player.gold = 1000
	var atk0: int = player.attack_power
	var hp0: int = player.max_hp
	Shop.buy(player, "iron_sword")
	_expect(player.equip("iron_sword") == "" and player.attack_power == atk0 + 6, "sword adds 6 attack")
	_expect(player.bag.count("iron_sword") == 0, "worn sword leaves the bag")
	Shop.buy(player, "iron_sword")
	_expect(player.equip("iron_sword") == "" and player.attack_power == atk0 + 6 and player.bag.count("iron_sword") == 1,
		"swapping the same slot does not stack bonuses")
	Shop.buy(player, "cloth_tunic")
	player.equip("cloth_tunic")
	_expect(player.max_hp == hp0 + 25, "tunic adds 25 HP")
	var layers: Array = player.actor.layer_sheets
	_expect(layers[2].resource_path.ends_with("test_chibi_iron.tres") and layers[0].resource_path.ends_with("test_chibi_tunic.tres"),
		"paper doll wears the iron sword and the tunic")
	_expect(player.equip("apple") == "not_equipment", "apples are not worn")
	# bag full: unequip refused, nothing lost
	var cap: int = player.bag.capacity
	player.bag.capacity = player.bag.slots.size()
	_expect(player.unequip("body") == "bag_full" and player.equipped.body == "cloth_tunic", "unequip into a full bag refused")
	player.bag.capacity = cap
	_expect(player.unequip("body") == "" and player.max_hp == hp0 and player.bag.count("cloth_tunic") == 1, "unequip returns it")
	_expect(player.actor.layer_sheets[0] == null, "no outfit layer after taking the tunic off")


func _test_use() -> void:
	player.hp = player.max_hp
	_expect(player.use_item("apple") == "full_hp", "no apple wasted at full HP")
	player.hp = 10
	var n: int = player.bag.count("apple")
	_expect(player.use_item("apple") == "" and player.hp > 10 and player.bag.count("apple") == n - 1, "apple heals and is used up")


func _test_quests() -> void:
	var q = player.quests
	q.index = 0
	q.accepted = false
	_expect(q.turn_in(player) == "none", "nothing to turn in before accepting")
	_expect(q.accept() and not q.accept(), "accept once")
	q.on_kill("boar")
	_expect(q.count(player) == 0, "wrong monster does not count")
	for i in 5:
		q.on_kill("slime")
	q.on_kill("slime")
	_expect(q.count(player) == 5, "kill count caps at the goal")
	var gold: int = player.gold
	_expect(q.turn_in(player) == "" and player.gold == gold + 60 and q.index == 1, "quest 1 pays once")
	_expect(q.turn_in(player) == "none", "cannot turn in again")
	q.accept()
	player.bag.remove("jelly_gel", player.bag.count("jelly_gel"))
	player.bag.add("jelly_gel", 4)
	_expect(q.turn_in(player) == "not_done", "4 of 5 gel is not enough")
	player.bag.add("jelly_gel", 1)
	var keep: Array[Dictionary] = player.bag.slots.duplicate(true)
	var cap: int = player.bag.capacity
	player.bag.capacity = 1
	var full: Array[Dictionary] = [{"id": "jelly_gel", "count": 6}]  # 1 gel stays, so the 3 apples have nowhere to go
	player.bag.slots = full
	_expect(q.turn_in(player) == "bag_full" and player.bag.count("jelly_gel") == 6 and q.index == 1,
		"no room for the reward: gel kept, quest still open")
	player.bag.capacity = cap
	player.bag.slots = keep
	var apples: int = player.bag.count("apple")
	_expect(q.turn_in(player) == "" and player.bag.count("jelly_gel") == 0 and player.bag.count("apple") == apples + 3,
		"quest 2 takes the gel and gives 3 apples")
	q.accept()
	player.unequip("weapon")
	_expect(q.turn_in(player) == "not_done", "equip quest needs the sword worn")
	player.equip("iron_sword")
	var lv: int = player.level
	_expect(q.turn_in(player) == "" and q.current().is_empty(), "quest 3 done, chain finished")
	_expect(player.level >= lv, "xp reward applied")


func _test_ui() -> void:
	await _fresh()
	var hud: Node = main.get_node("%HUD")
	var elder: Node3D = root.get_tree().get_nodes_in_group("npc")[0]
	var cam: Camera3D = main.get_node("%CameraRig").camera
	var portal: Node3D = main.get_node("ToTown")
	player.position = portal.position + Vector3(0, 0, -3)
	await _frames(20)
	main._click(cam.unproject_position(portal.global_position), true)
	await _until(func() -> bool: return main.zone == "town" and not main._travelling, "travelled to the village", 8.0)
	_expect(main.zone == "town" and player.bounds_center == Vector2(300, 0), "the portal takes the player to the village")
	await _frames(20)
	player.quests.index = 0
	player.quests.accepted = false
	player.gold = 400
	main._click(cam.unproject_position(elder.global_position + Vector3.UP), true)
	await _until(func() -> bool: return hud.npc_panel.visible, "walked to the elder, panel open", 6.0)
	_expect(hud.npc_panel.visible, "tapping the NPC opens its panel")
	await _press(hud.quest_button)
	_expect(player.quests.accepted and hud.quest_tracker.text.contains("0/5"), "accept from the panel, tracker shows 0/5")
	await _frames(1)
	var live: Array = hud.shop_rows.get_children().filter(func(r: Node) -> bool: return not r.is_queued_for_deletion())
	var sword_row: Node = live.filter(func(r: Node) -> bool: return r.name_label.text == "鐵劍")[0]
	var swords: int = player.bag.count("iron_sword")
	await _press(sword_row.action_button)
	_expect(player.bag.count("iron_sword") == swords + 1 and player.gold == 100, "buy the sword from its row")
	await _press(hud.close_button)
	await _press(hud.bag_button)
	await _frames(2)
	var row: Node = null
	for r: Node in hud.bag_rows.get_children():
		if not r.is_queued_for_deletion() and r.name_label.text.begins_with("鐵劍"):
			row = r
	_expect(row != null, "sword listed in the bag")
	if row:
		await _press(row.action_button)
	_expect(player.equipped.weapon == "iron_sword" and hud.gear_label.text.contains("鐵劍"), "equip from the bag row")


func _test_zone_save() -> void:
	# player is in the village after _test_ui; a restart keeps them there with the village bounds
	main.save_game()
	await _fresh()
	_expect(main.zone == "town" and player.position.x > 250.0 and player.bounds_center == Vector2(300, 0),
		"a save made in the village loads in the village")
	var back: Node3D = main.get_node("Town/ToMeadow")
	main.travel(back)
	await _until(func() -> bool: return not main._travelling, "travel back", 5.0)
	_expect(main.zone == "meadow" and player.position.x < 50.0 and player.bounds_center == Vector2.ZERO, "and back to the meadow")


func _test_tutorial() -> void:
	var tut = player.tutorial
	tut.step = 0
	tut._started = false
	tut.update(player)
	player.position += Vector3(3, 0, 0)
	_expect(tut.update(player) and tut.step == 1, "walking finishes hint 1")
	_expect(not tut.update(player), "hint 2 waits for a target")
	player.set_target(root.get_tree().get_nodes_in_group("monster")[0])
	_expect(tut.update(player) and tut.step == 2, "targeting finishes hint 2")
	tut.skip()
	_expect(tut.finished() and tut.text() == "", "skip ends the tutorial")
	main.save_game()
	await _fresh()
	_expect(player.tutorial.finished() and not main.get_node("%HUD").tutorial_panel.visible, "skipped tutorial stays hidden after a restart")


func _test_sale_confirmation() -> void:
	await _fresh()
	var hud: Node = main.hud
	player.bag.slots.clear()
	player.bag.add("ruby", 1)
	player.bag.add("clover", 1)
	player.gold = 0
	hud.open_npc()
	await _frames(3)
	hud.npc_panel.get_node("Scroll").ensure_control_visible(hud.sell_button)
	await _frames(3)
	await _press(hud.sell_button)
	_expect(player.gold == 0 and player.bag.count("ruby") == 1 and hud.sell_confirmation.dialog_text.contains("紅寶石"), "sale preview lists growth materials without spending")
	await _press(hud.sell_confirmation.get_node("%CancelSale"))
	_expect(not hud.sell_confirmation.visible and player.bag.count("clover") == 1, "cancel preserves evolution materials")
	hud._preview_sale()
	player.bag.add("jelly_gel", 1)
	hud._confirm_sale()
	_expect(player.gold == 0 and player.bag.count("ruby") == 1, "changed inventory rejects stale sale")
	hud.sell_confirmation.hide()
	hud._preview_sale()
	await _frames(3)
	await _press(hud.sell_confirmation.get_node("%ConfirmSale"))
	_expect(player.gold == 69 and player.bag.slots.is_empty(), "confirmed list sells exact materials")
	hud.sell_confirmation.hide()
	var restored: Dictionary = SaveSlots.restore(SAVE, main.SAVE_VERSION)
	_expect(int(restored.data.gold) == 69 and restored.data.bag.is_empty(), "confirmed sale persists")
	player.bag.add("ruby", 1)
	hud._preview_sale()
	hud.open_world_map()
	_expect(not hud.sell_confirmation.visible, "switching panels dismisses sale confirmation")
	hud._confirm_sale()
	_expect(player.bag.count("ruby") == 1, "dismissed confirmation cannot sell")

	for viewport_size: Vector2i in [Vector2i(844, 390), Vector2i(1280, 720)]:
		root.size = viewport_size
		hud.set_large_text(true)
		player.bag.slots.clear()
		player.bag.add("ruby", 120)
		hud._preview_sale()
		await _frames(4)
		var panel: Control = hud.sell_confirmation.get_node("Panel")
		_expect(hud.get_node("Root").get_global_rect().encloses(panel.get_global_rect()), "sale panel fits safe HUD at %s" % viewport_size)
		var scale_to_screen: Vector2 = Vector2(root.size) / root.get_visible_rect().size
		for name: String in ["%CancelSale", "%ConfirmSale"]:
			var button: Button = hud.sell_confirmation.get_node(name)
			_expect((button.size * scale_to_screen).y >= 44, "sale actions retain touch height at %s" % viewport_size)
		var listing: Label = hud.sell_confirmation.get_node("%SaleList")
		var scroll: ScrollContainer = listing.get_parent()
		_expect(scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page,
			"full bag with large text has a scrollable sale list at %s" % viewport_size)
		var confirm: Button = hud.sell_confirmation.get_node("%ConfirmSale")
		var confirm_rect := confirm.get_global_rect()
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
		await _frames(2)
		_expect(confirm.get_global_rect() == confirm_rect and scroll.scroll_vertical > 0,
			"scrolling the sale list leaves confirmation fixed at %s" % viewport_size)
		await _press(hud.sell_confirmation.get_node("%CancelSale"))
		_expect(player.bag.count("ruby") == 120 and not hud.sell_confirmation.visible,
			"canceling the scrolled list keeps every stack at %s" % viewport_size)
		hud.close_top_window()
	hud.set_large_text(false)
	root.size = Vector2i(1280, 720)
