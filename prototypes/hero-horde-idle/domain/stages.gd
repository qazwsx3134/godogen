extends RefCounted
## 樓層: the floor ladder, as pure data (the code calls a floor a stage). Floors are climbed in order, 第1層 up; beating
## a floor's 樓層王 opens the next. Every 樓層王 has two HP bars: the second is PushSim's phase 2 (faster, other
## moves), so breaking the first bar changes his moves. Each floor scales the
## boss for PushSim.new(seed, roster, stage(n)) and the push's rewards (progression.gd push_rewards):
##   hp, dmg   STEP to the power of the stage's place on the ladder (stage 1 is the reference push, x1), times EASE
##             for the first stages (a new player wins 1-1 at once and the next ones in a few pushes)
##   tempo     the gaps between his attacks, by region (< 1 = faster)
##   reward    gold and first-clear bonus scale with hp (a tougher boss pays more)
## The look of a stage (its region's tint, the boss's colour and name) is here too; every stage uses the same troll
## art, tinted, until each region has its own boss. tests/test_stages.gd measures the ladder with the bots.

const COUNT := 10
## Each stage's boss is this much tougher (HP and damage) than the one before.
const STEP := 2.2
## The first stages' boss is this much of the ladder's (1-1 to 1-3, then 2-1); the rest are x1. Measured with the bots:
## a player who dodges like a person wins 1-1 on the first push and each of the next in 3-4 pushes.
const EASE := [0.5, 0.5, 0.7, 0.8]
const REGIONS := [
	{"name": "黃昏要塞", "first": 1, "tempo": 1.0, "boss": "棍棒巨魔",
		"boss_tint": Color(1, 1, 1), "light": Color(1, 1, 1)},
	{"name": "霧沼古道", "first": 4, "tempo": 0.93, "boss": "沼地巨魔",
		"boss_tint": Color(0.78, 0.95, 0.82), "light": Color(0.78, 0.9, 1.0)},
	{"name": "熔岩裂谷", "first": 7, "tempo": 0.86, "boss": "熔岩巨魔",
		"boss_tint": Color(1.0, 0.72, 0.6), "light": Color(1.0, 0.78, 0.66)},
]
## The 推薦戰力 of a stage: the heroes' strength (progression.gd team_power()) a player who dodges like a person needs
## to win (measured: about 0.95 of the reference push at stage 1), scaled like the boss.
const RECOMMEND := 0.95
## 推薦戰力 from LATE_FROM on: x LATE, then x LATE_STEP more each floor (late_of).
const LATE_FROM := 4
const LATE := 1.6
const LATE_STEP := 1.03
## First clear of a stage: FIRST_GOLD x reward, FIRST_SHARDS.
const FIRST_GOLD := 15000.0
const FIRST_SHARDS := 2


## Region index (0-based) of stage n (1-based).
static func region(n: int) -> int:
	var r: int = 0
	for k: int in REGIONS.size():
		if n >= REGIONS[k].first:
			r = k
	return r


## Floor n's label, e.g. "第4層".
static func label(n: int) -> String:
	return "第%d層" % n


## Each floor's 樓層王 (the art is the region's troll, tinted).
const BOSSES := ["棍棒巨魔", "斷牙巨魔", "要塞巨魔王", "沼地巨魔", "苔背巨魔", "霧沼巨魔王", "熔岩巨魔", "焦岩巨魔", "炎角巨魔",
	"熔核巨魔王"]
## HP bars on a 樓層王's gauge; the bar under PushSim.PHASE2_AT is the angry one.
const BARS := 2


static func boss_name(n: int) -> String:
	return BOSSES[clampi(n - 1, 0, BOSSES.size() - 1)]


static func recommended(n: int) -> float:
	return RECOMMEND * pow(STEP, n - 1) * ease_of(n) * late_of(n)


## From 第4層 on the army needs more than the boss's scale alone: 士氣 fills at the attack rate, not by damage, so a
## strong late army gets no more 大招 than an early one (measured with the bots, 2026-10-28).
static func late_of(n: int) -> float:
	return 1.0 if n < LATE_FROM else LATE * pow(LATE_STEP, n - LATE_FROM)


static func ease_of(n: int) -> float:
	return EASE[n - 1] if n <= EASE.size() else 1.0


## What PushSim.new() takes, plus the reward scale.
static func stage(n: int) -> Dictionary:
	var scale: float = pow(STEP, n - 1)
	return {"n": n, "hp": scale * ease_of(n), "dmg": scale * ease_of(n), "tempo": REGIONS[region(n)].tempo, "reward": scale}
