extends SceneTree
## Reproducible M3 refine-cost simulation; the drop-on-failure example is illustrative, not a game rule.

const Refine = preload("res://scripts/refine.gd")
const Ladder = preload("res://addons/proto_kit/refine_ladder.gd")
const Items = preload("res://scripts/items.gd")
const RUNS := 10000


func _initialize() -> void:
	var current: Array[Dictionary] = Refine.STEPS.duplicate(true)
	var fallback: Array[Dictionary] = current.duplicate(true)
	fallback[4].fail = {"drop:3": 1}
	print(JSON.stringify({"runs": RUNS, "seed": 73, "current_keep": _simulate(current),
		"illustration_drop_to_3_at_plus4": _simulate(fallback)}, "  "))
	quit()


func _simulate(steps: Array[Dictionary]) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 73
	var result: Dictionary = Ladder.new(steps).expected_stones(0, 6, rng, RUNS)
	var cost := 0.0
	for id: String in result.stones:
		cost += float(result.stones[id]) * int(Items.ALL[id].buy)
	result["gold"] = cost
	return result
