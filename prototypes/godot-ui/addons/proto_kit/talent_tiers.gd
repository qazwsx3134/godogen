extends RefCounted
## Class talent trees in the classic three-tree style: a talent sits in a tree and a row, a row opens once
## `row_points` points are in the rows above it in that tree, a talent may need another one maxed first, and tree
## totals reach milestones (10 / 20 / 30 points) that change how spells play. Points come from talent XP earned by
## runs. Removing a point is refused when it would strand a talent lower in the tree. Several loadouts; reset is free.
## `const TalentTiers = preload("res://addons/proto_kit/talent_tiers.gd")`
##
##   var t := TalentTiers.new(talents, {"max_points": 51, "row_points": 5,
##       "milestones": {"arms": {10: "deep_wounds", 20: "sweeping", 30: "mortal_wounds"}},
##       "xp_curve": {"base": 80, "growth": 1.12}})
##   t.add_xp(TalentTiers.run_xp({"seconds": 128, "kills": 195, "bosses": 0, "victory": false}))
##   if t.can_add("cleave_dmg"): t.add("cleave_dmg")
##   var stats := t.stats()             # {"damage": 0.06, ...}: rank x per-rank effect, summed
##   t.milestones()                     # ["deep_wounds"]: what a spell checks to play differently
##
## Talent: {id, tree, row (0 = top), max_rank, effect: {stat: per rank}, requires: id (that talent maxed)}.

var max_points: int
var row_points: int
var points_earned: int = 0
var xp: float = 0.0
var loadout: int = 0

var _talents: Dictionary = {}
var _milestones: Dictionary = {}
var _xp_base: float
var _xp_growth: float
var _loadouts: Array = [{}]   # each: talent id -> rank


func _init(talents: Array[Dictionary], options: Dictionary = {}) -> void:
	for t: Dictionary in talents:
		_talents[t.id] = t
	max_points = int(options.get("max_points", 51))
	row_points = int(options.get("row_points", 5))
	_milestones = options.get("milestones", {})
	var curve: Dictionary = options.get("xp_curve", {})
	_xp_base = float(curve.get("base", 80.0))
	_xp_growth = float(curve.get("growth", 1.12))
	var count := int(options.get("loadouts", 3))
	_loadouts = []
	for i in maxi(1, count):
		_loadouts.append({})


## XP for one run. weights: per second survived, per kill, per boss, for a victory; mult: the zone's difficulty.
static func run_xp(run: Dictionary, weights: Dictionary = {}, mult: float = 1.0) -> float:
	var w := {"second": 0.2, "kill": 0.1, "boss": 15.0, "victory": 60.0}
	w.merge(weights, true)
	var total: float = float(run.get("seconds", 0.0)) * w.second + float(run.get("kills", 0)) * w.kill \
		+ float(run.get("bosses", 0)) * w.boss + (w.victory if run.get("victory", false) else 0.0)
	return total * mult


## XP needed for the next point.
func xp_to_next() -> float:
	return _xp_base * pow(_xp_growth, points_earned)


## Adds XP and returns how many points it earned (capped at max_points).
func add_xp(amount: float) -> int:
	xp += amount
	var gained := 0
	while points_earned < max_points and xp >= xp_to_next():
		xp -= xp_to_next()
		points_earned += 1
		gained += 1
	return gained


func rank(id: String) -> int:
	return _ranks().get(id, 0)


func spent(tree: String = "") -> int:
	var total := 0
	for id: String in _ranks():
		if tree == "" or _talents[id].tree == tree:
			total += _ranks()[id]
	return total


func available() -> int:
	return points_earned - spent()


func can_add(id: String) -> bool:
	if not _talents.has(id) or available() <= 0:
		return false
	var t: Dictionary = _talents[id]
	if rank(id) >= int(t.get("max_rank", 1)):
		return false
	if _points_above(t.tree, int(t.get("row", 0))) < int(t.get("row", 0)) * row_points:
		return false
	var need: String = t.get("requires", "")
	return need == "" or rank(need) >= int(_talents[need].get("max_rank", 1))


func add(id: String) -> bool:
	if not can_add(id):
		return false
	_ranks()[id] = rank(id) + 1
	return true


## Takes one point back unless a talent lower in the tree, or one that requires this one, would lose its access.
func can_remove(id: String) -> bool:
	if rank(id) <= 0:
		return false
	var ranks: Dictionary = _ranks().duplicate()
	ranks[id] -= 1
	return _valid(ranks)


func remove(id: String) -> bool:
	if not can_remove(id):
		return false
	_ranks()[id] -= 1
	if _ranks()[id] == 0:
		_ranks().erase(id)
	return true


func reset() -> void:
	_ranks().clear()


func use_loadout(index: int) -> void:
	loadout = clampi(index, 0, _loadouts.size() - 1)


## Summed effects of the active loadout: rank x per-rank value.
func stats() -> Dictionary:
	var out := {}
	for id: String in _ranks():
		for stat: String in _talents[id].get("effect", {}):
			out[stat] = out.get(stat, 0.0) + float(_talents[id].effect[stat]) * _ranks()[id]
	return out


## Milestone ids reached in the active loadout, in tree and threshold order.
func milestones() -> Array[String]:
	var out: Array[String] = []
	for tree: String in _milestones:
		var marks: Dictionary = _milestones[tree]
		var keys := marks.keys()
		keys.sort()
		for need in keys:
			if spent(tree) >= int(need):
				out.append(String(marks[need]))
	return out


func to_dict() -> Dictionary:
	return {"points": points_earned, "xp": xp, "loadout": loadout, "loadouts": _loadouts.duplicate(true)}


func from_dict(data: Dictionary) -> void:
	points_earned = int(data.get("points", 0))
	xp = float(data.get("xp", 0.0))
	var saved: Array = data.get("loadouts", [])
	for i in mini(saved.size(), _loadouts.size()):
		_loadouts[i] = {}
		for id in saved[i]:
			if _talents.has(id):
				_loadouts[i][id] = int(saved[i][id])
	use_loadout(int(data.get("loadout", 0)))


func _ranks() -> Dictionary:
	return _loadouts[loadout]


func _points_above(tree: String, row: int, ranks: Dictionary = {}) -> int:
	var source := ranks if not ranks.is_empty() else _ranks()
	var total := 0
	for id: String in source:
		var t: Dictionary = _talents[id]
		if t.tree == tree and int(t.get("row", 0)) < row:
			total += source[id]
	return total


func _valid(ranks: Dictionary) -> bool:
	for id: String in ranks:
		if ranks[id] <= 0:
			continue
		var t: Dictionary = _talents[id]
		var row := int(t.get("row", 0))
		var above := 0
		for other: String in ranks:
			var o: Dictionary = _talents[other]
			if o.tree == t.tree and int(o.get("row", 0)) < row:
				above += ranks[other]
		if above < row * row_points:
			return false
		var need: String = t.get("requires", "")
		if need != "" and ranks.get(need, 0) < int(_talents[need].get("max_rank", 1)):
			return false
	return true
