extends RefCounted
## 天賦: the army-wide talent tree, lit with gold (what a player holds is progression.gd `talent`, one level per
## node). 劍術 and 耐力 are the bulk of the strength, the role class levels had: one level of each costs together what
## raising every class a level did, for the same x1.08. The rest shape the idle side: 速度 (skill cooldowns), 休息
## (offline cap, march regen), 結伴 (march slots 3 -> 5), 拾光 (march gold); the three 專精 at the bottom of the tree
## make one 團 (PushSim.CLASS_SQUAD) stronger. Deeper in the tree: 學識 and 尋寶 (march EXP and drops), 鍛造 and 共鳴
## (the 職業武庫 weapons and the charms), 領袖 (the captains' boost), 劍聖 and 不屈 (a second attack and HP line), 迅捷
## (more cooldown) and 長征 (more offline hours). A node opens once `need` holds ({node: level}): those are the tree's
## edges (the 天賦 page draws them); a deeper node also waits for `stage` (stage bosses beaten, progression.gd
## `cleared`) and `level` (the highest hero level). Cost of level L -> L + 1: base x growth^L, or the node's own list.

const Stages = preload("res://domain/stages.gd")

const SWORD := 0
const STAMINA := 1
const SPEED := 2
const REST := 3
const COMPANY := 4
const FORTUNE := 5
const MELEE_SPEC := 6
const RANGED_SPEC := 7
const SUPPORT_SPEC := 8
const FORGE := 9
const RESONANCE := 10
const LEAD := 11
const STUDY := 12
const TREASURE := 13
const MASTER := 14
const UNYIELDING := 15
const SWIFT := 16
const LONG_MARCH := 17

const ROWS := [
	{"name": "劍術", "icon": "sword", "max": 200, "base": 3000.0, "growth": 1.08, "need": {},
		"text": "全軍攻擊 ×1.08（目前 ×%.2f）"},
	{"name": "耐力", "icon": "heart", "max": 200, "base": 3000.0, "growth": 1.08, "need": {},
		"text": "全軍生命 ×1.08（目前 ×%.2f）"},
	{"name": "速度", "icon": "boot", "max": 10, "base": 9000.0, "growth": 1.3, "need": {SWORD: 3},
		"text": "技能冷卻 −3%%（目前 −%d%%）"},
	{"name": "休息", "icon": "fire", "max": 4, "base": 12000.0, "growth": 1.8, "need": {STAMINA: 3},
		"text": "離線上限 +1 小時、行軍回血 +1%%／秒（目前 %d 小時）"},
	{"name": "結伴", "icon": "flag", "max": 2, "costs": [15000, 60000], "need": {SWORD: 5, STAMINA: 5},
		"text": "行軍上陣格 +1（目前 %d 格）"},
	{"name": "拾光", "icon": "coin", "max": 10, "base": 7000.0, "growth": 1.35, "need": {},
		"text": "行軍金幣 +10%%（目前 +%d%%）"},
	{"name": "近戰專精", "icon": "shield", "max": 10, "base": 100000.0, "growth": 1.7, "need": {SWORD: 10},
		"text": "近戰團（盾劍槍）攻擊與生命 ×1.02（目前 ×%.2f）"},
	{"name": "遠程專精", "icon": "equipment_item_1", "max": 10, "base": 100000.0, "growth": 1.7, "need": {SPEED: 2},
		"text": "遠程團（弓法）攻擊與生命 ×1.02（目前 ×%.2f）"},
	{"name": "輔助專精", "icon": "equipment_item_13", "max": 10, "base": 100000.0, "growth": 1.7, "need": {STAMINA: 10},
		"text": "輔助團（補）攻擊、生命與治療 ×1.02（目前 ×%.2f）"},
	{"name": "鍛造", "icon": "gear", "max": 10, "base": 50000.0, "growth": 1.5, "need": {MELEE_SPEC: 1}, "stage": 2,
		"level": 15, "text": "職業武庫的武器效果 +3%%（目前 +%d%%）"},
	{"name": "共鳴", "icon": "gem", "max": 10, "base": 50000.0, "growth": 1.5, "need": {SUPPORT_SPEC: 1}, "stage": 2,
		"level": 15, "text": "專屬飾品效果 +3%%（目前 +%d%%）"},
	{"name": "領袖", "icon": "portrait", "max": 5, "base": 80000.0, "growth": 1.8, "need": {TREASURE: 2}, "stage": 3,
		"level": 20, "text": "隊長給團的加成 +10%%（目前 +%d%%）"},
	{"name": "學識", "icon": "practice_dummy", "max": 10, "base": 20000.0, "growth": 1.4, "need": {COMPANY: 1}, "stage": 1,
		"level": 10, "text": "行軍經驗 +10%%（目前 +%d%%）"},
	{"name": "尋寶", "icon": "gift", "max": 10, "base": 30000.0, "growth": 1.45, "need": {STUDY: 3}, "stage": 2,
		"level": 15, "text": "行軍掉寶機率 +10%%（目前 +%d%%）"},
	{"name": "劍聖", "icon": "nav_0", "max": 50, "base": 400000.0, "growth": 1.12, "need": {FORGE: 3}, "stage": 4,
		"level": 25, "text": "全軍攻擊再 ×1.04（目前 ×%.2f）"},
	{"name": "不屈", "icon": "heart", "max": 50, "base": 400000.0, "growth": 1.12, "need": {RESONANCE: 3}, "stage": 4,
		"level": 25, "text": "全軍生命再 ×1.04（目前 ×%.2f）"},
	{"name": "迅捷", "icon": "item_5", "max": 5, "base": 300000.0, "growth": 1.6, "need": {RANGED_SPEC: 3}, "stage": 5,
		"level": 30, "text": "技能冷卻再 −2%%（目前 −%d%%）"},
	{"name": "長征", "icon": "item_3", "max": 2, "costs": [300000, 900000], "need": {REST: 4}, "stage": 5, "level": 30,
		"text": "離線上限再 +2 小時（目前 +%d 小時）"},
]
## The 團 (PushSim.MELEE, RANGED, SUPPORT) each 專精 node strengthens.
const SPEC_SQUAD := {MELEE_SPEC: 0, RANGED_SPEC: 1, SUPPORT_SPEC: 2}
const SPEC_STEP := 1.02
const STEP := 1.08
const SPEED_CD := 0.03
const REST_HOURS := 1
const REST_REGEN := 0.01
const BASE_SLOTS := 3
const FORTUNE_GOLD := 0.10
const FORGE_STEP := 0.03
const RESONANCE_STEP := 0.03
const LEAD_STEP := 0.10
const STUDY_EXP := 0.10
const TREASURE_LOOT := 0.10
const MASTER_STEP := 1.04
const SWIFT_CD := 0.02
const LONG_MARCH_HOURS := 2


static func count() -> int:
	return ROWS.size()


## Gold for row k from `level` to level + 1 (-1 at the top).
static func cost(k: int, level: int) -> int:
	var row: Dictionary = ROWS[k]
	if level >= row.max:
		return -1
	if row.has("costs"):
		return row.costs[level]
	return roundi(row.base * pow(row.growth, level))


## Whether row k is open with these levels, `cleared` stage bosses beaten and the highest hero at level `top`.
static func open(k: int, levels: PackedInt32Array, cleared: int, top: int) -> bool:
	return need_text(k, levels, cleared, top) == ""


## What row k still needs before it opens, e.g. "劍術 Lv3、打倒第3層樓層王、英雄 Lv15" ("" when open).
static func need_text(k: int, levels: PackedInt32Array, cleared: int, top: int) -> String:
	var parts := PackedStringArray()
	var need: Dictionary = ROWS[k].need
	for r: int in need:
		if levels[r] < need[r]:
			parts.append("%s Lv%d" % [ROWS[r].name, need[r]])
	if cleared < ROWS[k].get("stage", 0):
		parts.append("打倒%s樓層王" % Stages.label(ROWS[k].stage))
	if top < ROWS[k].get("level", 0):
		parts.append("英雄 Lv%d" % ROWS[k].level)
	return "、".join(parts)


## Row k's effect line at `levels`.
static func effect_text(k: int, levels: PackedInt32Array) -> String:
	var lv: int = levels[k]
	match k:
		SWORD, STAMINA: return ROWS[k].text % pow(STEP, lv)
		SPEED: return ROWS[k].text % roundi(SPEED_CD * lv * 100.0)
		REST: return ROWS[k].text % (8 + REST_HOURS * lv)
		COMPANY: return ROWS[k].text % (BASE_SLOTS + lv)
		FORTUNE: return ROWS[k].text % roundi(FORTUNE_GOLD * lv * 100.0)
		MELEE_SPEC, RANGED_SPEC, SUPPORT_SPEC: return ROWS[k].text % pow(SPEC_STEP, lv)
		FORGE: return ROWS[k].text % roundi(FORGE_STEP * lv * 100.0)
		RESONANCE: return ROWS[k].text % roundi(RESONANCE_STEP * lv * 100.0)
		LEAD: return ROWS[k].text % roundi(LEAD_STEP * lv * 100.0)
		STUDY: return ROWS[k].text % roundi(STUDY_EXP * lv * 100.0)
		TREASURE: return ROWS[k].text % roundi(TREASURE_LOOT * lv * 100.0)
		MASTER, UNYIELDING: return ROWS[k].text % pow(MASTER_STEP, lv)
		SWIFT: return ROWS[k].text % roundi(SWIFT_CD * lv * 100.0)
		LONG_MARCH: return ROWS[k].text % (LONG_MARCH_HOURS * lv)
	return ""


## The 專精 multiplier for a hero of 團 `squad`.
static func spec_mult(squad: int, levels: PackedInt32Array) -> float:
	for k: int in SPEC_SQUAD:
		if SPEC_SQUAD[k] == squad:
			return pow(SPEC_STEP, levels[k])
	return 1.0
