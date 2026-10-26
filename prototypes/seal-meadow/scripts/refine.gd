extends RefCounted
## Refining worn equipment, +0 .. +6 (D10: mobile-friendly, no level loss and no destroyed items).
## Crystal steps always work; ruby steps can fail and then only the ruby is lost. One press = one roll on Combat's
## seeded rng, and the result is saved right away (Main.town_action), so a retry is a new attempt, not a reroll.
## ponytail: the level is kept per item id (owning two iron swords shares one level); add item instances when
## duplicate gear matters.

const Items = preload("res://scripts/items.gd")
const RefineLadder = preload("res://addons/proto_kit/refine_ladder.gd")

const STEPS: Array[Dictionary] = [
	{"stone": "crystal", "chance": 1.0, "fail": {"keep": 1}},
	{"stone": "crystal", "chance": 1.0, "fail": {"keep": 1}},
	{"stone": "crystal", "chance": 1.0, "fail": {"keep": 1}},
	{"stone": "ruby", "chance": 0.7, "fail": {"keep": 1}},
	{"stone": "ruby", "chance": 0.6, "fail": {"keep": 1}},
	{"stone": "ruby", "chance": 0.5, "fail": {"keep": 1}},
]
## Bonus per refine level, by slot.
const PER_LEVEL := {"weapon": {"atk": 2}, "body": {"hp": 8}}

static var ladder := RefineLadder.new(STEPS)


static func max_level() -> int:
	return STEPS.size()


## Returns "" or why not: none (nothing worn), max, stone. On "", result has ok and the new level.
static func attempt(player: Node, slot: String, rng: RandomNumberGenerator, result: Dictionary = {}) -> String:
	var id: String = player.equipped.get(slot, "")
	if id == "":
		return "none"
	var level: int = player.refine.get(id, 0)
	if level >= max_level():
		return "max"
	var stone: String = STEPS[level].stone
	if not player.bag.remove(stone, 1):
		return "stone"
	var r: Dictionary = ladder.attempt(level, rng)
	player.refine[id] = r.level
	result.merge({"ok": r.ok, "level": r.level, "stone": stone}, true)
	player.refresh_stats()
	return ""


## {atk, hp} a worn item gets from its refine level.
static func bonus(slot: String, level: int) -> Dictionary:
	var out := {}
	for stat: String in PER_LEVEL[slot]:
		out[stat] = PER_LEVEL[slot][stat] * level
	return out
