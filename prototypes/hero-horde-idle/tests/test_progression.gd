extends "res://addons/proto_kit/test_kit.gd"
## The growth loop (domain/progression.gd) on 1-1 (domain/stages.gd, eased for new players). One round = one push
## by a bot, its rewards, one 行軍 1 小時 (the march's measured pace), then 一鍵養成 (auto_spend: the same spending for
## every bot). Over 3 seeds:
##   1  the first push is lost without playing
##   2  idle (never touches the push) wins on growth alone in 3-6 rounds
##   3  good wins 2-4 rounds sooner than idle
##   4  a person-style player (human) wins within the first two pushes
## plus 訓練 (rows, costs, what opens them, 結伴's slots), the march squad, the 圖鑑, captains, items as pieces with
## affixes and 自動分解, a save round trip, and a version 1 save brought forward.
##   godot --headless --path prototypes/hero-horde-idle --script res://tests/test_progression.gd
const PushSim = preload("res://domain/push_sim.gd")
const PushBots = preload("res://tests/push_bots.gd")
const Progression = preload("res://domain/progression.gd")
const Talents = preload("res://domain/talents.gd")
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
	_talents()
	_squad_and_codex()
	_items()
	_potions()
	_saves()
	_finish("PROGRESSION TESTS")


## 經驗藥水: dropped by the march, three sizes giving EXP (not whole levels), used on a resting hero, stop at the cap,
## saved; an old save's single count becomes small ones.
func _potions() -> void:
	var p := Progression.new(5)
	var got: Dictionary = p.march_hour()
	_expect(got.potions[0] > 0 and p.potions[0] == got.potions[0], "an hour of march drops small 經驗藥水 (%s)" % str(got.potions))
	var resting: int = 60
	_expect(not p.in_march(resting), "hero 60 is not marching")
	p.potions = PackedInt32Array([2, 1, 0])
	var lv: int = p.hero_level[resting]
	var small: Dictionary = p.use_potions(resting, 0, 1)
	_expect(small.used == 1 and p.hero_exp[resting] == Progression.POTIONS[0].exp and p.hero_level[resting] == lv,
		"a small potion gives 500 EXP, not a level")
	var mid: Dictionary = p.use_potions(resting, 1, 1)
	_expect(mid.used == 1 and p.hero_level[resting] > lv, "a medium potion (3000 EXP) levels them up (%d)" % mid.levels)
	p.hero_level[resting] = p.hero_cap(resting)
	_expect(p.use_potions(resting, 0, 1).used == 0 and p.potions[0] == 1, "a hero at the cap takes none")
	var copy: RefCounted = Progression.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())))
	_expect(copy.potions == PackedInt32Array([1, 0, 0]), "potions are saved by size")
	var old: Dictionary = p.to_dict()
	old.potions = 4
	_expect(Progression.from_dict(old).potions == PackedInt32Array([4, 0, 0]), "an old single count becomes small potions")


## 訓練: costs, what opens a row, the strength it gives, 結伴's slots, the 待辦 row.
func _talents() -> void:
	var p := Progression.new(4)
	p.gold = 3000
	var atk0: float = p.atk_mult(0)
	var hp0: float = p.hp_mult(0)
	_expect(p.talent_cost(Talents.SWORD) == 3000 and p.level_talent(Talents.SWORD) and p.gold == 0, "劍術 Lv1 costs 3000")
	_expect(is_equal_approx(p.atk_mult(0) / atk0, Talents.STEP) and is_equal_approx(p.hp_mult(0), hp0),
		"劍術 raises every hero's attack x%.2f, not HP" % Talents.STEP)
	p.gold = 1_000_000
	_expect(not p.talent_open(Talents.SPEED) and not p.level_talent(Talents.SPEED), "速度 waits for 劍術 Lv3")
	_expect(p.talent_need(Talents.SPEED) == "劍術 Lv3", "the row says what it waits for")
	p.level_talent(Talents.SWORD)
	p.level_talent(Talents.SWORD)
	_expect(p.level_talent(Talents.SPEED) and is_equal_approx(p.cooldown_mult(), 1.0 - Talents.SPEED_CD), "速度 opens at 劍術 Lv3")
	_expect(not p.level_talent(Talents.COMPANY), "結伴 waits for 劍術 and 耐力 Lv5")
	p.talent[Talents.SWORD] = 5
	p.talent[Talents.STAMINA] = 5
	_expect(p.slots() == 3 and p.level_talent(Talents.COMPANY) and p.slots() == 4 and p.march.size() == 4,
		"結伴 opens a 4th slot and fills it")
	_expect(p.level_talent(Talents.COMPANY) and p.slots() == 5 and p.march.size() == 5 and p.talent_cost(Talents.COMPANY) == -1,
		"a 5th slot, then 結伴 is done")
	# Deeper nodes wait for a stage boss and a hero level as well as their parent.
	_expect(not p.talent_open(Talents.STUDY) and p.talent_need(Talents.STUDY) == "打倒第1層樓層王、英雄 Lv10",
		"學識 waits for 第1層 and a Lv10 hero (%s)" % p.talent_need(Talents.STUDY))
	p.cleared = 1
	p.hero_level[0] = 10
	_expect(p.level_talent(Talents.STUDY) and is_equal_approx(p.exp_mult(), 1.0 + Talents.STUDY_EXP), "學識 opens; march EXP +10%")
	p.cleared = 4
	p.hero_level[0] = 25
	p.talent[Talents.MELEE_SPEC] = 1
	p.talent[Talents.FORGE] = 3
	atk0 = p.atk_mult(0)
	_expect(p.level_talent(Talents.MASTER) and is_equal_approx(p.atk_mult(0) / atk0, Talents.MASTER_STEP), "劍聖: attack x1.04")
	var product: Array = [Progression.START_POWER, Progression.START_POWER]
	for f: Dictionary in p.stat_factors(0):
		product[0] *= f.atk
		product[1] *= f.hp
	_expect(is_equal_approx(product[0], p.atk_mult(0)) and is_equal_approx(product[1], p.hp_mult(0)),
		"數值明細 multiplies out to the hero's attack and HP")
	var q := Progression.new(4)
	q.gold = 3000
	var kinds: Array = q.todo().map(func(item: Dictionary) -> String: return item.kind)
	_expect(kinds == ["push", "talent", "captain", "recruit"],
		"待辦 before the first push: the boss first, a talent the gold covers, no captain, a 十連 (%s)" % str(kinds))


## The march squad (toggle, slots), the 圖鑑, captains.
func _squad_and_codex() -> void:
	var p := Progression.new(6)
	_expect(not p.toggle_march(0), "a full squad takes no one more")
	_expect(p.toggle_march(13) and p.march.size() == 2 and p.toggle_march(0) and p.march[2] == 0,
		"one called back frees a slot for another")
	_expect(p.todo().all(func(item: Dictionary) -> bool: return item.kind != "slot"), "no free slot in 待辦 once filled")
	p.toggle_march(0)
	_expect(p.todo().any(func(item: Dictionary) -> bool: return item.kind == "slot"), "a free slot shows in 待辦")
	var power0: float = p.power(0)
	p.ascension[50] = 1
	_expect(p.codex_count() == 1 and is_equal_approx(p.power(0) / power0, 1.0 + Progression.CODEX_PER),
		"one 覺醒 hero in the 圖鑑: everyone +%.1f%%" % (Progression.CODEX_PER * 100.0))
	for i: int in [4, 30, 60]:
		_expect(p.toggle_captain(i), "hero %d becomes a captain" % i)
	_expect(not p.toggle_captain(90) and not p.is_captain(90), "a fourth captain is refused")
	_expect(p.toggle_captain(30) and not p.is_captain(30) and p.toggle_captain(90), "a captain steps down, freeing the place")
	_expect(p.tip_once("flag") and not p.tip_once("flag"), "a hint shows once")


## Pieces with affixes: drops, the armory, charms, 分解, 自動分解, a won push's loot and relic.
func _items() -> void:
	var p := Progression.new(11)
	var seen := [0, 0, 0, 0]
	var affixes_match: bool = true
	for k: int in 200:
		var item: Dictionary = p.roll_loot(2, 0)
		var r: int = Items.rarity(item.id)
		seen[r] += 1
		affixes_match = affixes_match and item.aff.size() == Items.AFFIX_COUNT[r]
	_expect(seen[0] > 0 and seen[2] > 0 and affixes_match, "drops roll rarities by region, affixes by rarity (%s)" % str(seen))
	var r1: Dictionary = p.new_item(Items.weapon_id(1, 1))
	var r3: Dictionary = p.new_item(Items.weapon_id(1, 3))
	_expect(r1.aff.size() == 1 and r3.aff.size() == 2 and r3.uid != r1.uid, "R has one affix, SSR two, each piece its own uid")
	var q := Progression.new(12)
	var sword: int = _first_of_class(1)
	var w: Dictionary = q.new_item(Items.weapon_id(1, 2))
	q.add_item(w)
	var before: float = q.atk_mult(sword)
	_expect(q.better_weapon(1) == w.uid and q.todo().any(func(t: Dictionary) -> bool: return t.kind == "equip"),
		"a better weapon in the bag shows in 待辦")
	_expect(q.equip_weapon(w.uid) and q.weapon_rarity(1) == 2 and q.bag.is_empty() and q.fresh.is_empty(), "the weapon goes in the 劍 armory")
	var expected: float = Items.WEAPON_MULT[2] * (1.0 + Items.affix(w, "atk"))
	_expect(is_equal_approx(q.atk_mult(sword) / before, expected), "every 劍 hero hits %.3fx harder (rarity and affix)" % expected)
	var worse: Dictionary = q.new_item(Items.weapon_id(1, 0))
	q.add_item(worse)
	_expect(q.better_weapon(1) < 0 and q.salvage(worse.uid) and q.stones == Items.SALVAGE[0], "a worse weapon is not offered; 分解 gives 強化石")
	q.stones = 3
	_expect(q.armory_cost(1) == 1 and q.upgrade_armory(1) and q.upgrade_armory(1) and not q.upgrade_armory(1) and q.stones == 0,
		"強化 costs 1, then 2 stones")
	_expect(q.armory_cost(0) == -1, "an empty armory slot cannot be 強化")
	var gold_charm: Dictionary = q.new_item(Items.charm_id(6))
	var leaf: Dictionary = q.new_item(Items.charm_id(0))
	q.add_item(gold_charm)
	q.add_item(leaf)
	q.auto_equip()
	_expect(q.charm[q.march[0]].uid == gold_charm.uid and q.charm[q.march[1]].uid == leaf.uid, "auto: the best charm to the first of the march")
	# 自動分解: an N that beats nothing equipped becomes stones; one that would fill an empty slot is kept.
	q.auto_salvage = 0
	q.stones = 0
	_expect(not q.add_item(q.new_item(Items.weapon_id(1, 0))) and q.stones == Items.SALVAGE[0], "自動分解 N: a worse N weapon turns into 強化石")
	_expect(q.add_item(q.new_item(Items.weapon_id(4, 0))), "an N for an empty armory slot is kept")
	_expect(q.salvage_up_to(1) == 1 and q.bag.is_empty(), "salvage everything up to R at once")
	q.auto_salvage = -1
	for k: int in Items.BAG_MAX:
		q.add_item(q.new_item(Items.charm_id(0)))
	_expect(q.bag.size() == Items.BAG_MAX and not q.add_item(q.new_item(Items.charm_id(2))), "a full bag turns the next drop into 強化石")
	q.salvage_up_to(3)
	var sim := PushSim.new(1)
	sim.phase = PushSim.Phase.WON
	var won: Dictionary = q.push_rewards(sim, 1)
	_expect(won.stones == Progression.WIN_STONES and won.items.size() == 1 and Items.rarity(won.items[0].id) >= 1,
		"a fallen boss drops %d 強化石 and %s" % [won.stones, Items.item_name(won.items[0].id)])
	_expect(won.relic == 0 and q.relic_stars[0] == 1 and q.cleared == 1 and q.march_stage == 2,
		"the first clear of 1-1: a relic star, and the march moves on to 1-2")


func _saves() -> void:
	var p := Progression.new(5)
	for k: int in 3:
		p.march_hour()
		p.gold += 50000
		p.shards += 4
		p.auto_spend()
	p.add_item(p.new_item(Items.weapon_id(2, 3)))
	p.auto_salvage = 1
	_expect(p.save(SAVE_TEST) == OK, "progress saves")
	var back: RefCounted = Progression.load_from(SAVE_TEST)
	_expect(JSON.stringify(back.to_dict()) == JSON.stringify(p.to_dict()), "progress loads back the same")
	_expect(back.march_hour().shards == p.march_hour().shards, "the shard drops carry on the same stream after a load")
	DirAccess.remove_absolute(SAVE_TEST)
	# A version 1 save: class levels refunded (x10 gold), items become pieces, the march fits the slots.
	var v1 := {"version": 1, "gold": 500, "shards": 3, "class_level": [3, 1, 1, 1, 1, 1], "hero_level": _filled(100, 2),
		"hero_exp": _filled(100, 0), "ascension": _filled(100, 0), "march": [13, 32, 33, 51, 69], "captains": [13],
		"tips": [], "cleared": 2, "march_since": 0, "pushes": 4, "wins": 2, "rng_state": "1", "stones": 7,
		"armory": [-1, 2, -1, -1, -1, -1], "armory_level": [1, 3, 1, 1, 1, 1], "charm": _filled(100, -1),
		"relic_stars": [1, 0, 0, 0], "bag": {"w0_1": 2, "c3": 1}, "fresh": [], "loot_state": "5", "tickets": 4}
	var old: RefCounted = Progression.from_dict(v1)
	_expect(old.gold == 5000 + 1000 + 1080, "a v1 save: gold x10 plus its class levels' cost back (%d)" % old.gold)
	_expect(old.march == PackedInt32Array([13, 32, 33]) and old.march_stage == 3, "the march keeps its first 3, marching at the stage to push")
	_expect(old.weapon_rarity(1) == 2 and old.armory_level[1] == 3 and old.bag.size() == 3 and old.tickets == 4,
		"its armory and bag come over as pieces")
	var fresh: RefCounted = Progression.load_from("user://no_such_progress.json")
	_expect(fresh.pushes == 0 and fresh.talent[0] == 0, "no save is a fresh start")


static func _filled(n: int, v: int) -> Array:
	var a: Array = []
	a.resize(n)
	a.fill(v)
	return a


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
			return {"round": round, "first_lost": first_lost, "log": log + " (power %.2f)" % p.team_power()}
		p.march_hour()
		p.auto_spend()
	return {"round": 0, "first_lost": first_lost, "log": log + " (power %.2f)" % p.team_power()}
