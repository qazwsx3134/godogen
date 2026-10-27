extends "res://addons/proto_kit/test_kit.gd"
## 招募, the store and captains. The rules (domain/recruit.gd, progression.gd recruit()): the rates add up and 機率說明
## shows the same table the roll uses, 招募券 pay for pulls (none without them), a pulled hero brings 突破素材, the
## 保底 SSR by the PITY-th pull, the banner turns with the day, one 免費單抽 a day, products granted (免廣告 only once),
## pulls on their own random stream (shard and loot drops unchanged), everything saved and an older save starting with
## the opening tickets. Captains boost their 團 by rarity, two adding up. The store page is tests/test_home.gd.
##   godot --headless --path prototypes/hero-horde-idle --script res://tests/test_recruit.gd

const PushSim = preload("res://domain/push_sim.gd")
const Progression = preload("res://domain/progression.gd")
const Recruit = preload("res://domain/recruit.gd")
const Shop = preload("res://domain/shop.gd")
const SAVE_TEST := "user://progress_test_recruit.json"
const STORE_TEST := "user://store_test_recruit.json"
const NAV_H := 116
const DAY := 86400
const T0 := 1_800_000_000


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_rules()
	_captains()
	_finish("RECRUIT TESTS")


func _rules() -> void:
	_expect(Recruit.RATES.reduce(func(a: int, b: int) -> int: return a + b, 0) == 100, "the rates add up to 100%")
	var lines: PackedStringArray = Recruit.rates_lines()
	for r: int in 4:
		_expect(lines[r].begins_with("%s　%d%%" % [PushSim.RARITY_NAMES[r], Recruit.RATES[r]]),
			"機率說明 shows %s at the rolled %d%% (%s)" % [PushSim.RARITY_NAMES[r], Recruit.RATES[r], lines[r]])
	var p := Progression.new(5)
	_expect(p.tickets == Recruit.START_TICKETS, "a new save starts with %d 招募券" % Recruit.START_TICKETS)
	var shards0: int = p.shards
	var got: Array = p.recruit(Recruit.TEN, T0)
	var brought: int = got.reduce(func(a: int, one: Dictionary) -> int: return a + one.shards, 0)
	_expect(got.size() == 10 and p.tickets == 0 and p.shards - shards0 == brought, "十連: 10 heroes for 10 tickets, their 突破素材 added")
	var fair: bool = true
	for one: Dictionary in got:
		fair = fair and one.shards == Recruit.SHARDS[one.rarity] and Recruit.pool(one.rarity).has(one.hero)
	_expect(fair, "each pull is a hero of its rarity, bringing that rarity's shards")
	_expect(p.recruit(1, T0).is_empty() and p.tickets == 0, "no tickets, no pull")
	_expect(p.recent.size() == Progression.RECENT_SIZE and p.recent[0] == got[9].hero, "近期獲得 keeps the last five, newest first")

	# 保底: PITY pulls always hold an SSR.
	var q := Progression.new(9)
	q.tickets = 1000
	var since: int = 0
	var longest: int = 0
	var ssr: int = 0
	for k: int in 600:
		var one: Dictionary = q.recruit(1, T0)[0]
		since += 1
		if one.rarity == PushSim.SSR:
			ssr += 1
			longest = maxi(longest, since)
			since = 0
	_expect(longest <= Recruit.PITY and q.pity == since, "保底: never more than %d pulls without an SSR (longest %d)" % [Recruit.PITY, longest])
	_expect(ssr >= 600 * Recruit.RATES[3] / 100, "SSRs come at least at the base rate (%d in 600)" % ssr)
	# 機率說明's 限時 share: half of the SSRs are the banner hero, not more.
	var many := Progression.new(13)
	many.tickets = 20000
	var ssrs: int = 0
	var banner: int = 0
	for one: Dictionary in many.recruit(20000, T0):
		if one.rarity == PushSim.SSR:
			ssrs += 1
			banner += 1 if one.featured else 0
	var share: float = float(banner) / ssrs
	_expect(absf(share - Recruit.FEATURED_SHARE) < 0.04, "限時 hero is %d%% of %d SSRs (shown %d%%)" % [roundi(share * 100),
		ssrs, roundi(Recruit.FEATURED_SHARE * 100)])

	var day1: int = Recruit.featured(T0)
	_expect(Recruit.featured(T0 + DAY) != day1 and Recruit.pool(PushSim.SSR).has(day1), "the banner's SSR turns each day")
	_expect(Recruit.rotation_left(T0) == DAY - T0 % DAY, "卡池倒數 counts to the turn")

	var f := Progression.new(3)
	_expect(f.ad_pull_ready(T0) and not f.free_pull(T0).is_empty(), "today's 免費單抽")
	_expect(not f.ad_pull_ready(T0 + 60) and f.free_pull(T0 + 60).is_empty(), "only once a day")
	_expect(f.ad_pull_ready(T0 + DAY), "and again the next day")

	_expect(f.grant("tickets_10") and f.tickets == Recruit.START_TICKETS + 10, "招募券 ×10 adds ten")
	_expect(f.grant("no_ads") and f.owns("no_ads") and not f.grant("no_ads"), "免廣告 is bought once")
	_expect(not f.grant("nothing"), "an unknown product grants nothing")

	# Pulls never move the shard or loot drops.
	var a := Progression.new(21)
	var b := Progression.new(21)
	b.tickets = 100
	b.recruit(50, T0)
	var same: bool = true
	for k: int in 40:
		var ha: Dictionary = a.march_hour()
		var hb: Dictionary = b.march_hour()
		same = same and ha.shards == hb.shards and ha.items == hb.items
	_expect(same, "pulls do not shift the march's shard and item drops")

	_expect(f.save(SAVE_TEST) == OK, "progress saves")
	var back: RefCounted = Progression.load_from(SAVE_TEST)
	_expect(JSON.stringify(back.to_dict()) == JSON.stringify(f.to_dict()), "tickets, 保底, 近期, ad day and purchases load back")
	_expect(back.recruit(1, T0)[0] == f.recruit(1, T0)[0], "the pulls carry on the same stream after a load")
	var old: Dictionary = f.to_dict()
	for key: String in ["tickets", "pity", "pulls", "recent", "ad_day", "ad_pulls", "owned", "pull_state"]:
		old.erase(key)
	var older: RefCounted = Progression.from_dict(old)
	_expect(older.tickets == Recruit.START_TICKETS and older.owned.is_empty() and older.gold == f.gold,
		"a save from before 招募 keeps its progress and starts with the opening tickets")
	DirAccess.remove_absolute(SAVE_TEST)


func _captains() -> void:
	var p := Progression.new(2)
	var sword_ssr: int = _first(p, 1, PushSim.SSR)
	var bow: int = _first(p, 3, 0)
	var shield: int = _first(p, 0, 0)
	var melee0: float = p.power(shield)
	var ranged0: float = p.power(bow)
	p.toggle_captain(sword_ssr)
	_expect(is_equal_approx(p.power(shield) / melee0, 1.0 + Progression.CAPTAIN_BUFF[3]),
		"an SSR 劍 captain makes the 近戰團 +%d%% (盾 too)" % roundi(Progression.CAPTAIN_BUFF[3] * 100))
	_expect(is_equal_approx(p.power(bow), ranged0), "the 遠程團 is untouched")
	var spear_n: int = _first(p, 2, 0)
	p.toggle_captain(spear_n)
	_expect(is_equal_approx(p.captain_buff(0), Progression.CAPTAIN_BUFF[3] + Progression.CAPTAIN_BUFF[0]),
		"two captains of one 團 add up")
	var t0: float = Progression.new(2).team_power()
	_expect(p.team_power() > t0, "captains raise the 戰力")


func _first(p: RefCounted, c: int, r: int) -> int:
	for i: int in Progression.HEROES:
		if Progression.base_class(i) == c and p.rarity(i) == r:
			return i
	return -1
