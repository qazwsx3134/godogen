extends RefCounted
## Equipment refining (+0 .. +12) as a ladder of gambles: each step names the stone it needs, a success chance and
## what a failure does (keep the level and lose only the stone, fall back to a level, or destroy the item). Support
## items raise the chance; protection items swap a harsh failure for a fall to a safe level.
## `const RefineLadder = preload("res://addons/proto_kit/refine_ladder.gd")`
##
##   var ladder := RefineLadder.new()                      # Seal Online-like default, or RefineLadder.new(my_steps)
##   ladder.step(4)                                         # {"stone": "ruby", "chance": 0.6, "fail": {...}}
##   var r := ladder.attempt(4, rng, {"bonus": 0.05, "protect": {"floor": 7, "chance": 0.7}})
##   # r: {"ok", "level" (after), "destroyed", "stone"}
##   ladder.expected_stones(0, 9, rng)                     # Monte Carlo cost of reaching +9 from +0
##
## Step (Dictionary, index = the level being refined from): stone, chance (0..1), fail: {"keep": w, "drop:3": w,
## "destroy": w} weighted outcomes. "protect": a floor level and the chance the protection works; when it works, any
## failure that would go below the floor (or destroy) lands on the floor instead.

## Default steps after Seal Online's wiki: crystal +0..+3 always works; ruby +3..+6 at 70/60/50 % and only the ruby is
## lost; diamond +6..+9 drops to +3, to +2 or destroys; pink diamond +9..+12 destroys. The wiki gives no diamond or
## pink-diamond rates: those numbers are placeholders.
const DEFAULT_STEPS: Array[Dictionary] = [
	{"stone": "crystal", "chance": 1.0, "fail": {"keep": 1}},
	{"stone": "crystal", "chance": 1.0, "fail": {"keep": 1}},
	{"stone": "crystal", "chance": 1.0, "fail": {"keep": 1}},
	{"stone": "ruby", "chance": 0.7, "fail": {"keep": 1}},
	{"stone": "ruby", "chance": 0.6, "fail": {"keep": 1}},
	{"stone": "ruby", "chance": 0.5, "fail": {"keep": 1}},
	{"stone": "diamond", "chance": 0.45, "fail": {"drop:3": 1}},
	{"stone": "diamond", "chance": 0.35, "fail": {"drop:2": 1, "destroy": 1}},
	{"stone": "diamond", "chance": 0.25, "fail": {"destroy": 1}},
	{"stone": "pink_diamond", "chance": 0.2, "fail": {"destroy": 1}},
	{"stone": "pink_diamond", "chance": 0.15, "fail": {"destroy": 1}},
	{"stone": "pink_diamond", "chance": 0.1, "fail": {"destroy": 1}},
]

var steps: Array[Dictionary]


func _init(custom: Array[Dictionary] = []) -> void:
	steps = custom if not custom.is_empty() else DEFAULT_STEPS.duplicate(true)


func max_level() -> int:
	return steps.size()


## The step for refining from `level` to level + 1 ({} at the top).
func step(level: int) -> Dictionary:
	return steps[level] if level >= 0 and level < steps.size() else {}


func chance(level: int, bonus: float = 0.0) -> float:
	var s := step(level)
	return clampf(float(s.get("chance", 0.0)) + bonus, 0.0, 1.0) if not s.is_empty() else 0.0


## One try. options: bonus (added to the chance), protect {floor, chance}. Never changes anything on its own:
## the caller applies r.level / r.destroyed to its item and takes one r.stone from the bag.
func attempt(level: int, rng: RandomNumberGenerator, options: Dictionary = {}) -> Dictionary:
	var s := step(level)
	if s.is_empty():
		return {"ok": false, "level": level, "destroyed": false, "stone": ""}
	if rng.randf() < chance(level, float(options.get("bonus", 0.0))):
		return {"ok": true, "level": level + 1, "destroyed": false, "stone": s.stone}
	var outcome := _pick(s.get("fail", {"keep": 1}), rng)
	var after := level
	var destroyed := false
	if outcome == "destroy":
		destroyed = true
	elif outcome.begins_with("drop:"):
		after = mini(level, int(outcome.substr(5)))
	var protect: Dictionary = options.get("protect", {})
	if not protect.is_empty() and (destroyed or after < int(protect.floor)) and level >= int(protect.floor):
		if rng.randf() < float(protect.get("chance", 1.0)):
			destroyed = false
			after = int(protect.floor)
	return {"ok": false, "level": after, "destroyed": destroyed, "stone": s.stone}


## Average stones spent (per stone kind) and the share of runs that destroyed the item, refining from `from` until
## `to` (restarting from +0 after a destruction is not counted: a destroyed run just ends). For tuning tables.
func expected_stones(from: int, to: int, rng: RandomNumberGenerator, runs: int = 2000, options: Dictionary = {}) -> Dictionary:
	var stones := {}
	var destroyed := 0
	for i in runs:
		var level := from
		var guard := 0
		while level < to and guard < 10000:
			guard += 1
			var r := attempt(level, rng, options)
			stones[r.stone] = stones.get(r.stone, 0) + 1
			if r.destroyed:
				destroyed += 1
				break
			level = r.level
	for k in stones:
		stones[k] = float(stones[k]) / runs
	return {"stones": stones, "destroy_rate": float(destroyed) / runs}


static func _pick(weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var pick := rng.randf() * total
	for k in weights:
		pick -= float(weights[k])
		if pick < 0.0:
			return String(k)
	return String(weights.keys()[-1])
