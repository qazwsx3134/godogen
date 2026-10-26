extends "res://addons/proto_kit/test_kit.gd"
const Model = preload("res://domain/game_model.gd")
const Catalog = preload("res://domain/catalog.gd")
const Driver = preload("res://scripts/simulation_driver.gd")
const Repository = preload("res://domain/save_repository.gd")
const AtomicFile = preload("res://addons/proto_kit/atomic_file.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_catalog_and_initial_profile()
	_test_training_deployment_and_talents()
	_test_recruit_and_equipment()
	_test_rewards_and_clear_receipts()
	_test_healing_and_reaction()
	_test_capacity_and_waiting_items()
	_test_defeat_and_restart()
	_test_frame_rate_independence()
	_test_save_and_recovery()
	_test_json_roundtrip_preserves_completed_stage_receipts()
	_test_long_run_is_bounded()
	print("checks: ", checks)
	_finish("DREAMLING DOMAIN")


func _test_catalog_and_initial_profile() -> void:
	var catalog := Catalog.new()
	_expect(catalog.errors.is_empty() and catalog.units.size() == 6 and catalog.stages.size() == 6, "valid six-unit/six-stage catalog")
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
	raw.units.append(raw.units[0].duplicate(true))
	_expect(not Catalog.new(raw).errors.is_empty(), "duplicate definition ID is rejected")
	var game := Model.new(7)
	_expect(game.state.roster.size() == 3 and game.state.deployed.size() == 2 and game.actors.size() == 5, "authored starting scope has three owned and two fighting")
	_expect(Repository.new("user://unused.json").valid(game.snapshot()), "fresh profile is valid and serializable")


func _test_training_deployment_and_talents() -> void:
	var game := Model.new(7)
	game.state.gold = 0
	var before: Dictionary = game.snapshot()
	_expect(not game.train("moss").ok and game.snapshot() == before, "insufficient training funds do not mutate anything")
	game.state.gold = 1000
	var old_gold: int = int(game.state.gold)
	var old_attack: float = float(game.stats("moss").attack)
	_expect(game.train("moss").ok and int(game.state.roster.moss.level) == 2 and game.state.gold < old_gold, "paid training grants exactly a level and spends money")
	_expect(game.stats("moss").attack > old_attack and game.build_pending, "growth updates preview and queues encounter build")
	_expect(not game.deploy("dew").ok, "cannot exceed two unlocked slots")
	_expect(not game.buy_talent("company").ok, "company requires courage even when funds are sufficient")
	_expect(game.buy_talent("might").ok and game.buy_talent("company").ok, "kit tree costs and explicit prerequisite integrate")
	_expect(game.slots() == 3 and game.deploy("dew").ok, "purchased third slot permits healer")
	_expect(game.bonds().grove, "two distinct grove members activate HP bond")
	var after_company: int = int(game.state.gold)
	_expect(not game.buy_talent("company").ok and game.state.gold == after_company, "maxed purchase never spends twice")
	game.deploy("moss")
	game.deploy("ember")
	_expect(not game.deploy("dew").ok, "last member cannot be removed")
	game._grant_xp("dew", 2000)
	_expect(int(game.state.roster.dew.level) > 2 and int(game.state.roster.dew.xp) < game.xp_needed(int(game.state.roster.dew.level)), "large XP grants cross multiple thresholds and preserve remainder")


func _test_recruit_and_equipment() -> void:
	var game := Model.new(8)
	game.state.gold = 2000
	_expect(not game.recruit("moon").ok, "recruit locked before first clear")
	game.state.best_stage = 0
	game.state.cleared = [0]
	_expect(game.recruit("moon").ok and game.state.roster.has("moon"), "eligible recruit creates owned state and loadout")
	var gold: int = int(game.state.gold)
	_expect(not game.recruit("moon").ok and game.state.gold == gold, "recruit duplicate does not spend again")
	var blade: String = str(game.state.equipped.ember.weapon)
	_expect(game.equip("moss", blade).ok and str(game.state.equipped.ember.weapon).is_empty(), "equipment transfer has exactly one holder")
	_expect(game.holder(blade) == "moss", "new equipment owner is visible")
	_expect(not game.sell(blade).ok, "equipped item protected from selling")
	var spare: Dictionary = game.state.items[2]
	game.lock_item(spare.uid)
	_expect(not game.sell(spare.uid).ok, "locked spare protected from selling")
	game.lock_item(spare.uid)
	_expect(game.sell(spare.uid).ok and game.item(spare.uid).is_empty(), "unlocked spare sells and leaves no ghost item")
	_expect(not game.equip("not_owned", blade).ok, "invalid owner safely rejected")
	_expect(Repository.new().valid(game.snapshot()), "post-command profile obeys ownership invariants")


func _test_rewards_and_clear_receipts() -> void:
	var game := Model.new(9)
	var source: Dictionary = game.actors[0]
	var target: Dictionary = game.actors[2]
	var kills: int = int(game.state.kills)
	game._damage(source, target, 99999.0, "attack")
	var gold: int = int(game.state.gold)
	game._damage(source, target, 99999.0, "attack")
	_expect(int(game.state.kills) == kills + 1 and int(game.state.gold) == gold, "dead target reward resolves only once")
	game.wave = 2
	game.state.auto_advance = false
	game._wave_cleared()
	var clear_gold: int = int(game.state.gold)
	var item_count: int = game.state.items.size()
	game.wave = 2
	game._wave_cleared()
	_expect(game.state.cleared == [0] and int(game.state.best_stage) == 0, "first completion unlocks exactly next stage")
	_expect(game.state.gold == clear_gold and game.state.items.size() == item_count, "re-farming does not repeat first-clear bonus")
	_expect(not game.select_stage(3).ok and game.select_stage(1).ok, "locked stage rejected; immediate next stage accepted")


func _test_healing_and_reaction() -> void:
	var game := Model.new(10)
	game.state.deployed = ["moss", "dew"]
	game._start_encounter(false)
	game.drain_events()
	var tank: Dictionary = game._actor("moss")
	var healer: Dictionary = game._actor("dew")
	tank.hp = tank.max_hp * 0.35
	healer.hp = healer.max_hp * 0.65
	healer.heal_left = 0.0
	var before: float = tank.hp
	game.step()
	var heals: Array = game.drain_events().filter(func(e: Dictionary) -> bool: return e.kind == "heal")
	_expect(heals.size() == 1 and heals[0].target == "moss" and tank.hp > before, "autocure chooses lowest HP ratio rather than lowest absolute HP")
	_expect(float(game.session_heal.get("dew", 0.0)) > 0 and int(game.session_damage.get("dew", 0)) > 0, "effective healing produces bounded reaction damage and separate accounting")
	tank.hp = tank.max_hp - 1
	game.drain_events()
	game._heal(healer, tank)
	var reaction: Array = game.drain_events().filter(func(e: Dictionary) -> bool: return e.kind == "reaction")
	_expect(is_equal_approx(tank.hp, tank.max_hp) and reaction.size() == 1, "overheal caps HP and generates only one reaction")
	game._heal(healer, tank)
	_expect(game.drain_events().is_empty(), "zero effective healing does not react")


func _test_capacity_and_waiting_items() -> void:
	var game := Model.new(11)
	game.catalog.bag_capacity = 1
	game.catalog.pending_capacity = 2
	var armor: String = str(game.state.equipped.moss.armor)
	_expect(not game.unequip("moss", "armor").ok and game.holder(armor) == "moss", "full bag rejects unequip without losing item")
	game.grant_loot()
	game.grant_loot()
	game.grant_loot()
	_expect(game.state.pending.size() == 2 and game.state.blocked_drops == 1, "waiting box is bounded; full capacity explicitly stops new item production")
	_expect(not game.claim_pending().ok, "full bag rejects pending claim")
	var spare: Dictionary = game.state.items[2]
	game.sell(spare.uid)
	_expect(game.claim_pending().ok and game.state.pending.size() == 1 and game.bag_count() == 1, "freeing space permits exactly one pending claim")
	var ids: Dictionary = {}
	for entry: Dictionary in game.state.items + game.state.pending: ids[entry.uid] = true
	_expect(ids.size() == game.state.items.size() + game.state.pending.size(), "pending moves conserve item UID uniqueness")


func _test_defeat_and_restart() -> void:
	var game := Model.new(12)
	for actor: Dictionary in game.actors:
		if actor.friendly: actor.hp = 0
	game.step()
	_expect(game.phase == "recover" and game.state.defeats == 1 and not game.state.auto_advance, "party wipe transitions into safe recovery and disables pushing")
	for i: int in 65: game.step()
	_expect(game.phase == "combat" and not game._living(true).is_empty(), "recovery returns to a playable encounter")
	game.paused = true
	var tick: int = game.tick_number
	game.step()
	_expect(game.tick_number == tick, "manual pause freezes game time")


func _test_frame_rate_independence() -> void:
	var expected: Dictionary = {}
	for fps: int in [15, 30, 60, 120]:
		var game := Model.new(13)
		var driver := Driver.new()
		driver.model = game
		for i: int in fps * 60: driver.advance(1.0 / fps)
		_expect(game.tick_number == 1200, "%d render FPS advances exactly sixty simulation seconds" % fps)
		if expected.is_empty(): expected = game.snapshot()
		else: _expect(game.snapshot() == expected, "render FPS %d has identical rewards, growth, RNG and progression" % fps)
		driver.free()
	var catchup := Driver.new()
	catchup.model = Model.new(14)
	catchup.max_steps_per_frame = 2
	catchup.advance(1.0)
	for i: int in 9: catchup.advance(0.0)
	_expect(catchup.model.tick_number == 20, "bounded work carries all elapsed simulation time instead of discarding it")
	catchup.free()


func _test_save_and_recovery() -> void:
	var file: String = "user://tests/profile.json"
	var repository := Repository.new(file)
	var game := Model.new(15)
	_expect(repository.save(game.snapshot()) == OK, "first valid snapshot saves")
	game.state.gold += 77
	_expect(repository.save(game.snapshot()) == OK, "second snapshot creates valid backup")
	var restored: Dictionary = repository.restore()
	_expect(restored.source == "main" and int(restored.state.gold) == int(game.state.gold), "primary save round trip")
	AtomicFile.write_text(file, "{interrupted")
	restored = repository.restore()
	_expect(restored.source == "backup" and not repository.read_only and int(restored.state.gold) == 100, "broken primary restores last known valid backup")
	_expect(repository.save(game.snapshot()) == OK, "backup recovery can repair main without replacing good backup with corrupt bytes")
	var invalid: Dictionary = game.snapshot()
	invalid.items.append(invalid.items[0].duplicate(true))
	_expect(not repository.valid(invalid) and repository.save(invalid) == ERR_INVALID_DATA, "duplicate item UID cannot be committed")
	invalid = game.snapshot()
	invalid.equipped.moss.weapon = invalid.equipped.ember.weapon
	_expect(not repository.valid(invalid), "two holders of same item rejected on load")
	invalid = game.snapshot()
	invalid.gold = -1
	_expect(not repository.valid(invalid), "negative wallet rejected")
	AtomicFile.write_text(file, JSON.stringify({"version": 99, "state": game.snapshot()}))
	var bytes: PackedByteArray = AtomicFile.read_bytes(file)
	_expect(repository.restore().source == "newer" and repository.read_only, "newer schema is read-only rather than silently rolled back")
	_expect(repository.save(game.snapshot()) == ERR_UNAUTHORIZED and AtomicFile.read_bytes(file) == bytes, "read-only play cannot overwrite future save")
	AtomicFile.write_text(file, "bad")
	AtomicFile.write_text(file + ".bak", "bad too")
	_expect(repository.restore().source == "corrupt" and repository.read_only, "double-corrupt files remain protected")


func _test_long_run_is_bounded() -> void:
	var game := Model.new(16)
	for i: int in 12000: game.step()
	_expect(game.state.kills > 0 and game.state.cleared.size() > 0, "ten-minute unassisted simulation produces real kills and progression")
	_expect(game.actors.size() <= 6 and game.events.size() <= 256 and game.state.journal.size() <= 80, "actor/event/journal storage remains bounded")
	_expect(game.state.pending.size() <= game.catalog.pending_capacity and game.bag_count() <= game.catalog.bag_capacity, "long-run loot respects both capacities")
	_expect(Repository.new().valid(game.snapshot()), "long-run result remains a valid save")
	print("SIMULATION: kills=", game.state.kills, " cleared=", game.state.cleared, " gold=", game.state.gold)


func _test_json_roundtrip_preserves_completed_stage_receipts() -> void:
	var game := Model.new(17)
	game.state.auto_advance = false
	game.wave = 2
	game._wave_cleared()
	var repository := Repository.new("user://tests/cleared_roundtrip.json")
	_expect(repository.save(game.snapshot()) == OK, "cleared-stage snapshot commits")
	var restored: Dictionary = repository.restore()
	_expect(restored.source == "main" and not restored.state.is_empty(), "JSON roundtrip recognizes completed-stage receipt despite numeric JSON types")
	if restored.state.is_empty(): return
	var resumed := Model.new(17, restored.state)
	var before: int = int(resumed.state.gold)
	resumed.wave = 2
	resumed._wave_cleared()
	_expect(int(resumed.state.gold) == before and resumed.state.cleared.size() == 1, "re-farming after reload cannot duplicate first-clear reward")
