extends RefCounted
## 養成: what a player keeps between pushes, as pure state (no nodes; saved as JSON with godot-kit atomic_file).
##   gold     from pushes (by damage dealt) and marches; spent on 職業等級 (class levels: the bulk of the power,
##            every hero of the class grows together)
##   shards   突破素材, from killing the stage boss and, by chance, marches; spent on 突破 (ascension: +10 level
##            cap, an SSR's 招牌技 grows, every ASCEND_PER_PROMOTE ascensions an N or R steps up a rarity, up to SR)
##   march    the 行軍小隊 (5 heroes): only they earn hero EXP, so who marches is who grows. The squad marches in
##            real time: every MARCH_SECONDS of wall clock is one march_hour() of rewards, banked up to MARCH_CAP_HOURS
##            (the 離線 cap) and handed over by claim_march(now); the clock is passed in, so tests set it
##   cleared  the highest 關卡 cleared (domain/stages.gd); the next one is the one to push. A first clear pays
##            Stages.FIRST_GOLD (scaled by the stage) and FIRST_SHARDS on top of the push's own rewards
##   tips     the first-push hints already shown (tip_once), so each appears once per save
##   items    道具 (domain/items.gd): weapons in the 職業武庫 (one per class, armory[c] = its rarity, armory_level[c]
##            its 強化 paid in stones), a 專屬飾品 per hero (charm[i]), the bag of unequipped ones (id -> count, the
##            fresh ones marked 新 until seen), relic stars. A march hour brings MARCH_STONES and maybe an item, a won
##            push WIN_STONES and an item (R or better), a first clear a relic star. Loot rolls on its own stream
##   captains up to MAX_CAPTAINS heroes the player picked to lead (drawn larger in the push, with a nameplate). Each
##            gives their 團 (PushSim.CLASS_SQUAD: 近戰 盾劍槍, 遠程 弓法, 輔助 補) CAPTAIN_BUFF[rarity] more strength,
##            two captains of one 團 adding up; it goes through power(), so the march earns more too. They can be
##            changed at any time
##   招募     招募券 (tickets) buy pulls (domain/recruit.gd): a pulled hero brings 突破素材 by rarity; pity counts the
##            pulls since the last SSR; recent keeps the last pulled heroes. One 免費單抽 a day for a rewarded ad
##            (ad_day, ad_pulls). owned holds the non-consumable purchases (domain/shop.gd). Pulls roll on a third
##            random stream
## roster() hands the result to PushSim.new(). Heroes start at START_POWER of the push's reference strength: the
## first pushes are lost even when played well, and growth wins them (the 教練 design; tests/test_progression.gd
## measures how many rounds that takes). Every number is a hardcoded prototype constant.

const PushSim = preload("res://domain/push_sim.gd")
const Items = preload("res://domain/items.gd")
const Stages = preload("res://domain/stages.gd")
const Recruit = preload("res://domain/recruit.gd")
const Shop = preload("res://domain/shop.gd")
const AtomicFile = preload("res://addons/proto_kit/atomic_file.gd")
const Gacha = preload("res://addons/proto_kit/gacha.gd")

const SAVE_PATH := "user://progress.json"
const SAVE_VERSION := 1
const HEROES := 100
const START_POWER := 0.42
## Each class level multiplies the class's HP and attack by CLASS_STEP; each hero level a hero's by HERO_STEP.
const CLASS_STEP := 1.08
const HERO_STEP := 1.03
## Gold for class level L -> L + 1.
const CLASS_COST_BASE := 100.0
const CLASS_COST_GROWTH := 1.08
const LEVEL_CAP := 10
const CAP_PER_ASCEND := 10
const MAX_ASCEND := 5
## Shards for ascension a -> a + 1.
const ASCEND_COST := [1, 2, 3, 4, 5]
const ASCEND_PER_PROMOTE := 2
## EXP for hero level L -> L + 1.
const EXP_PER_LEVEL := 60
const MARCH_SIZE := 5
## A march brings back MARCH_GOLD at the starting strength, more as the march squad grows (so the gold keeps pace
## with the class level costs, and growth per round stays steady).
const MARCH_GOLD := 1300
const MARCH_EXP := 150
const MARCH_SHARD_CHANCE := 0.3
const MARCH_SECONDS := 3600
const MARCH_CAP_HOURS := 8
const PUSH_GOLD_PER_DAMAGE := 1.0 / 40.0
const KILL_SHARDS := 3
const MAX_CAPTAINS := 3
const MARCH_STONES := 2
const MARCH_LOOT_CHANCE := 0.12
const WIN_STONES := 6
## A won push of a stage already cleared adds a star to a random relic this often.
const RELIC_WIN_CHANCE := 0.15
## A captain's boost to their 團 by the captain's rarity (N, R, SR, SSR).
const CAPTAIN_BUFF := [0.03, 0.05, 0.08, 0.12]
const RECENT_SIZE := 5

var gold: int = 0
var shards: int = 0
var stones: int = 0
var armory := PackedInt32Array()
var armory_level := PackedInt32Array()
var charm := PackedInt32Array()
var relic_stars := PackedInt32Array()
## Unequipped items: id -> count.
var bag: Dictionary = {}
## Items got since the 道具 page last showed them (the 新 badge).
var fresh := PackedStringArray()
var class_level := PackedInt32Array()
var hero_level := PackedInt32Array()
var hero_exp := PackedInt32Array()
var ascension := PackedInt32Array()
var march := PackedInt32Array()
var captains := PackedInt32Array()
var tips := PackedStringArray()
var pushes: int = 0
var cleared: int = 0
## Unix seconds the march's unclaimed time counts from (0 = not started: the first march_hours() starts it).
var march_since: int = 0
var wins: int = 0
var tickets: int = Recruit.START_TICKETS
var pity: int = 0
var pulls: int = 0
## The last pulled heroes, newest first.
var recent := PackedInt32Array()
## The day (Recruit.day) of the last ad pull and how many were taken that day.
var ad_day: int = -1
var ad_pulls: int = 0
## Non-consumable products bought (Shop.PRODUCTS ids).
var owned := PackedStringArray()
## Shard drops have their own random stream, saved with the rest, so the game's randf() is never touched.
var _rng := RandomNumberGenerator.new()
## Item drops have another, so loot never shifts the shard drops; pulls a third.
var _loot := RandomNumberGenerator.new()
var _pull := RandomNumberGenerator.new()


func _init(seed_value: int = 1) -> void:
	_rng.seed = seed_value
	_loot.seed = seed_value + 7919
	_pull.seed = seed_value + 15485863
	armory.resize(PushSim.ROSTER.size())
	armory.fill(-1)
	armory_level.resize(PushSim.ROSTER.size())
	armory_level.fill(1)
	charm.resize(HEROES)
	charm.fill(-1)
	relic_stars.resize(Items.RELICS.size())
	class_level.resize(PushSim.ROSTER.size())
	class_level.fill(1)
	hero_level.resize(HEROES)
	hero_level.fill(1)
	hero_exp.resize(HEROES)
	ascension.resize(HEROES)
	# The march squad starts as the first five SSRs.
	var probe := PushSim.new()
	for i: int in HEROES:
		if probe.rarity[i] == PushSim.SSR and march.size() < MARCH_SIZE:
			march.append(i)


## The fixed roster's class and starting rarity (PushSim's order).
static func base_class(i: int) -> int:
	var k: int = i
	for c: int in PushSim.ROSTER.size():
		if k < PushSim.ROSTER[c]:
			return c
		k -= PushSim.ROSTER[c]
	return -1


static func base_rarity(i: int) -> int:
	var k: int = i
	for c: int in PushSim.ROSTER.size():
		if k < PushSim.ROSTER[c]:
			for r: int in 4:
				if k < PushSim.RARITY_COUNTS[c][r]:
					return r
				k -= PushSim.RARITY_COUNTS[c][r]
		k -= PushSim.ROSTER[c]
	return -1


## A hero's rarity now: N and R step up every ASCEND_PER_PROMOTE ascensions, never past SR.
func rarity(i: int) -> int:
	var r: int = base_rarity(i)
	if r >= PushSim.SR:
		return r
	return mini(r + ascension[i] / ASCEND_PER_PROMOTE, PushSim.SR)


func hero_cap(i: int) -> int:
	return LEVEL_CAP + CAP_PER_ASCEND * ascension[i]


## How strong hero i is against the push's reference (1.0 = the balance tests' roster).
func power(i: int) -> float:
	var c: int = base_class(i)
	return START_POWER * pow(CLASS_STEP, class_level[c] - 1) * pow(HERO_STEP, hero_level[i] - 1) * weapon_mult(c) \
		* charm_mult(i) * (1.0 + captain_buff(c))


## The captains' boost to class c's 團 (0.17 = +17%).
func captain_buff(c: int) -> float:
	var total: float = 0.0
	for k: int in captains:
		if PushSim.CLASS_SQUAD[base_class(k)] == PushSim.CLASS_SQUAD[c]:
			total += CAPTAIN_BUFF[rarity(k)]
	return total


## The 職業武庫's boost for class c: its weapon, then its 強化 level (1 without a weapon).
func weapon_mult(c: int) -> float:
	if armory[c] < 0:
		return 1.0
	return Items.WEAPON_MULT[armory[c]] * pow(Items.ARMORY_STEP, armory_level[c] - 1)


func charm_mult(i: int) -> float:
	return 1.0 if charm[i] < 0 else Items.CHARM_MULT[Items.CHARMS[charm[i]].rarity]


## The sum of the relic effects with this key (Items.RELICS), e.g. 0.06 for two stars of +3%.
func relic(key: String) -> float:
	var total: float = 0.0
	for k: int in Items.RELICS.size():
		if Items.RELICS[k].key == key:
			total += Items.RELICS[k].per_star * relic_stars[k]
	return total


## What PushSim.new(seed, roster) needs.
func roster() -> Dictionary:
	var r := {"rarity": PackedInt32Array(), "hp_mult": PackedFloat32Array(), "atk_mult": PackedFloat32Array(),
		"sig_level": PackedInt32Array()}
	for i: int in HEROES:
		r.rarity.append(rarity(i))
		r.hp_mult.append(power(i) * (1.0 + relic("hp")))
		r.atk_mult.append(power(i) * (1.0 + relic("atk")))
		r.sig_level.append(ascension[i] if base_rarity(i) == PushSim.SSR else 0)
	return r


func class_cost(c: int) -> int:
	return roundi(CLASS_COST_BASE * pow(CLASS_COST_GROWTH, class_level[c] - 1))


func level_class(c: int) -> bool:
	var cost: int = class_cost(c)
	if gold < cost:
		return false
	gold -= cost
	class_level[c] += 1
	return true


func ascend_cost(i: int) -> int:
	return ASCEND_COST[ascension[i]] if ascension[i] < MAX_ASCEND else -1


func ascend(i: int) -> bool:
	var cost: int = ascend_cost(i)
	if cost < 0 or shards < cost:
		return false
	shards -= cost
	ascension[i] += 1
	return true


## Puts hero i in march slot `slot` (a hero already marching swaps places with the one there).
func set_march(slot: int, i: int) -> void:
	var at: int = march.find(i)
	if at >= 0:
		march[at] = march[slot]
	march[slot] = i


func in_march(i: int) -> bool:
	return march.has(i)


## True the first time `key` is asked for (and remembers it): show that hint now.
func tip_once(key: String) -> bool:
	if tips.has(key):
		return false
	tips.append(key)
	return true


func is_captain(i: int) -> bool:
	return captains.has(i)


## Makes hero i a captain, or stops them being one. False when they are not one and MAX_CAPTAINS are already picked.
func toggle_captain(i: int) -> bool:
	var at: int = captains.find(i)
	if at >= 0:
		captains.remove_at(at)
		return true
	if captains.size() >= MAX_CAPTAINS:
		return false
	captains.append(i)
	return true


## What can be done right now (the 營地's 待辦 and the nav bar's dots), most useful first, as
## {kind, text, tab, cls}: kind "march" (hours to claim), "class" (a class level the gold covers, the cheapest),
## "ascend" (a march hero the shards cover), "equip" (a better weapon in the bag, or a better charm for the march
## squad), "armory" (a 職業武庫 強化 the stones cover), "captain" (none picked yet), "recruit" (a 十連's tickets).
func todo(now: int) -> Array:
	var out: Array = []
	var hours: int = march_hours(now)
	if hours > 0:
		out.append({"kind": "march", "text": "行軍累積了 %d 小時，可以領取" % hours, "tab": &"camp", "cls": -1})
	var best: int = -1
	for c: int in class_level.size():
		if gold >= class_cost(c) and (best < 0 or class_cost(c) < class_cost(best)):
			best = c
	if best >= 0:
		out.append({"kind": "class", "text": "%s 職業等級可以升到 %d（%d 金）" % [PushSim.CLASS_NAMES[best], class_level[best] + 1,
			class_cost(best)], "tab": &"growth", "cls": best})
	for i: int in march:
		var cost: int = ascend_cost(i)
		if cost > 0 and shards >= cost:
			out.append({"kind": "ascend", "text": "行軍小隊有英雄可以突破（%d 素材）" % cost, "tab": &"growth",
				"cls": base_class(i)})
			break
	var equip: bool = range(armory.size()).any(func(c: int) -> bool: return better_weapon(c) != "")
	if not equip:
		for i: int in march:
			equip = equip or better_charm(i) != ""
	if equip:
		out.append({"kind": "equip", "text": "背包裡有更好的裝備可以換上", "tab": &"items", "cls": -1})
	var cheapest: int = -1
	for c: int in armory.size():
		if armory_cost(c) > 0 and (cheapest < 0 or armory_cost(c) < armory_cost(cheapest)):
			cheapest = c
	if cheapest >= 0 and stones >= armory_cost(cheapest):
		out.append({"kind": "armory", "text": "%s職業武庫可以強化到 Lv%d（%d 強化石）" % [PushSim.CLASS_NAMES[cheapest],
			armory_level[cheapest] + 1, armory_cost(cheapest)], "tab": &"items", "cls": cheapest})
	if captains.is_empty():
		out.append({"kind": "captain", "text": "還沒有隊長：在英雄頁挑 1～3 名，他們的團會變強", "tab": &"growth", "cls": -1})
	if tickets >= Recruit.TEN:
		out.append({"kind": "recruit", "text": "招募券有 %d 張，可以十連招募" % tickets, "tab": &"recruit", "cls": -1})
	return out


## The whole roster's average strength against the push's reference (1.0); compare with Stages.recommended().
func team_power() -> float:
	var total: float = 0.0
	for i: int in HEROES:
		total += power(i)
	return total / HEROES * sqrt((1.0 + relic("hp")) * (1.0 + relic("atk")))


## The march squad's average power against the starting strength.
func march_strength() -> float:
	var total: float = 0.0
	for i: int in march:
		total += power(i)
	return total / march.size() / START_POWER


## Whole march hours banked at `now` (unix seconds), at most MARCH_CAP_HOURS. A clock that went back restarts the count.
func march_hours(now: int) -> int:
	if march_since <= 0 or now < march_since:
		march_since = now
	return mini((now - march_since) / MARCH_SECONDS, MARCH_CAP_HOURS)


## Seconds until the next march hour is banked (0 when the bank is full).
func march_next_in(now: int) -> int:
	if march_hours(now) >= MARCH_CAP_HOURS:
		return 0
	return MARCH_SECONDS - (now - march_since) % MARCH_SECONDS


## Hands over every banked march hour (march_hour() each) and keeps the part-hour running; time past the cap is lost.
## Returns {hours, gold, shards, stones, items: [id], levels: {hero: levels gained}}.
func claim_march(now: int) -> Dictionary:
	var hours: int = march_hours(now)
	var got := {"hours": hours, "gold": 0, "shards": 0, "stones": 0, "items": [], "levels": {}}
	for k: int in hours:
		var one: Dictionary = march_hour()
		got.gold += one.gold
		got.shards += one.shards
		got.stones += one.stones
		got.items.append_array(one.items)
		for i: int in one.levels:
			got.levels[i] = got.levels.get(i, 0) + one.levels[i]
	if hours >= MARCH_CAP_HOURS:
		march_since = now
	else:
		march_since += hours * MARCH_SECONDS
	return got


## 行軍 1 小時: gold, EXP for the march squad (levels up to each hero's cap), maybe a shard, 強化石, maybe an item.
## Returns {gold, shards, stones, items: [id], levels: {hero: levels gained}}.
func march_hour() -> Dictionary:
	var earned: int = roundi(MARCH_GOLD * march_strength() * (1.0 + relic("march_gold")))
	var got := {"gold": earned, "shards": 0, "stones": MARCH_STONES, "items": [], "levels": {}}
	gold += earned
	stones += MARCH_STONES
	if _rng.randf() < MARCH_SHARD_CHANCE:
		shards += 1
		got.shards = 1
	if _loot.randf() < MARCH_LOOT_CHANCE:
		got.items.append(roll_loot(Stages.region(next_stage()), 0))
	var exp_gain: int = roundi(MARCH_EXP * (1.0 + relic("exp")))
	for i: int in march:
		var before: int = hero_level[i]
		hero_exp[i] += exp_gain
		while hero_level[i] < hero_cap(i) and hero_exp[i] >= EXP_PER_LEVEL * hero_level[i]:
			hero_exp[i] -= EXP_PER_LEVEL * hero_level[i]
			hero_level[i] += 1
		if hero_level[i] >= hero_cap(i):
			hero_exp[i] = 0
		if hero_level[i] > before:
			got.levels[i] = hero_level[i] - before
	return got


## The stage to push next: the one after the highest cleared (the last stays open once all are cleared).
func next_stage() -> int:
	return mini(cleared + 1, Stages.COUNT)


func unlocked(n: int) -> bool:
	return n >= 1 and n <= next_stage()


## A finished push of stage n pays out: gold by the damage dealt, shards when the boss fell, and the first-clear
## bonus the first time stage n falls (which opens the next stage, and gives Recruit.FIRST_TICKETS 招募券). A fallen
## boss also drops 強化石 and an item (R or better), and a relic star: always on the first clear, by chance after.
## Returns {gold, shards, stones, items, relic (index, -1 for none), tickets, won, first}.
func push_rewards(sim: PushSim, n: int = 1) -> Dictionary:
	var won: bool = sim.phase == PushSim.Phase.WON
	var got := {"gold": roundi(sim.damage_dealt * PUSH_GOLD_PER_DAMAGE), "shards": KILL_SHARDS if won else 0, "won": won,
		"first": won and n > cleared, "stones": 0, "items": [], "relic": -1, "tickets": 0}
	if won:
		got.stones = WIN_STONES + 2 * (n - 1)
		stones += got.stones
		got.items.append(roll_loot(Stages.region(n), 1))
		if got.first:
			got.relic = (n - 1) % Items.RELICS.size()
		elif _loot.randf() < RELIC_WIN_CHANCE:
			got.relic = _loot.randi_range(0, Items.RELICS.size() - 1)
		if got.relic >= 0 and relic_stars[got.relic] < Items.MAX_STARS:
			relic_stars[got.relic] += 1
		else:
			got.relic = -1
	if got.first:
		got.gold += roundi(Stages.FIRST_GOLD * Stages.stage(n).reward)
		got.shards += Stages.FIRST_SHARDS
		got.tickets = Recruit.FIRST_TICKETS
		tickets += got.tickets
		cleared = n
	gold += got.gold
	shards += got.shards
	pushes += 1
	if won:
		wins += 1
	return got


## 一鍵養成: spends everything the same way every time: the cheapest class level until gold runs out, then shards
## on the march squad in slot order. The balance bots use it, so both play the same growth.
func auto_spend() -> void:
	while true:
		var best: int = -1
		for c: int in class_level.size():
			if best < 0 or class_cost(c) < class_cost(best):
				best = c
		if not level_class(best):
			break
	for i: int in march:
		while ascend(i):
			pass
	auto_equip()
	while true:
		var best: int = -1
		for c: int in armory.size():
			if armory_cost(c) > 0 and (best < 0 or armory_cost(c) < armory_cost(best)):
				best = c
		if best < 0 or not upgrade_armory(best):
			break


## Drops one item from the region's odds (at least `floor_rarity`) into the bag, marked 新. Returns its id.
func roll_loot(region_index: int, floor_rarity: int) -> String:
	var odds: Array = Items.LOOT_ODDS[region_index]
	var roll: int = _loot.randi_range(1, 100)
	var r: int = 0
	while r < 3 and roll > odds[r]:
		roll -= odds[r]
		r += 1
	r = maxi(r, floor_rarity)
	var id: String
	if _loot.randf() < Items.WEAPON_SHARE:
		id = Items.weapon_id(_loot.randi_range(0, armory.size() - 1), r)
	else:
		var pool: Array = range(Items.CHARMS.size()).filter(func(k: int) -> bool: return Items.CHARMS[k].rarity == r)
		id = Items.charm_id(pool[_loot.randi_range(0, pool.size() - 1)])
	add_item(id)
	return id


func add_item(id: String, count: int = 1) -> void:
	bag[id] = int(bag.get(id, 0)) + count
	if not fresh.has(id):
		fresh.append(id)


func _take(id: String) -> bool:
	if int(bag.get(id, 0)) <= 0:
		return false
	bag[id] = int(bag[id]) - 1
	if bag[id] == 0:
		bag.erase(id)
		var at: int = fresh.find(id)
		if at >= 0:
			fresh.remove_at(at)
	return true


## Puts a weapon from the bag in its class's 職業武庫 (the one there goes back to the bag; the slot keeps its level).
func equip_weapon(id: String) -> bool:
	if not Items.is_weapon(id) or not _take(id):
		return false
	var c: int = Items.weapon_class(id)
	if armory[c] >= 0:
		add_item(Items.weapon_id(c, armory[c]))
		fresh.remove_at(fresh.find(Items.weapon_id(c, armory[c])))
	armory[c] = Items.rarity(id)
	return true


## Gives hero i a 專屬飾品 from the bag (theirs goes back to the bag).
func equip_charm(i: int, id: String) -> bool:
	if Items.is_weapon(id) or not _take(id):
		return false
	if charm[i] >= 0:
		add_item(Items.charm_id(charm[i]))
		fresh.remove_at(fresh.find(Items.charm_id(charm[i])))
	charm[i] = Items.charm_index(id)
	return true


## 分解: one item from the bag into 強化石 (Items.SALVAGE by rarity).
func salvage(id: String) -> bool:
	if not _take(id):
		return false
	stones += Items.SALVAGE[Items.rarity(id)]
	return true


## 強化石 for class c's slot level L -> L + 1 (-1 without a weapon or at the top).
func armory_cost(c: int) -> int:
	return armory_level[c] if armory[c] >= 0 and armory_level[c] < Items.ARMORY_MAX else -1


func upgrade_armory(c: int) -> bool:
	var cost: int = armory_cost(c)
	if cost < 0 or stones < cost:
		return false
	stones -= cost
	armory_level[c] += 1
	return true


## The best weapon in the bag for class c that beats the equipped one ("" when none).
func better_weapon(c: int) -> String:
	for r: int in range(3, armory[c], -1):
		if bag.has(Items.weapon_id(c, r)):
			return Items.weapon_id(c, r)
	return ""


## The best charm in the bag that beats hero i's ("" when none).
func better_charm(i: int) -> String:
	var mine: int = -1 if charm[i] < 0 else Items.CHARMS[charm[i]].rarity
	var best: String = ""
	for id: String in bag:
		if not Items.is_weapon(id) and Items.rarity(id) > mine and (best == "" or Items.rarity(id) > Items.rarity(best)):
			best = id
	return best


## Who gets charms first: the march squad, then the rest by rarity (highest first).
func charm_order() -> Array:
	var rest: Array = range(HEROES).filter(func(i: int) -> bool: return not march.has(i))
	rest.sort_custom(func(a: int, b: int) -> bool: return rarity(a) > rarity(b) or (rarity(a) == rarity(b) and a < b))
	return Array(march) + rest


## Equips every better weapon and hands out the charms (best first, charm_order()); the bag keeps the rest.
func auto_equip() -> void:
	for c: int in armory.size():
		var w: String = better_weapon(c)
		if w != "":
			equip_weapon(w)
	for i: int in charm_order():
		var id: String = better_charm(i)
		if id != "":
			equip_charm(i, id)


## 招募: `count` pulls paid with 招募券 (none when there are too few). Each is {hero, rarity, featured, shards}; the
## shards are added. `now` picks the banner's 限時 hero.
func recruit(count: int, now: int) -> Array:
	if count <= 0 or tickets < count:
		return []
	tickets -= count
	var out: Array = []
	for k: int in count:
		out.append(_pull_one(now))
	return out


## Whether today's 免費單抽 (for watching an ad) is still there.
func ad_pull_ready(now: int) -> bool:
	return Recruit.day(now) != ad_day or ad_pulls < Recruit.AD_PULLS_PER_DAY


## The 免費單抽 after an ad (or straight away with 免廣告): one pull, no ticket. {} when today's is used.
func free_pull(now: int) -> Dictionary:
	if not ad_pull_ready(now):
		return {}
	if Recruit.day(now) != ad_day:
		ad_day = Recruit.day(now)
		ad_pulls = 0
	ad_pulls += 1
	return _pull_one(now)


func _pull_one(now: int) -> Dictionary:
	pity += 1
	pulls += 1
	var r: int = Gacha.tier(_pull, Recruit.RATES, pity >= Recruit.PITY)
	var featured: int = Recruit.featured(now)
	# An SSR is the banner hero FEATURED_SHARE of the time, else one of the other SSRs.
	var hero: int = Gacha.pick(_pull, Recruit.pool(r), featured if r == PushSim.SSR else -1, Recruit.FEATURED_SHARE)
	if r == PushSim.SSR:
		pity = 0
	shards += Recruit.SHARDS[r]
	recent.insert(0, hero)
	recent.resize(mini(recent.size(), RECENT_SIZE))
	return {"hero": hero, "rarity": r, "featured": hero == featured, "shards": Recruit.SHARDS[r]}


## Pulls left until the 保底 SSR (this many more pulls make one certain).
func pity_left() -> int:
	return Recruit.PITY - pity


func owns(product_id: String) -> bool:
	return owned.has(product_id)


## Gives what a bought product holds (domain/shop.gd). False for an unknown product or a non-consumable already owned.
func grant(product_id: String) -> bool:
	var p: Dictionary = Shop.product(product_id)
	if p.is_empty() or owned.has(product_id):
		return false
	tickets += int(p.tickets)
	if p.kind == "non_consumable":
		owned.append(product_id)
	return true


## 看廣告 on a march claim: the claim's gold once more.
func double_march(got: Dictionary) -> int:
	gold += int(got.gold)
	return int(got.gold)


func to_dict() -> Dictionary:
	return {"version": SAVE_VERSION, "gold": gold, "shards": shards, "class_level": Array(class_level),
		"hero_level": Array(hero_level), "hero_exp": Array(hero_exp), "ascension": Array(ascension),
		"march": Array(march), "captains": Array(captains), "tips": Array(tips), "cleared": cleared, "march_since": march_since, "pushes": pushes, "wins": wins, "rng_state": str(_rng.state),
		"stones": stones, "armory": Array(armory), "armory_level": Array(armory_level), "charm": Array(charm),
		"relic_stars": Array(relic_stars), "bag": bag, "fresh": Array(fresh), "loot_state": str(_loot.state),
		"tickets": tickets, "pity": pity, "pulls": pulls, "recent": Array(recent), "ad_day": ad_day, "ad_pulls": ad_pulls,
		"owned": Array(owned), "pull_state": str(_pull.state)}


static func from_dict(d: Dictionary) -> RefCounted:
	var p := new()
	if int(d.get("version", 0)) != SAVE_VERSION:
		return p
	p.gold = int(d.gold)
	p.shards = int(d.shards)
	p.class_level = PackedInt32Array(d.class_level)
	p.hero_level = PackedInt32Array(d.hero_level)
	p.hero_exp = PackedInt32Array(d.hero_exp)
	p.ascension = PackedInt32Array(d.ascension)
	p.march = PackedInt32Array(d.march)
	p.captains = PackedInt32Array(d.get("captains", []))
	p.cleared = int(d.get("cleared", 0))
	p.tips = PackedStringArray(d.get("tips", []))
	p.march_since = int(d.get("march_since", 0))
	p.pushes = int(d.pushes)
	p.wins = int(d.wins)
	p._rng.state = int(d.rng_state)
	# 道具 came after the first saves: an older save loads with none.
	p.stones = int(d.get("stones", 0))
	if d.has("armory"):
		p.armory = PackedInt32Array(d.armory)
		p.armory_level = PackedInt32Array(d.armory_level)
		p.charm = PackedInt32Array(d.charm)
		p.relic_stars = PackedInt32Array(d.relic_stars)
		p.relic_stars.resize(Items.RELICS.size())
	for id: String in d.get("bag", {}):
		p.bag[id] = int(d.bag[id])
	p.fresh = PackedStringArray(d.get("fresh", []))
	if d.has("loot_state"):
		p._loot.state = int(d.loot_state)
	# 招募 came after 道具: an older save starts with the opening tickets.
	p.tickets = int(d.get("tickets", Recruit.START_TICKETS))
	p.pity = int(d.get("pity", 0))
	p.pulls = int(d.get("pulls", 0))
	p.recent = PackedInt32Array(d.get("recent", []))
	p.ad_day = int(d.get("ad_day", -1))
	p.ad_pulls = int(d.get("ad_pulls", 0))
	p.owned = PackedStringArray(d.get("owned", []))
	if d.has("pull_state"):
		p._pull.state = int(d.pull_state)
	return p


func save(path: String = SAVE_PATH) -> Error:
	return AtomicFile.write_text(path, JSON.stringify(to_dict()))


## The saved progress at `path`, or a fresh start when there is none (or it cannot be read).
static func load_from(path: String = SAVE_PATH) -> RefCounted:
	var bytes: PackedByteArray = AtomicFile.read_bytes(path)
	if bytes.is_empty():
		return new()
	var data: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	return from_dict(data) if data is Dictionary else new()
