extends "res://addons/proto_kit/test_kit.gd"

const TestBootstrap = preload("res://tests/test_bootstrap.gd")
const Catalog = preload("res://domain/progression_catalog.gd")

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	TestBootstrap.add_services(root)
	var game: Node = root.get_node("Game")
	_expect(game.get("gold") == 500, "new game starts with 500 gold")
	_expect(game.call("monster_ids") == ["sprout", "fox", "aqua", "mushroom"], "catalog exposes four independent monsters in stable order")
	_expect(game.get("deployed") == ["sprout", "fox", "aqua", "mushroom"], "all four monsters start deployed")
	_expect(Catalog.ITEMS.size() >= 14, "static equipment catalog has fourteen-plus items")
	_expect(game.call("items_for", "sprout").size() >= 7, "catalog includes monster equipment and the shared accessory")
	_expect(game.call("equipment_for", "hero").size() == 6, "hero has six distinct equipment slots")
	_expect(game.call("equipment_for", "sprout").size() == 6, "monsters have six distinct equipment slots")
	_expect(game.call("items_for", "hero", "weapon").size() == 3, "weapon filter returns hero weapon choices")
	_expect(game.call("items_for", "hero", "not-a-filter").is_empty(), "unknown item filters return no items")
	for monster_id: String in game.call("monster_ids"):
		var info: Dictionary = game.call("monster_info", monster_id)
		_expect(not info.is_empty(), "every catalog monster has independent unit info: " + monster_id)
		_expect(info.get("level") == 1 and info.get("xp") == 0 and info.get("xp_next") > 0, "monster progression starts at level one: " + monster_id)
		_expect(info.get("deployed") == true, "every monster starts deployed: " + monster_id)
		for stat: String in Catalog.STAT_KEYS:
			_expect(info["stats"].has(stat) and info["base"].has(stat) and info["bonus"].has(stat), "all monster stat groups expose " + stat + ": " + monster_id)
		_expect(game.call("equipment_for", monster_id).size() == 6, "each monster has six equipment slots: " + monster_id)
	var hero_items: Array = game.call("items_for", "hero")
	for item: Dictionary in hero_items:
		for field: String in ["id", "name", "slot", "level", "kind", "owner_type", "icon_index", "equipped_by"]:
			_expect(item.has(field), "item data exposes " + field + " for " + str(item.get("id", "unknown")))
	for item_filter: String in ["weapon", "armor", "accessory", "other"]:
		_expect(game.call("items_for", "hero", item_filter) is Array, "hero inventory accepts the " + item_filter + " filter")
	_expect(game.call("items_for", "hero", "armor").size() > 0, "armor filter returns hero-compatible armor")
	_expect(game.call("items_for", "hero", "accessory").size() > 0, "accessory filter returns hero-compatible accessories")
	_expect(game.call("items_for", "sprout", "other").size() >= 1, "other filter returns monster badge equipment")

	var hero_before: Dictionary = game.call("hero_info")
	var sprout_before: Dictionary = game.call("monster_info", "sprout")
	var fox_before: Dictionary = game.call("monster_info", "fox")
	var cost: int = int(game.call("training_cost", 0))
	var training_before: Array = game.get("training").duplicate()
	var train_result: Dictionary = game.call("train", 0)
	var hero_after: Dictionary = game.call("hero_info")
	_expect(bool(train_result.get("ok", false)), "one training click succeeds when funded")
	_expect(game.get("training")[0] == training_before[0] + 1, "training immediately adds one level to the selected hero track")
	_expect(game.get("gold") == 500 - cost, "training spends its displayed gold cost")
	_expect(int(hero_after["level"]) == int(hero_before["level"]) + 1, "one completed training click adds one hero level")
	_expect(float(hero_after["stats"]["attack"]) > float(hero_before["stats"]["attack"]), "hero attack training raises hero attack")
	_expect(is_equal_approx(float(hero_after["stats"]["health"]), float(hero_before["stats"]["health"])), "attack training leaves hero health unchanged")
	_expect(game.call("monster_info", "sprout")["stats"] == sprout_before["stats"], "hero training never changes monster stats")
	_expect(game.call("monster_info", "fox")["stats"] == fox_before["stats"], "hero training never changes another monster")
	_expect(hero_after.has("base") and hero_after.has("bonus") and hero_after.has("stats"), "unit info separates base, equipment bonus, and final stats")
	var expected_training_stats: Array[String] = ["health", "speed", "regen"]
	var mushroom_stats_before_training: Dictionary = game.call("monster_info", "mushroom")["stats"]
	for index: int in range(1, 4):
		var before_track: Dictionary = game.call("hero_info")
		var before_level: int = int(game.get("training")[index])
		var track_result: Dictionary = game.call("train", index)
		var after_track: Dictionary = game.call("hero_info")
		var changed_stat: String = expected_training_stats[index - 1]
		_expect(bool(track_result.get("ok", false)), "each hero training track can be purchased: " + changed_stat)
		_expect(int(game.get("training")[index]) == before_level + 1, "each track advances one level: " + changed_stat)
		_expect(int(after_track["level"]) == int(before_track["level"]) + 1, "each track adds one overall hero level: " + changed_stat)
		_expect(float(after_track["stats"][changed_stat]) > float(before_track["stats"][changed_stat]), "training affects its matching hero stat: " + changed_stat)
		_expect(game.call("monster_info", "mushroom")["stats"] == mushroom_stats_before_training, "hero training leaves monsters unchanged: " + changed_stat)

	var training_after: Array = game.get("training").duplicate()
	game.set("gold", 0)
	var unaffordable_training: Dictionary = game.call("train", 1)
	_expect(not bool(unaffordable_training.get("ok", true)), "unaffordable training fails")
	_expect(game.get("training") == training_after, "failed training leaves all levels unchanged")
	_expect(game.get("gold") == 0, "failed training does not change gold")
	game.set("gold", 500 - cost)

	var kill_gold_before: int = int(game.get("gold"))
	var monster_xp_before: Dictionary = {}
	for monster_id: String in game.call("monster_ids"):
		monster_xp_before[monster_id] = game.get("monsters")[monster_id]["xp"]
	game.call("add_kill_reward", 8)
	_expect(game.get("kills") == 1, "kill reward increments the kill counter")
	_expect(game.get("gold") == kill_gold_before + 8, "kill reward adds gold")
	for monster_id: String in game.call("monster_ids"):
		_expect(game.get("monsters")[monster_id]["xp"] == int(monster_xp_before[monster_id]) + 12, "each deployed monster receives kill XP: " + monster_id)

	var fox_xp: int = int(game.get("monsters")["fox"]["xp"])
	var deployment_result: Dictionary = game.call("toggle_deployment", "fox")
	_expect(bool(deployment_result.get("ok", false)) and not game.get("deployed").has("fox"), "deployment toggles one monster independently")
	game.call("add_kill_reward", 0)
	_expect(game.get("monsters")["fox"]["xp"] == fox_xp, "undeployed monster receives no kill XP")
	_expect(game.get("monsters")["aqua"]["xp"] == int(monster_xp_before["aqua"]) + 24, "other deployed monsters keep receiving XP")
	_expect(bool(game.call("toggle_deployment", "fox").get("ok", false)), "an undeployed monster can rejoin without excluding others")
	_expect(not bool(game.call("toggle_deployment", "unknown").get("ok", true)), "unknown monsters cannot enter the roster")
	var aqua_before_level_up: Dictionary = game.call("monster_info", "aqua")
	var aqua_xp_to_level: int = Catalog.xp_to_next(int(aqua_before_level_up["level"])) - int(aqua_before_level_up["xp"])
	game.call("add_monster_xp", "aqua", aqua_xp_to_level)
	var aqua_after_level_up: Dictionary = game.call("monster_info", "aqua")
	_expect(int(aqua_after_level_up["level"]) == int(aqua_before_level_up["level"]) + 1 and aqua_after_level_up["xp"] == 0, "monster XP crosses its threshold and raises only that monster level")
	_expect(float(aqua_after_level_up["base"]["attack"]) > float(aqua_before_level_up["base"]["attack"]), "monster level growth updates its own base stats")

	var hero_stats_before_move: Dictionary = game.call("hero_info")["stats"]
	var monster_stats_before_move: Dictionary = game.call("monster_info", "sprout")["stats"]
	var moved: Dictionary = game.call("equip", "sprout", "hero_ring")
	_expect(bool(moved.get("ok", false)), "a compatible item can move between owners")
	_expect(game.call("equipment_for", "hero")["accessory"] == "", "moving an equipped item clears its previous owner atomically")
	_expect(game.call("equipment_for", "sprout")["accessory"] == "hero_ring", "moved item is equipped in the destination slot")
	_expect(game.call("items_for", "sprout")[0].has("equipped_by"), "inventory items expose current equipment ownership")
	var moved_item: Dictionary = {}
	for item: Dictionary in game.call("items_for", "sprout"):
		if item["id"] == "hero_ring":
			moved_item = item
	_expect(moved_item.get("equipped_by") == "sprout", "inventory resolves an item's current owner after transfer")
	var hero_stats_after_move: Dictionary = game.call("hero_info")["stats"]
	var monster_stats_after_move: Dictionary = game.call("monster_info", "sprout")["stats"]
	_expect(not is_equal_approx(float(hero_stats_before_move["crit"]), float(hero_stats_after_move["crit"])), "moving gear updates the old owner's derived stats")
	_expect(not is_equal_approx(float(monster_stats_before_move["crit"]), float(monster_stats_after_move["crit"])), "moving gear updates the new owner's derived stats")
	var layout_before_failed_equip: Dictionary = {
		"hero": game.call("equipment_for", "hero"),
		"sprout": game.call("equipment_for", "sprout"),
	}
	var invalid_equip: Dictionary = game.call("equip", "hero", "monster_necklace")
	_expect(not bool(invalid_equip.get("ok", true)), "incompatible equipment is rejected")
	_expect(game.call("equipment_for", "hero") == layout_before_failed_equip["hero"] and game.call("equipment_for", "sprout") == layout_before_failed_equip["sprout"], "failed equip leaves both owners unchanged")
	_expect(bool(game.call("unequip", "sprout", "accessory").get("ok", false)), "equipment can be unequipped into inventory")
	_expect(game.call("equipment_for", "sprout")["accessory"] == "", "unequip clears its real slot")
	_expect(not bool(game.call("unequip", "sprout", "tail").get("ok", true)), "invalid slot cannot mutate a loadout")

	var sword_level: int = int(game.get("equipment_levels")["hero_sword"])
	var sword_cost: int = int(game.call("upgrade_cost", "hero_sword"))
	var attack_before_upgrade: float = float(game.call("hero_info")["stats"]["attack"])
	var upgrade: Dictionary = game.call("upgrade_equipment", "hero_sword")
	_expect(bool(upgrade.get("ok", false)), "equipment upgrade succeeds when funded")
	_expect(game.get("equipment_levels")["hero_sword"] == sword_level + 1, "equipment upgrade raises that item's level")
	_expect(game.get("gold") == 500 - cost + 8 - sword_cost, "equipment upgrade charges its quoted cost")
	_expect(float(game.call("hero_info")["stats"]["attack"]) > attack_before_upgrade, "upgrading equipped gear changes owner stats")
	var monster_attack_before_upgrade: float = float(game.call("monster_info", "sprout")["stats"]["attack"])
	var hero_attack_before_monster_upgrade: float = float(game.call("hero_info")["stats"]["attack"])
	var monster_item_cost: int = int(game.call("upgrade_cost", "monster_claws"))
	_expect(bool(game.call("upgrade_equipment", "monster_claws").get("ok", false)), "monster equipment can be upgraded with gold")
	_expect(game.get("gold") == 500 - cost + 8 - sword_cost - monster_item_cost, "monster equipment upgrade deducts its own cost")
	_expect(float(game.call("monster_info", "sprout")["stats"]["attack"]) > monster_attack_before_upgrade, "monster equipment upgrade changes its owner's stats")
	_expect(is_equal_approx(float(game.call("hero_info")["stats"]["attack"]), hero_attack_before_monster_upgrade), "monster equipment upgrade leaves hero stats unchanged")
	game.set("gold", 0)
	var level_before_failed_upgrade: int = int(game.get("equipment_levels")["hero_sword"])
	_expect(not bool(game.call("upgrade_equipment", "hero_sword").get("ok", true)), "unaffordable equipment upgrade fails")
	_expect(game.get("equipment_levels")["hero_sword"] == level_before_failed_upgrade and game.get("gold") == 0, "failed upgrade spends nothing and preserves item level")

	_finish("PROGRESSION V2")
