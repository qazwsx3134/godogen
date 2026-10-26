extends RefCounted
## Item definitions (read-only) and the drop tables that reference them.

## sell: what a shop pays per unit. buy: shop price (absent = not sold). slot/atk/hp: equipment.
## heal: fraction of max HP restored when used. sheet: paper-doll layer drawn while worn.
## pet: how much the pet likes it as food (pet_care's price scale; XP = price / 15 + 1, or / 20 + 2 from 80).
const ALL := {
	"jelly_gel": {"name": "蓬蓬凝膠", "stack": 20, "color": Color("9be36a"), "sell": 4, "pet": 90},
	"clover": {"name": "四葉草", "stack": 10, "color": Color("4fd18b"), "sell": 25},
	"apple": {"name": "草原蘋果", "stack": 10, "color": Color("ff6b5e"), "sell": 3, "buy": 10, "heal": 0.4, "pet": 160},
	"boar_tusk": {"name": "野豬長牙", "stack": 10, "color": Color("f2e6c9"), "sell": 12},
	"hound_fang": {"name": "獵犬尖牙", "stack": 10, "color": Color("c9d3e6"), "sell": 18},
	"crystal": {"name": "精煉水晶", "stack": 20, "color": Color("a8e6ff"), "sell": 10, "buy": 40},
	"ruby": {"name": "紅寶石", "stack": 10, "color": Color("ff3d6e"), "sell": 40, "buy": 160},
	"iron_sword": {"name": "鐵劍", "stack": 1, "color": Color("d7dde8"), "sell": 60, "buy": 300, "slot": "weapon", "atk": 6,
		"sheet": "res://resources/sheets/test_chibi_iron.tres"},
	"cloth_tunic": {"name": "布衣", "stack": 1, "color": Color("c8a36b"), "sell": 40, "buy": 200, "slot": "body", "hp": 25,
		"sheet": "res://resources/sheets/test_chibi_tunic.tres"},
}

## Paper-doll layer index per slot in player.tscn's Actor.layer_sheets ([outfit, hair, weapon]), and what an
## empty slot shows (the starter sword; no outfit).
const LAYER := {"body": 0, "weapon": 2}
const EMPTY_SHEET := {"body": "", "weapon": "res://resources/sheets/test_chibi_weapon.tres"}

## What the town shop sells, in display order.
const SHOP := ["apple", "crystal", "ruby", "iron_sword", "cloth_tunic"]

## Each entry rolls on its own: chance 0..1, count [min, max].
const DROPS := {
	"jelly": [
		{"id": "jelly_gel", "chance": 0.7, "count": [1, 2]},
		{"id": "apple", "chance": 0.15, "count": [1, 1]},
		{"id": "clover", "chance": 0.05, "count": [1, 1]},
		{"id": "crystal", "chance": 0.06, "count": [1, 1]},
	],
	"boar": [
		{"id": "boar_tusk", "chance": 0.4, "count": [1, 1]},
		{"id": "apple", "chance": 0.5, "count": [1, 2]},
	],
	"hound": [
		{"id": "hound_fang", "chance": 0.4, "count": [1, 1]},
		{"id": "clover", "chance": 0.1, "count": [1, 1]},
		{"id": "ruby", "chance": 0.08, "count": [1, 1]},
	],
}


static func roll(table_id: String, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in DROPS.get(table_id, []):
		if rng.randf() < e.chance:
			out.append({"id": e.id, "count": rng.randi_range(e.count[0], e.count[1])})
	return out


## Every drop table and shop id points at a defined item (content check, run by the tests).
static func broken_refs() -> Array[String]:
	var bad: Array[String] = []
	for id: String in SHOP:
		if not ALL.has(id) or not ALL[id].has("buy"):
			bad.append("shop -> %s" % id)
	for t: String in DROPS:
		for e: Dictionary in DROPS[t]:
			if not ALL.has(e.id):
				bad.append("%s -> %s" % [t, e.id])
	return bad
