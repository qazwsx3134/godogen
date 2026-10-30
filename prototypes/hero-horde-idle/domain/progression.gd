extends RefCounted
## 養成: what a player keeps between pushes, as pure state (no nodes; saved as JSON with godot-kit atomic_file).
##   gold     from pushes (by damage dealt) and the march's kills; spent on 訓練 (domain/talents.gd: army-wide
##            talents, the bulk of the strength)
##   shards   突破素材, from killing the stage boss, pulls and, by chance, march kills; spent on 突破 (ascension: +10
##            level cap, an SSR's 招牌技 grows, every ASCEND_PER_PROMOTE ascensions an N or R steps up a rarity, up to SR).
##            Every hero ascended at least once is 覺醒 in the 圖鑑: CODEX_PER more HP and attack for the whole army
##   march    the 行軍小隊 (slots(): 3, up to 5 with 訓練 結伴): only they earn hero EXP, so who marches is who grows.
##            The march is a real fight (domain/march_sim.gd) at march_stage: the home screen plays it and pays each
##            kill (march_kill); while the app is closed claim_offline() pays the time away (up to the cap) at the rate
##            measure_march() finds by playing the squad headless. Losing steps the march back a stage
##   cleared  the highest 關卡 cleared (domain/stages.gd); the next one is the one to push. A first clear pays
##            Stages.FIRST_GOLD (scaled by the stage) and FIRST_SHARDS, and moves the march to the new stage
##   tips     the first-push hints already shown (tip_once), so each appears once per save
##   items    道具 (domain/items.gd): every drop is its own piece with affixes. The 職業武庫 holds one weapon per class
##            (armory[c], its 強化 armory_level[c] paid in stones), each hero one 專屬飾品 (charm[i]); the bag the rest
##            (up to Items.BAG_MAX, the new ones marked 新 until seen). Drops at or under auto_salvage's rarity that
##            beat nothing equipped turn straight into 強化石. Relic stars from first clears. Loot rolls on its own stream
##   captains up to MAX_CAPTAINS heroes the player picked to lead (drawn larger in the push, with a nameplate). Each
##            gives their 團 (PushSim.CLASS_SQUAD: 近戰 盾劍槍, 遠程 弓法, 輔助 補) CAPTAIN_BUFF[rarity] more strength
##   招募     招募券 (tickets) buy pulls (domain/recruit.gd): a pulled hero brings 突破素材 by rarity; pity counts the
##            pulls since the last SSR; recent keeps the last pulled heroes. One 免費單抽 a day for a rewarded ad.
##            owned holds the non-consumable purchases (domain/shop.gd). Pulls roll on a third random stream
## Each hero is also a 形態 (domain/heroes.gd): a human's damage is x HUMAN_DAMAGE here; the monster's and the
## dreamling's passives ride along in roster() and march_units(). roster() hands everything to PushSim.new(). Heroes
## start at START_POWER of the push's reference strength: the first pushes are lost even when played well, and growth
## wins them (tests/test_progression.gd measures how many rounds that takes). Every number is a prototype constant.

const PushSim = preload("res://domain/push_sim.gd")
const MarchSim = preload("res://domain/march_sim.gd")
const Heroes = preload("res://domain/heroes.gd")
const Talents = preload("res://domain/talents.gd")
const Items = preload("res://domain/items.gd")
const Stages = preload("res://domain/stages.gd")
const Recruit = preload("res://domain/recruit.gd")
const Shop = preload("res://domain/shop.gd")
const AtomicFile = preload("res://addons/proto_kit/atomic_file.gd")
const Gacha = preload("res://addons/proto_kit/gacha.gd")

const SAVE_PATH := "user://progress.json"
const SAVE_VERSION := 2
const HEROES := 100
const START_POWER := 0.42
## Each hero level multiplies a hero's HP and attack by HERO_STEP.
const HERO_STEP := 1.03
const LEVEL_CAP := 10
const CAP_PER_ASCEND := 10
const MAX_ASCEND := 5
## Shards for ascension a -> a + 1.
const ASCEND_COST := [1, 2, 3, 4, 5]
const ASCEND_PER_PROMOTE := 2
## EXP for hero level L -> L + 1.
const EXP_PER_LEVEL := 600
## The squad a new save marches with: the shield, sword and healer SSRs (two humans and a human healer: 人類同行).
const START_MARCH := [13, 33, 99]
const MAX_SLOTS := 5
## A march kill at stage n pays KILL_GOLD x the stage's reward scale (x the march gold boosts) and KILL_EXP to each of
## the squad; it drops a shard, a 強化石 or an item this often. measure_march plays MEASURE_SECONDS to price an hour.
const KILL_GOLD := 8.5
const KILL_EXP := 1.0
const KILL_SHARD_CHANCE := 0.0003
const KILL_STONE_CHANCE := 0.003
## 經驗藥水, three sizes: each gives one hero `exp` EXP (levelling up to their cap), so heroes who never march grow too.
## A march kill drops each size by its `chance` (an elite x3); a fallen 樓層王 gives WIN_POTIONS, a first clear also
## FIRST_POTIONS.
const POTIONS := [{"name": "小經驗藥水", "exp": 500, "chance": 0.004}, {"name": "經驗藥水", "exp": 3000, "chance": 0.0005},
	{"name": "大經驗藥水", "exp": 15000, "chance": 0.0}]
const WIN_POTIONS := [0, 2, 0]
const FIRST_POTIONS := [0, 0, 1]
const KILL_LOOT_CHANCE := 0.002
const MEASURE_SECONDS := 90.0
const OFFLINE_CAP_HOURS := 8
## Offline time shorter than this is not reported (a quick app switch).
const OFFLINE_MIN := 60
const PUSH_GOLD_PER_DAMAGE := 1.0 / 4.0
const KILL_SHARDS := 3
const MAX_CAPTAINS := 3
const WIN_STONES := 6
## A won push of a stage already cleared adds a star to a random relic this often.
const RELIC_WIN_CHANCE := 0.15
## A captain's boost to their 團 by the captain's rarity (N, R, SR, SSR).
const CAPTAIN_BUFF := [0.03, 0.05, 0.08, 0.12]
## 圖鑑: each 覺醒 hero (ascended once or more) gives the whole army this much more HP and attack.
const CODEX_PER := 0.003
const RECENT_SIZE := 5

## Nonempty when loading/writing must preserve an unreadable or incompatible existing file.
var save_blocked_reason: String = ""

var gold: int = 0
var shards: int = 0
## 經驗藥水 held, by size (POTIONS order).
var potions := PackedInt32Array([0, 0, 0])
var stones: int = 0
var talent := PackedInt32Array()
## The 職業武庫's weapon per class and each hero's 專屬飾品: a piece (Items.make) or {} for an empty slot.
var armory: Array = []
var armory_level := PackedInt32Array()
var charm: Array = []
var relic_stars := PackedInt32Array()
## Unequipped pieces, oldest first.
var bag: Array = []
## The uids got since the 背包 page last showed them (the 新 badge).
var fresh := PackedInt32Array()
var next_uid: int = 1
## 自動分解: drops of this rarity or lower that beat nothing equipped become 強化石 (-1 = off, 0 = N, 1 = N and R).
var auto_salvage: int = -1
var hero_level := PackedInt32Array()
var hero_exp := PackedInt32Array()
var ascension := PackedInt32Array()
var march := PackedInt32Array()
var march_stage: int = 1
var march_kills: int = 0
var captains := PackedInt32Array()
var tips := PackedStringArray()
var pushes: int = 0
var cleared: int = 0
## Unix seconds the time away counts from (0 = not started: the first offline_seconds() starts it). The home screen
## keeps it at now while it plays the march, so only time with the app closed is paid offline.
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
## 經驗藥水 drops have their own stream too (added later: the other streams stay as they were).
var _potion := RandomNumberGenerator.new()


func _init(seed_value: int = 1) -> void:
	_rng.seed = seed_value
	_loot.seed = seed_value + 7919
	_pull.seed = seed_value + 15485863
	_potion.seed = seed_value + 32452843
	talent.resize(Talents.count())
	for c: int in PushSim.ROSTER.size():
		armory.append({})
	armory_level.resize(PushSim.ROSTER.size())
	armory_level.fill(1)
	for i: int in HEROES:
		charm.append({})
	relic_stars.resize(Items.RELICS.size())
	hero_level.resize(HEROES)
	hero_level.fill(1)
	hero_exp.resize(HEROES)
	ascension.resize(HEROES)
	march = PackedInt32Array(START_MARCH)


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


## Hero i's strength before the talents and affixes: levels, the armory's weapon, the charm, the captains, the 圖鑑.
func base_power(i: int) -> float:
	var c: int = base_class(i)
	return START_POWER * pow(HERO_STEP, hero_level[i] - 1) * weapon_mult(c) * charm_mult(i) * (1.0 + captain_buff(c)) \
		* codex_mult() * Talents.spec_mult(PushSim.CLASS_SQUAD[c], talent)


## Hero i's attack against the push's reference (1.0 = the balance tests' roster).
func atk_mult(i: int) -> float:
	return base_power(i) * talent_atk() * (1.0 + relic("atk")) \
		* (1.0 + affix_of(i, "atk")) * (Heroes.HUMAN_DAMAGE if Heroes.form(i) == Heroes.HUMAN else 1.0)


func hp_mult(i: int) -> float:
	return base_power(i) * talent_hp() * (1.0 + relic("hp")) * (1.0 + affix_of(i, "hp"))


## The talents' army-wide attack (劍術, 劍聖) and HP (耐力, 不屈).
func talent_atk() -> float:
	return pow(Talents.STEP, talent[Talents.SWORD]) * pow(Talents.MASTER_STEP, talent[Talents.MASTER])


func talent_hp() -> float:
	return pow(Talents.STEP, talent[Talents.STAMINA]) * pow(Talents.MASTER_STEP, talent[Talents.UNYIELDING])


## The highest hero level (天賦 nodes deeper in the tree wait for it).
func top_level() -> int:
	var top: int = 1
	for lv: int in hero_level:
		top = maxi(top, lv)
	return top


## What makes hero i's attack and HP (the 英雄 page's 數值明細): [{name, atk, hp}], one multiplier pair per source;
## START_POWER times every atk (hp) is atk_mult(i) (hp_mult(i)).
func stat_factors(i: int) -> Array:
	var c: int = base_class(i)
	var spec: float = Talents.spec_mult(PushSim.CLASS_SQUAD[c], talent)
	return [
		{"name": "等級", "atk": pow(HERO_STEP, hero_level[i] - 1), "hp": pow(HERO_STEP, hero_level[i] - 1)},
		{"name": "職業武庫", "atk": weapon_mult(c), "hp": weapon_mult(c)},
		{"name": "飾品", "atk": charm_mult(i), "hp": charm_mult(i)},
		{"name": "詞綴", "atk": 1.0 + affix_of(i, "atk"), "hp": 1.0 + affix_of(i, "hp")},
		{"name": "隊長", "atk": 1.0 + captain_buff(c), "hp": 1.0 + captain_buff(c)},
		{"name": "圖鑑", "atk": codex_mult(), "hp": codex_mult()},
		{"name": "天賦", "atk": talent_atk() * spec, "hp": talent_hp() * spec},
		{"name": "遺物", "atk": 1.0 + relic("atk"), "hp": 1.0 + relic("hp")},
		{"name": Heroes.PASSIVE_NAMES[Heroes.form(i)], "atk": Heroes.HUMAN_DAMAGE if Heroes.form(i) == Heroes.HUMAN else 1.0,
			"hp": 1.0},
	]


## How strong hero i is, in one number (attack and HP together).
func power(i: int) -> float:
	return sqrt(atk_mult(i) * hp_mult(i))


## The captains' boost to class c's 團 (0.17 = +17%).
func captain_buff(c: int) -> float:
	var total: float = 0.0
	for k: int in captains:
		if PushSim.CLASS_SQUAD[base_class(k)] == PushSim.CLASS_SQUAD[c]:
			total += CAPTAIN_BUFF[rarity(k)]
	return total * (1.0 + Talents.LEAD_STEP * talent[Talents.LEAD])


## The 職業武庫's boost for class c: its weapon, then its 強化 level (1 without a weapon).
func weapon_mult(c: int) -> float:
	if armory[c].is_empty():
		return 1.0
	return Items.WEAPON_MULT[Items.rarity(armory[c].id)] * pow(Items.ARMORY_STEP, armory_level[c] - 1) \
		* (1.0 + Talents.FORGE_STEP * talent[Talents.FORGE])


func weapon_rarity(c: int) -> int:
	return -1 if armory[c].is_empty() else Items.rarity(armory[c].id)


func charm_mult(i: int) -> float:
	return 1.0 if charm[i].is_empty() else Items.CHARM_MULT[Items.rarity(charm[i].id)] \
		* (1.0 + Talents.RESONANCE_STEP * talent[Talents.RESONANCE])


## The affix `key` reaching hero i: their class's weapon and their own charm.
func affix_of(i: int, key: String) -> float:
	return Items.affix(armory[base_class(i)], key) + Items.affix(charm[i], key)


## The sum of the relic effects with this key (Items.RELICS), e.g. 0.06 for two stars of +3%.
func relic(key: String) -> float:
	var total: float = 0.0
	for k: int in Items.RELICS.size():
		if Items.RELICS[k].key == key:
			total += Items.RELICS[k].per_star * relic_stars[k]
	return total


func codex_count() -> int:
	var n: int = 0
	for a: int in ascension:
		if a > 0:
			n += 1
	return n


func codex_mult() -> float:
	return 1.0 + CODEX_PER * codex_count()


## 訓練 速度: skill cooldowns x this (push and march).
func cooldown_mult() -> float:
	return 1.0 - Talents.SPEED_CD * talent[Talents.SPEED] - Talents.SWIFT_CD * talent[Talents.SWIFT]


## What PushSim.new(seed, roster) needs.
func roster() -> Dictionary:
	var r := {"rarity": PackedInt32Array(), "hp_mult": PackedFloat32Array(), "atk_mult": PackedFloat32Array(),
		"sig_level": PackedInt32Array(), "form": PackedInt32Array(), "cd_mult": cooldown_mult()}
	for i: int in HEROES:
		r.rarity.append(rarity(i))
		r.hp_mult.append(hp_mult(i))
		r.atk_mult.append(atk_mult(i))
		r.sig_level.append(ascension[i] if base_rarity(i) == PushSim.SSR else 0)
		r.form.append(Heroes.form(i))
	return r


# --- 天賦 -----------------------------------------------------------------------------------------------------

func talent_cost(k: int) -> int:
	return Talents.cost(k, talent[k])


func talent_open(k: int) -> bool:
	return Talents.open(k, talent, cleared, top_level())


## What talent row k still waits for ("" when open).
func talent_need(k: int) -> String:
	return Talents.need_text(k, talent, cleared, top_level())


## Buys one level of talent row k. 結伴 fills the new march slot with the strongest hero not marching.
func level_talent(k: int) -> bool:
	var cost: int = talent_cost(k)
	if cost < 0 or gold < cost or not talent_open(k):
		return false
	gold -= cost
	talent[k] += 1
	if k == Talents.COMPANY:
		fill_march()
	return true


# --- 行軍小隊 ---------------------------------------------------------------------------------------------------

func slots() -> int:
	return mini(Talents.BASE_SLOTS + talent[Talents.COMPANY], MAX_SLOTS)


## Puts hero i in march slot `slot` (a hero already marching swaps places with the one there).
func set_march(slot: int, i: int) -> void:
	var at: int = march.find(i)
	if at >= 0:
		march[at] = march[slot]
	march[slot] = i


func in_march(i: int) -> bool:
	return march.has(i)


## Sends hero i marching (into a free slot) or calls them back (the last one stays). False when nothing changed.
func toggle_march(i: int) -> bool:
	var at: int = march.find(i)
	if at >= 0:
		if march.size() <= 1:
			return false
		march.remove_at(at)
		return true
	if march.size() >= slots():
		return false
	march.append(i)
	return true


## Fills the free march slots with the strongest heroes not marching.
func fill_march() -> void:
	while march.size() < slots():
		var best: int = -1
		for i: int in HEROES:
			if not march.has(i) and (best < 0 or power(i) > power(best)):
				best = i
		march.append(best)


func bonds() -> Dictionary:
	return Heroes.bonds(march)


## The march squad as MarchSim units (stats from the push's base numbers x growth, the bonds and the passives).
func march_units() -> Array:
	var b: Dictionary = bonds()
	var rest: float = Talents.REST_REGEN * talent[Talents.REST]
	var out: Array = []
	for i: int in march:
		var c: int = base_class(i)
		var r: int = rarity(i)
		var base: Vector2 = PushSim.base_stats(c, r)
		var f: int = Heroes.form(i)
		var heal: float = 0.0
		if c == PushSim.HEALER:
			heal = MarchSim.HEAL * PushSim.RARITY_MULT[r] * (PushSim.PASSIVE_MULT if r >= PushSim.R else 1.0) * atk_mult(i)
		out.append({"hero": i, "cls": c, "rarity": r, "form": f,
			"hp": base.x * hp_mult(i) * (1.0 + b.hp), "atk": base.y * atk_mult(i) * (1.0 + b.atk), "heal": heal,
			"lifesteal": Heroes.BEAST_LIFESTEAL if f == Heroes.BEAST else 0.0,
			"regen": rest + (Heroes.ELF_REGEN if f == Heroes.ELF else 0.0),
			"heal_taken": Heroes.ELF_HEAL_TAKEN if f == Heroes.ELF else 1.0, "guard": b.guard})
	return out


## The march gold boosts together: relic, 訓練 拾光, the affixes of the armory and of the squad's charms.
func march_gold_mult() -> float:
	var affix: float = 0.0
	for c: int in armory.size():
		affix += Items.affix(armory[c], "gold")
	for i: int in march:
		affix += Items.affix(charm[i], "gold")
	return 1.0 + relic("march_gold") + Talents.FORTUNE_GOLD * talent[Talents.FORTUNE] + affix


func kill_gold(stage_n: int) -> int:
	return maxi(1, roundi(KILL_GOLD * Stages.stage(stage_n).reward * march_gold_mult()))


## The stages the march can be sent to: 1 up to the one being pushed.
func march_unlocked(n: int) -> bool:
	return unlocked(n)


func set_march_stage(n: int) -> bool:
	if not march_unlocked(n):
		return false
	march_stage = n
	return true


## The march lost: back a stage (not below 1).
func march_lost() -> void:
	march_stage = maxi(1, march_stage - 1)


## March EXP and item-drop boosts: the EXP relic, 天賦 學識 and 尋寶.
func exp_mult() -> float:
	return 1.0 + relic("exp") + Talents.STUDY_EXP * talent[Talents.STUDY]


func loot_mult() -> float:
	return 1.0 + Talents.TREASURE_LOOT * talent[Talents.TREASURE]


## A march kill: gold, EXP for the squad, and by chance a shard, a 強化石 or an item.
## Returns {gold, exp, levels: {hero: levels gained}, shards, stones, items, salvaged}.
func march_kill(stage_n: int, elite: bool = false) -> Dictionary:
	var mult: float = 3.0 if elite else 1.0
	var got := {"gold": roundi(kill_gold(stage_n) * mult), "exp": 0, "levels": {}, "shards": 0, "stones": 0, "potions": [0, 0, 0],
		"items": [], "salvaged": 0}
	gold += got.gold
	march_kills += 1
	got.exp = roundi(KILL_EXP * mult * exp_mult())
	got.levels = _give_exp(got.exp)
	if _rng.randf() < KILL_SHARD_CHANCE * mult:
		shards += 1
		got.shards = 1
	for k: int in POTIONS.size():
		if _potion.randf() < POTIONS[k].chance * mult:
			potions[k] += 1
			got.potions[k] += 1
	if _loot.randf() < KILL_STONE_CHANCE * mult:
		stones += 1
		got.stones = 1
	if _loot.randf() < KILL_LOOT_CHANCE * mult * loot_mult():
		_drop(got, Stages.region(stage_n), 0)
	return got


## EXP to every march hero, levelling up to each one's cap. Returns {hero: levels gained}.
func _give_exp(amount: int) -> Dictionary:
	var levels := {}
	for i: int in march:
		var gained: int = _hero_exp(i, amount)
		if gained > 0:
			levels[i] = gained
	return levels


## EXP to hero i, levelling up to their cap (EXP past the cap is lost). Returns the levels gained.
func _hero_exp(i: int, amount: int) -> int:
	var before: int = hero_level[i]
	hero_exp[i] += amount
	while hero_level[i] < hero_cap(i) and hero_exp[i] >= EXP_PER_LEVEL * hero_level[i]:
		hero_exp[i] -= EXP_PER_LEVEL * hero_level[i]
		hero_level[i] += 1
	if hero_level[i] >= hero_cap(i):
		hero_exp[i] = 0
	return hero_level[i] - before


## The march's pace now: plays the squad at march_stage (one stage lower each time it falls, which also moves the
## march there). Returns {stage, kills_per_sec, reward_units_per_sec}.
func measure_march() -> Dictionary:
	var units: Array = march_units()
	while true:
		var m: Dictionary = MarchSim.measure(units, march_stage, MEASURE_SECONDS, cooldown_mult())
		if not m.lost or march_stage == 1:
			return {"stage": march_stage, "kills_per_sec": m.kills_per_sec if not m.lost else 0.0,
				"reward_units_per_sec": m.reward_units_per_sec if not m.lost else 0.0}
		march_lost()
	return {}


func offline_cap_hours() -> int:
	return OFFLINE_CAP_HOURS + Talents.REST_HOURS * talent[Talents.REST] + Talents.LONG_MARCH_HOURS * talent[Talents.LONG_MARCH]


## Seconds away banked at `now` (unix seconds), at most the cap. A clock that went back restarts the count.
func offline_seconds(now: int) -> int:
	if march_since <= 0 or now < march_since:
		march_since = now
	return mini(now - march_since, offline_cap_hours() * 3600)


## The home screen is playing the march: time from here on is paid by the kills, not offline.
func keep_marching(now: int) -> void:
	march_since = now


## Resolves opening combat then estimates the remaining time and restarts the count. Returns {seconds, stage, kills, gold, shards,
## stones, items, salvaged, levels} (seconds 0 = nothing to pay).
func claim_offline(now: int) -> Dictionary:
	var seconds: int = offline_seconds(now)
	march_since = now
	if seconds < OFFLINE_MIN:
		return {"seconds": 0, "stage": march_stage, "kills": 0, "gold": 0, "shards": 0, "stones": 0, "potions": [0, 0, 0], "items": [],
			"salvaged": 0, "levels": {}}
	return _march_for(seconds)


## 行軍 1 小時 using the same offline settlement (the balance bots' march between pushes).
func march_hour() -> Dictionary:
	return _march_for(3600)


## Resolve the first five minutes with combat/retreat/growth, then estimate the remaining time.
## Work is bounded for long absences; no player interaction or automatic equipment changes are simulated.
func _march_for(seconds: int) -> Dictionary:
	var simulated_seconds := mini(seconds, 300)
	var got := {"seconds": seconds, "stage": march_stage, "kills": 0, "gold": 0, "shards": 0,
		"stones": 0, "potions": [0, 0, 0], "items": [], "salvaged": 0, "levels": {}}
	var sim := MarchSim.new(4242, march_units(), march_stage, cooldown_mult())
	var recovering := 0.0
	var pending := false
	for tick: int in simulated_seconds * 20:
		if recovering > 0.0:
			recovering -= MarchSim.TICK
			if recovering <= 0.0:
				sim = MarchSim.new(4242, march_units(), march_stage, cooldown_mult())
				pending = false
			continue
		sim.step(MarchSim.TICK)
		for event: Dictionary in sim.take_events():
			if event.kind == &"kill":
				_merge_march_rewards(got, march_kill(event.stage, event.elite))
				got.kills += 1
				pending = true
			elif event.kind == &"travel" and pending:
				sim = MarchSim.new(4242, march_units(), march_stage, cooldown_mult())
				sim.travel_t = MarchSim.TRAVEL_TIME
				pending = false
			elif event.kind == &"lost":
				march_lost()
				recovering = 2.0
	if seconds > simulated_seconds:
		var estimated := _estimate_march(seconds - simulated_seconds)
		_merge_march_rewards(got, estimated)
		got.kills += estimated.kills
	got.stage = march_stage
	return got


static func _merge_march_rewards(total: Dictionary, part: Dictionary) -> void:
	for key: String in ["gold", "shards", "stones", "salvaged"]:
		total[key] += part[key]
	for k: int in 3:
		total.potions[k] += part.potions[k]
	for hero: int in part.levels:
		total.levels[hero] = int(total.levels.get(hero, 0)) + int(part.levels[hero])
	total.items.append_array(part.items)


func _estimate_march(seconds: int) -> Dictionary:
	var pace: Dictionary = measure_march()
	var kills: float = pace.kills_per_sec * seconds
	# Elite kills count once in the kill ledger and three times in reward expectations.
	var reward_units: float = pace.reward_units_per_sec * seconds
	var got := {"seconds": seconds, "stage": pace.stage, "kills": roundi(kills), "items": [], "salvaged": 0}
	got.gold = roundi(reward_units * kill_gold(pace.stage))
	gold += got.gold
	march_kills += got.kills
	got.levels = _give_exp(roundi(reward_units * KILL_EXP * exp_mult()))
	got.shards = _chances(_rng, reward_units * KILL_SHARD_CHANCE)
	shards += got.shards
	got.stones = _chances(_loot, reward_units * KILL_STONE_CHANCE)
	stones += got.stones
	got.potions = [0, 0, 0]
	for k: int in POTIONS.size():
		got.potions[k] = _chances(_potion, reward_units * POTIONS[k].chance)
		potions[k] += got.potions[k]
	for k: int in _chances(_loot, reward_units * KILL_LOOT_CHANCE * loot_mult()):
		_drop(got, Stages.region(pace.stage), 0)
	return got


## An expected count as a whole number: its whole part, plus one more with the leftover's chance.
static func _chances(rng: RandomNumberGenerator, expected: float) -> int:
	var whole: int = floori(expected)
	return whole + (1 if rng.randf() < expected - whole else 0)


## Rolls one item into `got` (kept in the bag, or counted in got.salvaged).
func _drop(got: Dictionary, region_index: int, floor_rarity: int) -> void:
	var item: Dictionary = roll_loot(region_index, floor_rarity)
	if add_item(item):
		got.items.append(item)
	else:
		got.salvaged += 1


# --- 關卡與推王 --------------------------------------------------------------------------------------------------

## The stage to push next: the one after the highest cleared (the last stays open once all are cleared).
func next_stage() -> int:
	return mini(cleared + 1, Stages.COUNT)


func unlocked(n: int) -> bool:
	return n >= 1 and n <= next_stage()


## A finished push of stage n pays out: gold by the damage dealt, shards when the boss fell, and the first-clear
## bonus the first time stage n falls (which opens the next stage, moves the march there and gives
## Recruit.FIRST_TICKETS 招募券). A fallen boss also drops 強化石 and an item (R or better), and a relic star: always
## on the first clear, by chance after. Returns {gold, shards, stones, items, salvaged, relic (-1 for none), tickets,
## won, first}.
func push_rewards(sim: PushSim, n: int = 1) -> Dictionary:
	var won: bool = sim.phase == PushSim.Phase.WON
	var got := {"gold": roundi(sim.damage_dealt * PUSH_GOLD_PER_DAMAGE), "shards": KILL_SHARDS if won else 0, "won": won,
		"first": won and n > cleared, "stones": 0, "potions": [0, 0, 0], "items": [], "salvaged": 0, "relic": -1, "tickets": 0}
	if won:
		for k: int in POTIONS.size():
			got.potions[k] = WIN_POTIONS[k] + (FIRST_POTIONS[k] if got.first else 0)
			potions[k] += got.potions[k]
		got.stones = WIN_STONES + 2 * (n - 1)
		stones += got.stones
		_drop(got, Stages.region(n), 1)
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
		march_stage = next_stage()
	gold += got.gold
	shards += got.shards
	pushes += 1
	if won:
		wins += 1
	return got


# --- 突破、隊長、提示 ---------------------------------------------------------------------------------------------

func ascend_cost(i: int) -> int:
	return ASCEND_COST[ascension[i]] if ascension[i] < MAX_ASCEND else -1


func ascend(i: int) -> bool:
	var cost: int = ascend_cost(i)
	if cost < 0 or shards < cost:
		return false
	shards -= cost
	ascension[i] += 1
	return true


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


## `count` 經驗藥水 of size k on hero i: each gives POTIONS[k].exp EXP; none are used once the hero is at their cap.
## Returns {used, levels}.
func use_potions(i: int, k: int, count: int = 1) -> Dictionary:
	var out := {"used": 0, "levels": 0}
	while out.used < count and potions[k] > 0 and hero_level[i] < hero_cap(i):
		potions[k] -= 1
		out.used += 1
		out.levels += _hero_exp(i, POTIONS[k].exp)
	return out


func potion_total() -> int:
	var n: int = 0
	for c: int in potions:
		n += c
	return n


## What can be done right now (the 總覽's 待辦 and the nav bar's dots), most useful first, as {kind, text, tab}:
## "talent" (the cheapest 訓練 the gold covers), "ascend" (a march hero the shards cover), "slot" (a free march
## slot), "equip" (a better piece in the bag), "armory" (a 強化 the stones cover), "captain" (none picked yet),
## "recruit" (a 十連's tickets), "push" (the next stage boss: first of all before the first push, else last).
func todo() -> Array:
	var out: Array = []
	var push := {"kind": "push", "text": "挑戰樓層王 %s %s（推王）" % [Stages.label(next_stage()), Stages.boss_name(next_stage())],
		"tab": &"adventure"}
	if pushes == 0:
		out.append(push)
	var best: int = -1
	for k: int in talent.size():
		var cost: int = talent_cost(k)
		if cost >= 0 and talent_open(k) and gold >= cost and (best < 0 or cost < talent_cost(best)):
			best = k
	if best >= 0:
		out.append({"kind": "talent", "text": "天賦 %s 可以點亮到 Lv%d（%d 金）" % [Talents.ROWS[best].name, talent[best] + 1,
			talent_cost(best)], "tab": &"train"})
	for i: int in march:
		var cost: int = ascend_cost(i)
		if cost > 0 and shards >= cost:
			out.append({"kind": "ascend", "text": "行軍小隊有英雄可以突破（%d 素材）" % cost, "tab": &"heroes"})
			break
	if march.size() < slots():
		out.append({"kind": "slot", "text": "行軍小隊還有空位", "tab": &"heroes"})
	var equip: bool = range(armory.size()).any(func(c: int) -> bool: return better_weapon(c) >= 0)
	for i: int in march:
		equip = equip or better_charm(i) >= 0
	if equip:
		out.append({"kind": "equip", "text": "背包裡有更好的裝備可以換上", "tab": &"heroes"})
	var cheapest: int = -1
	for c: int in armory.size():
		if armory_cost(c) > 0 and (cheapest < 0 or armory_cost(c) < armory_cost(cheapest)):
			cheapest = c
	if cheapest >= 0 and stones >= armory_cost(cheapest):
		out.append({"kind": "armory", "text": "%s職業武庫可以強化到 Lv%d（%d 強化石）" % [PushSim.CLASS_NAMES[cheapest],
			armory_level[cheapest] + 1, armory_cost(cheapest)], "tab": &"heroes"})
	if captains.is_empty():
		out.append({"kind": "captain", "text": "還沒有隊長：在英雄頁挑 1～3 名，他們的團會變強", "tab": &"heroes"})
	if tickets >= Recruit.TEN:
		out.append({"kind": "recruit", "text": "招募券有 %d 張，可以十連招募" % tickets, "tab": &"store"})
	if pushes > 0:
		out.append(push)
	return out


## The whole roster's average strength against the push's reference (1.0); compare with Stages.recommended().
func team_power() -> float:
	var total: float = 0.0
	for i: int in HEROES:
		total += power(i)
	return total / HEROES


## 一鍵養成: spends everything the same way every time: the cheapest open talent until gold runs out, then shards on
## the march squad in slot order, the best gear, the 強化. The balance bots use it, so both play the same growth.
func auto_spend() -> void:
	while true:
		var best: int = -1
		for k: int in talent.size():
			if talent_cost(k) >= 0 and talent_open(k) and (best < 0 or talent_cost(k) < talent_cost(best)):
				best = k
		if best < 0 or not level_talent(best):
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


# --- 道具 -----------------------------------------------------------------------------------------------------

## Rolls one piece from the region's odds (at least `floor_rarity`); it is not in the bag yet (add_item).
func roll_loot(region_index: int, floor_rarity: int) -> Dictionary:
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
	var item: Dictionary = Items.make(next_uid, id, _loot)
	next_uid += 1
	return item


## A new piece of base `id` (tests, rewards); not in the bag yet.
func new_item(id: String) -> Dictionary:
	var item: Dictionary = Items.make(next_uid, id, _loot)
	next_uid += 1
	return item


## Puts a piece in the bag, marked 新; or turns it into 強化石 when 自動分解 covers it (and it beats nothing equipped)
## or the bag is full. True when it was kept.
func add_item(item: Dictionary) -> bool:
	var r: int = Items.rarity(item.id)
	if bag.size() >= Items.BAG_MAX or (r <= auto_salvage and not _beats_equipped(item)):
		stones += Items.SALVAGE[r]
		return false
	bag.append(item)
	fresh.append(item.uid)
	return true


func _beats_equipped(item: Dictionary) -> bool:
	if Items.is_weapon(item.id):
		return Items.score(item) > Items.score(armory[Items.weapon_class(item.id)])
	for i: int in march:
		if Items.score(item) > Items.score(charm[i]):
			return true
	return false


func bag_index(uid: int) -> int:
	for k: int in bag.size():
		if bag[k].uid == uid:
			return k
	return -1


func _take(uid: int) -> Dictionary:
	var k: int = bag_index(uid)
	if k < 0:
		return {}
	var item: Dictionary = bag[k]
	bag.remove_at(k)
	var at: int = fresh.find(uid)
	if at >= 0:
		fresh.remove_at(at)
	return item


## Puts a weapon from the bag in its class's 職業武庫 (the one there goes back to the bag; the slot keeps its level).
func equip_weapon(uid: int) -> bool:
	var k: int = bag_index(uid)
	if k < 0 or not Items.is_weapon(bag[k].id):
		return false
	var item: Dictionary = _take(uid)
	var c: int = Items.weapon_class(item.id)
	if not armory[c].is_empty():
		bag.append(armory[c])
	armory[c] = item
	return true


## Gives hero i a 專屬飾品 from the bag (theirs goes back to the bag).
func equip_charm(i: int, uid: int) -> bool:
	var k: int = bag_index(uid)
	if k < 0 or Items.is_weapon(bag[k].id):
		return false
	var item: Dictionary = _take(uid)
	if not charm[i].is_empty():
		bag.append(charm[i])
	charm[i] = item
	return true


## 分解: one piece from the bag into 強化石 (Items.SALVAGE by rarity).
func salvage(uid: int) -> bool:
	var item: Dictionary = _take(uid)
	if item.is_empty():
		return false
	stones += Items.SALVAGE[Items.rarity(item.id)]
	return true


## Salvages every bag piece of `max_rarity` or lower. Returns how many.
func salvage_up_to(max_rarity: int) -> int:
	var uids: Array = []
	for item: Dictionary in bag:
		if Items.rarity(item.id) <= max_rarity:
			uids.append(item.uid)
	for uid: int in uids:
		salvage(uid)
	return uids.size()


## 強化石 for class c's slot level L -> L + 1 (-1 without a weapon or at the top).
func armory_cost(c: int) -> int:
	return armory_level[c] if not armory[c].is_empty() and armory_level[c] < Items.ARMORY_MAX else -1


func upgrade_armory(c: int) -> bool:
	var cost: int = armory_cost(c)
	if cost < 0 or stones < cost:
		return false
	stones -= cost
	armory_level[c] += 1
	return true


## The best weapon in the bag for class c that beats the equipped one (its uid, -1 when none).
func better_weapon(c: int) -> int:
	var best: int = -1
	var best_score: float = Items.score(armory[c])
	for item: Dictionary in bag:
		if Items.is_weapon(item.id) and Items.weapon_class(item.id) == c and Items.score(item) > best_score:
			best = item.uid
			best_score = Items.score(item)
	return best


## The best charm in the bag that beats hero i's (its uid, -1 when none).
func better_charm(i: int) -> int:
	var best: int = -1
	var best_score: float = Items.score(charm[i])
	for item: Dictionary in bag:
		if not Items.is_weapon(item.id) and Items.score(item) > best_score:
			best = item.uid
			best_score = Items.score(item)
	return best


## Who gets charms first: the march squad, then the rest by rarity (highest first).
func charm_order() -> Array:
	var rest: Array = range(HEROES).filter(func(i: int) -> bool: return not march.has(i))
	rest.sort_custom(func(a: int, b: int) -> bool: return rarity(a) > rarity(b) or (rarity(a) == rarity(b) and a < b))
	return Array(march) + rest


## Equips every better weapon and hands out the charms (best first, charm_order()); the bag keeps the rest.
func auto_equip() -> void:
	for c: int in armory.size():
		var w: int = better_weapon(c)
		if w >= 0:
			equip_weapon(w)
	for i: int in charm_order():
		var uid: int = better_charm(i)
		if uid >= 0:
			equip_charm(i, uid)


# --- 招募與商店 -------------------------------------------------------------------------------------------------

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


## 看廣告 on an offline claim: the claim's gold once more.
func double_offline(got: Dictionary) -> int:
	gold += int(got.gold)
	return int(got.gold)


# --- 存檔 -------------------------------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"version": SAVE_VERSION, "gold": gold, "shards": shards, "talent": Array(talent),
		"hero_level": Array(hero_level), "hero_exp": Array(hero_exp), "ascension": Array(ascension),
		"march": Array(march), "march_stage": march_stage, "march_kills": march_kills, "captains": Array(captains),
		"tips": Array(tips), "cleared": cleared, "march_since": march_since, "pushes": pushes, "wins": wins,
		"rng_state": str(_rng.state), "stones": stones, "armory": armory, "armory_level": Array(armory_level),
		"charm": charm, "relic_stars": Array(relic_stars), "bag": bag, "fresh": Array(fresh), "next_uid": next_uid,
		"auto_salvage": auto_salvage, "loot_state": str(_loot.state), "tickets": tickets, "pity": pity, "pulls": pulls,
		"recent": Array(recent), "ad_day": ad_day, "ad_pulls": ad_pulls, "owned": Array(owned),
		"pull_state": str(_pull.state), "potions": Array(potions), "potion_state": str(_potion.state)}


static func from_dict(d: Dictionary) -> RefCounted:
	var version: int = int(d.get("version", 0))
	if version == 1:
		return _from_v1(d)
	var p := new()
	if version != SAVE_VERSION:
		return p
	p.gold = int(d.gold)
	p.shards = int(d.shards)
	p.talent = PackedInt32Array(d.talent)
	p.talent.resize(Talents.count())
	p.hero_level = PackedInt32Array(d.hero_level)
	p.hero_exp = PackedInt32Array(d.hero_exp)
	p.ascension = PackedInt32Array(d.ascension)
	p.march = PackedInt32Array(d.march)
	p.march_stage = int(d.get("march_stage", 1))
	p.march_kills = int(d.get("march_kills", 0))
	p.captains = PackedInt32Array(d.get("captains", []))
	p.cleared = int(d.get("cleared", 0))
	p.tips = PackedStringArray(d.get("tips", []))
	p.march_since = int(d.get("march_since", 0))
	p.pushes = int(d.pushes)
	p.wins = int(d.wins)
	p._rng.state = int(d.rng_state)
	p.stones = int(d.get("stones", 0))
	p.armory = d.armory.map(func(x: Dictionary) -> Dictionary: return Items.normalize(x))
	p.armory_level = PackedInt32Array(d.armory_level)
	p.charm = d.charm.map(func(x: Dictionary) -> Dictionary: return Items.normalize(x))
	p.relic_stars = PackedInt32Array(d.relic_stars)
	p.relic_stars.resize(Items.RELICS.size())
	p.bag = d.bag.map(func(x: Dictionary) -> Dictionary: return Items.normalize(x))
	p.fresh = PackedInt32Array(d.get("fresh", []))
	p.next_uid = int(d.get("next_uid", 1))
	p.auto_salvage = int(d.get("auto_salvage", -1))
	p._loot.state = int(d.loot_state)
	p._read_recruit(d)
	return p


## A save from before 訓練 and pieces (version 1, gold at a tenth of today's): its gold and every class level's cost
## come back x10, the march keeps its first slots(), and each held item becomes a piece without affixes.
static func _from_v1(d: Dictionary) -> RefCounted:
	var p := new()
	p.gold = int(d.gold) * 10
	for lv: int in d.get("class_level", []):
		for l: int in range(1, int(lv)):
			p.gold += roundi(1000.0 * pow(1.08, l - 1))
	p.shards = int(d.shards)
	p.hero_level = PackedInt32Array(d.hero_level)
	p.hero_exp = PackedInt32Array(d.hero_exp)
	p.ascension = PackedInt32Array(d.ascension)
	var old_march := PackedInt32Array(d.march)
	p.march = old_march.slice(0, p.slots())
	p.captains = PackedInt32Array(d.get("captains", []))
	p.cleared = int(d.get("cleared", 0))
	p.march_stage = p.next_stage()
	p.tips = PackedStringArray(d.get("tips", []))
	p.march_since = int(d.get("march_since", 0))
	p.pushes = int(d.pushes)
	p.wins = int(d.wins)
	p._rng.state = int(d.rng_state)
	p.stones = int(d.get("stones", 0))
	if d.has("armory"):
		for c: int in p.armory.size():
			if int(d.armory[c]) >= 0:
				p.armory[c] = {"uid": p.next_uid, "id": Items.weapon_id(c, int(d.armory[c])), "aff": []}
				p.next_uid += 1
		p.armory_level = PackedInt32Array(d.armory_level)
		for i: int in HEROES:
			if int(d.charm[i]) >= 0:
				p.charm[i] = {"uid": p.next_uid, "id": Items.charm_id(int(d.charm[i])), "aff": []}
				p.next_uid += 1
		p.relic_stars = PackedInt32Array(d.relic_stars)
		p.relic_stars.resize(Items.RELICS.size())
	for id: String in d.get("bag", {}):
		for n: int in int(d.bag[id]):
			p.bag.append({"uid": p.next_uid, "id": id, "aff": []})
			p.next_uid += 1
	if d.has("loot_state"):
		p._loot.state = int(d.loot_state)
	p._read_recruit(d)
	return p


func _read_recruit(d: Dictionary) -> void:
	tickets = int(d.get("tickets", Recruit.START_TICKETS))
	pity = int(d.get("pity", 0))
	pulls = int(d.get("pulls", 0))
	recent = PackedInt32Array(d.get("recent", []))
	ad_day = int(d.get("ad_day", -1))
	ad_pulls = int(d.get("ad_pulls", 0))
	owned = PackedStringArray(d.get("owned", []))
	if d.has("pull_state"):
		_pull.state = int(d.pull_state)
	var held: Variant = d.get("potions", 0)
	# A save from when there was one size: those were levels, now the small ones.
	potions = PackedInt32Array(held) if held is Array else PackedInt32Array([int(held), 0, 0])
	potions.resize(POTIONS.size())
	if d.has("potion_state"):
		_potion.state = int(d.potion_state)


func save(path: String = SAVE_PATH) -> Error:
	if not save_blocked_reason.is_empty():
		return ERR_FILE_CANT_WRITE
	# Also protect a file replaced by a newer build while this instance was running.
	var existing := _read_save(path)
	if existing.error not in ["", "missing"]:
		save_blocked_reason = existing.error
		return ERR_FILE_CANT_WRITE
	var snapshot := to_dict()
	if not _valid_payload(snapshot):
		return ERR_INVALID_DATA
	return AtomicFile.write_text(path, JSON.stringify(snapshot))


## Missing files start fresh; incompatible/unreadable files keep their original bytes and block writes.
static func load_from(path: String = SAVE_PATH) -> RefCounted:
	var saved := _read_save(path)
	if saved.error == "":
		return from_dict(saved.data)
	var progress := new()
	if saved.error != "missing":
		progress.save_blocked_reason = saved.error
	return progress


static func _read_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"error": "missing"}
	var json := JSON.new()
	var bytes := AtomicFile.read_bytes(path)
	if bytes.is_empty() or json.parse(bytes.get_string_from_utf8()) != OK or not json.data is Dictionary:
		return {"error": "corrupt"}
	var data: Dictionary = json.data
	var version: Variant = data.get("version")
	if not (version is int or version is float) or not is_finite(float(version)) or floorf(float(version)) != float(version):
		return {"error": "corrupt"}
	if float(version) > SAVE_VERSION:
		return {"error": "newer"}
	if float(version) != 1.0 and float(version) != float(SAVE_VERSION):
		return {"error": "unsupported"}
	if not _valid_payload(data):
		return {"error": "corrupt"}
	return {"error": "", "data": data}


## Validate persisted input before any conversion, resize or item normalization can discard data.
static func _valid_payload(d: Dictionary) -> bool:
	var current := new().to_dict()
	for key: String in d:
		if not current.has(key) and not (int(d.version) == 1 and key == "class_level"):
			return false
	for key: String in ["gold", "shards", "hero_level", "hero_exp", "ascension", "march", "pushes", "wins", "rng_state"]:
		if not d.has(key):
			return false
	for key: String in current:
		if current[key] is int and d.has(key):
			if not _save_integer(d[key], -1 if key in ["ad_day", "auto_salvage"] else 0):
				return false
	for key: String in ["rng_state", "loot_state", "pull_state", "potion_state"]:
		if d.has(key):
			var state: Variant = d[key]
			if state is String:
				if not state.is_valid_int() or str(int(state)) != state:
					return false
			elif not _save_integer(state, -9007199254740991):
				return false
	for key: String in ["hero_level", "hero_exp", "ascension"]:
		var maximum: int = LEVEL_CAP + CAP_PER_ASCEND * MAX_ASCEND if key == "hero_level" else (MAX_ASCEND if key == "ascension" else 2147483647)
		if not _save_int_array(d[key], 1 if key == "hero_level" else 0, maximum) or d[key].size() != HEROES:
			return false
	if not _save_int_array(d.march, 0, HEROES - 1) or d.march.is_empty() or d.march.size() > MAX_SLOTS or not _save_unique(d.march):
		return false
	if not _save_int_array(d.get("captains", []), 0, HEROES - 1) or d.get("captains", []).size() > MAX_CAPTAINS or not _save_unique(d.get("captains", [])):
		return false
	if not _save_int_array(d.get("recent", []), 0, HEROES - 1) or d.get("recent", []).size() > RECENT_SIZE:
		return false
	for key: String in ["tips", "owned"]:
		if not d.get(key, []) is Array:
			return false
		for entry: Variant in d.get(key, []):
			if not entry is String:
				return false
	if int(d.get("cleared", 0)) > Stages.COUNT or int(d.get("march_stage", 1)) not in range(1, Stages.COUNT + 1):
		return false
	var potions_data: Variant = d.get("potions", 0)
	if potions_data is Array:
		if not _save_int_array(potions_data) or potions_data.size() > POTIONS.size():
			return false
	elif not _save_integer(potions_data, 0, 2147483647):
		return false
	if int(d.version) == 1:
		return _valid_legacy_payload(d)
	for key: String in ["talent", "armory", "armory_level", "charm", "relic_stars", "bag", "loot_state"]:
		if not d.has(key):
			return false
	if not _save_int_array(d.talent) or d.talent.size() > Talents.count():
		return false
	for k: int in d.talent.size():
		if d.talent[k] > Talents.ROWS[k].max:
			return false
	if not _save_int_array(d.armory_level, 0, Items.ARMORY_MAX) or d.armory_level.size() != PushSim.ROSTER.size():
		return false
	if not _save_int_array(d.relic_stars, 0, Items.MAX_STARS) or d.relic_stars.size() > Items.RELICS.size():
		return false
	if not _save_int_array(d.get("fresh", []), 1) or int(d.get("auto_salvage", -1)) not in [-1, 0, 1]:
		return false
	if not d.armory is Array or d.armory.size() != PushSim.ROSTER.size() or not d.charm is Array or d.charm.size() != HEROES:
		return false
	if not d.bag is Array or d.bag.size() > Items.BAG_MAX:
		return false
	var uids := {}
	for k: int in d.armory.size():
		if not _valid_save_piece(d.armory[k], uids, true):
			return false
		if not d.armory[k].is_empty() and (not Items.is_weapon(d.armory[k].id) or Items.weapon_class(d.armory[k].id) != k):
			return false
	for piece: Variant in d.charm:
		if not _valid_save_piece(piece, uids, true):
			return false
		if not piece.is_empty() and Items.is_weapon(piece.id):
			return false
	for piece: Variant in d.bag:
		if not _valid_save_piece(piece, uids, false):
			return false
	var next: Variant = d.get("next_uid", 1)
	if not _save_integer(next, 1, 2147483647):
		return false
	for uid: int in uids:
		if uid >= int(next):
			return false
	return true


static func _valid_legacy_payload(d: Dictionary) -> bool:
	if not _save_int_array(d.get("class_level", []), 1):
		return false
	if d.get("class_level", []).size() > PushSim.ROSTER.size():
		return false
	if d.has("armory"):
		if not _save_int_array(d.armory, -1, Items.RARITY_NAMES.size() - 1) or d.armory.size() != PushSim.ROSTER.size():
			return false
		if not _save_int_array(d.get("armory_level"), 0, Items.ARMORY_MAX) or d.armory_level.size() != PushSim.ROSTER.size():
			return false
		if not _save_int_array(d.get("charm"), -1, Items.CHARMS.size() - 1) or d.charm.size() != HEROES:
			return false
		if not _save_int_array(d.get("relic_stars"), 0, Items.MAX_STARS) or d.relic_stars.size() > Items.RELICS.size():
			return false
	if not d.get("bag", {}) is Dictionary:
		return false
	var count := 0
	for id: Variant in d.get("bag", {}):
		if not id is String or not _known_save_item(id) or not _save_integer(d.bag[id], 0, Items.BAG_MAX):
			return false
		count += int(d.bag[id])
	return count <= Items.BAG_MAX


static func _valid_save_piece(piece: Variant, uids: Dictionary, allow_empty: bool) -> bool:
	if not piece is Dictionary:
		return false
	if piece.is_empty():
		return allow_empty
	for key: Variant in piece:
		if key not in ["uid", "id", "aff"]:
			return false
	if not _save_integer(piece.get("uid"), 1, 2147483647) or not piece.get("id") is String or not _known_save_item(piece.id):
		return false
	var uid := int(piece.uid)
	if uids.has(uid):
		return false
	uids[uid] = true
	if not piece.get("aff", []) is Array:
		return false
	var affixes := {}
	for pair: Variant in piece.get("aff", []):
		if not pair is Array or pair.size() != 2 or pair[0] not in Items.AFFIX_KEYS or affixes.has(pair[0]):
			return false
		if not (pair[1] is int or pair[1] is float) or not is_finite(float(pair[1])):
			return false
		affixes[pair[0]] = true
	return true


static func _known_save_item(id: String) -> bool:
	for c: int in Items.WEAPONS.size():
		for rarity: int in Items.RARITY_NAMES.size():
			if id == Items.weapon_id(c, rarity):
				return true
	for k: int in Items.CHARMS.size():
		if id == Items.charm_id(k):
			return true
	return false


static func _save_integer(value: Variant, minimum: int = 0, maximum: int = 9007199254740991) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and floorf(float(value)) == float(value) and value >= minimum and value <= maximum


static func _save_int_array(value: Variant, minimum: int = 0, maximum: int = 2147483647) -> bool:
	if not value is Array:
		return false
	for entry: Variant in value:
		if not _save_integer(entry, minimum, maximum):
			return false
	return true


static func _save_unique(values: Array) -> bool:
	var seen := {}
	for value: Variant in values:
		if seen.has(int(value)):
			return false
		seen[int(value)] = true
	return true
