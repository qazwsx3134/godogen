extends RefCounted
## Refining worn equipment, +0 .. +6 (D10: mobile-friendly, no level loss and no destroyed items).
## Crystal steps always work; ruby steps can fail and then only the ruby is lost. Levels belong to an equipment
## instance. A repeated request sequence returns its recorded result, while an older request is rejected.

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


## Returns "" or why not: none (nothing worn), max, stone, stale. On "", result has ok and the new level.
## A negative request sequence allocates the next local command; callers may supply one for retries.
static func attempt(player: Node, slot: String, rng: RandomNumberGenerator, result: Dictionary = {}, request_seq: int = -1) -> String:
	var seq: int = player.refine_request_seq + 1 if request_seq < 0 else request_seq
	if seq > 0 and seq == player.refine_request_seq:
		result.merge(player.refine_last_result, true)
		return ""
	if seq <= player.refine_request_seq:
		return "stale"
	var id: String = player.equipped.get(slot, "")
	if id == "":
		return "none"
	var level: int = player.refine_level(slot)
	if level >= max_level():
		return "max"
	var stone: String = STEPS[level].stone
	if not player.bag.remove(stone, 1):
		return "stone"
	var r: Dictionary = ladder.attempt(level, rng)
	player.gear[slot].refine = r.level
	player.refine_request_seq = seq
	player.refine_last_result = {"ok": r.ok, "level": r.level, "stone": stone, "uid": player.gear[slot].uid}
	result.merge(player.refine_last_result, true)
	player.refresh_stats()
	return ""


## {atk, hp} a worn item gets from its refine level.
static func bonus(slot: String, level: int) -> Dictionary:
	var out := {}
	for stat: String in PER_LEVEL[slot]:
		out[stat] = PER_LEVEL[slot][stat] * level
	return out
