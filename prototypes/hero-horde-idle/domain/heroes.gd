extends RefCounted
## 英雄的形態 (form), as pure data. Every hero is 人類, 怪獸 or 夢靈 on top of their class (push_sim.gd ROSTER): the
## class says where they stand in the push, the form gives a passive (both in the push and the march) and counts toward
## the march squad's 羈絆 (bonds). FORM_CYCLE spreads the forms over the roster index: 40 humans, 30 monsters,
## 30 dreamlings, every class holding all three.

const HUMAN := 0
const MONSTER := 1
const DREAM := 2
const FORM_NAMES := ["人類", "怪獸", "夢靈"]
const FORM_CYCLE := [HUMAN, MONSTER, DREAM, HUMAN, MONSTER, DREAM, HUMAN, MONSTER, DREAM, HUMAN]
const FORM_COLORS := [Color("6fa8dc"), Color("e69138"), Color("8fce6f")]

## 形態被動. 人類 戰技: damage x HUMAN_DAMAGE. 怪獸 吸血: heals MONSTER_LIFESTEAL of the damage it deals. 夢靈 夢癒:
## regains DREAM_REGEN of its max HP a second, and healing on it is x DREAM_HEAL_TAKEN.
const HUMAN_DAMAGE := 1.10
const MONSTER_LIFESTEAL := 0.08
const DREAM_REGEN := 0.015
const DREAM_HEAL_TAKEN := 1.25
const PASSIVE_NAMES := ["戰技", "吸血", "夢癒"]
const PASSIVE_TEXT := ["造成的傷害 +10%", "造成傷害的 8% 回復自己", "每秒回復 1.5% 生命，受到的治療 +25%"]

## 羈絆: BOND_AT heroes of one form in the march squad reach tier 1, 2, 3. 人類 attack, 怪獸 HP, 夢靈 less damage
## taken; one of each form (三族同行) adds TRIO to everything.
const BOND_AT := [2, 3, 5]
const BOND_VALUES := [[0.10, 0.18, 0.30], [0.15, 0.25, 0.40], [0.08, 0.14, 0.22]]
const BOND_TEXT := ["人類同行：攻擊 +%d%%", "怪獸同行：生命 +%d%%", "夢靈同行：受到傷害 −%d%%"]
const TRIO := 0.08
const TRIO_TEXT := "三族同行：全能力 +%d%%"


static func form(i: int) -> int:
	return FORM_CYCLE[i % FORM_CYCLE.size()]


## The bond tier (0 = none, 1-3) of `count` heroes of one form.
static func tier(count: int) -> int:
	var t: int = 0
	for k: int in BOND_AT.size():
		if count >= BOND_AT[k]:
			t = k + 1
	return t


## The march squad's bonds: {atk, hp, guard (share of damage taken away), trio, tiers: [per form], lines: [text]}.
static func bonds(heroes: PackedInt32Array) -> Dictionary:
	var counts := [0, 0, 0]
	for i: int in heroes:
		counts[form(i)] += 1
	var out := {"atk": 0.0, "hp": 0.0, "guard": 0.0, "trio": false, "tiers": [0, 0, 0], "counts": counts, "lines": []}
	for f: int in 3:
		var t: int = tier(counts[f])
		out.tiers[f] = t
		if t == 0:
			continue
		var v: float = BOND_VALUES[f][t - 1]
		match f:
			HUMAN: out.atk += v
			MONSTER: out.hp += v
			DREAM: out.guard += v
		out.lines.append(BOND_TEXT[f] % roundi(v * 100.0))
	if counts[0] > 0 and counts[1] > 0 and counts[2] > 0:
		out.trio = true
		out.atk += TRIO
		out.hp += TRIO
		out.lines.append(TRIO_TEXT % roundi(TRIO * 100.0))
	return out
