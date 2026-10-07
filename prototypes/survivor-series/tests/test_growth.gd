extends "res://addons/proto_kit/test_kit.gd"
## Run build rules, level-up flow, death/finish precedence and the meta save.
const Build = preload("res://scripts/run_build.gd")
const META_PATH = "user://test_growth_meta.json"
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var config: Resource = load("res://data/progression.tres")
	var b = Build.new(config)
	_expect(b.weapons == [&"punch"] and b.count(&"punch") == 1, "every run starts with the punch")
	b.award(16)
	_expect(b.level == 3 and is_equal_approx(b.experience, 0.0) and b.pending_choices == 2, "XP overflow carries into the next level and queues both picks")
	var offers: Array[Resource] = b.offers()
	var distinct: Dictionary = {}
	for item: Resource in offers:
		distinct[item.id] = true
		_expect(item.slot == "weapon" and b.count(item.id) == 0 and item.unlock == &"", "first offer is an unlocked new weapon: " + String(item.id))
	_expect(offers.size() == 3 and distinct.size() == 3, "first level-up offers three distinct new weapons")
	_expect(not b.pick(&"lantern") and not b.pick(&"cane"), "locked weapons cannot be picked")
	_expect(b.pick(&"slipper") and b.count(&"slipper") == 1 and b.weapons.has(&"slipper"), "picking a weapon fills a weapon slot")
	_expect(not b.pick(&"unknown"), "unknown card is rejected")
	var unlocked = Build.new(config, {}, ["survive_5", "kills_300"])
	unlocked.pending_choices = 2
	_expect(unlocked.pick(&"lantern") and unlocked.pick(&"cane"), "achievement unlocks make locked weapons pickable")

	var full = Build.new(config, {}, ["survive_5", "kills_300", "total_2000"])
	full.pending_choices = 100
	for id: StringName in [&"wave", &"kick", &"slipper", &"pearl", &"firecracker"]:
		full.pick(id)
	_expect(full.weapons.size() == 6 and not full.eligible(full.definition(&"incense")), "weapon slots stop at six")
	for id: StringName in [&"sacha", &"chicken", &"energy", &"points", &"amulet", &"megaphone"]:
		full.pick(id)
	_expect(full.passives.size() == 6 and not full.eligible(full.definition(&"massage")), "passive slots stop at six")
	_expect(full.eligible(full.definition(&"energy")), "owned passive can still level up")

	var evo = Build.new(config)
	evo.pending_choices = 100
	evo.pick(&"slipper")
	_expect(not evo.eligible(evo.definition(&"homing_slipper")), "evolution needs the weapon at max level")
	for i: int in 4:
		evo.pick(&"slipper")
	_expect(evo.count(&"slipper") == 5 and not evo.eligible(evo.definition(&"homing_slipper")), "evolution needs its passive too")
	evo.pick(&"massage")
	_expect(evo.eligible(evo.definition(&"homing_slipper")), "maxed weapon plus passive makes the evolution eligible")
	_expect(evo.offers()[0].id == &"homing_slipper", "an eligible evolution is always offered first")
	var slot: int = evo.weapons.find(&"slipper")
	_expect(evo.pick(&"homing_slipper") and evo.weapons[slot] == &"homing_slipper" and evo.count(&"slipper") == 0, "evolution replaces its base weapon in the same slot")
	_expect(not evo.eligible(evo.definition(&"slipper")) and not evo.eligible(evo.definition(&"homing_slipper")), "neither base nor evolution can be picked again")
	_expect(evo.weapon_stats(&"homing_slipper").variant == &"homing", "evolved weapon carries its variant")

	var stats = Build.new(config, {&"might": 0.5})
	stats.pending_choices = 10
	var base: Dictionary = stats.weapon_stats(&"punch")
	_expect(is_equal_approx(base.damage, 28.0 * 1.5), "shop might multiplies weapon damage")
	for i: int in 2:
		stats.pick(&"punch")
	_expect(stats.weapon_stats(&"punch").amount == 2 and stats.weapon_stats(&"punch").damage > base.damage, "punch level 3 hits one more target and harder")
	stats.pick(&"energy")
	_expect(stats.weapon_stats(&"punch").cooldown < base.cooldown, "cooldown passive shortens weapon cooldowns")
	var grow = Build.new(config, {&"growth": 1.0})
	grow.award(5)
	_expect(grow.level == 2 and is_equal_approx(grow.total_experience, 10.0), "growth bonus scales gained XP")

	var maxed = Build.new(config, {}, ["survive_5", "kills_300", "total_2000"])
	maxed.pending_choices = 1000
	for round: int in 200:
		var options: Array[Resource] = maxed.offers()
		if options[0].slot == "filler":
			break
		maxed.pick(options[0].id)
	var leftover: Array[Resource] = maxed.offers()
	_expect(leftover.size() == 2 and leftover[0].slot == "filler", "a maxed build is offered rice and change instead of nothing")
	_expect(maxed.pick(&"rice"), "filler card can be picked")

	var fresh = Build.new(config)
	fresh.rng.seed = 17
	fresh.pending_choices = 30
	fresh.pick(&"wave")
	for i: int in 25:
		var seen: Dictionary = {}
		var options: Array[Resource] = fresh.offers()
		for item: Resource in options:
			_expect(not seen.has(item.id) and fresh.eligible(item), "random offers are distinct and legal")
			seen[item.id] = true
		fresh.pick(options[0].id)
	_expect(Build.new(config).summary() == "拳頭 1", "a new run does not inherit mutable build state")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(META_PATH))
	var game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	game.get_node("Services/Meta").save_path = META_PATH
	root.add_child(game)
	game.set_physics_process(false)
	await _frames(2)
	game.get_node("%TimeControl").hit_stop_scale = 1.0
	game.start_run()
	var street = game.street
	street.spawn_left = 1000.0
	street.phase_index = 0
	street.build.award(5)
	game._physics_process(0.01)
	_expect(game.state == game.State.UPGRADE and paused and game.upgrade_panel.options.get_child_count() == 3, "level-up opens three scene cards and freezes the world")
	_expect(game.upgrade_panel.options.get_child(0).tag_label.text == "新武器", "card tag names a new weapon")
	var time_before: float = game.elapsed
	game._physics_process(10)
	_expect(game.elapsed == time_before and game.stick.vector == Vector2.ZERO, "selection freezes time and releases held input")
	_expect(not game.choose_upgrade(&"not_offered"), "cannot pick an unoffered card")
	var first_id: StringName = game.current_offers[0].id
	game.upgrade_panel.options.get_child(0).pressed.emit()
	_expect(game.state == game.State.RUNNING and not paused and street.build.count(first_id) == 1, "real card signal picks the weapon and resumes")
	street.build.award(200)
	game._physics_process(0.01)
	var old_generation: int = game.upgrade_generation
	var old_card = game.upgrade_panel.options.get_child(0)
	old_card.pressed.emit()
	var pending_before: int = street.build.pending_choices
	_expect(game.state == game.State.UPGRADE and game.upgrade_generation > old_generation, "multi-level XP opens the next pending selection")
	old_card.pressed.emit()
	_expect(street.build.pending_choices == pending_before, "stale card event cannot spend another queued choice")
	_expect(not game.choose_upgrade(game.current_offers[0].id, old_generation), "stale selection generation is rejected")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(game.state == game.State.UPGRADE and paused, "focus loss cannot bypass upgrade selection")
	while game.state == game.State.UPGRADE:
		game.choose_upgrade(game.current_offers[0].id)
	var limit_before: float = street.player.hp_limit
	if not street.build.passives.has(&"chicken"):
		street.build.passives.append(&"chicken")
	street.build.levels[&"chicken"] = street.build.count(&"chicken") + 1
	street.refresh_player_stats()
	_expect(street.player.hp_limit > limit_before and street.player.hp > 0.0, "an HP passive raises the hero's cap during the run")

	street.build.pending_choices = 1
	var chest = street.drop("chest", street.player.position, 1.0)
	var before_chest: int = street.build.pending_choices
	street._collect(chest)
	_expect(street.build.pending_choices - before_chest in [1, 3, 5] and street.chests == 1, "a chest grants one, three or five picks")
	street.player.hp = 0.0
	game._physics_process(0.01)
	_expect(game.state == game.State.RESULTS and not game.won and not game.upgrade_panel.visible, "death wins over queued level-ups")
	_expect(game.results.get_node("%Title").text == "倒下了…" and game.sound_events.has(&"death"), "death shows the defeat result")
	_expect(street.projectiles.get_child_count() == 0 and street.pickups.get_child_count() == 0, "results reclaim projectiles and drops")
	var banked: int = game.meta.coins
	_expect(banked == game.earned and int(game.meta.records.runs) == 1, "run coins are banked in the meta save")

	game.start_run()
	_expect(street.build.level == 1 and street.build.weapons == [&"punch"] and street.best_combo == 0 and street.kills == 0 and street.player.hp == street.player.hp_limit, "retry resets level, weapons, combo and HP")
	street.spawn_left = 1000.0
	game.elapsed = game.session_duration - 0.01
	street.build.award(500)
	game._physics_process(0.2)
	_expect(game.state == game.State.RESULTS and game.won and game.results.get_node("%Title").text == "撐過十分鐘！", "surviving the clock wins over queued level-ups")

	var meta = game.meta
	var goal_ids: Array = game.fresh_unlocks.map(func(goal: Resource) -> StringName: return goal.id)
	_expect(goal_ids.has(&"survive_5") and meta.is_unlocked(&"survive_5") and game.results.get_node("%Unlocks").text.contains("天燈"), "a ten-minute run unlocks the lantern and says so")
	_expect(meta.record_run(320.0, 10, 5, false, 0).is_empty(), "an achievement unlocks only once")
	meta.coins = 1000
	var price: int = meta.price(&"might")
	_expect(meta.buy(&"might") and meta.coins == 1000 - price and meta.level_of(&"might") == 1, "buying a shop item spends coins and raises its level")
	_expect(is_equal_approx(meta.bonuses()[&"might"], 0.05), "shop levels become run bonuses")
	_expect(meta.price(&"revival") == 800 and meta.buy(&"revival") and meta.price(&"revival") == -1, "a single-level item has no price once bought")
	var copy := Node.new()
	copy.set_script(load("res://scripts/meta.gd"))
	copy.catalogue = meta.catalogue
	copy.save_path = META_PATH
	copy.load_save()
	_expect(copy.coins == meta.coins and copy.level_of(&"might") == 1 and copy.is_unlocked(&"survive_5") and int(copy.records.runs) == int(meta.records.runs), "meta save round-trips through the file")
	var file := FileAccess.open(META_PATH, FileAccess.WRITE)
	file.store_string("{not json")
	file.close()
	copy.load_save()
	_expect(copy.coins == 0 and copy.unlocked.is_empty(), "a corrupt save falls back to defaults")
	copy.free()
	game.start_run()
	_expect(is_equal_approx(street.build.stat(&"might"), 0.05) and street.build.unlocked.has(&"survive_5"), "the next run receives shop bonuses and unlocks")
	street.spawn_left = 1000.0
	street.player.hp = 0.0
	game._physics_process(0.01)
	_expect(game.state == game.State.RUNNING and is_equal_approx(street.player.hp, street.player.hp_limit * 0.5) and game.revivals == 0, "a bought revival brings the hero back once at half HP")

	game.show_menu()
	game.menu.get_node("%OpenShop").pressed.emit()
	_expect(game.state == game.State.SHOP and game.shop.visible and game.shop.items.get_child_count() == meta.catalogue.shop.size(), "shop lists every permanent upgrade")
	meta.coins = 0
	game.shop.refresh()
	_expect(game.shop.items.get_child(0).disabled, "unaffordable upgrades are disabled")
	game.shop.get_node("%Back").pressed.emit()
	_expect(game.state == game.State.MENU and game.menu.visible, "leaving the shop returns to the menu")
	var player_scene = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	_expect(player_scene.get_node("Motion/Visual").position == Vector2.ZERO, "animation never changes authored player transform")
	player_scene.free()
	game.queue_free()
	await _frames(2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(META_PATH))
	OS.delay_msec(120)
	await _frames(2)
	print("checks: ", checks)
	_finish("STREET GROWTH")
