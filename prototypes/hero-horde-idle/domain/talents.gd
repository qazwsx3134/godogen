extends RefCounted
## 天賦: the army-wide talent tree, lit with gold (what a player holds is progression.gd `talent`, one level per
## node). 劍術 and 耐力 are the bulk of the strength, the role class levels had: one level of each costs together what
## raising every class a level did, for the same x1.08. The rest shape the idle side: 速度 (skill cooldowns), 休息
## (offline cap, march regen), 結伴 (march slots 3 -> 5), 拾光 (march gold); the three 專精 at the bottom of the tree
## make one 團 (PushSim.CLASS_SQUAD) stronger. A node opens once `need` holds ({node: level}): those are the tree's
## edges (the 天賦 page draws them). Cost of level L -> L + 1: base x growth^L, or the node's own list.

const SWORD := 0
const STAMINA := 1
const SPEED := 2
const REST := 3
const COMPANY := 4
const FORTUNE := 5
const MELEE_SPEC := 6
const RANGED_SPEC := 7
const SUPPORT_SPEC := 8

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


## Whether row k is open with these levels.
static func open(k: int, levels: PackedInt32Array) -> bool:
	var need: Dictionary = ROWS[k].need
	for r: int in need:
		if levels[r] < need[r]:
			return false
	return true


## What row k needs before it opens, e.g. "劍術 Lv3" ("" when open).
static func need_text(k: int, levels: PackedInt32Array) -> String:
	var parts := PackedStringArray()
	var need: Dictionary = ROWS[k].need
	for r: int in need:
		if levels[r] < need[r]:
			parts.append("%s Lv%d" % [ROWS[r].name, need[r]])
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
	return ""


## The 專精 multiplier for a hero of 團 `squad`.
static func spec_mult(squad: int, levels: PackedInt32Array) -> float:
	for k: int in SPEC_SQUAD:
		if SPEC_SQUAD[k] == squad:
			return pow(SPEC_STEP, levels[k])
	return 1.0
