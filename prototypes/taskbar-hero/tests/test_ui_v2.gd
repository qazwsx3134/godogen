extends "res://addons/proto_kit/test_kit.gd"

const TestBootstrap = preload("res://tests/test_bootstrap.gd")
const Catalog = preload("res://domain/progression_catalog.gd")
const PAGE_IDS: Array[String] = ["overview", "train", "backpack", "monster", "equipment", "adventure", "store"]
const MONSTER_IDS: Array[String] = ["sprout", "fox", "aqua", "mushroom"]

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	TestBootstrap.add_services(root)
	var game: Node = root.get_node("Game")
	var save_manager: Node = root.get_node("SaveManager")
	save_manager.set("save_path", "/tmp/taskbar-ui-v2-%d.json" % Time.get_ticks_usec())
	game.set("gold", 5000)
	game.set("current_stage", "3-7")
	game.set("training", Catalog.default_training())
	game.set("monsters", Catalog.default_monsters())
	game.set("deployed", Catalog.default_deployed())
	game.set("loadouts", Catalog.default_loadouts())
	game.set("equipment_levels", Catalog.default_equipment_levels())
	game.call("set_combat_paused", true)
	game.emit_signal("changed")
	game.emit_signal("gold_changed", 5000)

	var ui: Control = load("res://main.tscn").instantiate() as Control
	var arena: Node2D = ui.get_node("Pages/Overview/BattleSocket/CombatArena")
	arena.set("auto_simulate", false)
	root.add_child(ui)
	await _frames(3)
	_expect(ui.get("current_page") == "overview", "overview remains the initial view")
	_expect(ui.get_node("Pages").get_child_count() == PAGE_IDS.size(), "main owns all seven authored page scenes")
	for page_id: String in PAGE_IDS:
		var page_name: String = page_id.capitalize()
		var page: Control = ui.get_node("Pages/%s" % page_name)
		var panel: Control = page.get_node("ContentPanel")
		var expected_top: float = 950.0 if page_id == "overview" else 525.0
		_expect(is_equal_approx(panel.offset_top, expected_top), "%s content panel top is fixed" % page_id)
		_expect(is_equal_approx(panel.offset_bottom, 1520.0), "%s content panel ends at 1520" % page_id)
		_expect((page.get_node("Ground") as Control).offset_top == 470.0, "%s ground starts at 470" % page_id)
		_expect((page.get_node("BattleSocket") as Node2D).position == Vector2(0, 470), "%s battle socket aligns to ground" % page_id)
		_expect((page.get_node("Navigation") as Control).offset_top == 1536.0, "%s navigation shares the bottom row" % page_id)
	_expect(arena.get_parent() == ui.get_node("Pages/Overview/BattleSocket"), "reference arena is loaded under overview socket")
	_expect(arena.call("live_units").size() == 8, "arena contains the authored hero, four monsters and three enemies")
	ui.call("_on_damage_dealt", "knight", "enemy_0", 7, 43, 50)
	_expect((ui.get_node("Pages/Overview/CombatLogScroll/CombatLog") as Label).text.contains("造成 7 傷害"), "combat log refresh resolves its label through the nested scroll container")

	var arena_id: int = arena.get_instance_id()
	var game_gold: int = int(game.get("gold"))
	ui.set("reference_preview", true)
	ui.call("_refresh_header")
	_expect(ui.get_node("Header/GoldBadge").text == "12,480", "reference preview changes only the displayed gold badge")
	_expect(int(game.get("gold")) == game_gold, "reference preview leaves saved gold untouched")
	ui.set("reference_preview", false)
	ui.call("_refresh_header")

	var nav: Node = ui.get_node("Pages/Overview/Navigation")
	await _press(nav.get_node("TrainButton") as BaseButton)
	_expect(ui.get("current_page") == "train", "training navigation opens its saved scene")
	var training_before: Array = game.get("training").duplicate()
	var cost: int = int(game.call("training_cost", 0))
	var gold_before_training: int = int(game.get("gold"))
	var train_row: Node = ui.get_node("Pages/Train/TrainingList/TrainingRow0")
	_expect(str(train_row.get_node("NextCost").text).contains(str(cost)), "training row shows the domain cost for the next level")
	await _press(train_row.get_node("TrainButton") as BaseButton)
	_expect(int(game.get("training")[0]) == int(training_before[0]) + 1, "one training click immediately buys exactly one hero level")
	_expect(int(game.get("gold")) == gold_before_training - cost, "training click pays its shown cost")
	_expect((ui.get_node("Pages/Monster/PetStatAttack") as Label).text.contains("攻擊"), "monster stats display remains independent from hero training")

	var backpack_nav: Node = ui.get_node("Pages/Train/Navigation")
	await _press(backpack_nav.get_node("BackpackButton") as BaseButton)
	var backpack_grid: GridContainer = ui.get_node("Pages/Backpack/ItemsGridScroll/ItemsGrid")
	_expect(backpack_grid.columns == 5, "backpack keeps its five-column layout inside its scroll container")
	_expect(backpack_grid.get_child_count() == Catalog.ITEMS.size(), "backpack shows each unique catalog item once")
	for card: Node in backpack_grid.get_children():
		_expect(card.has_meta("item_id"), "backpack grid contains only real item cards")
	await _press(ui.get_node("Pages/Backpack/FilterRow/FilterWeapon") as BaseButton)
	await _frames(2)
	var visible_backpack_cards: Array[Control] = []
	for card: Node in backpack_grid.get_children():
		if card.visible:
			visible_backpack_cards.append(card as Control)
	_expect(visible_backpack_cards.size() == game.call("items_for", "hero", "weapon").size(), "backpack filter leaves only matching weapon cards")
	_expect(visible_backpack_cards.size() == 3, "hidden items compact the grid without spacer cards")
	if visible_backpack_cards.size() == 3:
		_expect(visible_backpack_cards[0].position.y == visible_backpack_cards[1].position.y and visible_backpack_cards[1].position.y == visible_backpack_cards[2].position.y, "filtered backpack cards occupy one compact row")

	await _press(ui.get_node("Pages/Backpack/Navigation/MonsterButton") as BaseButton)
	var deployed_before: Array = game.get("deployed").duplicate()
	for i: int in MONSTER_IDS.size():
		var expected_name: String = str(game.call("monster_info", MONSTER_IDS[i]).get("name", MONSTER_IDS[i]))
		_expect(ui.get_node("Pages/Monster/MonsterGrid/MonsterCard%d/Title" % i).text == expected_name, "collection card uses catalog name for %s" % MONSTER_IDS[i])
	await _press(ui.get_node("Pages/Monster/MonsterGrid/MonsterCard1/InspectButton") as BaseButton)
	_expect(ui.get_node("Pages/Monster/PetName").text == game.call("monster_info", "fox").get("name"), "monster inspection uses the Game catalog name")
	_expect(game.get("deployed") == deployed_before, "inspecting a monster does not change deployment")
	await _press(ui.get_node("Pages/Monster/MonsterGrid/MonsterCard2/DeploymentButton") as BaseButton)
	_expect(not game.get("deployed").has("aqua"), "deployment button toggles only its monster")
	_expect(game.get("deployed").has("sprout") and game.get("deployed").has("fox"), "other monster deployment states remain independent")

	await _press(ui.get_node("Pages/Monster/Navigation/EquipmentButton") as BaseButton)
	var equipment_grid: GridContainer = ui.get_node("Pages/Equipment/EquipmentItemsGridScroll/EquipmentItemsGrid")
	_expect(equipment_grid.columns == 7, "equipment bag matches the reference seven-column grid")
	_expect(ui.get_node("Pages/Equipment/HeroSlotGrid").get_child_count() == 6, "hero equipment block exposes six slots")
	_expect(ui.get_node("Pages/Equipment/MonsterSlotGrid").get_child_count() == 6, "monster equipment block exposes six slots")
	for slot_index: int in 6:
		for grid_path: String in ["HeroSlotGrid", "MonsterSlotGrid"]:
			var slot: Button = ui.get_node("Pages/Equipment/%s/%s%d" % [grid_path, "HeroSlot" if grid_path == "HeroSlotGrid" else "MonsterSlot", slot_index]) as Button
			_expect(slot.text.is_empty(), "%s %d keeps its Button text empty" % [grid_path, slot_index])
			_expect(slot.has_node("Icon") and slot.has_node("SlotLabel") and slot.has_node("LevelLabel"), "%s %d exposes editable slot art and labels" % [grid_path, slot_index])
			_expect((slot.get_node("Icon") as TextureRect).texture != null, "%s %d displays an atlas item icon" % [grid_path, slot_index])
	_expect((ui.get_node("Pages/Equipment/HeroEquipmentPanel") as Control).offset_top == 622.0 and (ui.get_node("Pages/Equipment/HeroEquipmentPanel") as Control).offset_bottom == 940.0, "hero equipment section matches the reference vertical bounds")
	_expect((ui.get_node("Pages/Equipment/MonsterEquipmentPanel") as Control).offset_top == 950.0 and (ui.get_node("Pages/Equipment/MonsterEquipmentPanel") as Control).offset_bottom == 1240.0, "monster equipment section matches the reference vertical bounds")
	_expect((ui.get_node("Pages/Equipment/EquipmentInventoryPanel") as Control).offset_top == 1250.0 and (ui.get_node("Pages/Equipment/EquipmentInventoryPanel") as Control).offset_bottom == 1520.0, "equipment bag matches the reference vertical bounds")
	for i: int in MONSTER_IDS.size():
		var expected_name: String = str(game.call("monster_info", MONSTER_IDS[i]).get("name", MONSTER_IDS[i]))
		_expect(ui.get_node("Pages/Equipment/EquipmentMonster%d" % i).text == expected_name, "equipment selector uses catalog name for %s" % MONSTER_IDS[i])
	await _press(ui.get_node("Pages/Equipment/EquipmentMonster1") as BaseButton)
	await _press(ui.get_node("Pages/Equipment/UseMonsterButton") as BaseButton)
	_expect(ui.get("equipment_owner") == "fox", "equipment owner follows the independently inspected monster")
	_expect(equipment_grid.get_child_count() == game.call("items_for", "fox", "all").size(), "monster equipment grid shows compatible items")
	var compact_card: Control = equipment_grid.get_child(0) as Control
	_expect(compact_card.get_node("Icon").position.y < compact_card.get_node("Level").position.y, "compact equipment cards put the item icon above its level")
	_expect(not compact_card.get_node("Title").visible and not compact_card.get_node("EquippedBy").visible, "compact equipment cards hide title and kind side text")
	if equipment_grid.get_child_count() == 8:
		var equipment_cards: Array[Control] = []
		for child: Node in equipment_grid.get_children():
			equipment_cards.append(child as Control)
		var first_row_y: float = equipment_cards[0].position.y
		var second_row_y: float = equipment_cards[7].position.y
		_expect(equipment_cards[0].custom_minimum_size == Vector2(118, 70), "equipment bag uses compact reference cards")
		_expect(equipment_cards[6].position.y == first_row_y and second_row_y > first_row_y and equipment_cards[7].position.x == equipment_cards[0].position.x, "seven-column equipment bag wraps cleanly into its second row")

	for kind: String in ["all", "weapon", "armor", "accessory", "other"]:
		await _press(ui.get_node("Pages/Equipment/EquipmentFilterRow/EquipmentFilter%s" % kind.capitalize()) as BaseButton)
		_expect(equipment_grid.get_child_count() == game.call("items_for", "fox", kind).size(), "equipment filter %s matches the Game catalog" % kind)

	await _press(ui.get_node("Pages/Equipment/UseHeroButton") as BaseButton)
	await _press(ui.get_node("Pages/Equipment/EquipmentFilterRow/EquipmentFilterWeapon") as BaseButton)
	var hero_bow: Control = _find_item_card(equipment_grid, "hero_bow")
	_expect(hero_bow != null, "hero equipment card exists in nested equipment grid")
	if hero_bow != null:
		await _press(hero_bow.get_node("SelectButton") as BaseButton)
	_expect(game.call("equipment_for", "hero").get("weapon") == "hero_bow", "management click equips selected compatible item")
	await _press(ui.get_node("Pages/Equipment/HeroSlotGrid/HeroSlot0") as BaseButton)
	_expect(ui.get_node("Pages/Equipment/UnequipButton").visible, "selected equipped slot reveals the unequip action")
	await _press(ui.get_node("Pages/Equipment/UnequipButton") as BaseButton)
	_expect(str(game.call("equipment_for", "hero").get("weapon", "")).is_empty(), "unequip action clears the selected real slot")
	await _press(ui.get_node("Pages/Equipment/UpgradeTab") as BaseButton)
	hero_bow = _find_item_card(equipment_grid, "hero_bow")
	if hero_bow != null:
		await _press(hero_bow.get_node("SelectButton") as BaseButton)
	var upgrade_cost: int = int(game.call("upgrade_cost", "hero_bow"))
	var level_before_upgrade: int = int(game.get("equipment_levels").get("hero_bow", 0))
	var gold_before_upgrade: int = int(game.get("gold"))
	_expect(ui.get_node("Pages/Equipment/SelectedItemCost").text.contains(str(upgrade_cost)), "upgrade tab displays the domain quote")
	await _press(ui.get_node("Pages/Equipment/UpgradeButton") as BaseButton)
	_expect(int(game.get("equipment_levels").get("hero_bow", 0)) == level_before_upgrade + 1, "upgrade click raises only the selected item's level")
	_expect(int(game.get("gold")) == gold_before_upgrade - upgrade_cost, "upgrade click pays the displayed cost")

	game.set("current_stage", "3-7")
	game.emit_signal("changed")
	await _frames(3)
	await _press(ui.get_node("Pages/Equipment/Navigation/AdventureButton") as BaseButton)
	_expect(ui.get_node("Pages/Adventure/DepartButton").text.contains("3-7"), "adventure continues from Game.current_stage")
	_expect(ui.get_node("Pages/Adventure/StageGrid/StageCard0/Title").text == "3-7", "current route card reflects the advancing stage")
	_expect(ui.get_node("Pages/Adventure/ChapterButton").text.contains("第 3 章"), "chapter selector follows the current stage")
	var arena_x: float = arena.position.x
	await _press(ui.get_node("Pages/Adventure/DepartButton") as BaseButton)
	_expect(str(game.get("current_stage")) == "3-7", "depart resumes without resetting the current stage")
	_expect(ui.get("current_page") == "overview", "depart returns to the persistent battle view")
	_expect(arena.get_instance_id() == arena_id and is_equal_approx(arena.position.x, arena_x), "page changes preserve the same marching arena and its camera offset")

	var saved_gold_before_shop: int = int(game.get("gold"))
	await _press(ui.get_node("Pages/Overview/Navigation/StoreButton") as BaseButton)
	await _press(ui.get_node("Pages/Store/ProductGrid/ProductCard0/BuyButton") as BaseButton)
	_expect(int(game.get("gold")) == saved_gold_before_shop, "shop demo button does not mutate player currency")
	await _press(ui.get_node("Header/SettingsButton") as BaseButton)
	_expect(ui.get_node("SettingsPanel").visible, "settings button opens the saved settings panel")
	var was_paused: bool = bool(game.get("combat_paused"))
	await _press(ui.get_node("SettingsPanel/PauseButton") as BaseButton)
	_expect(bool(game.get("combat_paused")) != was_paused, "settings pause button calls the real combat pause API")
	await _press(ui.get_node("SettingsPanel/SaveButton") as BaseButton)
	_expect(FileAccess.file_exists(str(save_manager.get("save_path"))), "settings save button writes through SaveManager")
	await _press(ui.get_node("SettingsPanel/CloseButton") as BaseButton)
	_expect(not ui.get_node("SettingsPanel").visible, "settings panel closes from its authored button")

	game.call("set_combat_paused", true)
	ui.queue_free()
	await _frames(3)
	_finish("REFERENCE UI V2 INPUT AND LAYOUT")

func _find_item_card(grid: GridContainer, item_id: String) -> Control:
	for card: Node in grid.get_children():
		if str(card.get_meta("item_id", "")) == item_id:
			return card as Control
	return null
