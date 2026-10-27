extends RefCounted
## 招募 (gacha) rules, as pure data. Every hero is on the roster from the start, so a pulled hero comes as their
## 英雄之魂: SHARDS 突破素材 by the hero's rarity. A pull costs one 招募券; 十連 ten. RATES is both what the roll uses
## and what 機率說明 shows (the page reads it from here, tests/test_recruit.gd checks they match). PITY pulls without an
## SSR make the next one an SSR (保底), and an SSR is the banner's 限時 hero FEATURED_SHARE of the time. The banner
## turns to the next SSR every ROTATION seconds of the clock. The rolls are godot-kit's gacha.gd, called from
## progression.gd (recruit()) on its own random stream.

const PushSim = preload("res://domain/push_sim.gd")

## Percent chance of N, R, SR, SSR per pull.
const RATES := [55, 30, 12, 3]
const PITY := 30
const FEATURED_SHARE := 0.5
## 突破素材 a pulled hero brings, by rarity.
const SHARDS := [1, 2, 4, 8]
const TEN := 10
const ROTATION := 86400
## 招募券 a new save starts with (one 十連), and what each first clear of a stage gives.
const START_TICKETS := 10
const FIRST_TICKETS := 10
## The 免費單抽 a rewarded ad gives, once per day of the clock.
const AD_PULLS_PER_DAY := 1


static var _pools: Array = []


## Every hero of a rarity, in roster order (rarity at the start: a promoted N stays in the N pool).
static func pool(rarity: int) -> PackedInt32Array:
	if _pools.is_empty():
		var probe := PushSim.new()
		for r: int in 4:
			var heroes := PackedInt32Array()
			for i: int in probe.rarity.size():
				if probe.rarity[i] == r:
					heroes.append(i)
			_pools.append(heroes)
	return _pools[rarity]


## The banner's 限時 SSR at `now` (unix seconds).
static func featured(now: int) -> int:
	var ssr: PackedInt32Array = pool(PushSim.SSR)
	return ssr[(now / ROTATION) % ssr.size()]


## Seconds until the banner turns.
static func rotation_left(now: int) -> int:
	return ROTATION - now % ROTATION


static func clock_text(seconds: int) -> String:
	return "%02d:%02d:%02d" % [seconds / 3600, seconds / 60 % 60, seconds % 60]


## The 機率說明 lines, from RATES.
static func rates_lines() -> PackedStringArray:
	var out := PackedStringArray()
	for r: int in RATES.size():
		out.append("%s　%d%%　（每名英雄之魂：突破素材 ×%d）" % [PushSim.RARITY_NAMES[r], RATES[r], SHARDS[r]])
	out.append("SSR 之中 %d%% 是限時英雄" % roundi(FEATURED_SHARE * 100))
	out.append("連續 %d 抽沒有 SSR，第 %d 抽必出 SSR" % [PITY - 1, PITY])
	return out


## The day number of `now`, for the once-a-day ad pull.
static func day(now: int) -> int:
	return now / 86400
