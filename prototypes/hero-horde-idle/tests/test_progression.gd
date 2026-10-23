extends "res://addons/proto_kit/test_kit.gd"
## The v2 growth loop (domain/progression.gd) on 1-1 (domain/stages.gd, eased for new players). One round = one push
## by a bot, its rewards, one 行軍 1 小時, then 一鍵養成 (auto_spend: the same spending for every bot). Over 3 seeds:
##   1  the first push is lost without playing
##   2  idle (never touches the push) wins on growth alone in 3-6 rounds
##   3  good wins 2-4 rounds sooner than idle
##   4  a person-style player (human) wins within the first two pushes (the author lost 1-1 again and again at the
##      old difficulty, never getting the boss under 80%)
## plus captains (at most three), and a save round trip.
##   godot --headless --path prototypes/hero-horde-idle --script res://tests/test_progression.gd

const PushSim = preload("res://domain/push_sim.gd")
const PushBots = preload("res://tests/push_bots.gd")
const Progression = preload("res://domain/progression.gd")
const Items = preload("res://domain/items.gd")
const Stages = preload("res://domain/stages.gd")
const SEEDS := [1, 2, 3]
const MAX_ROUNDS := 16
const SAVE_TEST := "user://progress_test.json"


func _init() -> void:
	for seed_value: int in SEEDS:
		var idle: Dictionary = _rounds(seed_value, PushBots.IDLE)
		var good: Dictionary = _rounds(seed_value, PushBots.GOOD)
		var human: Dictionary = _rounds(seed_value, PushBots.HUMAN)
		print("seed %d  idle %s\n        good %s\n       human %s" % [seed_value, idle.log, good.log, human.log])
		_expect(idle.first_lost, "seed %d: the first push is lost without playing" % seed_value)
		_expect(idle.round >= 3 and idle.round <= 6, "seed %d: idle wins on growth in 3-6 rounds (round %d)" % [seed_value, idle.round])
		var ahead: int = idle.round - good.round
		_expect(good.round > 0 and ahead >= 2 and ahead <= 4,
			"seed %d: good wins 2-4 rounds sooner (good %d, idle %d)" % [seed_value, good.round, idle.round])
		_expect(human.round > 0 and human.round >= good.round and human.round <= 2,
			"seed %d: human wins within two pushes, not before good (%d)" % [seed_value, human.round])

	var p := Progression.new(5)
	for k: int in 3:
		p.march_hour()
		p.gold += 5000
		p.shards += 4
		p.auto_spend()
	# Captains: up to three, toggled on and off, saved with the rest.
	for i: int in [4, 30, 60]:
		_expect(p.toggle_captain(i), "hero %d becomes a captain" % i)
	_expect(not p.toggle_captain(90) and not p.is_captain(90), "a fourth captain is refused")
	_expect(p.toggle_captain(30) and not p.is_captain(30) and p.toggle_captain(90), "a captain steps down, freeing the place")
	_expect(p.tip_once("flag") and not p.tip_once("flag"), "a hint shows once")
	_expect(p.save(SAVE_TEST) == OK, "progress saves")
	var back: RefCounted = Progression.load_from(SAVE_TEST)
	_expect(JSON.stringify(back.to_dict()) == JSON.stringify(p.to_dict()), "progress loads back the same")
	_expect(back.captains == PackedInt32Array([4, 60, 90]), "the captains load back")
	var old: Dictionary = p.to_dict()
	old.erase("captains")
	_expect(Progression.from_dict(old).captains.is_empty(), "a save from before captains loads with none")
	_expect(back.march_hour().shards == p.march_hour().shards, "the shard drops carry on the same stream after a load")
	DirAccess.remove_absolute(SAVE_TEST)
	# Real-time march: hours bank on the clock, up to the cap; a claim pays each hour and keeps the part-hour.
	var m := Progression.new(9)
	var t0: int = 1_800_000_000
	_expect(m.march_hours(t0) == 0, "the march starts counting at the first look")
	_expect(m.march_hours(t0 + 3 * 3600 + 600) == 3 and m.march_next_in(t0 + 3 * 3600 + 600) == 3000,
		"3 h 10 min banks 3 hours, the 4th in 50 min")
	var g0: int = m.gold
	var claimed: Dictionary = m.claim_march(t0 + 3 * 3600 + 600)
	_expect(claimed.hours == 3 and m.gold - g0 == claimed.gold and claimed.gold > 0, "a claim pays the 3 hours (%d gold)" % claimed.gold)
	_expect(m.march_hours(t0 + 4 * 3600) == 1, "the 10 minutes left over count toward the next hour")
	_expect(m.march_hours(t0 + 40 * 3600) == Progression.MARCH_CAP_HOURS, "away for days banks only the cap")
	m.claim_march(t0 + 40 * 3600)
	_expect(m.march_hours(t0 + 40 * 3600 + 60) == 0, "time past the cap is lost")
	_expect(m.march_hours(t0) == 0 and m.march_since == t0, "a clock set back restarts the count instead of paying")
	# 待辦: what can be done now, most useful first.
	var d := Progression.new(4)
	d.march_since = t0 - 2 * 3600
	d.gold = 150
	var kinds: Array = d.todo(t0).map(func(item: Dictionary) -> String: return item.kind)
	_expect(kinds == ["march", "class", "captain", "recruit"],
		"待辦: march to claim, a class level the gold covers, no captain, a 十連's tickets (%s)" % str(kinds))
	d.gold = 0
	d.captains = PackedInt32Array([1])
	d.claim_march(t0)
	d.gold = 0
	d.shards = 0
	d.stones = 0
	d.tickets = 0
	d.bag.clear()
	_expect(d.todo(t0).is_empty(), "nothing to do: an empty 待辦")
	_items()
	var fresh: RefCounted = Progression.load_from("user://no_such_progress.json")
	_expect(fresh.pushes == 0 and fresh.class_level[0] == 1, "no save is a fresh start")
	_finish("PROGRESSION TESTS")


## 道具: drops from the march and the boss, the 職業武庫, charms, 分解, relics, the 待辦 rows, saving.
func _items() -> void:
	var p := Progression.new(11)
	var shards_alone := Progression.new(11)
	var dropped: int = 0
	for k: int in 60:
		dropped += p.march_hour().items.size()
		shards_alone.march_hour()
	_expect(p.shards == shards_alone.shards, "item drops do not move the shard drops")
	_expect(p.stones == 60 * Progression.MARCH_STONES and dropped >= 3 and dropped <= 14,
		"60 march hours: %d 強化石, %d items" % [p.stones, dropped])
	var held: int = 0
	for id: String in p.bag:
		held += p.bag[id]
	_expect(held == dropped and p.fresh.size() == p.bag.size(), "every drop is in the bag, marked 新")
	var q := Progression.new(12)
	q.add_item(Items.weapon_id(1, 2))
	var before: float = q.power(_first_of_class(1))
	_expect(q.better_weapon(1) == Items.weapon_id(1, 2) and q.todo(0).any(func(t: Dictionary) -> bool: return t.kind == "equip"),
		"a better weapon in the bag shows in 待辦")
	_expect(q.equip_weapon(Items.weapon_id(1, 2)) and q.armory[1] == 2 and q.bag.is_empty(), "the weapon goes in the 劍 armory")
	var sword: int = _first_of_class(1)
	_expect(is_equal_approx(q.power(sword) / before, Items.WEAPON_MULT[2]), "every 劍 hero is %.2fx stronger" % Items.WEAPON_MULT[2])
	q.add_item(Items.weapon_id(1, 0))
	_expect(q.better_weapon(1) == "" and q.salvage(Items.weapon_id(1, 0)) and q.stones == Items.SALVAGE[0],
		"a worse weapon is not offered; 分解 turns it into 強化石")
	q.stones = 3
	_expect(q.armory_cost(1) == 1 and q.upgrade_armory(1) and q.upgrade_armory(1) and not q.upgrade_armory(1) and q.stones == 0,
		"強化 costs 1, then 2 stones (3 is too few for the third)")
	_expect(q.armory_cost(0) == -1, "an empty armory slot cannot be 強化")
	q.add_item(Items.charm_id(6))
	q.add_item(Items.charm_id(0))
	q.auto_equip()
	_expect(q.charm[q.march[0]] == 6 and q.charm[q.march[1]] == 0, "auto: the best charm to the first of the march squad")
	# A won push: 強化石, an item of R or better, and the first clear's relic star.
	var sim := PushSim.new(1)
	sim.phase = PushSim.Phase.WON
	var won: Dictionary = q.push_rewards(sim, 1)
	_expect(won.stones == Progression.WIN_STONES and won.items.size() == 1 and Items.rarity(won.items[0]) >= 1,
		"a fallen boss drops %d 強化石 and %s" % [won.stones, Items.item_name(won.items[0])])
	_expect(won.relic == 0 and q.relic_stars[0] == 1, "the first clear of 1-1 gives a star of %s" % Items.RELICS[0].name)
	var g: float = q.march_hour().gold
	q.relic_stars[0] = 0
	_expect(g > q.march_hour().gold, "%s raises the march gold" % Items.RELICS[0].name)
	_expect(q.save(SAVE_TEST) == OK and JSON.stringify(Progression.load_from(SAVE_TEST).to_dict()) == JSON.stringify(q.to_dict()),
		"items save and load back")
	var old: Dictionary = q.to_dict()
	for key: String in ["stones", "armory", "armory_level", "charm", "relic_stars", "bag", "fresh", "loot_state"]:
		old.erase(key)
	var back: RefCounted = Progression.from_dict(old)
	_expect(back.stones == 0 and back.armory[1] == -1 and back.bag.is_empty() and back.gold == q.gold,
		"a save from before 道具 keeps its gold and starts with none")
	DirAccess.remove_absolute(SAVE_TEST)


func _first_of_class(c: int) -> int:
	for i: int in Progression.HEROES:
		if Progression.base_class(i) == c:
			return i
	return -1


## Plays rounds until the bot wins (or MAX_ROUNDS). Returns {round (0 = never), first_lost, log}.
func _rounds(seed_value: int, bot: Dictionary) -> Dictionary:
	var p := Progression.new(seed_value)
	var log := ""
	var first_lost: bool = false
	for round: int in range(1, MAX_ROUNDS + 1):
		var opts: Dictionary = bot.duplicate()
		opts.roster = p.roster()
		opts.stage = Stages.stage(1)
		var r: Dictionary = PushBots.play(seed_value * 100 + round, opts)
		var sim: PushSim = r.sim
		p.push_rewards(sim, 1)
		if round == 1:
			first_lost = sim.phase == PushSim.Phase.LOST
		log += " %d:%s" % [round, "WIN" if sim.phase == PushSim.Phase.WON else "%d%%" % ceili(sim.hp_ratio() * 100.0)]
		if sim.phase == PushSim.Phase.WON:
			return {"round": round, "first_lost": first_lost, "log": log + " (power %.2f)" % p.power(0)}
		p.march_hour()
		p.auto_spend()
	return {"round": 0, "first_lost": first_lost, "log": log + " (power %.2f)" % p.power(0)}
